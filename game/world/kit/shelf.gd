@tool
class_name Shelf
extends KitPiece
## A low-poly bookshelf packed with individual books. Change `size` and it
## rebuilds. The node's origin is the centre of the shelf's base; books face
## south (+Z), toward the camera.

## Target height of one row of books; rows stretch to fill the shelf.
const ROW_HEIGHT := 0.6

@export var size := Vector3(4.0, 2.25, 1.0):
	set(value):
		size = value
		queue_rebuild()


func _build(mesh: ArrayMesh, rng: RandomNumberGenerator) -> void:
	var st := LowPoly.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var faces := LowPoly.VISIBLE_FACES
	var wood := LowPoly.vary(KitPalette.WOOD, rng, 0.05)

	# Frame: back panel, sides, top with a small overhang, and a plinth.
	LowPoly.box(st, Vector3(0, h / 2, -d / 2 + 0.04), Vector3(w, h, 0.08), KitPalette.WOOD_DARK, Basis.IDENTITY, faces)
	for side in [-1.0, 1.0]:
		LowPoly.box(st, Vector3(side * (w / 2 - 0.05), h / 2, 0), Vector3(0.1, h, d), wood, Basis.IDENTITY, faces)
	LowPoly.box(st, Vector3(0, h - 0.05, 0), Vector3(w + 0.06, 0.1, d + 0.06), wood.lightened(0.06), Basis.IDENTITY, faces)
	LowPoly.box(st, Vector3(0, 0.06, -0.02), Vector3(w - 0.02, 0.12, d - 0.04), KitPalette.WOOD_DARK, Basis.IDENTITY, faces)

	var bottom := 0.12
	var top := h - 0.1
	var rows := maxi(1, floori((top - bottom) / ROW_HEIGHT))
	var row_height := (top - bottom) / rows
	for row in rows:
		var floor_y := bottom + row * row_height
		if row > 0:
			LowPoly.box(st, Vector3(0, floor_y, 0), Vector3(w - 0.2, 0.05, d - 0.06), wood, Basis.IDENTITY, faces)
		_fill_row(st, rng, floor_y + 0.025, row_height - 0.07, w - 0.2, d - 0.12)
	LowPoly.commit(st, mesh)


## Lines one shelf row with books of random sizes and colours, with the odd gap
## holding a little stack of books lying flat.
func _fill_row(st: SurfaceTool, rng: RandomNumberGenerator, y: float, max_height: float, width: float, depth: float) -> void:
	var back := -size.z / 2 + 0.08
	var x := -width / 2
	while x < width / 2 - 0.06:
		if rng.randf() < 0.05:
			var gap := minf(rng.randf_range(0.2, 0.4), width / 2 - x)
			if gap >= 0.2:
				_flat_stack(st, rng, Vector3(x + gap / 2, y, back + depth * 0.4), gap * 0.9, depth * 0.7, max_height)
			x += gap
			continue
		var book_width := rng.randf_range(0.07, 0.15)
		if x + book_width > width / 2:
			break
		var book_height := rng.randf_range(0.55, 0.95) * max_height
		var book_depth := rng.randf_range(0.6, 0.9) * depth
		var color := LowPoly.vary(KitPalette.pick(KitPalette.SPINES, rng), rng)
		var center := Vector3(x + book_width / 2, y + book_height / 2, back + book_depth / 2)
		LowPoly.box(st, center, Vector3(book_width, book_height, book_depth), color,
				Basis.IDENTITY, LowPoly.VISIBLE_FACES, KitPalette.PAGE_SHADE)
		if rng.randf() < 0.35:
			var band_y := center.y + book_height * rng.randf_range(0.2, 0.35)
			LowPoly.box(st, Vector3(center.x, band_y, center.z + book_depth / 2 + 0.003),
					Vector3(book_width, 0.03, 0.006), KitPalette.GILT, Basis.IDENTITY, LowPoly.Face.FRONT)
		x += book_width + 0.004


func _flat_stack(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, width: float, depth: float, max_height: float) -> void:
	var y := base.y
	for i in rng.randi_range(1, 3):
		var thickness := rng.randf_range(0.05, 0.09)
		if y + thickness - base.y > max_height:
			break
		var turn := Basis(Vector3.UP, rng.randf_range(-0.15, 0.15))
		LowPoly.box(st, Vector3(base.x, y + thickness / 2, base.z),
				Vector3(width * rng.randf_range(0.8, 1.0), thickness, depth * rng.randf_range(0.8, 1.0)),
				LowPoly.vary(KitPalette.pick(KitPalette.SPINES, rng), rng), turn, LowPoly.VISIBLE_FACES, KitPalette.PAGE)
		y += thickness


func _collision_shape() -> Shape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


func _collision_center() -> Vector3:
	return Vector3(0, size.y / 2, 0)
