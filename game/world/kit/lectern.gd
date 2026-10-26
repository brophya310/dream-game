@tool
class_name Lectern
extends KitPiece
## A wooden lectern holding an open, softly glowing book. In the library hub,
## opening a book on a lectern pulls the owl into the world inside it.

@export var book_color := Color(0.25, 0.35, 0.6):
	set(value):
		book_color = value
		queue_rebuild()
@export var glowing := true:
	set(value):
		glowing = value
		queue_rebuild()


func _build(mesh: ArrayMesh, rng: RandomNumberGenerator) -> void:
	var st := LowPoly.begin()
	var faces := LowPoly.VISIBLE_FACES
	var wood := LowPoly.vary(KitPalette.WOOD, rng, 0.05)
	LowPoly.box(st, Vector3(0, 0.04, 0), Vector3(0.62, 0.08, 0.5), KitPalette.WOOD_DARK, Basis.IDENTITY, faces)
	LowPoly.cylinder(st, Vector3(0, 0.08, 0), 0.1, 0.07, 0.86, 6, wood)
	var tilt := Basis(Vector3.RIGHT, 0.42)
	var board_center := Vector3(0, 1.0, 0)
	LowPoly.box(st, board_center, Vector3(0.78, 0.05, 0.56), wood.lightened(0.05), tilt, faces)
	LowPoly.box(st, board_center + tilt * Vector3(0, 0.05, 0.27), Vector3(0.78, 0.06, 0.03), KitPalette.WOOD_DARK, tilt, faces)
	# The open book's cover sits on the board; the pages glow on their own surface.
	LowPoly.box(st, board_center + tilt * Vector3(0, 0.035, 0), Vector3(0.66, 0.02, 0.46), book_color, tilt, faces)
	LowPoly.commit(st, mesh)

	var pages := LowPoly.begin()
	for side in [-1.0, 1.0]:
		var page_turn := tilt * Basis(Vector3.BACK, side * -0.09)
		LowPoly.box(pages, board_center + tilt * Vector3(side * 0.155, 0.06, 0), Vector3(0.3, 0.03, 0.42),
				KitPalette.PAGE, page_turn, faces)
	if glowing:
		LowPoly.commit(pages, mesh, LowPoly.glow(KitPalette.MAGIC_GLOW, 0.6))
	else:
		LowPoly.commit(pages, mesh)


func _after_build(_rng: RandomNumberGenerator) -> void:
	var light: OmniLight3D = _generated_child("Glow", OmniLight3D)
	light.visible = glowing
	light.position = Vector3(0, 1.35, 0.15)
	light.light_color = KitPalette.MAGIC_GLOW
	light.light_energy = 0.7
	light.omni_range = 2.5


func _collision_shape() -> Shape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.1, 0.5)
	return shape


func _collision_center() -> Vector3:
	return Vector3(0, 0.55, 0)
