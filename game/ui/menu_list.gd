class_name MenuList
extends VBoxContainer
## A vertical list of menu buttons driven by directions + Accept. Navigation
## wraps from the bottom to the top. Items can show a "!" badge for new things.


## items: [{"text": String, "action": Callable, "disabled": bool, "badge": bool}]
func set_items(items: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var buttons: Array[Button] = []
	for item: Dictionary in items:
		var button := Button.new()
		button.text = item.text
		button.name = String(item.text).validate_node_name()
		button.disabled = item.get("disabled", false)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if item.has("action"):
			button.pressed.connect(item.action)
		if item.get("badge", false):
			_add_badge(button)
		add_child(button)
		if not button.disabled:
			buttons.append(button)
	# Wrap around at the ends.
	for i in buttons.size():
		var up := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var down := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(up)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(down)
		buttons[i].focus_previous = buttons[i].focus_neighbor_top
		buttons[i].focus_next = buttons[i].focus_neighbor_bottom


func focus_first() -> void:
	for child in get_children():
		if child is Button and not child.disabled:
			child.grab_focus.call_deferred()
			return


func button(text: String) -> Button:
	return get_node_or_null(text.validate_node_name()) as Button


func _add_badge(button_node: Button) -> void:
	var badge := Label.new()
	badge.text = "!"
	badge.add_theme_color_override("font_color", Color(0.85, 0.3, 0.2))
	badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	badge.offset_left = -14.0
	badge.offset_right = -4.0
	badge.offset_top = -9.0
	badge.offset_bottom = 9.0
	button_node.add_child(badge)
