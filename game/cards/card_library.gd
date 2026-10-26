class_name CardLibrary
extends RefCounted
## Every card in the game, looked up by id. Add new cards to CARDS.

const CARDS: Array[CardData] = [
	preload("res://game/cards/library/light.tres"),
	preload("res://game/cards/library/daze_dust.tres"),
]
## How many cards fit in a loadout (design doc section 8).
const DECK_SIZE := 10


static func get_card(card_id: String) -> CardData:
	for card in CARDS:
		if card.id == card_id:
			return card
	return null
