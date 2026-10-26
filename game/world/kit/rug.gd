@tool
class_name Rug
extends KitPiece
## A flat patterned rug. No collision: the owl walks over it.

@export var size := Vector2(3.0, 2.0):
	set(value):
		size = value
		queue_rebuild()
@export var border_color := Color(0.5, 0.2, 0.25):
	set(value):
		border_color = value
		queue_rebuild()
@export var field_color := Color(0.78, 0.5, 0.36):
	set(value):
		field_color = value
		queue_rebuild()


func _build(mesh: ArrayMesh, _rng: RandomNumberGenerator) -> void:
	var st := LowPoly.begin()
	var top := LowPoly.Face.TOP
	LowPoly.box(st, Vector3(0, 0.005, 0), Vector3(size.x, 0.01, size.y), border_color, Basis.IDENTITY, top)
	LowPoly.box(st, Vector3(0, 0.008, 0), Vector3(size.x - 0.24, 0.01, size.y - 0.24), field_color, Basis.IDENTITY, top)
	var diamond := minf(size.x, size.y) * 0.4
	LowPoly.box(st, Vector3(0, 0.011, 0), Vector3(diamond, 0.01, diamond), border_color.lightened(0.15),
			Basis(Vector3.UP, PI / 4), top)
	LowPoly.box(st, Vector3(0, 0.014, 0), Vector3(diamond * 0.45, 0.01, diamond * 0.45), KitPalette.GILT,
			Basis(Vector3.UP, PI / 4), top)
	LowPoly.commit(st, mesh)
