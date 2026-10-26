class_name TestCase
extends Node
## Base for test scenes. Run one with:
##   godot --headless --path . --fixed-fps 60 res://tests/<name>.tscn
## It prints each check and exits with code 0 if all passed, 1 if any failed.
## Tests save into user://test_saves, never the player's real save slots.
## Add `-- --shots=/some/folder` (and drop --headless) to save screenshots.

const TEST_SAVE_DIR := "user://test_saves"
## Hard stop so a stuck test can't hang forever (seconds of game time).
const TIMEOUT := 120.0

var failures: Array[String] = []
var shots_dir := ""
var checks := 0
var _elapsed := 0.0
var _finished := false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.save_dir = TEST_SAVE_DIR
	Settings.path = TEST_SAVE_DIR.path_join("settings.cfg")
	_clear_test_saves()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT and not _finished:
		fail("Test timed out after %d seconds" % TIMEOUT)
		finish()


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("  ok    ", description)
	else:
		fail(description)


func fail(description: String) -> void:
	failures.append(description)
	print("  FAIL  ", description)


func finish() -> void:
	if _finished:
		return
	_finished = true
	Input.action_release("accept")
	_clear_test_saves()
	print("%s: %d checks, %d failed -> %s" % [name, checks, failures.size(), "PASSED" if failures.is_empty() else "FAILED"])
	get_tree().quit(0 if failures.is_empty() else 1)


func wait_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


## Waits until `condition` returns true. Returns false if it took too long.
func wait_until(condition: Callable, timeout := 10.0) -> bool:
	var waited := 0.0
	while not condition.call():
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
		if waited > timeout:
			return false
	return true


## Presses and releases a button the way a player would (goes through input events).
func tap(action: String) -> void:
	_send(action, true)
	await wait_frames(2)
	_send(action, false)
	await wait_frames(2)


## Saves a screenshot when running with --shots (does nothing headless).
func shot(shot_name: String) -> void:
	if shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(shot_name + ".png"))


func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _clear_test_saves() -> void:
	var dir := DirAccess.open(TEST_SAVE_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
