class_name LowPoly
extends RefCounted
## Helpers for building flat-shaded, vertex-coloured low-poly meshes in code.
## Colours are given as they should look on screen (sRGB).

enum Face { TOP = 1, BOTTOM = 2, FRONT = 4, BACK = 8, LEFT = 16, RIGHT = 32 }
const ALL_FACES := 63
## Faces the fixed camera can never see (it looks north and down).
const VISIBLE_FACES := Face.TOP | Face.FRONT | Face.LEFT | Face.RIGHT

static var _matte: StandardMaterial3D
static var _glow_cache := {}


## The shared material for all low-poly pieces.
static func matte() -> StandardMaterial3D:
	if _matte == null:
		_matte = StandardMaterial3D.new()
		_matte.vertex_color_use_as_albedo = true
		_matte.vertex_color_is_srgb = true
		_matte.roughness = 1.0
	return _matte


## An unshaded, glowing material (lamp shades, magic pages).
static func glow(color: Color, energy := 1.5) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), energy]
	if not _glow_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_cache[key] = material
	return _glow_cache[key]


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Adds the surface to `mesh` (if it has any triangles).
static func commit(st: SurfaceTool, mesh: ArrayMesh, material: Material = null) -> void:
	var arrays := st.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material if material else matte())


## A four-cornered face. `normal` points outward; winding is fixed up to match it.
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	# Godot treats clockwise triangles (seen from outside) as front faces.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = d
		d = swap
	for vertex in [a, b, c, a, c, d]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertex)


static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for vertex in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(vertex)


## A box centred on `center`, optionally rotated, drawing only `faces`.
## `top_color` tints the top face (handy for paper edges); defaults to `color`.
static func box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color,
		rotation := Basis.IDENTITY, faces := ALL_FACES, top_color := Color(0, 0, 0, 0)) -> void:
	var h := size / 2.0
	var corner := func(x: float, y: float, z: float) -> Vector3:
		return center + rotation * Vector3(x * h.x, y * h.y, z * h.z)
	var top := color if top_color.a == 0.0 else top_color
	if faces & Face.TOP:
		quad(st, corner.call(-1, 1, -1), corner.call(1, 1, -1), corner.call(1, 1, 1), corner.call(-1, 1, 1), rotation * Vector3.UP, top)
	if faces & Face.BOTTOM:
		quad(st, corner.call(-1, -1, -1), corner.call(1, -1, -1), corner.call(1, -1, 1), corner.call(-1, -1, 1), rotation * Vector3.DOWN, color)
	if faces & Face.FRONT:
		quad(st, corner.call(-1, -1, 1), corner.call(1, -1, 1), corner.call(1, 1, 1), corner.call(-1, 1, 1), rotation * Vector3.BACK, color)
	if faces & Face.BACK:
		quad(st, corner.call(-1, -1, -1), corner.call(1, -1, -1), corner.call(1, 1, -1), corner.call(-1, 1, -1), rotation * Vector3.FORWARD, color)
	if faces & Face.LEFT:
		quad(st, corner.call(-1, -1, -1), corner.call(-1, -1, 1), corner.call(-1, 1, 1), corner.call(-1, 1, -1), rotation * Vector3.LEFT, color)
	if faces & Face.RIGHT:
		quad(st, corner.call(1, -1, -1), corner.call(1, -1, 1), corner.call(1, 1, 1), corner.call(1, 1, -1), rotation * Vector3.RIGHT, color)


## A low-poly cylinder or cone standing on `base`. `sides` 5-8 keeps it chunky.
static func cylinder(st: SurfaceTool, base: Vector3, bottom_radius: float, top_radius: float,
		height: float, sides: int, color: Color, cap := true, rotation := Basis.IDENTITY) -> void:
	var top_center := base + rotation * Vector3(0, height, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := base + rotation * (d0 * bottom_radius)
		var b1 := base + rotation * (d1 * bottom_radius)
		var t0 := top_center + rotation * (d0 * top_radius)
		var t1 := top_center + rotation * (d1 * top_radius)
		var outward := (d0 + d1).normalized()
		var slope := (bottom_radius - top_radius) / maxf(height, 0.001)
		var normal := (rotation * (outward + Vector3.UP * slope)).normalized()
		if top_radius <= 0.0001:
			triangle(st, b0, b1, t0, normal, color)
		else:
			quad(st, b0, b1, t1, t0, normal, color)
		if cap and top_radius > 0.0001:
			triangle(st, top_center, t0, t1, rotation * Vector3.UP, color.lightened(0.08))


## A colour nudged randomly in brightness, so repeated pieces don't look identical.
static func vary(color: Color, rng: RandomNumberGenerator, amount := 0.08) -> Color:
	var shift := rng.randf_range(-amount, amount)
	return color.lightened(shift) if shift > 0.0 else color.darkened(-shift)
