class_name StrategyRuntimeV3Adapter
extends RefCounted

const UNIT_RUNTIME := preload("res://scripts/strategy_v3/strategy_runtime_v3.gd")
const SELECTOR := preload("res://scripts/strategy_v3/selector_engine.gd")

var world: Node
var plan: Dictionary = {}
var runtimes: Dictionary = {}
var last_replan_tick: Dictionary = {}
var hold_positions: Dictionary = {}
var selector_engine := SELECTOR.new()

func setup(controller: Node, runtime_plan: Dictionary) -> void:
	world = controller
	plan = runtime_plan.duplicate(true)
	for actor_id in plan.get("units", {}):
		var runtime := UNIT_RUNTIME.new()
		if runtime.setup(plan, str(actor_id)): runtimes[str(actor_id)] = runtime

func is_active() -> bool:
	return not runtimes.is_empty()

func actor_id(unit: Node) -> String:
	var preferred := "blue_%d" % int(unit.strategy_slot)
	if runtimes.has(preferred): return preferred
	for id in runtimes:
		var suffix := str(id).rsplit("_", true, 1)
		if not suffix.is_empty() and int(suffix[-1]) == int(unit.strategy_slot): return str(id)
	return ""

func _refresh(unit: Node) -> Variant:
	var id := actor_id(unit)
	if id.is_empty(): return null
	var runtime: Variant = runtimes[id]
	var tick := int(world.battle_tick)
	if int(last_replan_tick.get(id, -1)) != tick:
		last_replan_tick[id] = tick
		var threat := _nearest_enemy_default(unit)
		var all_rule_states := {}
		for other_runtime in runtimes.values():
			for rule_id in other_runtime.states.records: all_rule_states[rule_id] = other_runtime.states.state(str(rule_id))
		var availability := {}
		for rule in runtime.rules():
			var position_ref: Variant = rule.get("action", {}).get("positionRef")
			if position_ref is Dictionary and position_ref.get("function") == "line_block_position":
				var protected: Node2D = world.get_unit_by_slot(unit.team, int(position_ref.get("protectedSlot", 0)))
				availability[str(rule["id"])] = protected != null and not world.intended_attackers_of(protected).is_empty()
		var allies: Array = world.units.filter(func(item): return is_instance_valid(item) and not item.dead and item.team == unit.team)
		var enemies: Array = world.units.filter(func(item): return is_instance_valid(item) and not item.dead and item.team != unit.team)
		var visible_enemies: Array = enemies.filter(func(item): return world.can_see_unit(unit, item))
		var areas: Array = []
		for raw_area in world.battle_areas:
			var area: Dictionary = raw_area.duplicate(true)
			area["distance_to_self"] = unit.position.distance_to(area.get("center", unit.position))
			area["is_reachable"] = bool(area.get("is_passable", true))
			areas.append(area)
		var current_area: String = str(world.area_type_at(unit.position))
		if unit.last_strategy_area_type.is_empty(): unit.last_strategy_area_type = current_area
		elif unit.last_strategy_area_type != current_area:
			world.emit_strategy_event("area_exited", unit, unit, 40)
			world.emit_strategy_event("area_entered", unit, unit, 41)
			unit.last_strategy_area_type = current_area
		var relevant_events: Array = world.strategy_current_events.filter(func(event):
			return int(event.get("sourceSlot", 0)) == int(unit.strategy_slot) or int(event.get("targetSlot", 0)) == int(unit.strategy_slot))
		for event in relevant_events:
			if event.get("type") == "damage_received" and int(event.get("targetSlot", 0)) == int(unit.strategy_slot):
				runtime.memory.set_value("last_attacker_id", str(event.get("sourceEntityId", "")))
				if runtime.memory.get_value("first_damage_tick") == null: runtime.memory.set_value("first_damage_tick", tick)
		var event_context: Dictionary = relevant_events[-1] if not relevant_events.is_empty() else {}
		var context := {"battle":{"tick":tick,"elapsed_time":float(world.battle_elapsed)},"ruleStates":all_rule_states,"ruleAvailability":availability,
			"events":relevant_events,
			"event":{"type":event_context.get("type"),"source_id":event_context.get("sourceEntityId"),"target_id":event_context.get("targetEntityId")},
			"memory":runtime.memory.values.duplicate(true),
			"selfUnit":unit,"candidateScopes":{"ally_units":allies,"visible_ally_units":allies,"enemy_units":enemies,
				"visible_enemy_units":visible_enemies,"areas":areas,"bushes":areas.filter(func(area): return area.get("type") == "bush")},
			"self":{"is_alive":not unit.dead,"hp":unit.hp,"max_hp":unit.max_hp,
				"hp_percent":float(unit.hp)/maxf(1.0,float(unit.max_hp)),"attack_range":unit.attack_range,
				"distance_to_threat":unit.position.distance_to(threat.position) if threat != null else INF,
				"is_under_attack":unit.strategy_under_attack_time > 0.0,"current_area_type":current_area}}
		runtime.replan(context, tick)
	return runtime

func movement_action(unit: Node) -> Dictionary:
	var runtime: Variant = _refresh(unit)
	if runtime == null: return {}
	var lease: Dictionary = runtime.action_state.active_by_resource.get("MOVE", {})
	if lease.is_empty(): return {}
	var result: Dictionary = lease.get("action", {}).duplicate(true)
	result["rule_id"] = lease.get("id", "")
	return result

func skill_action(unit: Node) -> Dictionary:
	var runtime: Variant = _refresh(unit)
	if runtime == null: return {}
	var resources: Array = runtime.action_state.active_by_resource.keys().filter(func(key): return str(key).begins_with("SKILL_SLOT:"))
	resources.sort()
	for resource in resources:
		var lease: Dictionary = runtime.action_state.active_by_resource[resource]
		if lease.get("action", {}).get("opcode") == "cast_skill":
			var result: Dictionary = lease.get("action", {}).duplicate(true)
			result["rule_id"] = lease.get("id", "")
			return result
	return {}

func role_target(unit: Node, role: String) -> Variant:
	return _role_target(unit, role)

func audit_events() -> Array:
	var result: Array = []
	var actor_ids: Array = runtimes.keys()
	actor_ids.sort()
	for id in actor_ids:
		for raw_event in runtimes[id].decision_events:
			var event: Dictionary = raw_event.duplicate(true)
			event["actorId"] = id
			result.append(event)
	result.sort_custom(func(a, b):
		if int(a.get("tick",0)) != int(b.get("tick",0)): return int(a.get("tick",0)) < int(b.get("tick",0))
		if str(a.get("actorId","")) != str(b.get("actorId","")): return str(a.get("actorId","")) < str(b.get("actorId",""))
		if str(a.get("type","")) != str(b.get("type","")): return str(a.get("type","")) < str(b.get("type",""))
		return str(a.get("ruleId","")) < str(b.get("ruleId","")))
	return result

func movement_destination(unit: Node, action: Dictionary) -> Variant:
	var opcode := str(action.get("opcode", ""))
	match opcode:
		"hold_position", "stop":
			var key := str(unit.replay_id) + ":" + str(action.get("rule_id", ""))
			if not hold_positions.has(key): hold_positions[key] = unit.position
			return hold_positions[key]
		"follow":
			var target: Node2D = _role_target(unit, str(action.get("targetRef", "follow_target")))
			if target == null:
				var target_slot: int = _target_slot_for_rule(unit, str(action.get("rule_id", "")))
				target = world.get_unit_by_slot(unit.team, target_slot)
			return target.position if target != null else unit.position
		"move_away_from":
			if action.get("positionRef") == "last_attack_target_position" and not unit.last_attack_target_position.is_zero_approx():
				return unit.position + unit.last_attack_target_position.direction_to(unit.position) * unit.attack_range
			var threat: Node2D = _nearest_enemy_default(unit)
			return unit.position + threat.position.direction_to(unit.position) * unit.attack_range if threat != null else unit.position
		"move_to_range", "move_towards":
			var target: Node2D = select_enemy(unit, world.units)
			return target.position if target != null else unit.position
		"move_to_area": return world.nearest_area_position(unit, _area_type_for_rule(unit, str(action.get("rule_id", ""))))
		"move_to_position":
			var position_ref: Variant = action.get("positionRef", "")
			if position_ref is Dictionary and position_ref.get("function") == "line_block_position":
				var protected: Node2D = world.get_unit_by_slot(unit.team, int(position_ref.get("protectedSlot", 0)))
				var attackers: Array = world.intended_attackers_of(protected) if protected != null else []
				return world.line_block_position(attackers[0], protected, unit, bool(position_ref.get("predict", true))) if not attackers.is_empty() else unit.position
			return world.strategy_position_reference(unit, str(position_ref))
		"move_to_relative_position": return _relative_position(unit, action)
	return null

func holds_position(unit: Node) -> bool:
	return str(movement_action(unit).get("opcode", "")) in ["hold_position", "stop"]

func constrain_destination(_unit: Node, destination: Vector2) -> Vector2:
	return destination

func select_enemy(unit: Node, candidates: Array) -> Node2D:
	var runtime: Variant = _refresh(unit)
	if runtime != null:
		var locked: Variant = runtime.target_roles.value("attack_target")
		if locked is Node2D and is_instance_valid(locked) and not locked.dead: return locked
	var target_rule: Dictionary = _active_rule(runtime, "PRIMARY_COMBAT") if runtime != null else {}
	var selector: Dictionary = {}
	if not target_rule.is_empty():
		for rule in runtime.rules():
			if rule.get("channel") == "targeting" and not rule.get("targetBinding", null) == null:
				selector = rule["targetBinding"].get("selector", {})
				break
	var enemies: Array = candidates.filter(func(candidate): return is_instance_valid(candidate) and not candidate.dead and candidate.team != unit.team)
	if selector.get("scope") == "visible_enemy_units": enemies = enemies.filter(func(candidate): return world.can_see_unit(unit, candidate))
	if not selector.is_empty():
		var selected: Array = selector_engine.select(selector, enemies, unit)
		if not selected.is_empty(): return selected[0]
	return _nearest_enemy_default(unit)

func select_injured_ally(unit: Node, candidates: Array) -> Node2D:
	var allies: Array = candidates.filter(func(candidate): return is_instance_valid(candidate) and not candidate.dead and candidate.team == unit.team and candidate != unit and candidate.hp < candidate.max_hp)
	allies.sort_custom(func(a, b):
		var ar := float(a.hp)/float(a.max_hp); var br := float(b.hp)/float(b.max_hp)
		if not is_equal_approx(ar, br): return ar < br
		return int(a.strategy_slot) < int(b.strategy_slot))
	return allies[0] if not allies.is_empty() else null

func preferred_resource(unit: Node) -> String:
	var runtime: Variant = _refresh(unit)
	if runtime == null: return ""
	for rule in runtime.rules():
		if rule.get("channel") == "economy" and runtime.states.state(str(rule["id"])) in ["PENDING","ACTIVE"]:
			var ref := str(rule.get("action", {}).get("positionRef", ""))
			return ref.trim_prefix("resource:")
	return ""

func has_explicit_action(unit: Node, channel: String, action_types: Array) -> bool:
	var id := actor_id(unit)
	if id.is_empty(): return false
	var normalized := _normalize_action_types(action_types)
	for rule in runtimes[id].rules():
		if rule.get("channel") == channel and str(rule.get("action", {}).get("opcode", "")) in normalized: return true
	return false

func first_action(unit: Node, channel: String, action_types: Array) -> Dictionary:
	var id := actor_id(unit)
	if id.is_empty(): return {}
	var normalized := _normalize_action_types(action_types)
	for rule in runtimes[id].rules():
		if rule.get("channel") == channel and str(rule.get("action", {}).get("opcode", "")) in normalized: return rule.get("action", {})
	return {}

func _normalize_action_types(action_types: Array) -> Array:
	var aliases := {"attack":"basic_attack","set_target":"set_target","heal":"cast_skill","hold":"hold_position","retreat":"move_to_area","gather":"move_to_position"}
	return action_types.map(func(item): return aliases.get(str(item), str(item)))

func actions_for(unit: Node, channel: String) -> Array:
	var id := actor_id(unit)
	if id.is_empty(): return []
	return runtimes[id].rules().filter(func(rule): return rule.get("channel") == channel).map(func(rule): return rule.get("action", {}))

func _active_rule(runtime: Variant, resource: String) -> Dictionary:
	return runtime.action_state.active_by_resource.get(resource, {}) if runtime != null else {}

func _target_slot_for_rule(unit: Node, rule_id: String) -> int:
	var id := actor_id(unit)
	for rule in runtimes[id].rules():
		if rule.get("id") != rule_id: continue
		for filter in rule.get("targetBinding", {}).get("selector", {}).get("filters", []):
			if filter.get("field") == "slot_no": return int(filter.get("value", {}).get("value", 0))
	return 0

func _area_type_for_rule(unit: Node, rule_id: String) -> String:
	var id := actor_id(unit)
	for rule in runtimes[id].rules():
		if rule.get("id") != rule_id: continue
		for filter in rule.get("targetBinding", {}).get("selector", {}).get("filters", []):
			if filter.get("field") == "type": return str(filter.get("value", {}).get("value", ""))
	return ""

func _relative_position(unit: Node, action: Dictionary) -> Vector2:
	var anchor: Node2D = world.get_unit_by_slot(unit.team, int(action.get("anchorSlot", 0)))
	var enemy: Node2D = _nearest_enemy_default(unit)
	if anchor == null or enemy == null: return unit.position
	var direction: Vector2 = enemy.position.direction_to(anchor.position)
	return anchor.position + direction * 48.0

func _nearest_enemy_default(unit: Node) -> Node2D:
	var candidates: Array = world.units.filter(func(item): return is_instance_valid(item) and not item.dead and item.team != unit.team and world.can_see_unit(unit, item))
	candidates.sort_custom(func(a, b):
		var ad: float = unit.position.distance_squared_to(a.position); var bd: float = unit.position.distance_squared_to(b.position)
		if not is_equal_approx(ad, bd): return ad < bd
		return str(a.replay_id) < str(b.replay_id))
	return candidates[0] if not candidates.is_empty() else null

func _role_target(unit: Node, role: String) -> Variant:
	var id := actor_id(unit)
	if id.is_empty(): return null
	var target: Variant = runtimes[id].target_roles.value(role)
	return target if target is Node2D and is_instance_valid(target) and not target.dead else null
