class_name SpawnPoint
extends Marker3D
## Where the owl appears when entering a level. Levels look these up by node name.

## Which way the owl faces on arrival.
@export_enum("south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west")
var facing := "south"


func _init() -> void:
	add_to_group("spawn_points")
