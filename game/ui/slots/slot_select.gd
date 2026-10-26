class_name SlotSelect
extends PanelContainer
## Pick a save slot, for a new game or to load one. Starting a new game on a
## used slot asks first. Decline goes back.

signal slot_chosen(slot: int)
signal closed

enum Mode { NEW_GAME, LOAD }

var mode := Mode.LOAD
var _title: Label
var _list: MenuList
var _confirm_slot := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	box.add_child(_title)
	_list = MenuList.new()
	_list.add_theme_constant_override("separation", 4)
	box.add_child(_list)


func open(new_mode: Mode) -> void:
	mode = new_mode
	_confirm_slot = -1
	_show_slots()
	show()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _confirm_slot >= 0:
		_cancel_confirm()
	else:
		close()


func _show_slots() -> void:
	_title.text = "New game: choose a slot" if mode == Mode.NEW_GAME else "Load game"
	var items := []
	for slot in SaveManager.SLOT_COUNT:
		var summary := SaveManager.slot_summary(slot)
		var usable: bool = summary.state == "ok" or mode == Mode.NEW_GAME
		items.append({
			"text": "Slot %d   %s" % [slot + 1, describe(summary)],
			"action": _on_slot_pressed.bind(slot, summary.state),
			"disabled": not usable,
		})
	items.append({"text": "Back", "action": close})
	_list.set_items(items)
	_list.focus_first()


func _on_slot_pressed(slot: int, state: String) -> void:
	if mode == Mode.NEW_GAME and state != "empty":
		_confirm_slot = slot
		_title.text = "Start over in slot %d? Its save will be replaced." % (slot + 1)
		_list.set_items([
			{"text": "No, keep it", "action": _cancel_confirm},
			{"text": "Yes, start over", "action": _choose.bind(slot)},
		])
		_list.focus_first()
		return
	_choose(slot)


func _cancel_confirm() -> void:
	_confirm_slot = -1
	_show_slots()


func _choose(slot: int) -> void:
	hide()
	slot_chosen.emit(slot)


## "Library  1:02:33  Oct 22", "Empty" or "Damaged".
static func describe(summary: Dictionary) -> String:
	match summary.state:
		"empty":
			return "Empty"
		"damaged":
			return "Damaged save"
	var seconds := int(summary.play_time)
	var played := "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	var date := Time.get_date_dict_from_unix_time(int(summary.saved_unix))
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s   %s   %s %d" % [summary.level_name, played, MONTHS[date.month - 1], date.day]
