extends TestCase
## Plays the whole loop through the real menus with simulated button presses:
## title -> new game -> skip intro -> play -> pause (Edit Deck, Options) ->
## save and quit -> Continue, and checks the owl comes back exactly where it was.
##   godot --headless --path . --fixed-fps 60 res://tests/flow_test.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Keep this test node alive while the game changes scenes around it.
	get_tree().current_scene = null

	await Game.go_to_title()
	check(await wait_until(func() -> bool: return _scene_name() == "TitleScreen"), "Title screen loads")
	await wait_frames(5)
	await shot("10_title")
	await tap("start")
	await shot("11_title_menu")
	check(_focused_text() == "New game", "With no saves, the menu starts on New game (Continue is greyed out)")
	await tap("ui_accept")
	await wait_frames(3)
	check(_focused_text().begins_with("Slot 1"), "New game opens the slot picker on slot 1")
	await tap("ui_accept")
	check(await wait_until(func() -> bool: return _scene_name() == "IntroCutscene", 5.0), "Choosing an empty slot starts the intro")
	check(SaveManager.has_game() and SaveManager.slot == 0, "A new game is created in slot 1")

	await wait_seconds(1.5)
	await shot("12_intro")
	Input.action_press("accept")
	await wait_seconds(0.6)
	await shot("13_intro_skipping")
	var skipped := await wait_until(func() -> bool: return Game.state == Game.State.PLAYING and Game.current_level != null, 8.0)
	Input.action_release("accept")
	check(skipped, "Holding the action button skips the intro into the library")
	await wait_frames(10)
	check(SaveManager.slot_summary(0).state == "ok", "Arriving in the library saves the game")

	var level := Game.current_level
	var owl := level.player
	Input.action_press("move_up")
	await wait_seconds(1.3)
	Input.action_release("move_up")
	await wait_seconds(0.3)
	var feather := level.get_node_or_null("FeatherTrail/Feather1") as TrailFeather
	check(feather == null or feather.is_collected(), "Walking north picks up the first feather")
	check(await wait_until(_feather1_saved, 4.0), "Picking up a feather autosaves it")

	# Pause menu: Edit Deck with a new card.
	SaveManager.add_card("light")
	await tap("start")
	check(get_tree().paused, "Start pauses the game")
	await shot("14_pause")
	check(_focused_text() == "Resume", "The pause menu starts on Resume")
	var pause := level.get_node("PauseMenu") as PauseMenu
	var deck_button: Button = pause._list.button("Edit Deck")
	check(deck_button != null and deck_button.get_child_count() > 0, "Edit Deck shows a ! badge for the new card")
	await tap("ui_down")
	check(_focused_text() == "Edit Deck", "Down moves to Edit Deck")
	await tap("ui_accept")
	await wait_frames(3)
	await shot("15_edit_deck")
	check(_focused_text().begins_with("Light"), "Edit Deck lists the Light card")
	check(not SaveManager.has_unseen("deck"), "Opening Edit Deck clears the badge")
	await tap("ui_accept")
	check(SaveManager.data.cards.deck == ["light"], "Accept puts the card in the deck")
	await tap("ui_cancel")
	await wait_frames(3)
	check(_focused_text() == "Resume", "Decline goes back to the pause menu")

	# Options: change the master volume.
	await tap("ui_down")
	await tap("ui_down")
	check(_focused_text() == "Options", "Down twice reaches Options")
	await tap("ui_accept")
	await wait_frames(3)
	await shot("16_options")
	check(_focused() is HSlider, "Options opens on the first volume slider")
	var volume_before := Settings.master_volume
	await tap("ui_left")
	check(Settings.master_volume < volume_before, "Left lowers the master volume")
	check(FileAccess.file_exists(Settings.path), "Options are saved to the settings file")
	await tap("ui_cancel")
	await wait_frames(3)
	check(_focused_text() == "Resume", "Decline goes back to the pause menu")

	# Save and quit, then continue.
	var saved_position := owl.global_position
	var saved_facing := owl.facing
	for i in 3:
		await tap("ui_down")
	check(_focused_text() == "Save and quit to title", "Down three times reaches Save and quit")
	await tap("ui_accept")
	check(await wait_until(func() -> bool: return _scene_name() == "TitleScreen", 5.0), "Save and quit returns to the title")
	check(not get_tree().paused, "The title screen isn't paused")
	check(not SaveManager.has_game(), "The game is closed after quitting")
	var summary := SaveManager.slot_summary(0)
	check(summary.state == "ok" and summary.get("level_name") == "The Grassy Library", "Slot 1 shows the library")
	check(summary.get("play_time", 0.0) > 1.0, "Play time was recorded (%.1f s)" % summary.get("play_time", 0.0))

	await wait_frames(5)
	await tap("start")
	await shot("17_title_continue")
	check(_focused_text() == "Continue", "With a save, the menu starts on Continue")
	await tap("ui_accept")
	check(await wait_until(func() -> bool: return Game.state == Game.State.PLAYING and Game.current_level != null, 5.0), "Continue loads the library")
	await wait_frames(5)
	var restored_owl := Game.current_level.player
	check(restored_owl.global_position.distance_to(saved_position) < 0.05, "Continue puts the owl exactly where it was saved")
	check(restored_owl.facing == saved_facing, "The owl faces the same way as when saved")
	var restored_feather := Game.current_level.get_node_or_null("FeatherTrail/Feather1") as TrailFeather
	check(restored_feather == null or restored_feather.is_queued_for_deletion(), "The collected feather stays collected")
	check(SaveManager.data.cards.deck == ["light"], "The deck is remembered")
	finish()


func _feather1_saved() -> bool:
	var levels: Dictionary = SaveManager.read_slot(0).get("levels", {})
	return levels.get("library_wake", {}).get("FeatherTrail/Feather1", false) == true


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _focused_text() -> String:
	var focused := _focused()
	return focused.text if focused is Button else ""


func _scene_name() -> String:
	var scene := get_tree().current_scene
	return String(scene.name) if scene else ""
