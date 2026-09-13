extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	# Prevent asynchronous cloud bootstrap from outliving this short fixture.
	game.test_mode = true
	root.add_child(game)
	await process_frame
	# Bush mechanics are a future-map capability. This fixture enables them
	# explicitly without changing the current production map baseline.
	game.battle_snapshot = {"map":{"supportedAreaTypes":["open_ground", "spawn_zone", "bush"]}}
	await game.start_game()
	while not game.battle_started:
		await process_frame
	var observer: Node2D = game.get_unit_by_slot("blue", 1)
	var target: Node2D = game.get_unit_by_slot("red", 1)
	var ally: Node2D = game.get_unit_by_slot("red", 2)
	observer.position = Vector2(360, 640)
	target.position = Vector2(150, 250)
	ally.position = Vector2(155, 252)
	check(game.area_type_at(target.position) == "bush", "future bush-enabled map must expose functional areas")
	check(not game.can_see_unit(observer, target), "enemy outside bush must not see hidden target")
	check(game.can_see_unit(ally, target), "ally visibility must not be blocked by bush")
	observer.position = Vector2(145, 248)
	check(game.can_see_unit(observer, target), "enemy in the same bush must see target")
	var nearest: Vector2 = game.nearest_area_position(game.get_unit_by_slot("blue", 3), "bush")
	check(game.area_type_at(nearest) == "bush", "nearest bush selector destination must resolve to a bush")
	await create_timer(1.0).timeout
	game.free()
	if failures.is_empty():
		print("BUSH_VISIBILITY_TEST_OK")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
