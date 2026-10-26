class_name OptionsMenu
extends PanelContainer
## Volume and display options. Used from the title screen and the pause menu.
## Changes apply and save immediately. Decline goes back.

signal closed

var _rows: VBoxContainer
var _window_button: Button
var _fullscreen_button: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	add_child(_rows)
	var title := Label.new()
	title.text = "Options"
	title.theme_type_variation = &"HeaderLabel"
	_rows.add_child(title)
	_add_volume("Master volume", "master_volume")
	_add_volume("Music volume", "music_volume")
	_add_volume("Sound volume", "sfx_volume")
	_fullscreen_button = CheckButton.new()
	_fullscreen_button.text = "Fullscreen"
	_fullscreen_button.button_pressed = Settings.fullscreen
	_fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	_rows.add_child(_fullscreen_button)
	_window_button = Button.new()
	_window_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_window_button.pressed.connect(_on_window_size_pressed)
	_rows.add_child(_window_button)
	var back := Button.new()
	back.text = "Back"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(close)
	_rows.add_child(back)
	_refresh()
	visibility_changed.connect(_refresh)


func open() -> void:
	show()
	var first := _first_focusable(_rows)
	if first:
		first.grab_focus.call_deferred()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _add_volume(text: String, setting: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 110
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = Settings.get(setting)
	slider.custom_minimum_size = Vector2(110, 16)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(_on_volume_changed.bind(setting))
	row.add_child(slider)
	_rows.add_child(row)


func _on_volume_changed(value: float, setting: String) -> void:
	Settings.set(setting, value)
	Settings.commit()


func _on_fullscreen_toggled(on: bool) -> void:
	Settings.fullscreen = on
	Settings.commit()
	_refresh()


func _on_window_size_pressed() -> void:
	Settings.window_scale = Settings.window_scale % Settings.MAX_WINDOW_SCALE + 1
	Settings.commit()
	_refresh()


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL:
			return child
		var nested := _first_focusable(child)
		if nested:
			return nested
	return null


func _refresh() -> void:
	_window_button.text = "Window size: %dx" % Settings.window_scale
	_window_button.disabled = Settings.fullscreen
	_fullscreen_button.set_pressed_no_signal(Settings.fullscreen)
