extends Node
## Save slots. Autoloaded as `SaveManager`.
##
## Each slot is one small file holding only progress: story flags, what's been
## collected or changed in each level, cards, play time and where the owl stands.
## Files are compressed, checksummed, written to a temporary file first and then
## swapped in, and the previous save is kept as a backup. If a save is damaged,
## the backup is loaded instead.

signal saved(slot: int)

const SLOT_COUNT := 3
## Bump when the shape of the save data changes, and add a step to _migrate().
const DATA_VERSION := 1
const MAGIC := "DRMS"
const MAX_FILE_BYTES := 16 * 1024 * 1024

## Folder for save files. Tests point this somewhere else.
var save_dir := "user://saves"
## Live save data for the slot being played. Empty when no game is running.
var data: Dictionary = {}
## Slot being played, or -1.
var slot := -1


#region Slots

func has_game() -> bool:
	return slot >= 0 and not data.is_empty()


func new_game(slot_index: int) -> Error:
	slot = slot_index
	data = _fresh_data()
	return write()


func load_game(slot_index: int) -> bool:
	var loaded := read_slot(slot_index)
	if loaded.is_empty():
		return false
	slot = slot_index
	data = loaded
	return true


func close_game() -> void:
	slot = -1
	data = {}


## Writes the current game to its slot. Returns OK on success.
func write() -> Error:
	if not has_game():
		return ERR_UNCONFIGURED
	data.saved_unix = int(Time.get_unix_time_from_system())
	var err := _write_file(_slot_path(slot), data)
	if err == OK:
		saved.emit(slot)
	else:
		push_error("Saving slot %d failed (error %d)" % [slot, err])
	return err


## Reads a slot without making it the current game. Returns {} if the slot is
## empty or both the save and its backup are unreadable.
func read_slot(slot_index: int) -> Dictionary:
	var path := _slot_path(slot_index)
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var loaded := _read_file(candidate)
		if not loaded.is_empty():
			return loaded
		push_warning("Save file %s is damaged" % candidate)
	return {}


## What the slot menus show. "state" is "empty", "ok" or "damaged".
func slot_summary(slot_index: int) -> Dictionary:
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return {"state": "empty"}
	var loaded := read_slot(slot_index)
	if loaded.is_empty():
		return {"state": "damaged"}
	return {
		"state": "ok",
		"level_name": loaded.level_name,
		"play_time": loaded.play_time,
		"saved_unix": loaded.saved_unix,
	}


## The slot saved most recently, or -1 if there are none.
func most_recent_slot() -> int:
	var best := -1
	var best_time := -1
	for i in SLOT_COUNT:
		var summary := slot_summary(i)
		if summary.state == "ok" and summary.saved_unix > best_time:
			best = i
			best_time = summary.saved_unix
	return best


func delete_slot(slot_index: int) -> void:
	var path := _slot_path(slot_index)
	for file in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	if slot == slot_index:
		close_game()

#endregion


#region Progress helpers

func set_flag(flag: String, value: Variant = true) -> void:
	if has_game():
		data.flags[flag] = value


func get_flag(flag: String, default: Variant = false) -> Variant:
	return data.flags.get(flag, default) if has_game() else default


## Saved state for one level: {node path: state}. Empty if never saved.
func level_state(level_id: String) -> Dictionary:
	return data.levels.get(level_id, {}) if has_game() else {}


func set_level_state(level_id: String, state: Dictionary) -> void:
	if has_game():
		data.levels[level_id] = state


## Cards the player owns, by id.
func owned_cards() -> Array:
	return data.cards.owned if has_game() else []


func add_card(card_id: String) -> void:
	if not has_game():
		return
	data.cards.owned.append(card_id)
	mark_unseen("deck")


## Marks something new for a "!" badge, e.g. "deck" when a card unlocks.
func mark_unseen(key: String) -> void:
	if has_game() and key not in data.unseen:
		data.unseen.append(key)


func clear_unseen(key: String) -> void:
	if has_game():
		data.unseen.erase(key)


func has_unseen(key: String) -> bool:
	return has_game() and key in data.unseen

#endregion


#region Files

func _slot_path(slot_index: int) -> String:
	return save_dir.path_join("slot_%d.save" % (slot_index + 1))


func _fresh_data() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	return {
		"version": DATA_VERSION,
		"created_unix": now,
		"saved_unix": now,
		"play_time": 0.0,
		"level_path": "",
		"level_name": "",
		"player": {},
		"flags": {},
		"levels": {},
		"cards": {"owned": [], "deck": [], "die": ""},
		"records": [],
		"unseen": [],
	}


## File layout: magic, data version, raw size, SHA-256 of the raw bytes,
## compressed size, then the zstd-compressed bytes of the data.
func _write_file(path: String, value: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var raw := var_to_bytes(value)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)

	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(DATA_VERSION)
	file.store_32(raw.size())
	file.store_buffer(_sha256(raw))
	file.store_32(packed.size())
	file.store_buffer(packed)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error

	# Keep the previous save as a backup, then swap the new one in.
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(temp_path, path)


func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() < 48 or file.get_length() > MAX_FILE_BYTES:
		return {}
	if file.get_buffer(4).get_string_from_ascii() != MAGIC:
		return {}
	var version := file.get_32()
	var raw_size := file.get_32()
	var checksum := file.get_buffer(32)
	var packed_size := file.get_32()
	if version > DATA_VERSION or raw_size > MAX_FILE_BYTES or packed_size != file.get_length() - file.get_position():
		return {}
	var raw := file.get_buffer(packed_size).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size or _sha256(raw) != checksum:
		return {}
	# bytes_to_var never creates objects, so a tampered save can't run code.
	var value: Variant = bytes_to_var(raw)
	if not value is Dictionary:
		return {}
	return _migrate(value)


## Brings older saves up to date and fills in anything missing.
func _migrate(value: Dictionary) -> Dictionary:
	# Example for later: if value.version < 2: <convert fields>; value.version = 2
	var fresh := _fresh_data()
	for key in fresh:
		if not value.has(key) or typeof(value[key]) != typeof(fresh[key]):
			value[key] = fresh[key]
	for key in fresh.cards:
		if not value.cards.has(key):
			value.cards[key] = fresh.cards[key]
	value.version = DATA_VERSION
	return value


func _sha256(bytes: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()

#endregion
