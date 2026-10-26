extends TestCase
## Plays through the library test area with simulated input and checks that
## movement, footprints, the gust, props, bookworms, the feather trail and pausing work.
##
##   godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
## With screenshots (opens a window briefly):
##   godot --path . --fixed-fps 60 res://tests/smoke_test.tscn -- --shots=/some/folder

const LEVEL := preload("res://game/levels/library_wake/library_wake.tscn")

var level: Level
var owl: Owl
var feathers_collected := 0


func _ready() -> void:
	var started := Time.get_ticks_msec()
	level = LEVEL.instantiate()
	add_child(level)
	print("  level built in %d ms" % (Time.get_ticks_msec() - started))
	owl = level.player
	for feather in get_tree().get_nodes_in_group("trail_feathers"):
		feather.collected.connect(_on_feather_collected)
	_run.call_deferred()


func _run() -> void:
	await wait_frames(10)
	check(owl.global_position.distance_to(Vector3(0, 0, 2)) < 0.1, "Owl starts at the Start spawn point")
	await shot("00_start")

	var worms: Array[Bookworm] = []
	for worm in level.get_node("Bookworms").get_children():
		worms.append(worm)
	var worm_start := worms[1].global_position
	check(worms.all(func(w: Bookworm) -> bool: return w.body_length() > 1.0), "Bookworms are long (over 1 unit)")
	check(_all_different(worms.map(func(w: Bookworm) -> Color: return w.body_color)), "Every bookworm is a different colour")

	var footprints := owl.get_node("Footprints") as FootprintTrail
	await walk_to(Vector2(0, -9.5))
	check(footprints.visible_count() >= 5, "Walking leaves footprints (%d showing)" % footprints.visible_count())
	await shot("01_row_a")
	await walk_to(Vector2(5.5, -11.6))
	await walk_to(Vector2(5.5, -12.7))
	await shot("02_blocked_gap")
	await flap_facing(Vector2.UP, 4)
	await shot("03_after_gust")
	var blocking := level.get_node("BlockedGap").get_children().filter(
		func(prop: Node3D) -> bool: return prop.global_position.z > -14.6 and absf(prop.global_position.x - 5.5) < 1.2)
	check(blocking.is_empty(), "Gust cleared the pages and books out of the gap")
	# Blown books can land on the path, so step through and flap again.
	await walk_to(Vector2(5.5, -14.9), true)
	await flap_facing(Vector2.UP, 2)
	await walk_to(Vector2(5.5, -16.4))
	# Bookworm1 crawls around here, so it may be in the way.
	await walk_to(Vector2(1.5, -16.3), true)
	check(worms[1].global_position.distance_to(worm_start) > 0.3, "Bookworms crawl around")
	check(worms.all(func(w: Bookworm) -> bool: return w.global_position.distance_to(w.home) < w.wander_radius + 1.0),
		"Bookworms stay near where they were placed")
	await shot("04_bookworm")
	var hurt := await gust_worm(worms[0])
	check(hurt, "Gust hurt Bookworm1")
	await walk_to(Vector2(-3.5, -16.8))
	await walk_to(Vector2(-8.6, -17.0))
	await walk_to(Vector2(-8.2, -21.0))
	await walk_to(Vector2(-7.75, -25.0))
	await shot("05_north_side")
	await walk_to(Vector2(-3.0, -29.0))
	await walk_to(Vector2(0.0, -33.0))
	await wait_seconds(0.5)
	await shot("06_trail_end")
	await wait_seconds(footprints.hold_time + footprints.fade_time)
	check(footprints.visible_count() == 0, "Footprints fade away once the owl stops")
	check(feathers_collected == 8, "Collected all 8 feathers (got %d)" % feathers_collected)
	check(level.progress_summary() == "Yellow feathers found: 8 of 8", "Level reports feather progress for the pause card")

	await tap("start")
	check(get_tree().paused, "Start opens the pause menu and pauses the game")
	await shot("07_pause_menu")
	await tap("start")
	check(not get_tree().paused, "Start again closes the pause menu")
	finish()


func walk_to(goal: Vector2, may_block := false) -> void:
	var waited := 0.0
	var limit := 1.5 if may_block else 8.0
	while true:
		var here := Vector2(owl.global_position.x, owl.global_position.z)
		var to_goal := goal - here
		if to_goal.length() < 0.25:
			break
		if waited > limit:
			if not may_block:
				fail("Owl got stuck walking to %s (reached %s)" % [goal, here.snappedf(0.01)])
			break
		_press_direction(to_goal.normalized())
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	_press_direction(Vector2.ZERO)


func flap_facing(direction: Vector2, times: int) -> void:
	_press_direction(direction)
	await wait_frames(3)
	_press_direction(Vector2.ZERO)
	for i in times:
		Input.action_press("accept")
		await wait_frames(2)
		Input.action_release("accept")
		await wait_seconds(0.4)
	await wait_seconds(0.6)


## Walks up to a crawling worm and flaps at it until it's defeated (or tries run out).
## Returns true if the gust hurt it.
func gust_worm(worm: Bookworm, tries := 8) -> bool:
	var hurt := false
	for i in tries:
		if not is_instance_valid(worm) or worm.health <= 0:
			return true
		var target := Vector2(worm.global_position.x, worm.global_position.z)
		await walk_to(target + Vector2(0, 0.8), true)
		var here := Vector2(owl.global_position.x, owl.global_position.z)
		var health := worm.health
		await flap_facing((target - here).normalized(), 1)
		hurt = hurt or not is_instance_valid(worm) or worm.health < health
	return hurt


func _on_feather_collected(_feather: TrailFeather) -> void:
	feathers_collected += 1


func _press_direction(direction: Vector2) -> void:
	_set_action("move_right", maxf(direction.x, 0.0))
	_set_action("move_left", maxf(-direction.x, 0.0))
	_set_action("move_down", maxf(direction.y, 0.0))
	_set_action("move_up", maxf(-direction.y, 0.0))


func _set_action(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _all_different(colors: Array) -> bool:
	for i in colors.size():
		for j in range(i + 1, colors.size()):
			var a: Color = colors[i]
			var b: Color = colors[j]
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.25:
				return false
	return true
