extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.player_lineup = ["warrior", "lancer", "archer", "monk", "worker"]
	game.active_strategy = fixture_document()
	Engine.time_scale = 12.0
	await game.start_game()
	game.test_mode = false
	game.battle_started = true

	var red_refs: Array = []
	for unit in game.units:
		if unit.team == "red":
			red_refs.append({"unit": unit, "type": unit.unit_type, "slot": unit.strategy_slot})
	var death_order: Array[String] = []
	var recorded_deaths: Dictionary = {}
	var wrong_targets: Array[String] = []
	var worker_target_samples: Array[String] = []
	var worker_trace: Array[String] = []
	var sample_index := 0
	var elapsed := 0.0
	while elapsed < 55.0 and not game.battle_finished:
		await create_timer(0.25).timeout
		elapsed += 0.25
		sample_index += 1
		var red_monk_alive := false
		for entry in red_refs:
			var watched: Variant = entry["unit"]
			if entry["type"] == "monk" and is_instance_valid(watched) and not watched.dead:
				red_monk_alive = true
			if (not is_instance_valid(watched) or watched.dead) and not recorded_deaths.has(entry["slot"]):
				recorded_deaths[entry["slot"]] = true
				death_order.append(String(entry["type"]))
		for unit in game.units:
			if not is_instance_valid(unit) or unit.dead or unit.team != "blue":
				continue
			if unit.unit_type == "worker":
				if is_instance_valid(unit.resource_target):
					worker_target_samples.append(String(unit.resource_target.resource_type))
					if sample_index % 8 == 0:
						worker_trace.append("t=%.1f state=%s distance=%.1f charges=%d carrying=%s" % [elapsed, unit.state, unit.position.distance_to(unit.resource_target.position), unit.resource_target.charges, unit.carrying])
			elif red_monk_alive and is_instance_valid(unit.target) and unit.target.unit_type != "monk":
				wrong_targets.append("%s->%s" % [unit.unit_type, unit.target.unit_type])

	var damaged_blue_resources: Dictionary = {}
	for resource in game.resources:
		if is_instance_valid(resource) and resource.team == "blue" and resource.charges < resource.MAX_CHARGES:
			damaged_blue_resources[resource.resource_type] = true
	check(wrong_targets.is_empty(), "fighters targeted non-monk while enemy monk lived: %s" % [wrong_targets])
	check(not worker_target_samples.is_empty(), "worker never selected a resource")
	check(worker_target_samples.all(func(kind: String) -> bool: return kind == "meat"), "worker selected non-meat: %s" % [worker_target_samples])
	check(damaged_blue_resources.keys().all(func(kind: String) -> bool: return kind == "meat"), "worker damaged non-meat resources: %s" % [damaged_blue_resources.keys()])
	check("monk" in death_order, "enemy monk did not die during playtest")
	if "monk" in death_order:
		check(death_order.find("monk") == 0, "enemy monk was not first red death: %s" % [death_order])

	print("PLAYTEST elapsed=", elapsed, " death_order=", death_order, " blue_resources=", game.resource_counts.get("blue", {}), " worker_samples=", worker_target_samples.size())
	print("WORKER_TRACE ", worker_trace)
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("STRATEGY_FULL_PLAYTEST_OK")
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
		"schema_version":"2.0","compiler_version":"strategy-2.0.0","strategy_name":"先杀僧侣并采肉",
		"directives":[
			{"id":"d1","slots":[1,2,3,4],"channel":"combat","priority":10,"when":[],"action_mode":"all","actions":[{"type":"attack","target_type":"monk"}],"source_messages":[1]},
			{"id":"d2","slots":[5],"channel":"economy","priority":10,"when":[],"action_mode":"all","actions":[{"type":"gather","resource":"meat"}],"source_messages":[1]}
		],
		"message_resolution":[{"message_index":1,"status":"applied","overridden_by":null,"applied_to_slots":[1,2,3,4,5],"note":"测试"}],
		"unit_results":[
			{"slot":1,"status":"accepted","accepted_directive_ids":["d1"],"rejections":[]},{"slot":2,"status":"accepted","accepted_directive_ids":["d1"],"rejections":[]},{"slot":3,"status":"accepted","accepted_directive_ids":["d1"],"rejections":[]},{"slot":4,"status":"accepted","accepted_directive_ids":["d1"],"rejections":[]},{"slot":5,"status":"accepted","accepted_directive_ids":["d2"],"rejections":[]}
		],
		"unit_summaries":{"1":"攻击僧侣","2":"攻击僧侣","3":"攻击僧侣","4":"攻击僧侣","5":"采肉"},"warnings":[]
	}
