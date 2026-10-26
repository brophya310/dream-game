@tool
class_name BookPile
extends KitPiece
## A small heap of books on the floor. Solid, but the gust doesn't move it
## (use the GustProp books for that).

@export_range(2, 8) var count := 4:
	set(value):
		count = value
		queue_rebuild()


func _build(mesh: ArrayMesh, rng: RandomNumberGenerator) -> void:
	var st := LowPoly.begin()
	var y := 0.0
	for i in count:
		var book := Vector3(rng.randf_range(0.35, 0.55), rng.randf_range(0.06, 0.12), rng.randf_range(0.25, 0.4))
		var spot := Vector3(rng.randf_range(-0.08, 0.08), y + book.y / 2, rng.randf_range(-0.08, 0.08))
		LowPoly.box(st, spot, book, LowPoly.vary(KitPalette.pick(KitPalette.SPINES, rng), rng),
				Basis(Vector3.UP, rng.randf_range(-0.6, 0.6)), LowPoly.VISIBLE_FACES, KitPalette.PAGE)
		y += book.y
	LowPoly.commit(st, mesh)


func _collision_shape() -> Shape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55, 0.1 * count, 0.45)
	return shape


func _collision_center() -> Vector3:
	return Vector3(0, 0.05 * count, 0)
