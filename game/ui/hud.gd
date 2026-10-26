class_name Hud
extends CanvasLayer
## On-screen text: a controls hint that fades once the player has tried them,
## and short story messages.

@onready var controls_hint: Label = $ControlsHint
@onready var message_label: Label = $Message

var _has_moved := false
var _has_flapped := false
var _message_tween: Tween


func _ready() -> void:
	message_label.modulate.a = 0.0
	_update_controls_hint()
	Game.input_device_changed.connect(func(_gamepad: bool) -> void: _update_controls_hint())


func _update_controls_hint() -> void:
	controls_hint.text = "Move: %s    Flap: %s    Pause: %s" % [
		Game.button_label("move"), Game.button_label("accept"), Game.button_label("start")]


func _unhandled_input(event: InputEvent) -> void:
	if controls_hint.modulate.a < 1.0:
		return
	if event.is_action_pressed("accept"):
		_has_flapped = true
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down") \
			or event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		_has_moved = true
	if _has_moved and _has_flapped:
		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(controls_hint, "modulate:a", 0.0, 1.0)


func show_message(text: String, hold_seconds := 4.0) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(message_label, "modulate:a", 1.0, 0.4)
	_message_tween.tween_interval(hold_seconds)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.8)
