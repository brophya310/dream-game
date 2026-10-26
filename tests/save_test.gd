extends TestCase
## Checks the save system: round trips, backups, damaged files, version handling
## and file size. Uses user://test_saves, never real save slots.
##   godot --headless --path . res://tests/save_test.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Round trip, including Godot types like Vector3 and Transform3D.
	check(SaveManager.slot_summary(0).state == "empty", "A fresh slot reads as empty")
	check(SaveManager.new_game(0) == OK, "New game writes a save")
	SaveManager.set_flag("met_finch")
	SaveManager.add_card("light")
	SaveManager.data.player = {"position": Vector3(1.5, 0, -3.25), "facing": "north-east"}
	SaveManager.set_level_state("library_wake", {"BlockedGap/BookLeft": Transform3D(Basis.IDENTITY, Vector3(5, 0.1, -16))})
	SaveManager.data.play_time = 123.4
	check(SaveManager.write() == OK, "Second write succeeds")
	var loaded := SaveManager.read_slot(0)
	check(loaded.get("flags", {}).get("met_finch", false) == true, "Story flags survive saving")
	check(loaded.cards.owned == ["light"], "Owned cards survive saving")
	check("deck" in loaded.unseen, "New card marks Edit Deck with a ! badge")
	check(loaded.player.position == Vector3(1.5, 0, -3.25), "Owl position survives saving exactly")
	check(loaded.levels.library_wake["BlockedGap/BookLeft"].origin == Vector3(5, 0.1, -16), "Moved props survive saving")
	check(is_equal_approx(loaded.play_time, 123.4), "Play time survives saving")

	var path := TEST_SAVE_DIR.path_join("slot_1.save")
	check(FileAccess.file_exists(path + ".bak"), "The previous save is kept as a backup")
	check(not FileAccess.file_exists(path + ".tmp"), "No temporary file is left behind")
	var size := FileAccess.get_file_as_bytes(path).size()
	print("  save file is %d bytes" % size)
	check(size < 2048, "A save file is small (%d bytes)" % size)

	# A damaged save falls back to the backup.
	SaveManager.set_flag("second_write_only")
	SaveManager.write()
	_corrupt(path)
	var recovered := SaveManager.read_slot(0)
	check(not recovered.is_empty(), "A damaged save falls back to its backup")
	check(not recovered.flags.has("second_write_only"), "The backup is the previous save")
	_corrupt(path + ".bak")
	check(SaveManager.slot_summary(0).state == "damaged", "With both copies damaged the slot shows as damaged")
	check(not SaveManager.load_game(0), "A damaged slot can't be loaded")

	# Truncated and junk files.
	_write_bytes(path, FileAccess.get_file_as_bytes(path).slice(0, 20))
	DirAccess.remove_absolute(path + ".bak")
	check(SaveManager.read_slot(0).is_empty(), "A truncated save is rejected")
	var junk := PackedByteArray()
	for i in 300:
		junk.append(randi() % 256)
	_write_bytes(path, junk)
	check(SaveManager.read_slot(0).is_empty(), "A junk file is rejected")

	# Older saves are filled in; saves from a newer game version are refused.
	var old_save := SaveManager._fresh_data()
	old_save.erase("records")
	old_save.erase("unseen")
	SaveManager._write_file(TEST_SAVE_DIR.path_join("slot_2.save"), old_save)
	var migrated := SaveManager.read_slot(1)
	check(migrated.has("records") and migrated.has("unseen"), "Older saves get any missing fields filled in")
	_write_version(TEST_SAVE_DIR.path_join("slot_3.save"), 99)
	check(SaveManager.read_slot(2).is_empty(), "Saves from a newer game version are refused")

	# Continue picks the most recently saved slot.
	SaveManager.delete_slot(0)
	SaveManager.delete_slot(2)
	var older := SaveManager._fresh_data()
	older.saved_unix = 1000
	var newer := SaveManager._fresh_data()
	newer.saved_unix = 2000
	SaveManager._write_file(TEST_SAVE_DIR.path_join("slot_1.save"), older)
	SaveManager._write_file(TEST_SAVE_DIR.path_join("slot_3.save"), newer)
	SaveManager.delete_slot(1)
	check(SaveManager.most_recent_slot() == 2, "Continue picks the most recently saved slot")
	SaveManager.delete_slot(2)
	check(SaveManager.slot_summary(2).state == "empty", "Deleting a slot empties it")
	finish()


## Flips bytes in the middle of a file so its checksum no longer matches.
func _corrupt(file_path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(file_path)
	for i in range(bytes.size() / 2, mini(bytes.size() / 2 + 8, bytes.size())):
		bytes[i] = bytes[i] ^ 0xFF
	_write_bytes(file_path, bytes)


func _write_bytes(file_path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## Writes a valid save but stamps it with a different data version.
func _write_version(file_path: String, version: int) -> void:
	SaveManager._write_file(file_path, SaveManager._fresh_data())
	var bytes := FileAccess.get_file_as_bytes(file_path)
	bytes.encode_u32(4, version)
	_write_bytes(file_path, bytes)
