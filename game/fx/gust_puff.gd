extends CPUParticles3D
## A one-shot puff of wind from the owl's flap. Frees itself when done.


func _ready() -> void:
	finished.connect(queue_free)
	emitting = true


## Points the puff along the gust before it plays.
func blow(gust_direction: Vector3) -> void:
	direction = (gust_direction + Vector3.UP * 0.15).normalized()
	restart()
