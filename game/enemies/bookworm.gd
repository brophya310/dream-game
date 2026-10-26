class_name Bookworm
extends CharacterBody3D
## Early enemy: a long, wiggly worm that crawls around the grass between the shelves.
## Placeholder look (a chain of low-poly beads, a different colour for each worm)
## until its sprite is drawn. It doesn't attack yet; for now it's a target for the
## gust (weak damage + knockback).
##
## This node moves the head. The rest of the body follows it like a chain and
## lives on a separate hitbox on the enemies layer, so the gust can hit any part
## of the worm and the owl bumps into the whole length of it.

const ENEMIES_LAYER := 1 << 2

@export var max_health := 3
## How quickly knockback wears off.
@export var knockback_friction := 12.0
## Stay gone after being defeated, even after reloading.
@export var stays_defeated := true

@export_group("Body")
## Beads in the body, head included. Each worm adds up to 2 more at random.
@export_range(3, 24) var segment_count := 10
## Distance between beads (world units; 1 unit = 32 px).
@export var segment_spacing := 0.12
## Radius of the middle of the body. The head is a bit bigger and the tail tapers.
@export var thickness := 0.12
## Leave fully transparent to pick a colour automatically. Worms placed side by
## side under the same parent always get different colours.
@export var color := Color(0, 0, 0, 0)

@export_group("Crawling")
@export var crawl_speed := 0.6
## How far it strays from where it was placed.
@export var wander_radius := 1.6
## Side-to-side wave that runs down the body.
@export var wiggle_amount := 0.05
@export var wiggle_speed := 7.0

var health := 0
## The colour this worm ended up with.
var body_color := Color.WHITE
## Where it was placed. It wanders around this spot.
var home := Vector3.ZERO

var _knockback := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _time := 0.0
## Direction of travel as an angle on the ground (0 = east, PI/2 = south).
var _heading := 0.0
var _meander_phase := 0.0
var _crawl_left := 0.0
var _rest_left := 0.0
## 0 while crawling, eases to 1 while resting with its head reared up.
var _rear := 0.0
## Extra wiggle right after being hit.
var _flinch := 0.0
## Ground position of each bead, head first, in world space.
var _points := PackedVector3Array()
var _radii := PackedFloat32Array()
var _beads: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _hitbox: Hitbox
var _hit_shapes: Array[CollisionShape3D] = []


## The part of the worm the gust and the owl collide with. It passes gusts on to the worm.
class Hitbox extends AnimatableBody3D:
	var worm: Bookworm

	func take_gust(damage: int, push: Vector3) -> void:
		worm.take_gust(damage, push)


func _ready() -> void:
	health = max_health
	add_to_group("persistent")
	_rng.seed = hash(str(get_path()))
	home = global_position
	_heading = _rng.randf() * TAU
	_meander_phase = _rng.randf() * TAU
	_time = _rng.randf() * 10.0
	_crawl_left = _rng.randf_range(1.0, 3.0)
	_build_body()
	_update_body(0.0)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_time += delta
	var crawl := _crawl_velocity(delta) if health > 0 else Vector3.ZERO
	velocity.x = crawl.x + _knockback.x
	velocity.z = crawl.z + _knockback.z
	velocity.y = 0.0 if is_on_floor() else velocity.y + get_gravity().y * delta
	_knockback = _knockback.move_toward(Vector3.ZERO, knockback_friction * delta)
	move_and_slide()

	# Bumped into a shelf or the owl: turn away from it.
	if is_on_wall() and crawl != Vector3.ZERO:
		var away := get_wall_normal()
		_heading = atan2(away.z, away.x) + _rng.randf_range(-0.7, 0.7)

	_flinch = move_toward(_flinch, 0.0, delta * 2.0)
	_update_body(delta)


## Total length from head to tail tip, in world units.
func body_length() -> float:
	return (_points.size() - 1) * segment_spacing + _radii[0] + _radii[_radii.size() - 1]


func get_save_state() -> Variant:
	return {"defeated": true} if health <= 0 and stays_defeated else null


func apply_save_state(state: Variant) -> void:
	if state is Dictionary and state.get("defeated", false):
		health = 0
		queue_free()


func take_gust(damage: int, push: Vector3) -> void:
	if health <= 0:
		return
	health -= damage
	_knockback = Vector3(push.x, 0.0, push.z)
	# Get blown back, then crawl off the way the wind went.
	_heading = atan2(push.z, push.x)
	_rest_left = 0.0
	_crawl_left = _rng.randf_range(1.5, 3.0)
	_flinch = 1.0
	_flash()
	if health <= 0:
		_die()


## Inches along in pulses, meandering, and turns back when it strays too far from home.
## Alternates between crawling and resting with its head up.
func _crawl_velocity(delta: float) -> Vector3:
	if _rest_left > 0.0:
		_rest_left -= delta
		if _rest_left <= 0.0:
			_crawl_left = _rng.randf_range(1.5, 4.0)
		return Vector3.ZERO
	_crawl_left -= delta
	if _crawl_left <= 0.0:
		_rest_left = _rng.randf_range(0.6, 1.8)

	_heading += sin(_time * 0.9 + _meander_phase) * 1.4 * delta
	var to_home := home - global_position
	to_home.y = 0.0
	if to_home.length() > wander_radius:
		_heading = rotate_toward(_heading, atan2(to_home.z, to_home.x), 2.5 * delta)

	var pulse := 0.55 + 0.45 * sin(_time * 5.0)
	var swing := sin(_time * wiggle_speed * 0.5) * 0.45
	var direction := Vector3(cos(_heading + swing), 0.0, sin(_heading + swing))
	return direction * crawl_speed * pulse


func _build_body() -> void:
	var count := segment_count + _rng.randi_range(0, 2)
	body_color = color if color.a > 0.0 else _auto_color()
	var stripe := Color.from_hsv(fposmod(body_color.h + 0.06, 1.0), body_color.s * 0.95, body_color.v * 0.78)
	_materials = [_material(body_color.lightened(0.1)), _material(body_color), _material(stripe)]
	var eye_material := _material(Color(0.08, 0.05, 0.1))

	# Beads live in world space so each one can trail behind the head on its own.
	var beads_root := Node3D.new()
	beads_root.name = "Beads"
	beads_root.top_level = true
	add_child(beads_root)

	_hitbox = Hitbox.new()
	_hitbox.name = "Hitbox"
	_hitbox.worm = self
	_hitbox.collision_layer = ENEMIES_LAYER
	_hitbox.collision_mask = 0
	_hitbox.sync_to_physics = false
	add_child(_hitbox)

	var back := -Vector3(cos(_heading), 0.0, sin(_heading))
	for i in count:
		var along := float(i) / (count - 1)
		var radius := thickness * 1.15 if i == 0 else lerpf(thickness, thickness * 0.5, pow(along, 2.0))
		_radii.append(radius)
		_points.append(global_position + back * segment_spacing * i)

		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		var bead := MeshInstance3D.new()
		bead.name = "Head" if i == 0 else "Bead%d" % i
		bead.mesh = sphere
		bead.material_override = _materials[0] if i == 0 else _materials[1 + i % 2]
		beads_root.add_child(bead)
		_beads.append(bead)

		var shape := SphereShape3D.new()
		shape.radius = radius
		var hit_shape := CollisionShape3D.new()
		hit_shape.shape = shape
		_hitbox.add_child(hit_shape)
		_hit_shapes.append(hit_shape)

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.035
	eye_mesh.height = 0.07
	eye_mesh.radial_segments = 6
	eye_mesh.rings = 3
	eye_mesh.material = eye_material
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.065, 0.07, -0.1)
		_beads[0].add_child(eye)


## Lays the beads along the chain, with a wave running down the body, a hump that
## travels back while crawling, and the head reared up while resting.
func _update_body(delta: float) -> void:
	var resting := _rest_left > 0.0 or health <= 0
	_rear = move_toward(_rear, 1.0 if resting else 0.0, delta * 3.0)

	_points[0] = global_position
	for i in range(1, _points.size()):
		var offset := _points[i] - _points[i - 1]
		offset.y = 0.0
		if offset.length_squared() < 0.000001:
			offset = -Vector3(cos(_heading), 0.0, sin(_heading))
		_points[i] = _points[i - 1] + offset.normalized() * segment_spacing
		_points[i].y = global_position.y

	var last := _points.size() - 1
	for i in _points.size():
		var forward := (_points[0] - _points[1]) if i == 0 else (_points[i - 1] - _points[i])
		forward = forward.normalized()
		var side := Vector3(-forward.z, 0.0, forward.x)
		var along := float(i) / last
		var wave := sin(_time * wiggle_speed - i * 0.9) * wiggle_amount * (0.3 + along) * (1.0 + _flinch * 3.0)
		var hump := maxf(sin(_time * 5.0 - i * 0.8), 0.0) * 0.03 * (1.0 - _rear)
		var rear_lift := _rear * maxf(0.2 - i * 0.07, 0.0)
		var sway := side * sin(_time * 2.5) * 0.04 * _rear * maxf(1.0 - i * 0.4, 0.0)
		var ground := _points[i] + side * wave + sway
		_beads[i].global_position = ground + Vector3.UP * (_radii[i] + hump + rear_lift)
		_hit_shapes[i].position = (_points[i] - global_position) + Vector3.UP * _radii[i]
		if i == 0:
			_beads[0].global_basis = Basis.looking_at(forward, Vector3.UP)


## A bright, dreamy colour. Siblings step round the colour wheel by the golden
## ratio, so worms placed together never match.
func _auto_color() -> Color:
	var hue := fposmod(0.02 + get_index() * 0.618034 + _rng.randf_range(-0.03, 0.03), 1.0)
	return Color.from_hsv(hue, _rng.randf_range(0.5, 0.65), _rng.randf_range(0.82, 0.95))


func _material(albedo: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 1.0
	return material


func _flash() -> void:
	var tween := create_tween().set_parallel()
	for material in _materials:
		material.emission_enabled = true
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 1.5
		tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.2)


## Pops flat bead by bead, tail first.
func _die() -> void:
	Game.request_autosave()
	collision_mask = 1
	_hitbox.collision_layer = 0
	var tween := create_tween().set_parallel()
	for i in _beads.size():
		var delay := 0.12 + (_beads.size() - 1 - i) * 0.035
		tween.tween_property(_beads[i], "scale", Vector3(1.4, 0.05, 1.4), 0.15).set_delay(delay)
	tween.chain().tween_callback(queue_free)
