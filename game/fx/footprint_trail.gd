class_name FootprintTrail
extends MultiMeshInstance3D
## Little footprints left behind as the parent character walks. Each one fades
## away after a moment. Add it as a child of a CharacterBody3D; it draws in world
## space, all prints in one draw call.

const SHADER := preload("res://game/fx/footprint.gdshader")
## Moving further than this in one physics frame counts as a teleport, not a step.
const TELEPORT_DISTANCE := 1.0

## Distance walked between prints (world units; 1 unit = 32 px).
@export var step_length := 0.42
## How far each print sits left or right of the path.
@export var stance_width := 0.07
## Seconds a print stays at full strength before it starts fading.
@export var hold_time := 0.8
## Seconds it takes to fade out.
@export var fade_time := 1.6
@export var tint := Color(0.16, 0.1, 0.06, 0.5)
## Square frames side by side: toes pointing north, then north-east. Other
## directions turn these in quarter turns so the pixels stay crisp.
@export var prints_texture: Texture2D = preload("res://assets/fx/footprint.png")
## Prints on the ground at once. Raise it for faster walkers or longer fades.
@export var max_prints := 32

var _ages := PackedFloat32Array()
var _next := 0
var _walked := 0.0
var _left_foot := true
var _last_position := Vector3.ZERO
var _body: CharacterBody3D


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	top_level = true
	global_transform = Transform3D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var frame_size := prints_texture.get_height()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * frame_size / 32.0
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("prints", prints_texture)
	material.set_shader_parameter("frames", float(prints_texture.get_width()) / frame_size)
	material.set_shader_parameter("tint", tint)
	plane.material = material

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = plane
	multimesh.instance_count = max_prints
	_ages.resize(max_prints)
	_ages.fill(INF)
	for i in max_prints:
		multimesh.set_instance_color(i, Color(1, 1, 1, 0))
	if _body:
		_last_position = _body.global_position


func _physics_process(delta: float) -> void:
	_fade(delta)
	if _body == null:
		return
	var here := _body.global_position
	var step := here - _last_position
	step.y = 0.0
	_last_position = here
	if step.length() > TELEPORT_DISTANCE:
		_walked = 0.0
		return
	if not _body.is_on_floor() or step.is_zero_approx():
		return
	_walked += step.length()
	if _walked >= step_length:
		_walked = fmod(_walked, step_length)
		_place(here, step.normalized())


## Prints that can still be seen.
func visible_count() -> int:
	var lifetime := hold_time + fade_time
	return Array(_ages).filter(func(age: float) -> bool: return age < lifetime).size()


## Removes every print at once (e.g. when the scene is reset).
func clear() -> void:
	_ages.fill(INF)
	for i in max_prints:
		multimesh.set_instance_color(i, Color(1, 1, 1, 0))


func _fade(delta: float) -> void:
	var lifetime := hold_time + fade_time
	for i in max_prints:
		if _ages[i] >= lifetime:
			continue
		_ages[i] += delta
		var strength := 1.0 - clampf((_ages[i] - hold_time) / fade_time, 0.0, 1.0)
		multimesh.set_instance_color(i, Color(1, 1, 1, strength))


func _place(at: Vector3, forward: Vector3) -> void:
	var side := Vector3(-forward.z, 0.0, forward.x)
	var spot := at + side * (stance_width if _left_foot else -stance_width)
	_left_foot = not _left_foot
	# Sit on the pixel grid, just above the ground.
	spot = Vector3(snappedf(spot.x, 1.0 / 32.0), at.y + 0.012, snappedf(spot.z, 1.0 / 32.0))

	# 8 directions, 0 = north, clockwise. Even ones use the straight frame, odd the diagonal.
	var octant := wrapi(roundi(atan2(forward.x, -forward.z) / (PI / 4.0)), 0, 8)
	var turn := Basis(Vector3.UP, -floorf(octant / 2.0) * PI / 2.0)
	multimesh.set_instance_transform(_next, Transform3D(turn, spot))
	multimesh.set_instance_custom_data(_next, Color(octant % 2, 0, 0, 0))
	multimesh.set_instance_color(_next, Color.WHITE)
	_ages[_next] = 0.0
	_next = (_next + 1) % max_prints
