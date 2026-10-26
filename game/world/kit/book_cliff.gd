@tool
class_name BookCliff
extends KitPiece
## A cliff of giant books stacked flat, used for walls and raised ground
## ("book-cliffs" in the design doc). Long cliffs are made of several stacks
## side by side, each a little different in height. The node's origin is the
## centre of its base; collision is a simple box of `size`.

@export var size := Vector3(4.0, 3.0, 2.0):
	set(value):
		size = value
		queue_rebuild()
## Small books scattered on top, per square unit of top surface.
@export_range(0.0, 1.0) var clutter := 0.12:
	set(value):
		clutter = value
		queue_rebuild()


func _build(mesh: ArrayMesh, rng: RandomNumberGenerator) -> void:
	var st := LowPoly.begin()
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var width := size.z if along_x else size.x
	var start := -length / 2.0
	while start < length / 2.0 - 0.01:
		var segment := minf(rng.randf_range(2.5, 5.0), length / 2.0 - start)
		if length / 2.0 - start - segment < 1.5:
			segment = length / 2.0 - start
		var height := maxf(size.y + rng.randf_range(-0.3, 0.05), 0.3)
		_stack(st, rng, start + segment / 2.0, segment, width, height, along_x)
		start += segment
	LowPoly.commit(st, mesh)


## One stack of giant books occupying part of the cliff's length.
func _stack(st: SurfaceTool, rng: RandomNumberGenerator, center_along: float, length: float,
		width: float, height: float, along_x: bool) -> void:
	var to_3d := func(along: float, up: float, across: float) -> Vector3:
		return Vector3(along, up, across) if along_x else Vector3(across, up, along)
	var y := 0.0
	while y < height - 0.05:
		var thickness := minf(rng.randf_range(0.35, 0.65), height - y)
		if height - y - thickness < 0.2:
			thickness = height - y
		var slab_length := length - rng.randf_range(0.04, 0.2)
		var slab_width := width - rng.randf_range(0.0, 0.14)
		var center: Vector3 = to_3d.call(center_along + rng.randf_range(-0.05, 0.05), y + thickness / 2,
				rng.randf_range(-0.04, 0.04))
		var slab: Vector3 = to_3d.call(slab_length, thickness, slab_width).abs()
		var turn := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2) / length)
		_giant_book(st, rng, center, slab, turn)
		y += thickness
	# A few ordinary-sized books left lying on top.
	var count := mini(int(length * width * clutter), 12)
	for i in count:
		var book := Vector3(rng.randf_range(0.25, 0.5), rng.randf_range(0.05, 0.1), rng.randf_range(0.18, 0.35))
		var spot: Vector3 = to_3d.call(center_along + rng.randf_range(-0.5, 0.5) * (length - 0.6), height + book.y / 2,
				rng.randf_range(-0.5, 0.5) * (width - 0.6))
		LowPoly.box(st, spot, book, LowPoly.vary(KitPalette.pick(KitPalette.SPINES, rng), rng),
				Basis(Vector3.UP, rng.randf() * TAU), LowPoly.VISIBLE_FACES, KitPalette.PAGE)


## One giant book lying flat: covers top and bottom, pages between, and the
## spine facing either toward the camera or away.
func _giant_book(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, slab: Vector3, turn: Basis) -> void:
	var faces := LowPoly.VISIBLE_FACES
	var cover := LowPoly.vary(KitPalette.pick(KitPalette.COVERS, rng), rng)
	var cover_thickness := minf(0.06, slab.y * 0.18)
	var offset := turn * Vector3(0, slab.y / 2 - cover_thickness / 2, 0)
	var cover_size := Vector3(slab.x, cover_thickness, slab.z)
	LowPoly.box(st, center + offset, cover_size, cover, turn, faces)
	LowPoly.box(st, center - offset, cover_size, cover.darkened(0.15), turn, faces)
	var pages := Vector3(slab.x - 0.08, slab.y - cover_thickness * 2, slab.z - 0.08)
	LowPoly.box(st, center, pages, KitPalette.PAGE_SHADE, turn, faces)
	if rng.randf() < 0.5:
		# Spine toward the camera, with a gilt band.
		var spine_center := center + turn * Vector3(0, 0, slab.z / 2 - 0.03)
		LowPoly.box(st, spine_center, Vector3(slab.x, slab.y, 0.06), cover, turn, faces)
		if slab.y > 0.3:
			LowPoly.box(st, spine_center + turn * Vector3(0, 0, 0.032), Vector3(slab.x, 0.04, 0.004),
					KitPalette.GILT, turn, LowPoly.Face.FRONT)


func _collision_shape() -> Shape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


func _collision_center() -> Vector3:
	return Vector3(0, size.y / 2, 0)
