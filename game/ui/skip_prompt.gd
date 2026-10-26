class_name SkipPrompt
extends Control
## "Hold to skip cutscene" in the bottom-right corner (design doc section 13):
## holding the action button fills a circle; when it's full, `skipped` fires.
## The button has to be let go once first, so a press carried over from the
## previous screen can't skip by accident.

signal skipped

@export var hold_seconds := 1.2

var progress := 0.0

var _armed := false
var _done := false
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -190.0
	offset_top = -34.0
	offset_right = -10.0
	offset_bottom = -10.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.theme_type_variation = &"LightLabel"
	_label.add_theme_font_size_override("font_size", 10)
	_label.position = Vector2(30, 4)
	add_child(_label)
	_update_label()
	Game.input_device_changed.connect(func(_gamepad: bool) -> void: _update_label())


func _process(delta: float) -> void:
	if _done:
		return
	var holding := Input.is_action_pressed("accept")
	if not holding:
		_armed = true
	if holding and _armed:
		progress = minf(progress + delta / hold_seconds, 1.0)
	else:
		progress = maxf(progress - delta * 2.0, 0.0)
	modulate.a = 0.55 + 0.45 * minf(progress * 3.0, 1.0)
	queue_redraw()
	if progress >= 1.0:
		_done = true
		skipped.emit()


func _draw() -> void:
	var center := Vector2(12, 12)
	draw_circle(center, 10, Color(0.12, 0.07, 0.16, 0.8))
	draw_arc(center, 10, 0, TAU, 24, Color(1, 0.97, 0.88, 0.35), 2.0)
	if progress > 0.0:
		draw_arc(center, 10, -PI / 2, -PI / 2 + TAU * progress, 24, Color(1, 0.8, 0.25), 2.0)
	var font := get_theme_default_font()
	var glyph := Game.button_label("accept")
	var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	draw_string(font, center + Vector2(-glyph_size.x / 2, 4), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.97, 0.88))


func _update_label() -> void:
	_label.text = "Hold to skip cutscene"
	queue_redraw()
