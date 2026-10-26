@tool
class_name GustProp
extends RigidBody3D
## A light object the owl's gust can blow around: loose pages, toppled books.
## Placeholder look: a coloured box. Swap the Mesh child for real art later.

## Placeholder colour for this prop.
@export var tint := Color(0.93, 0.9, 0.8):
	set(value):
		tint = value
		_apply_tint()
## How strongly this prop reacts to the gust (1 = fully).
@export var gust_response := 1.0
## How much the gust sets it spinning.
@export var spin := 0.6

var _start_transform: Transform3D


func _ready() -> void:
	_apply_tint()
	if not Engine.is_editor_hint():
		_start_transform = global_transform
		add_to_group("persistent")


## Only remembered once it has actually been moved.
func get_save_state() -> Variant:
	var moved := global_position.distance_to(_start_transform.origin) > 0.05
	var turned := not global_basis.is_equal_approx(_start_transform.basis)
	return global_transform if moved or turned else null


func apply_save_state(state: Variant) -> void:
	if state is Transform3D:
		global_transform = state
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		reset_physics_interpolation()


func take_gust(_damage: int, push: Vector3) -> void:
	apply_central_impulse(push * mass * gust_response)
	var tumble := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	apply_torque_impulse(tumble * spin * mass)


func _apply_tint() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	mesh.material_override = material
