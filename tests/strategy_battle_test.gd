extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.strategy_messages = []
	var pending_input := LineEdit.new()
	pending_input.text = "先杀僧侣 工人先采集肉"
	check(game.apply_pending_strategy_input(pending_input), "send/save should automatically commit pending input")
	check(game.strategy_messages == ["先杀僧侣 工人先采集肉"], "pending input should become the current strategy message")
	game.player_lineup = ["warrior", "lancer", "archer", "monk", "worker"]
	game.active_strategy = fixture_document()
	check(game.active_strategy_hud_text() == "优先攻击僧侣 · 工人采集肉", "HUD should show the active strategy")
	await game.start_game()
	game.battle_started = true
	for _frame in 8:
		await process_frame

	var blue_units: Array = game.units.filter(func(unit: Node) -> bool: return is_instance_valid(unit) and unit.team == "blue")
	for unit in blue_units:
		if unit.unit_type == "worker":
			check(is_instance_valid(unit.resource_target), "worker should select a resource")
			if is_instance_valid(unit.resource_target):
				check(unit.resource_target.resource_type == "meat", "worker should target meat, got %s" % unit.resource_target.resource_type)
		else:
			check(is_instance_valid(unit.target), "%s should select an enemy" % unit.unit_type)
			if is_instance_valid(unit.target):
				check(unit.target.unit_type == "monk", "%s should target monk, got %s" % [unit.unit_type, unit.target.unit_type])

	if failures.is_empty():
		print("STRATEGY_BATTLE_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func fixture_document() -> Dictionary:
	return {
		"schema_version": "2.0",
		"compiler_version": "strategy-2.0.0",
		"strategy_name": "先杀僧侣并采肉",
		"directives": [
			{"id":"d1","slots":[1,2,3,4],"channel":"combat","priority":10,"when":[],"action_mode":"all","actions":[{"type":"attack","target_type":"monk"}],"source_messages":[1]},
			{"id":"d2","slots":[5],"channel":"economy","priority":10,"when":[],"action_mode":"all","actions":[{"type":"gather","resource":"meat"}],"source_messages":[1]}
		],
		"message_resolution": [{"message_index":1,"status":"applied","overridden_by":null,"applied_to_slots":[1,2,3,4,5],"note":"先杀僧侣，工人采肉"}],
		"unit_results": [
			{"slot":1,"status":"accepted","accepted_directive_ids":["d1"],"rejections":[]},
			{"slot":2,"status":"accepted","accepted_directive_ids":["d1"],"rejections":[]},
			{"slot":3,"status":"accepted","accepted_directive_ids":["d1"],"rejections":[]},
			{"slot":4,"status":"accepted","accepted_directive_ids":["d1"],"rejections":[]},
			{"slot":5,"status":"accepted","accepted_directive_ids":["d2"],"rejections":[]}
		],
		"unit_summaries": {"1":"攻击僧侣","2":"攻击僧侣","3":"攻击僧侣","4":"攻击僧侣","5":"采肉"},
		"warnings": []
	}
