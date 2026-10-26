extends Node3D
## Title screen: the game's name over a slowly drifting library diorama.
## Press Start, then Continue / New game / Load game / Options / Quit.

enum Screen { PRESS_START, MAIN, SLOTS, OPTIONS, LEAVING }

var _screen := Screen.PRESS_START
var _time := 0.0

@onready var camera_focus: Node3D = $Backdrop/CameraFocus
@onready var press_start: Label = $UI/PressStart
@onready var main_panel: PanelContainer = $UI/Center/MainPanel
@onready var menu: MenuList = $UI/Center/MainPanel/Menu
@onready var slots: SlotSelect = $UI/Center/SlotSelect
@onready var options: OptionsMenu = $UI/Center/Options


func _ready() -> void:
	Game.state = Game.State.MENU
	main_panel.hide()
	slots.hide()
	options.hide()
	slots.slot_chosen.connect(_on_slot_chosen)
	slots.closed.connect(_show_main)
	options.closed.connect(_show_main)
	Game.input_device_changed.connect(func(_gamepad: bool) -> void: _update_press_start())
	_update_press_start()


func _process(delta: float) -> void:
	_time += delta
	camera_focus.position.x = sin(_time * 0.12) * 2.5
	press_start.modulate.a = 0.6 + 0.4 * sin(_time * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	match _screen:
		Screen.PRESS_START:
			if event.is_action_pressed("start") or event.is_action_pressed("accept") or event.is_action_pressed("ui_accept"):
				get_viewport().set_input_as_handled()
				_show_main()
		Screen.MAIN:
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				_show_press_start()


func _show_press_start() -> void:
	_screen = Screen.PRESS_START
	main_panel.hide()
	press_start.show()


func _show_main() -> void:
	_screen = Screen.MAIN
	press_start.hide()
	main_panel.show()
	var recent := SaveManager.most_recent_slot()
	var has_saves := recent >= 0
	menu.set_items([
		{"text": "Continue", "action": _continue.bind(recent), "disabled": not has_saves},
		{"text": "New game", "action": _open_slots.bind(SlotSelect.Mode.NEW_GAME)},
		{"text": "Load game", "action": _open_slots.bind(SlotSelect.Mode.LOAD), "disabled": not has_saves},
		{"text": "Options", "action": _open_options},
		{"text": "Quit", "action": Game.quit_game},
	])
	menu.focus_first()


func _open_slots(mode: SlotSelect.Mode) -> void:
	_screen = Screen.SLOTS
	main_panel.hide()
	slots.open(mode)


func _open_options() -> void:
	_screen = Screen.OPTIONS
	main_panel.hide()
	options.open()


func _continue(slot: int) -> void:
	_screen = Screen.LEAVING
	main_panel.hide()
	if not await Game.continue_game(slot):
		_show_main()


func _on_slot_chosen(slot: int) -> void:
	_screen = Screen.LEAVING
	if slots.mode == SlotSelect.Mode.NEW_GAME:
		Game.start_new_game(slot)
	elif not await Game.continue_game(slot):
		_show_main()


func _update_press_start() -> void:
	press_start.text = "Press %s" % Game.button_label("start")
