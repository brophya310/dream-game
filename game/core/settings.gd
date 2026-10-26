extends Node
## Player options (volume, display), stored separately from save slots in
## user://settings.cfg and applied on startup. Autoloaded as `Settings`.

signal changed

const BASE_SIZE := Vector2i(640, 360)
const MAX_WINDOW_SCALE := 4

## Where options are stored. Tests point this somewhere else.
var path := "user://settings.cfg"
var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
var window_scale := 2


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	master_volume = clampf(config.get_value("audio", "master", master_volume), 0.0, 1.0)
	music_volume = clampf(config.get_value("audio", "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	window_scale = clampi(config.get_value("display", "window_scale", window_scale), 1, MAX_WINDOW_SCALE)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "window_scale", window_scale)
	var err := config.save(path)
	if err != OK:
		push_warning("Could not save settings (error %d)" % err)


func apply() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	if DisplayServer.get_name() == "headless":
		changed.emit()
		return
	var window := get_window()
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		if window.mode == Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
		var screen_size := DisplayServer.screen_get_usable_rect(window.current_screen).size
		var scale := window_scale
		while scale > 1 and (BASE_SIZE.x * scale > screen_size.x or BASE_SIZE.y * scale > screen_size.y):
			scale -= 1
		window.size = BASE_SIZE * scale
		window.move_to_center()
	changed.emit()


## Saves and applies in one go; menus call this after each change.
func commit() -> void:
	save_settings()
	apply()


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.0)
