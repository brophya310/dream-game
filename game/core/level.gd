class_name Level
extends Node3D
## Base for every playable area. Restores saved progress, places the owl,
## records progress for saving, and adds the pause menu.
##
## Anything in a level that should remember its state joins the "persistent"
## group and implements:
##   get_save_state() -> Variant        # null when there's nothing worth saving
##   apply_save_state(state: Variant)   # called before the level starts
## States are keyed by the node's path in the level, so renaming a saved node
## means old saves forget it (harmless: it just starts fresh).

const PAUSE_MENU := preload("res://game/ui/pause/pause_menu.tscn")

## Stable save key. Defaults to the scene's file name.
@export var level_id := ""
## Shown on save slots and in the pause menu.
@export var display_name := "Somewhere in the dream"
@export var player_path: NodePath = ^"Owl"

var player: Owl

## Final states of persistent things that have left the level (a collected
## feather frees itself), so they still get saved.
var _departed_state := {}


func _ready() -> void:
	if level_id.is_empty():
		level_id = scene_file_path.get_file().get_basename()
	player = get_node_or_null(player_path) as Owl
	for node in _persistent_nodes():
		node.tree_exiting.connect(_remember_departed.bind(node))
	add_child(PAUSE_MENU.instantiate())
	Game.register_level(self)


func apply_save_state(state: Dictionary) -> void:
	for node in _persistent_nodes():
		var key := String(get_path_to(node))
		if state.has(key):
			node.apply_save_state(state[key])


func collect_save_state() -> Dictionary:
	var state := _departed_state.duplicate()
	for node in _persistent_nodes():
		var node_state: Variant = node.get_save_state()
		if node_state != null:
			state[String(get_path_to(node))] = node_state
	return state


func spawn_player(spawn_name: String) -> void:
	if player == null:
		return
	for spawn in get_tree().get_nodes_in_group("spawn_points"):
		if spawn.name == spawn_name and is_ancestor_of(spawn):
			player.teleport(spawn.global_position, spawn.facing)
			get_tree().call_group("follow_camera", "snap")
			return
	push_warning("%s has no spawn point called '%s'" % [display_name, spawn_name])


func restore_player(saved: Dictionary) -> void:
	if player == null:
		return
	player.teleport(saved.get("position", player.global_position), saved.get("facing", "south"))
	get_tree().call_group("follow_camera", "snap")


func player_state() -> Dictionary:
	if player == null:
		return {}
	return {"position": player.global_position, "facing": player.facing}


## One line for the pause menu's info card, e.g. "Feathers found: 3 of 8".
func progress_summary() -> String:
	return ""


func _remember_departed(node: Node) -> void:
	var node_state: Variant = node.get_save_state()
	if node_state != null:
		_departed_state[String(get_path_to(node))] = node_state


func _persistent_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for node in get_tree().get_nodes_in_group("persistent"):
		if is_ancestor_of(node):
			nodes.append(node)
	return nodes
