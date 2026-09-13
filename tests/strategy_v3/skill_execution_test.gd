extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.player_lineup = ["archer", "warrior"]
	game.active_strategy = fixture_plan()
	game.battle_snapshot = fixture_snapshot()
	await game.start_game()
	while not game.battle_started: await process_frame
	var caster: Node2D = game.get_unit_by_slot("blue", 1)
	var target: Node2D = game.get_unit_by_slot("red", 1)
	caster.position = Vector2(340, 760)
	target.position = Vector2(340, 650)
	var start_hp := int(target.hp)
	while game.battle_elapsed < 1.5: await process_frame
	check(game.units.filter(func(unit): return unit.team == "blue").size() == 2, "2人阵容不应补齐默认英雄")
	check(game.replay_strategy_events.any(func(event): return event.get("type") == "skill_cast" and event.get("skillId") == "power_arrow"), "cast_skill 应产生技能施放事件")
	check(game.replay_projectile_events.any(func(event): return event.get("sourceKind") == "skill:power_arrow"), "投射物技能应使用统一 ProjectileEngine")
	check(target.hp < start_hp, "伤害技能应通过战斗结算降低目标生命")
	game.free()
	if failures.is_empty():
		print("STRATEGY_V3_SKILL_EXECUTION_OK")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func fixture_snapshot() -> Dictionary:
	return {"teams":{"blue":{"heroes":[
		{"slotNo":1,"skills":[{"skillNo":1,"skillId":"power_arrow","cd":0.6,"castRange":220.0,"castTime":0.1,"recoveryTime":0.1,
			"targetType":"enemy","effect":{"type":"damage","value":31.0},"projectile":{"speed":700.0,"radius":6.0,"range":240.0,
			"blockedByObstacle":true,"blockedByEnemyUnit":true,"blockedByAllyUnit":false,"pierceEnemyUnit":false,"maxPierceCount":0}}]},
		{"slotNo":2,"skills":[]}
	]}}}

func fixture_plan() -> Dictionary:
	var rule := {"id":"r_skill","actorIds":["blue_1"],"channel":"combat","priorityClass":"CRITICAL_SKILL","priorityModifier":0,"specificityClass":"EXACT","sourceOrder":1,
		"when":{"op":"eq","left":{"node":"field","path":"self.is_alive"},"right":{"node":"const","value":true}},
		"targetBinding":{"writeRole":"skill_target","selector":{"scope":"visible_enemy_units","filters":[{"field":"is_alive","op":"eq","value":{"node":"const","value":true}}],"sort":[{"field":"distance_to_self","order":"asc"}],"limit":1},"releasePolicy":"on_target_invalid"},
		"resourceClaims":[{"resource":"PRIMARY_COMBAT","mode":"exclusive"},{"resource":"SKILL_SLOT:1","mode":"exclusive"},{"resource":"TARGET_ROLE:skill_target","mode":"exclusive"}],
		"action":{"opcode":"cast_skill","skillNo":1,"targetRef":"skill_target","interruptClass":"COMBAT","interruptibleBy":["SYSTEM_FORCE","EMERGENCY_SURVIVAL"]},
		"until":null,"fallback":null,"runtimePrerequisites":[],"execution":{"recoveryPolicy":"resume","retriggerPolicy":"on_condition_reenter","minActiveTicks":1,"cooldownTicks":0,"replanIntervalTicks":1,"replanEvents":["target_invalid","skill_ready"]},"sourceMessageIds":["m1"]}
	return {"schemaVersion":"3.0","compilerVersion":"strategy-compiler-3.0.0","metadataVersion":"strategy-metadata-3.0.0","snapshotId":"s","snapshotHash":"sha256:test","planHash":"sha256:test","units":{"blue_1":{"rules":[rule]}},"sourceMap":{},"compileResults":[],"warnings":[]}
