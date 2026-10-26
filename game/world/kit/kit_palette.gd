class_name KitPalette
extends RefCounted
## Placeholder colours for the library environment kit (sRGB, as seen on screen).
## The design doc says each region's palette comes from its concept page; swap
## these when the library's colours are decided.

const WOOD := Color(0.45, 0.29, 0.18)
const WOOD_DARK := Color(0.28, 0.17, 0.11)
const WOOD_LIGHT := Color(0.58, 0.39, 0.24)
const PAGE := Color(0.95, 0.9, 0.78)
const PAGE_SHADE := Color(0.84, 0.78, 0.66)
const GILT := Color(0.93, 0.78, 0.42)
const STONE := Color(0.66, 0.62, 0.7)
const STONE_DARK := Color(0.5, 0.47, 0.56)
const LAMP_GLOW := Color(1.0, 0.82, 0.55)
const MAGIC_GLOW := Color(0.98, 0.93, 0.72)

const SPINES: Array[Color] = [
	Color(0.6, 0.22, 0.27), Color(0.25, 0.35, 0.6), Color(0.3, 0.52, 0.4), Color(0.82, 0.64, 0.32),
	Color(0.5, 0.33, 0.6), Color(0.76, 0.44, 0.3), Color(0.88, 0.83, 0.7), Color(0.2, 0.45, 0.52),
	Color(0.38, 0.26, 0.42),
]
## Big, dark covers for the giant books that make up the cliffs.
const COVERS: Array[Color] = [
	Color(0.42, 0.18, 0.22), Color(0.2, 0.27, 0.45), Color(0.24, 0.38, 0.3), Color(0.5, 0.36, 0.2),
	Color(0.33, 0.22, 0.4),
]


static func pick(colors: Array[Color], rng: RandomNumberGenerator) -> Color:
	return colors[rng.randi() % colors.size()]
