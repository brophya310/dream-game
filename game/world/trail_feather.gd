class_name TrailFeather
extends Area3D
## One of the yellow feathers the finch drops as the kestrel carries it off.
## A yellow feather means "look for the finch". It drifts away when the owl reaches it.
## Placeholder look (a flat yellow shape) until the feather sprite is drawn.

signal collected(feather: TrailFeather)

## Shown on screen when the owl reaches this feather (leave empty for none).
@export_multiline var message := ""

var _time := 0.0
var _collected := false

@onready var visual: Node3D = $Visual


func _ready() -> void:
	_time = randf() * TAU
	add_to_group("persistent")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	visual.position.y = 0.35 + sin(_time * 2.0) * 0.06
	visual.rotation.y = sin(_time * 1.3) * 0.6


func is_collected() -> bool:
	return _collected


func get_save_state() -> Variant:
	return true if _collected else null


func apply_save_state(state: Variant) -> void:
	if state == true:
		_collected = true
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body is Owl:
		return
	_collected = true
	set_deferred("monitoring", false)
	collected.emit(self)
	Game.request_autosave()
	var tween := create_tween().set_parallel()
	tween.tween_property(visual, "position:y", visual.position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.8).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
