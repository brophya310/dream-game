class_name FollowCamera
extends Camera3D
## Top-down orthographic camera, tilted down ~65 degrees, that follows a target.
## Its position snaps to the screen's pixel grid so pixel art doesn't shimmer.

@export var target: Node3D
## Degrees below the horizon the camera looks.
@export_range(30.0, 90.0) var pitch_degrees := 65.0
## Distance back from the point it looks at (only affects clipping in orthographic mode).
@export var distance := 30.0
## Higher = snappier follow.
@export var follow_speed := 7.0
## Raises the focus point so the view centres on the owl's body rather than its feet.
@export var focus_height := 0.5
@export var pixel_snap := true

var _focus := Vector3.ZERO


func _ready() -> void:
	# This camera moves itself every frame, so physics interpolation would only add lag.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("follow_camera")
	rotation = Vector3(deg_to_rad(-pitch_degrees), 0.0, 0.0)
	if target:
		_focus = _target_position()
	_place()


func _process(delta: float) -> void:
	if target:
		_focus = _focus.lerp(_target_position(), 1.0 - exp(-follow_speed * delta))
	_place()


## Jumps straight to the target (after spawning or loading) instead of gliding there.
func snap() -> void:
	if target:
		_focus = _target_position()
	_place()


func _target_position() -> Vector3:
	return target.get_global_transform_interpolated().origin + Vector3.UP * focus_height


func _place() -> void:
	var view_basis := global_transform.basis
	var position_3d := _focus + view_basis.z * distance
	if pixel_snap and projection == PROJECTION_ORTHOGONAL:
		var world_units_per_pixel := size / get_viewport().get_visible_rect().size.y
		var local := view_basis.inverse() * position_3d
		local.x = snappedf(local.x, world_units_per_pixel)
		local.y = snappedf(local.y, world_units_per_pixel)
		position_3d = view_basis * local
	global_position = position_3d
