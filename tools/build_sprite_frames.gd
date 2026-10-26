extends SceneTree
## Builds a SpriteFrames resource (<name>_frames.tres) from a character's PNG folders.
##
## Usage (from the project folder):
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_sprite_frames.gd -- res://assets/characters/owl
##
## Folder layout:
##   idle/<facing>.png               one still image per facing
##   <action>/<facing>/<frame>.png   numbered frames, e.g. walk/south/0.png
## Facings are south, south-east, east, north-east and north. West-side facings
## are drawn by flipping the east-side art in game, so they don't need files.
## Animations are named "<action>_<facing>", e.g. "walk_south-east".

## Frames per second for each action. Anything not listed uses DEFAULT_FPS.
const FPS := {"idle": 1.0, "walk": 12.0, "flap": 16.0}
const DEFAULT_FPS := 12.0
## Actions that play once instead of looping.
const ONE_SHOT := ["flap"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the character folder, e.g. -- res://assets/characters/owl")
		quit(1)
		return

	var root: String = args[0].trim_suffix("/")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	var actions := Array(DirAccess.get_directories_at(root))
	actions.sort()
	for action: String in actions:
		var folder := root.path_join(action)
		if action == "idle":
			for file in _pngs(folder):
				_add(frames, "idle_" + file.get_basename(), [folder.path_join(file)], action)
			continue
		var facings := Array(DirAccess.get_directories_at(folder))
		facings.sort()
		for facing: String in facings:
			var facing_folder := folder.path_join(facing)
			var paths := _pngs(facing_folder).map(func(file: String) -> String: return facing_folder.path_join(file))
			_add(frames, action + "_" + facing, paths, action)

	var out := root.path_join(root.get_file() + "_frames.tres")
	var err := ResourceSaver.save(frames, out)
	print("Saved %d animations to %s (error code %d)" % [frames.get_animation_names().size(), out, err])
	quit(0 if err == OK else 1)


func _add(frames: SpriteFrames, anim: String, paths: Array, action: String) -> void:
	if paths.is_empty():
		return
	frames.add_animation(anim)
	frames.set_animation_speed(anim, FPS.get(action, DEFAULT_FPS))
	frames.set_animation_loop(anim, action not in ONE_SHOT)
	for path: String in paths:
		var texture: Texture2D = load(path)
		if texture == null:
			push_error("Could not load %s (run --import first?)" % path)
			continue
		frames.add_frame(anim, texture)


## PNG files in a folder, in frame order (0, 1, 2 ... 10, 11).
func _pngs(folder: String) -> Array:
	var files := Array(DirAccess.get_files_at(folder)).filter(
		func(file: String) -> bool: return file.get_extension() == "png")
	files.sort_custom(func(a: String, b: String) -> bool:
		var a_num := a.get_basename()
		var b_num := b.get_basename()
		if a_num.is_valid_int() and b_num.is_valid_int():
			return a_num.to_int() < b_num.to_int()
		return a_num < b_num)
	return files
