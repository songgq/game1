extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.test_mode = true
	game.player_lineup = ["warrior", "lancer", "archer"]
	game.active_strategy = fixture_plan()
	await game.start_game()
	while not game.battle_started: await process_frame
	var protector: Node2D = game.get_unit_by_slot("blue", 3)
	var protected: Node2D = game.get_unit_by_slot("blue", 2)
	var other: Node2D = game.get_unit_by_slot("blue", 1)
	var intended_attacker: Node2D = game.get_unit_by_slot("red", 1)
	var nearer_wrong_attacker: Node2D = game.get_unit_by_slot("red", 2)
	protector.position = Vector2(360, 800)
	intended_attacker.position = Vector2(250, 700)
	nearer_wrong_attacker.position = Vector2(360, 740)
	intended_attacker.target = protected; intended_attacker.target_locked = true
	nearer_wrong_attacker.target = other; nearer_wrong_attacker.target_locked = true
	var selected: Node2D = game.strategy_runtime.select_enemy(protector, game.units)
	check(selected == intended_attacker, "保护攻击必须选择正在攻击2号的敌人，而不是更近的其他敌人")
	game.free()
	if failures.is_empty(): print("PROTECTIVE_TARGET_TEST_OK"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func fixture_plan() -> Dictionary:
	var alive := {"op":"eq","left":{"node":"field","path":"self.is_alive"},"right":{"node":"const","value":true}}
	var selector := {"scope":"visible_enemy_units","filters":[
		{"field":"is_alive","op":"eq","value":{"node":"const","value":true}},
		{"field":"intended_target_slot","op":"eq","value":{"node":"const","value":2}}],
		"sort":[{"field":"distance_to_self","order":"asc"}],"limit":1}
	var execution := {"recoveryPolicy":"resume","retriggerPolicy":"on_condition_reenter","minActiveTicks":1,"cooldownTicks":0,"replanIntervalTicks":1,"replanEvents":["target_invalid","damage_received"]}
	var targeting := {"id":"r_target","actorIds":["blue_3"],"channel":"targeting","priorityClass":"PROTECTION","priorityModifier":0,"specificityClass":"EXACT","sourceOrder":1,
		"when":alive,"targetBinding":{"writeRole":"attack_target","selector":selector,"releasePolicy":"on_target_invalid"},
		"resourceClaims":[{"resource":"TARGET_ROLE:attack_target","mode":"exclusive"}],
		"action":{"opcode":"set_target","targetRef":"attack_target","interruptClass":"EMERGENCY_SURVIVAL","interruptibleBy":["SYSTEM_FORCE","EMERGENCY_SURVIVAL"]},
		"until":null,"fallback":null,"runtimePrerequisites":[],"execution":execution,"sourceMessageIds":["m1"]}
	var combat := {"id":"r_combat","actorIds":["blue_3"],"channel":"combat","priorityClass":"PROTECTION","priorityModifier":0,"specificityClass":"EXACT","sourceOrder":1,
		"when":alive,"targetBinding":null,"resourceClaims":[{"resource":"PRIMARY_COMBAT","mode":"exclusive"}],
		"action":{"opcode":"basic_attack","targetRef":"attack_target","interruptClass":"EMERGENCY_SURVIVAL","interruptibleBy":["SYSTEM_FORCE","EMERGENCY_SURVIVAL"]},
		"until":null,"fallback":null,"runtimePrerequisites":[],"execution":execution,"sourceMessageIds":["m1"]}
	return {"schemaVersion":"3.0","compilerVersion":"strategy-compiler-3.0.0","metadataVersion":"strategy-metadata-3.0.0",
		"snapshotId":"s","snapshotHash":"sha256:test","planHash":"sha256:test","units":{"blue_3":{"rules":[targeting,combat]}},"sourceMap":{},"compileResults":[],"warnings":[]}
