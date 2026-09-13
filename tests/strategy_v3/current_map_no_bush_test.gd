extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	# Set this before _ready so account bootstrap does not leave an HTTP timer
	# alive when this short headless test exits.
	game.test_mode = true
	root.add_child(game)
	await process_frame
	# The current map snapshot intentionally has no bush capability.
	game.battle_snapshot = {"map":{"supportedAreaTypes":["open_ground", "spawn_zone"]}}
	await game.start_game()
	while not game.battle_started:
		await process_frame
	check(game.battle_areas.is_empty(), "current map must not register functional bushes")
	check(game.area_type_at(Vector2(150, 250)) == "enemy_side", "old decorative coordinates must not behave as bushes")
	var unit: Node2D = game.get_unit_by_slot("blue", 1)
	check(game.nearest_area_position(unit, "bush") == unit.position, "unsupported bush selector must not invent a destination")
	# Let the countdown coroutine release its final timer/layer before teardown.
	await create_timer(1.0).timeout
	game.free()
	if failures.is_empty():
		print("CURRENT_MAP_NO_BUSH_TEST_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
