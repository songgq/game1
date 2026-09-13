extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.test_mode = true; Engine.time_scale = 1.0
	game.player_lineup = ["warrior","lancer","archer","monk","worker"]
	game.active_strategy = fixture_plan()
	await game.start_game()
	while not game.battle_started: await process_frame
	var protected: Node2D = game.get_unit_by_slot("blue",2)
	var blocker: Node2D = game.get_unit_by_slot("blue",3)
	var attacker: Node2D = game.get_unit_by_slot("red",1)
	protected.position = Vector2(360,800); blocker.position = Vector2(250,800); attacker.position = Vector2(360,650)
	protected.last_move_direction = Vector2.RIGHT
	var static_point: Vector2 = game.line_block_position(attacker,protected,blocker,false)
	var predicted_point: Vector2 = game.line_block_position(attacker,protected,blocker,true)
	check(predicted_point.x > static_point.x, "时间预测挡线应考虑保护目标在前摇和飞行期间的移动")
	protected.last_move_direction = Vector2.ZERO
	protected.move_speed = 0.0; attacker.move_speed = 0.0
	attacker.target = protected; attacker.target_locked = true; attacker.action_cooldown = 2.5
	var initial_distance: float = blocker.position.distance_to(game.line_block_position(attacker,protected,blocker,true))
	while game.battle_elapsed < 4.0: await process_frame
	var final_distance: float = blocker.position.distance_to(game.line_block_position(attacker,protected,blocker,true))
	check(final_distance < initial_distance, "挡线者应持续靠近预测挡线位置")
	check(game.strategy_runtime.runtimes["blue_3"].states.state("r_block") in ["ACTIVE","PENDING"], "挡线规则应在保护目标被瞄准时激活")
	check(game.replay_projectile_events.any(func(event): return event.get("type") == "projectile_hit" and event.get("intendedTargetId") == protected.replay_id and event.get("actualHitTargetId") == blocker.replay_id),
		"主动挡线后真实弹道应记录 intended=2号、actual=3号 events=%s positions=%s/%s/%s" % [game.replay_projectile_events,attacker.position,blocker.position,protected.position])
	Engine.time_scale = 1.0; game.free()
	if failures.is_empty():
		print("LINE_BLOCK_STRATEGY_TEST_OK")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func fixture_plan() -> Dictionary:
	var rule := {"id":"r_block","actorIds":["blue_3"],"channel":"survival","priorityClass":"PROTECTION","priorityModifier":0,"specificityClass":"EXACT","sourceOrder":1,
		"when":{"op":"eq","left":{"node":"field","path":"self.is_alive"},"right":{"node":"const","value":true}},"targetBinding":null,
		"resourceClaims":[{"resource":"MOVE","mode":"exclusive"}],
		"action":{"opcode":"move_to_position","positionRef":{"function":"line_block_position","protectedSlot":2,"predict":true},"interruptClass":"EMERGENCY_SURVIVAL","interruptibleBy":["SYSTEM_FORCE","EMERGENCY_SURVIVAL"]},
		"until":null,"fallback":{"opcode":"hold_position","allowCombat":true},"runtimePrerequisites":[],
		"execution":{"recoveryPolicy":"resume","retriggerPolicy":"on_condition_reenter","minActiveTicks":3,"cooldownTicks":0,"replanIntervalTicks":1,"replanEvents":["target_invalid","damage_received"]},"sourceMessageIds":["m1"]}
	return {"schemaVersion":"3.0","compilerVersion":"strategy-compiler-3.0.0","metadataVersion":"strategy-metadata-3.0.0","snapshotId":"s","snapshotHash":"sha256:test","planHash":"sha256:test","units":{"blue_3":{"rules":[rule]}},"sourceMap":{},"compileResults":[],"warnings":[]}
