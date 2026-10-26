@tool
class_name FloorLamp
extends KitPiece
## A standing lamp with a glowing shade and a warm light.

@export var light_color := KitPalette.LAMP_GLOW:
	set(value):
		light_color = value
		queue_rebuild()
@export var light_energy := 1.3:
	set(value):
		light_energy = value
		queue_rebuild()
@export var light_range := 5.0:
	set(value):
		light_range = value
		queue_rebuild()

const HEIGHT := 1.6


func _build(mesh: ArrayMesh, _rng: RandomNumberGenerator) -> void:
	var st := LowPoly.begin()
	LowPoly.cylinder(st, Vector3.ZERO, 0.2, 0.17, 0.05, 6, KitPalette.WOOD_DARK)
	LowPoly.cylinder(st, Vector3(0, 0.05, 0), 0.035, 0.03, HEIGHT - 0.3, 5, KitPalette.GILT.darkened(0.2))
	LowPoly.commit(st, mesh)
	var shade := LowPoly.begin()
	LowPoly.cylinder(shade, Vector3(0, HEIGHT - 0.32, 0), 0.32, 0.17, 0.32, 6, light_color)
	LowPoly.commit(shade, mesh, LowPoly.glow(light_color, 0.9))


func _after_build(_rng: RandomNumberGenerator) -> void:
	var light: OmniLight3D = _generated_child("Light", OmniLight3D)
	light.position = Vector3(0, HEIGHT - 0.2, 0)
	light.light_color = light_color
	light.light_energy = light_energy
	light.omni_range = light_range


func _collision_shape() -> Shape3D:
	var shape := CylinderShape3D.new()
	shape.radius = 0.2
	shape.height = HEIGHT
	return shape


func _collision_center() -> Vector3:
	return Vector3(0, HEIGHT / 2, 0)
