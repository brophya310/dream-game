extends Node
## Scene flow (title, intro, levels), fades, play time, autosaves and button
## prompts. Autoloaded as `Game`.

signal level_ready(level: Level)
signal input_device_changed(using_gamepad: bool)

const TITLE_SCENE := "res://game/ui/title/title_screen.tscn"
const INTRO_SCENE := "res://game/cutscenes/intro/intro_cutscene.tscn"
const FIRST_LEVEL := "res://game/levels/library_wake/library_wake.tscn"
const FIRST_SPAWN := "Start"
## Seconds to wait after something worth saving happens, so bursts become one save.
const AUTOSAVE_DELAY := 1.5
## Also save quietly this often during play, so a crash loses at most a minute.
const BACKGROUND_SAVE_SECONDS := 60.0
const FADE_SECONDS := 0.35

enum State { MENU, CUTSCENE, PLAYING, TRANSITION }

const KEY_LABELS := {"accept": "Z", "decline": "X", "start": "Enter", "move": "Arrows"}
const PAD_LABELS := {"accept": "A", "decline": "B", "start": "Start", "move": "D-pad"}

var state := State.MENU
var current_level: Level
var using_gamepad := false

var _pending_spawn := FIRST_SPAWN
var _pending_player: Dictionary = {}
var _fade: ColorRect
var _saved_label: Label
var _autosave_timer: Timer
var _since_last_save := 0.0
var _quiet_save := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_build_overlay()
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_DELAY
	_autosave_timer.timeout.connect(save_progress)
	add_child(_autosave_timer)
	SaveManager.saved.connect(_on_saved)


func _process(delta: float) -> void:
	if state == State.PLAYING and not get_tree().paused and SaveManager.has_game():
		SaveManager.data.play_time += delta
		_since_last_save += delta
		if _since_last_save >= BACKGROUND_SAVE_SECONDS:
			_quiet_save = true
			save_progress()
			_quiet_save = false


func _input(event: InputEvent) -> void:
	var gamepad := using_gamepad
	if event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
	if gamepad != using_gamepad:
		using_gamepad = gamepad
		input_device_changed.emit(using_gamepad)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


#region Flow

func go_to_title() -> void:
	await _change_scene(TITLE_SCENE)
	state = State.MENU


func start_new_game(slot_index: int) -> void:
	if SaveManager.new_game(slot_index) != OK:
		push_error("Couldn't create a save in slot %d" % (slot_index + 1))
		return
	state = State.TRANSITION
	await _change_scene(INTRO_SCENE)
	state = State.CUTSCENE


## Called by the intro cutscene when it ends or is skipped.
func finish_intro() -> void:
	await enter_level(FIRST_LEVEL, FIRST_SPAWN)


func continue_game(slot_index: int) -> bool:
	if not SaveManager.load_game(slot_index):
		return false
	var saved := SaveManager.data
	var path: String = saved.level_path
	if path.is_empty() or not ResourceLoader.exists(path):
		path = FIRST_LEVEL
	else:
		_pending_player = saved.player.duplicate()
	await enter_level(path, FIRST_SPAWN)
	return true


## Loads a level. The owl appears at the named spawn point, unless a game is
## being continued, in which case it appears exactly where it was saved.
func enter_level(path: String, spawn := FIRST_SPAWN) -> void:
	_pending_spawn = spawn
	state = State.TRANSITION
	await _change_scene(path)
	state = State.PLAYING


## Levels call this from _ready() so saved state is applied before anything moves.
func register_level(level: Level) -> void:
	current_level = level
	level.apply_save_state(SaveManager.level_state(level.level_id))
	if not _pending_player.is_empty():
		level.restore_player(_pending_player)
		_pending_player = {}
	else:
		level.spawn_player(_pending_spawn)
	if state != State.TRANSITION:
		state = State.PLAYING
	if SaveManager.has_game():
		save_progress()
	level_ready.emit(level)


func can_pause() -> bool:
	return state == State.PLAYING and current_level != null


func save_and_quit_to_title() -> void:
	save_progress()
	SaveManager.close_game()
	get_tree().paused = false
	await go_to_title()


func quit_game() -> void:
	if state == State.PLAYING:
		save_progress()
	get_tree().quit()

#endregion


#region Saving

## Saves now. Returns true if something was written.
func save_progress() -> bool:
	_autosave_timer.stop()
	if not SaveManager.has_game() or current_level == null or not is_instance_valid(current_level):
		return false
	var saved := SaveManager.data
	SaveManager.set_level_state(current_level.level_id, current_level.collect_save_state())
	saved.level_path = current_level.scene_file_path
	saved.level_name = current_level.display_name
	saved.player = current_level.player_state()
	return SaveManager.write() == OK


## Saves shortly, so several things happening at once become one save.
func request_autosave() -> void:
	if SaveManager.has_game():
		_autosave_timer.start()

#endregion


#region Button prompts

## The button to show for an action on the device the player is using.
func button_label(action: String) -> String:
	var labels := PAD_LABELS if using_gamepad else KEY_LABELS
	return labels.get(action, action)

#endregion


#region Overlay and scene changes

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.03, 0.09, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_saved_label = Label.new()
	_saved_label.text = "Saved"
	_saved_label.modulate.a = 0.0
	_saved_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_saved_label.offset_left = -60.0
	_saved_label.offset_top = -26.0
	_saved_label.offset_right = -10.0
	_saved_label.offset_bottom = -8.0
	_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saved_label.add_theme_font_size_override("font_size", 10)
	_saved_label.add_theme_constant_override("outline_size", 4)
	_saved_label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.16))
	layer.add_child(_saved_label)


func _on_saved(_slot: int) -> void:
	_since_last_save = 0.0
	if state != State.PLAYING or _quiet_save:
		return
	var tween := create_tween()
	tween.tween_property(_saved_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.0)
	tween.tween_property(_saved_label, "modulate:a", 0.0, 0.5)


func _change_scene(path: String) -> void:
	var previous := get_tree().current_scene
	await _fade_to(1.0)
	get_tree().paused = false
	current_level = null
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Couldn't load %s (error %d)" % [path, err])
		await _fade_to(0.0)
		return
	# The swap happens at the end of the frame; wait for the new scene.
	for i in 30:
		await get_tree().process_frame
		if get_tree().current_scene != previous and get_tree().current_scene != null:
			break
	await _fade_to(0.0)


func _fade_to(alpha: float) -> void:
	if is_equal_approx(_fade.color.a, alpha):
		return
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_SECONDS)
	await tween.finished
	if alpha == 0.0:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

#endregion
