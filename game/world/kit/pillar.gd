@tool
class_name Pillar
extends KitPiece
## A chunky octagonal stone column.

@export var height := 4.0:
	set(value):
		height = value
		queue_rebuild()


func _build(mesh: ArrayMesh, rng: RandomNumberGenerator) -> void:
	var st := LowPoly.begin()
	var faces := LowPoly.VISIBLE_FACES
	var stone := LowPoly.vary(KitPalette.STONE, rng, 0.04)
	LowPoly.box(st, Vector3(0, 0.12, 0), Vector3(0.95, 0.24, 0.95), KitPalette.STONE_DARK, Basis.IDENTITY, faces)
	LowPoly.cylinder(st, Vector3(0, 0.24, 0), 0.34, 0.3, height - 0.5, 8, stone)
	LowPoly.box(st, Vector3(0, height - 0.13, 0), Vector3(1.0, 0.26, 1.0), KitPalette.STONE_DARK, Basis.IDENTITY, faces)
	LowPoly.commit(st, mesh)


func _collision_shape() -> Shape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, height, 0.8)
	return shape


func _collision_center() -> Vector3:
	return Vector3(0, height / 2, 0)
