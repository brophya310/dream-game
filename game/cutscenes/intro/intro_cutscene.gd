extends Control
## Opening cutscene (design doc section 13). PLACEHOLDER: text panels stand in
## for the pixel artwork, soundtrack and voiceover. Panels advance on their own;
## holding the action button skips the whole thing.

## Each panel: text, a background colour, and how long it stays up.
const PANELS := [
	{"text": "Somewhere far from here, a great mage closed his eyes.", "color": Color(0.08, 0.06, 0.16), "seconds": 4.0},
	{"text": "He opened them in a library that could not exist.\nGrass grew between the shelves.", "color": Color(0.1, 0.14, 0.12), "seconds": 4.5},
	{"text": "His hands were wings. His eyes were wide and watchful.\nHe was, it seemed, an owl.", "color": Color(0.16, 0.1, 0.08), "seconds": 4.5},
	{"text": "Far above the stacks, something with burning eyes was circling.", "color": Color(0.18, 0.06, 0.08), "seconds": 4.0},
]
const FADE := 0.6

var _index := -1
var _finished := false

@onready var background: ColorRect = $Background
@onready var text_label: Label = $Text
@onready var skip_prompt: SkipPrompt = $SkipPrompt


func _ready() -> void:
	skip_prompt.skipped.connect(_finish)
	text_label.modulate.a = 0.0
	_next_panel()


func _next_panel() -> void:
	if _finished:
		return
	_index += 1
	if _index >= PANELS.size():
		_finish()
		return
	var panel: Dictionary = PANELS[_index]
	var tween := create_tween()
	if _index > 0:
		tween.tween_property(text_label, "modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void: text_label.text = panel.text)
	tween.parallel().tween_property(background, "color", panel.color, FADE)
	tween.tween_property(text_label, "modulate:a", 1.0, FADE)
	tween.tween_interval(panel.seconds)
	tween.tween_callback(_next_panel)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Game.finish_intro()
