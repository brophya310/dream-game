@tool
class_name GrassPatch
extends Node3D
## Scatters low-poly grass tufts over a rectangle centred on this node.
## Change the exports in the inspector to reshape the patch.

const TUFT_SHADER := preload("res://game/world/grass_tuft.gdshader")
## Tuft colours as they should look on screen (sRGB).
const COLORS: Array[Color] = [
	Color(0.38, 0.6, 0.29), Color(0.31, 0.52, 0.26), Color(0.47, 0.67, 0.32), Color(0.28, 0.46, 0.27),
]

@export var extent := Vector2(4.0, 4.0):
	set(value):
		extent = value
		_scatter()
@export var count := 80:
	set(value):
		count = value
		_scatter()
@export var random_seed := 1:
	set(value):
		random_seed = value
		_scatter()

var _tufts_node: MultiMeshInstance3D


func _ready() -> void:
	_scatter()


func _scatter() -> void:
	if not is_inside_tree():
		return
	# Built in code and not saved into scenes, so only the exports need storing.
	if _tufts_node == null:
		_tufts_node = MultiMeshInstance3D.new()
		add_child(_tufts_node)

	var material := ShaderMaterial.new()
	material.shader = TUFT_SHADER
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.07
	blade.height = 0.32
	blade.radial_segments = 4
	blade.rings = 0
	blade.material = material

	var tufts := MultiMesh.new()
	tufts.transform_format = MultiMesh.TRANSFORM_3D
	tufts.use_colors = true
	tufts.mesh = blade
	tufts.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for i in count:
		var spot := Vector3(rng.randf_range(-0.5, 0.5) * extent.x, 0.0, rng.randf_range(-0.5, 0.5) * extent.y)
		var tilt := Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		var size := rng.randf_range(0.7, 1.4)
		var tuft_basis := Basis.from_euler(tilt).scaled(Vector3.ONE * size)
		spot.y = 0.13 * size
		tufts.set_instance_transform(i, Transform3D(tuft_basis, spot))
		tufts.set_instance_color(i, COLORS[rng.randi() % COLORS.size()].srgb_to_linear())
	_tufts_node.multimesh = tufts
