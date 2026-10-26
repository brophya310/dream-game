class_name PauseMenu
extends CanvasLayer
## Opens with Start during play and pauses the game (design doc sections 6 and 8).
## Directions + Accept to choose, Decline or Start to resume. Levels add this
## automatically.

var _dim: ColorRect
var _main: PanelContainer
var _list: MenuList
var _info: Label
var _options: OptionsMenu
var _deck: EditDeck


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("start") and Game.can_pause() and not get_tree().paused:
			get_viewport().set_input_as_handled()
			open()
		return
	if _options.visible or _deck.visible:
		return
	if event.is_action_pressed("start") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	get_tree().paused = true
	visible = true
	_show_main()


func close() -> void:
	visible = false
	_options.hide()
	_deck.hide()
	get_tree().paused = false


func is_open() -> bool:
	return visible


func _show_main() -> void:
	_main.show()
	_refresh_info()
	var quit_text := "Save and quit to title" if SaveManager.has_game() else "Quit to title"
	_list.set_items([
		{"text": "Resume", "action": close},
		{"text": "Edit Deck", "action": _open_deck, "badge": SaveManager.has_unseen("deck")},
		{"text": "Options", "action": _open_options},
		{"text": quit_text, "action": _quit_to_title},
		{"text": "Quit game", "action": Game.quit_game},
	])
	_list.focus_first()


func _refresh_info() -> void:
	var level := Game.current_level
	var lines: Array[String] = []
	lines.append(level.display_name if level else "Somewhere in the dream")
	if level and not level.progress_summary().is_empty():
		lines.append(level.progress_summary())
	if SaveManager.has_game():
		var seconds := int(SaveManager.data.play_time)
		lines.append("Play time %d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60])
		lines.append("Slot %d" % (SaveManager.slot + 1))
	_info.text = "\n".join(lines)


func _open_deck() -> void:
	_main.hide()
	_deck.open()


func _open_options() -> void:
	_main.hide()
	_options.open()


func _quit_to_title() -> void:
	visible = false
	Game.save_and_quit_to_title()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.03, 0.1, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)

	_main = PanelContainer.new()
	row.add_child(_main)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_main.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.theme_type_variation = &"HeaderLabel"
	box.add_child(title)
	# A card-style info display, per the design doc's UI direction.
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(1, 0.96, 0.88)
	card_style.border_color = Color(0.93, 0.7, 0.3)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(3)
	card_style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", card_style)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 10)
	card.add_child(_info)
	box.add_child(card)
	_list = MenuList.new()
	_list.add_theme_constant_override("separation", 4)
	box.add_child(_list)

	_options = OptionsMenu.new()
	_options.hide()
	_options.closed.connect(_show_main)
	row.add_child(_options)
	_deck = EditDeck.new()
	_deck.hide()
	_deck.closed.connect(_show_main)
	row.add_child(_deck)
