class_name CardData
extends Resource
## One card: crystallised magic. See design doc sections 7-9.

enum Kind {
	PRAYER, ## The spell equivalent; adds a weapon-style loadout slot.
	PASSIVE, ## Stays active until the next reshuffle.
	ONE_TIME, ## Used once, then recovers over a cooldown.
}
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

const KIND_NAMES := {Kind.PRAYER: "Prayer", Kind.PASSIVE: "Passive", Kind.ONE_TIME: "One-time"}
const RARITY_NAMES := {
	Rarity.COMMON: "Common", Rarity.UNCOMMON: "Uncommon", Rarity.RARE: "Rare", Rarity.LEGENDARY: "Legendary",
}

## Stable id used in save files. Never change it once players have the card.
@export var id := ""
@export var display_name := ""
@export var kind := Kind.PASSIVE
@export var rarity := Rarity.COMMON
@export_multiline var description := ""
## Seconds before a one-time card can be used again.
@export var cooldown := 0.0


func kind_name() -> String:
	return KIND_NAMES.get(kind, "?")


func rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "?")
