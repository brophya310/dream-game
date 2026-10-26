extends Level
## Tutorial test area (design doc section 13, stages 1 and 2).
## The owl wakes in the grassy library and follows the finch's yellow feather
## trail: first just moving, then using the gust as a tool (a pile of pages and
## books blocks a gap in the shelves), then meeting the first bookworms.
## Not built yet: the kestrel snatch and stage 3 (cards).

var _feathers: Array[TrailFeather] = []

@onready var hud: Hud = $Hud


func _ready() -> void:
	for feather in get_tree().get_nodes_in_group("trail_feathers"):
		if is_ancestor_of(feather):
			_feathers.append(feather)
			feather.collected.connect(_on_feather_collected)
	super()


func progress_summary() -> String:
	var found := _feathers.filter(func(f: Variant) -> bool: return not is_instance_valid(f) or f.is_collected()).size()
	return "Yellow feathers found: %d of %d" % [found, _feathers.size()]


func _on_feather_collected(feather: TrailFeather) -> void:
	if not feather.message.is_empty():
		hud.show_message(feather.message)
