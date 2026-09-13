extends SceneTree

const RUNTIME := preload("res://scripts/strategy_runtime.gd")
const RULES := preload("res://scripts/strategy_rules.gd")

class MockUnit extends Node2D:
	var team := "blue"
	var unit_type := "warrior"
	var strategy_slot := 1
	var hp := 100
	var max_hp := 100
	var attack_range := 192.0
	var dead := false
	var target: Node
	var strategy_under_attack_time := 0.0
	var strategy_gather_counts := {"gold": 0, "stone": 0, "wood": 0, "meat": 0}
	var home_position := Vector2(72, 1152)

class MockResource extends Node2D:
	var team := "blue"
	var resource_type := "meat"
	var depleted := false

class MockWorld extends Node:
	var battle_started := true
	var units: Array = []
	var resources: Array = []
	func has_living_non_worker_combatants(team_name: String) -> bool:
		return units.any(func(unit: MockUnit) -> bool: return not unit.dead and unit.team == team_name and unit.unit_type != "worker")
	func get_unit_by_slot(team_name: String, slot: int) -> Node2D:
		for unit in units:
			if not unit.dead and unit.team == team_name and unit.strategy_slot == slot:
				return unit
		return null
	func get_nearest_injured_ally(unit: MockUnit) -> Node2D:
		for candidate in units:
			if candidate.team == unit.team and candidate != unit and candidate.hp < candidate.max_hp:
				return candidate
		return null
	func get_nearest_resource(unit: MockUnit, preferred := "") -> Node2D:
		for resource in resources:
			if not resource.depleted and resource.team == unit.team and (preferred == "" or resource.resource_type == preferred):
				return resource
		return null
	func count_attackers_targeting(team_name: String, combat_target: Node) -> int:
		var count := 0
		for unit in units:
			if unit.team == team_name and unit.target == combat_target:
				count += 1
		return count

var failures: Array = []

func _initialize() -> void:
	var world := MockWorld.new()
	var kinds := ["warrior", "lancer", "archer", "monk", "worker"]
	for index in 5:
		var unit := MockUnit.new()
		unit.strategy_slot = index + 1
		unit.unit_type = kinds[index]
		unit.position = Vector2(72 + index * 100, 900)
		world.add_child(unit)
		world.units.append(unit)
	var enemy_monk := MockUnit.new()
	enemy_monk.team = "red"
	enemy_monk.unit_type = "monk"
	enemy_monk.strategy_slot = 4
	enemy_monk.position = Vector2(400, 400)
	world.add_child(enemy_monk)
	world.units.append(enemy_monk)
	var enemy_warrior := MockUnit.new()
	enemy_warrior.team = "red"
	enemy_warrior.unit_type = "warrior"
	enemy_warrior.strategy_slot = 1
	enemy_warrior.position = Vector2(360, 450)
	world.add_child(enemy_warrior)
	world.units.append(enemy_warrior)
	var meat := MockResource.new()
	meat.resource_type = "meat"
	world.add_child(meat)
	world.resources.append(meat)
	var wood := MockResource.new()
	wood.resource_type = "wood"
	world.add_child(wood)
	world.resources.append(wood)
	var document := fixture_document()
	var runtime := RUNTIME.new()
	runtime.setup(world, document)
	check(runtime.is_active(), "runtime should be active")
	var legacy_document := document.duplicate(true)
	legacy_document["directives"][1]["actions"][0]["coordination"] = true
	var legacy_runtime := RUNTIME.new()
	legacy_runtime.setup(world, legacy_document)
	check(legacy_runtime.select_enemy(world.units[0], world.units) == enemy_monk, "legacy boolean coordination must not stop a unit")
	var http_document: Variant = JSON.parse_string(JSON.stringify(document))
	var http_runtime := RUNTIME.new()
	http_runtime.setup(world, http_document)
	check(not http_runtime.actions_for(world.units[0], "movement").is_empty(), "HTTP JSON float slots must match integer unit slots")
	check(RULES.validate_document(http_document, kinds), "client schema validation must accept integral JSON floats")
	var movement := runtime.movement_action(world.units[0])
	check(movement.get("route") == "left_bridge", "slot 1 should use left bridge")
	for fighter_index in 4:
		var selected := runtime.select_enemy(world.units[fighter_index], world.units)
		check(selected == enemy_monk, "slot %d should prioritize enemy monk" % (fighter_index + 1))
	var capped_document := document.duplicate(true)
	capped_document["directives"][1]["actions"][0]["max_attackers"] = 1
	capped_document["directives"][1]["actions"][0]["fallback"] = "nearest"
	var capped_runtime := RUNTIME.new()
	capped_runtime.setup(world, capped_document)
	world.units[0].target = enemy_monk
	check(capped_runtime.select_enemy(world.units[1], world.units) == enemy_warrior, "attacker cap should use nearest fallback instead of idling")
	world.units[0].target = null
	check(runtime.has_explicit_action(world.units[3], "combat", ["attack"]), "monk should have an explicit combat order")
	check(runtime.has_explicit_action(world.units[3], "support", ["heal"]), "explicit heal order should override monk combat")
	world.units[0].hp = 40
	var healed := runtime.select_injured_ally(world.units[3], world.units)
	check(healed == world.units[0], "monk should heal slot 1 first")
	check(runtime.preferred_resource(world.units[4]) == "meat", "worker should gather meat first")
	world.units[4].strategy_gather_counts["meat"] = 2
	check(runtime.preferred_resource(world.units[4]) == "wood", "worker should continue with wood after two meat")
	for index in 4:
		world.units[index].dead = true
	check(runtime.first_action(world.units[4], "combat", ["attack"]).get("type") == "attack", "worker combat should unlock after all non-workers die")
	check(RULES.validate_document(document, kinds), "client schema validation should accept fixture")
	var illegal_document := document.duplicate(true)
	illegal_document["directives"][0]["channel"] = "economy"
	check(not RULES.validate_document(illegal_document, kinds), "client schema validation must reject action/channel mismatch")
	var rejection := {"slot": 1, "status": "rejected", "accepted_directive_ids": [], "rejections": [{"message_index": 1, "fragment": "砍树", "reason_code": "CAPABILITY_GATHER_FORBIDDEN"}]}
	var refusal: String = RULES.build_reply(rejection, "warrior", 1, 1)
	check("收到" not in refusal and refusal.length() > 8, "warrior rejection should be playful instead of acknowledged")
	world.free()
	if failures.is_empty():
		print("STRATEGY_RUNTIME_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func fixture_document() -> Dictionary:
	var directives := [
		{"id":"d1","slots":[1],"channel":"movement","priority":100,"when":[],"action_mode":"all","actions":[{"type":"move","route":"left_bridge","position":"enemy_side"}],"source_messages":[1]},
		{"id":"d2","slots":[1,2,3,4],"channel":"combat","priority":100,"when":[],"action_mode":"all","actions":[{"type":"attack","target_type":"monk","coordination":"focus"}],"source_messages":[1]},
		{"id":"d3","slots":[4],"channel":"support","priority":100,"when":[],"action_mode":"all","actions":[{"type":"heal","target_sort":"lowest_hp","exclude_types":["worker"]}],"source_messages":[1]},
		{"id":"d4","slots":[5],"channel":"economy","priority":100,"when":[],"action_mode":"sequence","actions":[{"type":"gather","resource":"meat","amount":2},{"type":"gather","resource":"wood","amount":3}],"source_messages":[1]},
		{"id":"d5","slots":[5],"channel":"combat","priority":100,"when":[{"type":"all_non_worker_units_dead"}],"action_mode":"all","actions":[{"type":"attack","target_sort":"nearest"}],"source_messages":[1]}
	]
	return {
		"schema_version":"2.0","compiler_version":"strategy-2.0.0","strategy_name":"运行时测试","directives":directives,
		"message_resolution":[{"message_index":1,"status":"applied","overridden_by":null,"applied_to_slots":[1,2,4,5],"note":"测试"}],
		"unit_results":[
			{"slot":1,"status":"accepted","accepted_directive_ids":["d1","d2"],"rejections":[]},
			{"slot":2,"status":"accepted","accepted_directive_ids":["d2"],"rejections":[]},
			{"slot":3,"status":"accepted","accepted_directive_ids":["d2"],"rejections":[]},
			{"slot":4,"status":"accepted","accepted_directive_ids":["d2","d3"],"rejections":[]},
			{"slot":5,"status":"accepted","accepted_directive_ids":["d4","d5"],"rejections":[]}
		],
		"unit_summaries":{"1":"左桥","2":"攻击僧侣","3":"默认","4":"治疗1号","5":"采集后参战"},"warnings":[]
	}
