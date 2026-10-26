class_name EditDeck
extends PanelContainer
## "Edit Deck" from the pause menu (design doc section 8): shows the loadout
## (one die and up to 10 cards) and every card the owl owns, as card-style tiles.
## Accept moves a card in or out of the deck. Decline goes back.
## Opening it clears the "!" badge for new cards.

signal closed

var _summary: Label
var _grid: GridContainer
var _empty_note: Label
var _detail: Label
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(440, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Edit Deck"
	title.theme_type_variation = &"HeaderLabel"
	box.add_child(title)
	_summary = Label.new()
	box.add_child(_summary)
	_empty_note = Label.new()
	_empty_note.text = "No cards yet.\nMagic in the dream crystallises into cards: spells the owl remembers, and magic other creatures leave behind."
	_empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_note.custom_minimum_size.x = 400
	box.add_child(_empty_note)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_grid)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.x = 400
	box.add_child(_detail)
	_back = Button.new()
	_back.text = "Back"
	_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_back.pressed.connect(close)
	box.add_child(_back)


func open() -> void:
	SaveManager.clear_unseen("deck")
	_rebuild()
	show()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _rebuild(focus_card := "") -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var deck: Array = SaveManager.data.cards.deck if SaveManager.has_game() else []
	var owned := SaveManager.owned_cards()
	var die: String = SaveManager.data.cards.die if SaveManager.has_game() else ""
	_summary.text = "Die: %s     Deck: %d / %d cards" % [
		die if not die.is_empty() else "none", deck.size(), CardLibrary.DECK_SIZE]
	_empty_note.visible = owned.is_empty()
	_detail.text = ""

	var focus_target: Control = null
	for card_id: String in owned:
		var card := CardLibrary.get_card(card_id)
		if card == null:
			continue
		var tile := _card_tile(card, card_id in deck)
		_grid.add_child(tile)
		if card_id == focus_card or focus_target == null:
			focus_target = tile
	if focus_target == null:
		focus_target = _back
	focus_target.grab_focus.call_deferred()


func _card_tile(card: CardData, in_deck: bool) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(138, 74)
	tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.text = "%s\n%s, %s%s" % [
		card.display_name, card.kind_name(), card.rarity_name(), "\nIn deck" if in_deck else ""]
	tile.pressed.connect(_toggle_in_deck.bind(card.id))
	tile.focus_entered.connect(func() -> void: _detail.text = card.description)
	return tile


func _toggle_in_deck(card_id: String) -> void:
	if not SaveManager.has_game():
		return
	var deck: Array = SaveManager.data.cards.deck
	if card_id in deck:
		deck.erase(card_id)
	elif deck.size() < CardLibrary.DECK_SIZE:
		deck.append(card_id)
	Game.request_autosave()
	_rebuild(card_id)
