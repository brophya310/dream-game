class_name Owl
extends CharacterBody3D
## The player: a dream-wise owl mage. Moves and faces in 8 directions and flaps
## his wings to make a gust of wind (weak damage + knockback, and it blows light
## props like loose pages and toppled books out of the way).

signal flapped(gust_center: Vector3, direction: Vector3)

## Facing names by octant, clockwise from east (screen space, y pointing down).
const OCTANT_FACINGS: Array[String] = [
	"east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east",
]
## West-side facings reuse the east-side art, flipped horizontally.
const MIRRORED := {"west": "east", "south-west": "south-east", "north-west": "north-east"}
const ENEMIES_LAYER := 1 << 2
const PROPS_LAYER := 1 << 3
## Light things like loose pages: the gust moves them but the owl walks over them.
const DEBRIS_LAYER := 1 << 4

@export_group("Movement")
## World units per second (1 unit = 32 pixels).
@export var move_speed := 3.5
@export var acceleration := 28.0
@export var deceleration := 36.0

@export_group("Gust")
## Seconds before the owl can flap again. Flapping is unlimited otherwise.
@export var flap_recovery := 0.3
@export var gust_damage := 1
## Speed (units/sec) the gust gives to whatever it hits.
@export var gust_force := 6.0
## How far ahead of the owl the gust is centred.
@export var gust_reach := 0.9
@export var gust_radius := 0.85
@export var gust_puff_scene: PackedScene

var facing := "south"

var _facing_vector := Vector3.BACK
var _recovery_left := 0.0
var _flap_time_left := 0.0

@onready var sprite: AnimatedSprite3D = $Sprite


func _ready() -> void:
	_rest_feet_on_origin()
	_update_animation(false)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := input != Vector2.ZERO

	var target := Vector3(input.x, 0.0, input.y) * move_speed
	var rate := acceleration if moving else deceleration
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	velocity.y = 0.0 if is_on_floor() else velocity.y + get_gravity().y * delta
	move_and_slide()

	if input.length() > 0.2:
		_face(input)

	_recovery_left = maxf(_recovery_left - delta, 0.0)
	_flap_time_left = maxf(_flap_time_left - delta, 0.0)
	if Input.is_action_just_pressed("accept") and _recovery_left == 0.0:
		_flap()

	_update_animation(moving)


## Moves the owl instantly (spawning, loading a save) without smoothing across the jump.
func teleport(where: Vector3, new_facing := "south") -> void:
	global_position = where
	velocity = Vector3.ZERO
	set_facing(new_facing)
	reset_physics_interpolation()
	if is_node_ready():
		_update_animation(false)


func set_facing(new_facing: String) -> void:
	var octant := OCTANT_FACINGS.find(new_facing)
	if octant == -1:
		return
	facing = new_facing
	var snapped := Vector2.from_angle(octant * PI / 4.0)
	_facing_vector = Vector3(snapped.x, 0.0, snapped.y)


func _face(input: Vector2) -> void:
	var octant := wrapi(roundi(input.angle() / (PI / 4.0)), 0, 8)
	set_facing(OCTANT_FACINGS[octant])


func _flap() -> void:
	_recovery_left = flap_recovery
	var source := _source_facing()
	var flap_anim := StringName("flap_" + source)
	if sprite.sprite_frames.has_animation(flap_anim):
		var frames := sprite.sprite_frames
		_flap_time_left = frames.get_frame_count(flap_anim) / frames.get_animation_speed(flap_anim)
		sprite.play(flap_anim)
		sprite.set_frame_and_progress(0, 0.0)
	_squash()

	var center := global_position + _facing_vector * gust_reach + Vector3.UP * 0.4
	_apply_gust(center)
	if gust_puff_scene:
		var puff := gust_puff_scene.instantiate()
		get_parent().add_child(puff)
		puff.global_position = center
		if puff.has_method("blow"):
			puff.blow(_facing_vector)
	flapped.emit(center, _facing_vector)


## Pushes (and lightly damages) everything inside the gust. Anything that should
## react to the gust implements take_gust(damage: int, push: Vector3).
func _apply_gust(center: Vector3) -> void:
	var shape := SphereShape3D.new()
	shape.radius = gust_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = ENEMIES_LAYER | PROPS_LAYER | DEBRIS_LAYER
	query.exclude = [get_rid()]

	var already_hit := {}
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body: Object = hit.collider
		if already_hit.has(body) or not body.has_method("take_gust"):
			continue
		already_hit[body] = true
		var away: Vector3 = body.global_position - global_position
		away.y = 0.0
		var direction := (_facing_vector + away.normalized() * 0.5).normalized()
		body.take_gust(gust_damage, (direction + Vector3.UP * 0.2) * gust_force)


func _update_animation(moving: bool) -> void:
	var source := _source_facing()
	sprite.flip_h = MIRRORED.has(facing)
	if _flap_time_left > 0.0 and sprite.animation == StringName("flap_" + source):
		return

	var action := "walk" if moving else "idle"
	var anim := StringName(action + "_" + source)
	if sprite.animation == anim:
		return
	# Keep the step timing when turning mid-walk so the hop doesn't restart.
	var keep_timing := sprite.animation.begins_with(action)
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.play(anim)
	if keep_timing and frame < sprite.sprite_frames.get_frame_count(anim):
		sprite.set_frame_and_progress(frame, progress)


func _source_facing() -> String:
	return MIRRORED.get(facing, facing)


## A quick squash-and-stretch so every flap reads, even in facings with no flap art yet.
func _squash() -> void:
	var tween := create_tween()
	sprite.scale = Vector3(1.15, 0.88, 1.0)
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sprites are centred on their canvas; shift the art up so the owl's feet sit
## on this node's origin (which is on the ground).
func _rest_feet_on_origin() -> void:
	var texture := sprite.sprite_frames.get_frame_texture(&"idle_south", 0)
	if texture == null:
		return
	var image := texture.get_image()
	var feet_below_center := image.get_used_rect().end.y - image.get_height() / 2.0
	sprite.offset.y = feet_below_center
