@tool
class_name ReadingTable
extends KitPiece
## A low-poly reading table with books and a candle on top.

@export var size := Vector2(1.6, 0.9):
	set(value):
		size = value
		queue_rebuild()
@export var candle := true:
	set(value):
		candle = value
		queue_rebuild()

const HEIGHT := 0.75


func _build(mesh: ArrayMesh, rng: RandomNumberGenerator) -> void:
	var st := LowPoly.begin()
	var faces := LowPoly.VISIBLE_FACES
	var wood := LowPoly.vary(KitPalette.WOOD_LIGHT, rng, 0.05)
	LowPoly.box(st, Vector3(0, HEIGHT - 0.04, 0), Vector3(size.x, 0.08, size.y), wood, Basis.IDENTITY, faces)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var leg := Vector3(x * (size.x / 2 - 0.1), (HEIGHT - 0.08) / 2, z * (size.y / 2 - 0.1))
			LowPoly.box(st, leg, Vector3(0.08, HEIGHT - 0.08, 0.08), KitPalette.WOOD_DARK, Basis.IDENTITY, faces)

	# A stack of books at one end and an open book in the middle.
	var stack_x := size.x / 2 - 0.35
	var y := HEIGHT
	for i in rng.randi_range(2, 4):
		var thickness := rng.randf_range(0.05, 0.09)
		LowPoly.box(st, Vector3(stack_x, y + thickness / 2, rng.randf_range(-0.05, 0.05)),
				Vector3(rng.randf_range(0.32, 0.42), thickness, rng.randf_range(0.24, 0.3)),
				LowPoly.vary(KitPalette.pick(KitPalette.SPINES, rng), rng),
				Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), faces, KitPalette.PAGE)
		y += thickness
	var open_turn := Basis(Vector3.UP, rng.randf_range(-0.4, 0.4))
	LowPoly.box(st, Vector3(-0.15, HEIGHT + 0.01, 0), Vector3(0.5, 0.02, 0.34), KitPalette.pick(KitPalette.SPINES, rng), open_turn, faces)
	LowPoly.box(st, Vector3(-0.15, HEIGHT + 0.03, 0), Vector3(0.46, 0.025, 0.3), KitPalette.PAGE, open_turn, faces)

	if candle:
		var candle_spot := Vector3(-size.x / 2 + 0.22, HEIGHT, -size.y / 2 + 0.2)
		LowPoly.cylinder(st, candle_spot, 0.07, 0.07, 0.02, 6, KitPalette.GILT)
		LowPoly.cylinder(st, candle_spot + Vector3(0, 0.02, 0), 0.035, 0.035, 0.14, 5, KitPalette.PAGE)
	LowPoly.commit(st, mesh)

	if candle:
		var flame := LowPoly.begin()
		var flame_spot := Vector3(-size.x / 2 + 0.22, HEIGHT + 0.16, -size.y / 2 + 0.2)
		LowPoly.cylinder(flame, flame_spot, 0.025, 0.0, 0.07, 4, KitPalette.LAMP_GLOW, false)
		LowPoly.commit(flame, mesh, LowPoly.glow(KitPalette.LAMP_GLOW, 2.0))


func _after_build(_rng: RandomNumberGenerator) -> void:
	var light: OmniLight3D = _generated_child("CandleLight", OmniLight3D)
	light.visible = candle
	light.position = Vector3(-size.x / 2 + 0.22, HEIGHT + 0.35, -size.y / 2 + 0.2)
	light.light_color = KitPalette.LAMP_GLOW
	light.light_energy = 0.8
	light.omni_range = 2.2


func _collision_shape() -> Shape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, HEIGHT, size.y)
	return shape


func _collision_center() -> Vector3:
	return Vector3(0, HEIGHT / 2, 0)
