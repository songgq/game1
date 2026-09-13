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
	Engine.time_scale = 1.0
	game.player_lineup = ["warrior", "lancer", "archer", "monk", "worker"]
	game.active_strategy = fixture_plan()
	await game.start_game()
	while not game.battle_started: await process_frame
	var unit3: Node2D = game.get_unit_by_slot("blue", 3)
	var opening_position := unit3.position
	for _index in 20: await process_frame
	check(unit3.position.distance_to(opening_position) < 1.0, "3号在开局保持阶段不得主动移动")
	while game.battle_elapsed < 1.6: await process_frame
	var runtime: Variant = game.strategy_runtime.runtimes.get("blue_3")
	check(unit3.position.distance_to(opening_position) > 2.0, "等待结束后3号应开始跟随2号 position=%s elapsed=%.2f states=%s leases=%s" % [unit3.position, game.battle_elapsed, runtime.states.records, runtime.action_state.active_by_resource])
	check(game.strategy_runtime.is_active(), "Strategy 3.0 adapter should remain active")
	Engine.time_scale = 1.0
	game.free()
	if failures.is_empty():
		print("STRATEGY_V3_FULL_PLAYTEST_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func execution(retrigger: String) -> Dictionary:
	return {"recoveryPolicy":"resume","retriggerPolicy":retrigger,"minActiveTicks":1,"cooldownTicks":0,"replanIntervalTicks":1,"replanEvents":["damage_received"]}

func fixture_plan() -> Dictionary:
	var before := {"op":"lt","left":{"node":"field","path":"battle.elapsed_time"},"right":{"node":"const","value":1.0}}
	var after := {"op":"gte","left":{"node":"field","path":"battle.elapsed_time"},"right":{"node":"const","value":1.0}}
	var alive := {"op":"eq","left":{"node":"field","path":"self.is_alive"},"right":{"node":"const","value":true}}
	var hold := {"id":"r_0001","actorIds":["blue_3"],"channel":"locomotion","priorityClass":"IDLE","priorityModifier":0,"specificityClass":"EXACT","sourceOrder":1,
		"when":{"op":"all","args":[alive,before]},"targetBinding":null,"resourceClaims":[{"resource":"MOVE","mode":"exclusive"}],
		"action":{"opcode":"hold_position","allowCombat":true,"interruptClass":"TACTICAL_MOVE","interruptibleBy":["SYSTEM_FORCE","EMERGENCY_SURVIVAL"]},"until":after,"fallback":null,
		"runtimePrerequisites":[],"execution":execution("never"),"sourceMessageIds":["m1"]}
	var follow_selector := {"scope":"ally_units","filters":[{"field":"slot_no","op":"eq","value":{"node":"const","value":2}},{"field":"is_alive","op":"eq","value":{"node":"const","value":true}}],"sort":[{"field":"slot_no","order":"asc"}],"limit":1}
	var follow := {"id":"r_0002","actorIds":["blue_3"],"channel":"locomotion","priorityClass":"FOLLOW","priorityModifier":0,"specificityClass":"EXACT","sourceOrder":2,
		"when":{"op":"all","args":[alive,after]},"targetBinding":{"writeRole":"follow_target","selector":follow_selector,"releasePolicy":"on_target_invalid"},
		"resourceClaims":[{"resource":"MOVE","mode":"exclusive"},{"resource":"TARGET_ROLE:follow_target","mode":"exclusive"}],
		"action":{"opcode":"follow","targetRef":"follow_target","distance":48.0,"interruptClass":"TACTICAL_MOVE","interruptibleBy":["SYSTEM_FORCE","EMERGENCY_SURVIVAL"]},"until":null,
		"fallback":{"opcode":"hold_position","allowCombat":true},"runtimePrerequisites":[],"execution":execution("on_condition_reenter"),"sourceMessageIds":["m2"]}
	return {"schemaVersion":"3.0","compilerVersion":"strategy-compiler-3.0.0","metadataVersion":"strategy-metadata-3.0.0","snapshotId":"s1","snapshotHash":"sha256:test","planHash":"sha256:test",
		"units":{"blue_3":{"rules":[hold,follow]}},"sourceMap":{},"compileResults":[],"warnings":[]}
