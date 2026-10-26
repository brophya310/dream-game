@tool
class_name KitPiece
extends StaticBody3D
## Base for low-poly environment pieces that build their own mesh and collision
## in code. Change a piece's settings in the inspector and it rebuilds. The
## generated children aren't saved into scenes, so scenes only store settings.
## Each piece's look is random but stable: it's seeded from `random_seed`, or
## from the node's name when the seed is 0.

@export var random_seed := 0:
	set(value):
		random_seed = value
		queue_rebuild()

var mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _rebuild_queued := false


func _ready() -> void:
	collision_mask = 0
	rebuild()


func queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		_collision = CollisionShape3D.new()
		add_child(mesh_instance)
		add_child(_collision)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed if random_seed != 0 else hash(String(name))
	var mesh := ArrayMesh.new()
	_build(mesh, rng)
	mesh_instance.mesh = mesh
	var shape := _collision_shape()
	_collision.shape = shape
	_collision.disabled = shape == null
	_collision.position = _collision_center()
	_after_build(rng)


## Override: add surfaces to `mesh` with LowPoly helpers.
func _build(_mesh: ArrayMesh, _rng: RandomNumberGenerator) -> void:
	pass


## Override: the collision shape, or null for none (decor you can walk over).
func _collision_shape() -> Shape3D:
	return null


func _collision_center() -> Vector3:
	return Vector3.ZERO


## Override: anything else to add after the mesh, such as lights.
func _after_build(_rng: RandomNumberGenerator) -> void:
	pass


## A child built in code (not saved); reused across rebuilds.
func _generated_child(child_name: String, type: Variant) -> Node:
	var existing := get_node_or_null(child_name)
	if existing:
		return existing
	var child: Node = type.new()
	child.name = child_name
	add_child(child)
	return child
