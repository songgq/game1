class_name StrategyRuntime
extends RefCounted

const BRIDGE_LEFT_X := 328.0
const BRIDGE_RIGHT_X := 392.0

var world: Node
var document: Dictionary = {}
var directives: Array = []

func setup(controller: Node, strategy_document: Dictionary) -> void:
	world = controller
	document = strategy_document.duplicate(true)
	directives = Array(document.get("directives", [])).duplicate(true)
	directives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 100)) < int(b.get("priority", 100)))

func is_active() -> bool:
	return not document.is_empty() and String(document.get("schema_version", "")) == "2.0" and String(document.get("compiler_version", "")) == "strategy-2.0.0"

func actions_for(unit: Node, channel: String) -> Array:
	if not is_active() or unit.team != "blue" or int(unit.strategy_slot) <= 0:
		return []
	var result: Array = []
	for value in directives:
		if not value is Dictionary:
			continue
		var directive: Dictionary = value
		var slot_matches := false
		for value_slot in directive.get("slots", []):
			if int(value_slot) == int(unit.strategy_slot):
				slot_matches = true
				break
		# HTTP JSON numbers decode as floats (1.0), while local fixtures use
		# ints (1). Array membership is type-sensitive, so normalize both.
		if String(directive.get("channel", "")) != channel or not slot_matches:
			continue
		if not conditions_met(Array(directive.get("when", [])), unit):
			continue
		for value_action in directive.get("actions", []):
			if value_action is Dictionary:
				var action: Dictionary = value_action.duplicate(true)
				action["_directive_id"] = String(directive.get("id", ""))
				action["_mode"] = String(directive.get("action_mode", "all"))
				result.append(action)
	return result

func first_action(unit: Node, channel: String, allowed_types: Array) -> Dictionary:
	for action in actions_for(unit, channel):
		if String(action.get("type", "")) in allowed_types:
			return action
	return {}

func has_explicit_action(unit: Node, channel: String, allowed_types: Array) -> bool:
	return not first_action(unit, channel, allowed_types).is_empty()

func movement_action(unit: Node) -> Dictionary:
	var survival := first_action(unit, "survival", ["retreat"])
	if not survival.is_empty():
		return survival
	return first_action(unit, "movement", ["retreat", "hold", "follow", "protect", "move"])

func holds_position(unit: Node) -> bool:
	return String(movement_action(unit).get("type", "")) == "hold"

func constraint_action(unit: Node) -> Dictionary:
	return first_action(unit, "constraint", ["stay_in_zone"])

func constrain_destination(unit: Node, destination: Vector2) -> Vector2:
	var constraint := constraint_action(unit)
	if constraint.is_empty():
		return destination
	match String(constraint.get("zone", "anywhere")):
		"ally_side":
			if unit.team == "blue":
				destination.y = maxf(destination.y, 707.0)
			else:
				destination.y = minf(destination.y, 573.0)
		"enemy_side":
			if unit.team == "blue":
				destination.y = minf(destination.y, 573.0)
			else:
				destination.y = maxf(destination.y, 707.0)
	return destination

func select_enemy(unit: Node, candidates: Array) -> Node2D:
	var living: Array = []
	for candidate in candidates:
		if is_instance_valid(candidate) and not candidate.dead and candidate.team != unit.team:
			living.append(candidate)
	if living.is_empty():
		return null
	var movement := movement_action(unit)
	if String(movement.get("type", "")) == "protect":
		var protected: Node2D = world.get_unit_by_slot(unit.team, int(movement.get("target_slot", 0)))
		if protected != null:
			return nearest_node(protected.position, living)
	var action := first_action(unit, "combat", ["set_target", "attack"])
	if action.is_empty():
		return nearest_node(unit.position, living)
	var excluded: Array = action.get("exclude_types", []) if action.get("exclude_types", []) is Array else []
	var target_type := String(action.get("target_type", ""))
	var eligible: Array = []
	for candidate in living:
		if candidate.unit_type in excluded:
			continue
		eligible.append(candidate)
	if eligible.is_empty():
		return null
	var filtered: Array = eligible
	if target_type != "":
		var preferred := eligible.filter(func(candidate: Node) -> bool: return candidate.unit_type == target_type)
		if not preferred.is_empty():
			filtered = preferred
		elif String(action.get("fallback", "nearest")) == "idle":
			return null
	var max_attackers := int(action.get("max_attackers", 0))
	if max_attackers > 0:
		filtered = filtered.filter(func(candidate: Node) -> bool: return world.count_attackers_targeting(unit.team, candidate) < max_attackers or unit.target == candidate)
		if filtered.is_empty():
			if String(action.get("fallback", "nearest")) == "idle":
				return null
			# The preferred target has reached its attacker cap. A nearest fallback
			# means the remaining units must keep fighting, not stand idle.
			filtered = eligible.filter(func(candidate: Node) -> bool:
				return candidate.unit_type != target_type and (world.count_attackers_targeting(unit.team, candidate) < max_attackers or unit.target == candidate)
			)
			if filtered.is_empty():
				return null
	var target_sort := String(action.get("target_sort", "nearest"))
	if target_sort in ["worker", "monk", "archer", "lancer", "warrior"]:
		var typed := filtered.filter(func(candidate: Node) -> bool: return candidate.unit_type == target_sort)
		if not typed.is_empty():
			filtered = typed
		target_sort = "nearest"
	match target_sort:
		"lowest_hp":
			filtered.sort_custom(func(a: Node, b: Node) -> bool: return float(a.hp) / float(a.max_hp) < float(b.hp) / float(b.max_hp))
			return filtered[0]
		"backline":
			filtered.sort_custom(func(a: Node, b: Node) -> bool: return a.position.y < b.position.y if unit.team == "blue" else a.position.y > b.position.y)
			return filtered[0]
	# Older/model-generated strategies may encode “集火” as the JSON boolean
	# `true`. Calling String(true) raises every frame in Godot 4 and leaves the
	# affected unit idle. Treat that legacy value as focus coordination; focus
	# already follows the filtered target normally, while spread needs sorting.
	var coordination_value: Variant = action.get("coordination", "")
	var coordination: String = coordination_value if coordination_value is String else ("focus" if coordination_value == true else "")
	if coordination == "spread":
		filtered.sort_custom(func(a: Node, b: Node) -> bool:
			var a_count: int = world.count_attackers_targeting(unit.team, a)
			var b_count: int = world.count_attackers_targeting(unit.team, b)
			return a_count < b_count if a_count != b_count else unit.position.distance_to(a.position) < unit.position.distance_to(b.position)
		)
		return filtered[0]
	return nearest_node(unit.position, filtered)

func select_injured_ally(unit: Node, candidates: Array) -> Node2D:
	var injured: Array = []
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.dead or candidate.team != unit.team or candidate == unit or candidate.hp >= candidate.max_hp:
			continue
		# A persistent zone constraint and a support order can coexist. Do not let
		# an unreachable low-HP ally monopolize the healer forever: select the
		# lowest-priority ally that can actually be healed from the legal zone.
		var legal_cast_position := constrain_destination(unit, candidate.position)
		if legal_cast_position.distance_to(candidate.position) > float(unit.attack_range):
			continue
		injured.append(candidate)
	if injured.is_empty():
		return null
	var actions := actions_for(unit, "support")
	for action in actions:
		if String(action.get("type", "")) != "heal":
			continue
		var excluded: Array = action.get("exclude_types", []) if action.get("exclude_types", []) is Array else []
		var target_slot := int(action.get("target_slot", 0))
		if target_slot > 0:
			var preferred: Node2D = world.get_unit_by_slot(unit.team, target_slot)
			if preferred != null and preferred in injured and preferred.unit_type not in excluded:
				return preferred
		var eligible := injured.filter(func(candidate: Node) -> bool: return candidate.unit_type not in excluded)
		if eligible.is_empty():
			continue
		if String(action.get("target_sort", "")) == "lowest_hp":
			eligible.sort_custom(func(a: Node, b: Node) -> bool: return float(a.hp) / float(a.max_hp) < float(b.hp) / float(b.max_hp))
			return eligible[0]
		return nearest_node(unit.position, eligible)
	return nearest_node(unit.position, injured)

func preferred_resource(unit: Node) -> String:
	var actions := actions_for(unit, "economy")
	var has_gather_rule := false
	for action in actions:
		if String(action.get("type", "")) != "gather":
			continue
		has_gather_rule = true
		var kind := String(action.get("resource", ""))
		var amount := int(action.get("amount", 0))
		if amount > 0 and int(unit.strategy_gather_counts.get(kind, 0)) >= amount:
			continue
		if world.get_nearest_resource(unit, kind) != null:
			return kind
	return "__none__" if has_gather_rule else ""

func movement_destination(unit: Node, action: Dictionary) -> Variant:
	var action_type := String(action.get("type", ""))
	if action_type == "follow" or action_type == "protect":
		var followed: Node2D = world.get_unit_by_slot(unit.team, int(action.get("target_slot", 0)))
		return followed.position if followed != null else null
	if action_type == "retreat":
		return unit.home_position
	var position_name := String(action.get("position", ""))
	var destination: Vector2 = unit.position
	match position_name:
		"home_platform": destination = unit.home_position
		"river_edge": destination = Vector2(unit.position.x, 710.0 if unit.team == "blue" else 570.0)
		"ally_side": destination = Vector2(unit.position.x, 820.0 if unit.team == "blue" else 460.0)
		"enemy_side": destination = Vector2(unit.position.x, 500.0 if unit.team == "blue" else 780.0)
		_: destination = unit.position
	var route := String(action.get("route", ""))
	if route == "left_bridge":
		destination.x = BRIDGE_LEFT_X
	elif route == "right_bridge":
		destination.x = BRIDGE_RIGHT_X
	return constrain_destination(unit, destination)

func conditions_met(conditions: Array, unit: Node) -> bool:
	for value in conditions:
		if not value is Dictionary or not condition_met(value, unit):
			return false
	return true

func condition_met(condition: Dictionary, unit: Node) -> bool:
	var condition_type := String(condition.get("type", ""))
	match condition_type:
		"battle_started": return world.battle_started
		"self_under_attack": return float(unit.strategy_under_attack_time) > 0.0
		"self_hp_below": return float(unit.hp) / float(unit.max_hp) < float(condition.get("value", 0.3))
		"self_hp_above": return float(unit.hp) / float(unit.max_hp) > float(condition.get("value", 0.7))
		"all_non_worker_units_dead": return not world.has_living_non_worker_combatants(unit.team)
		"no_injured_ally": return world.get_nearest_injured_ally(unit) == null
		"ally_hp_below":
			var threshold := float(condition.get("value", 0.5))
			for candidate in world.units:
				if is_instance_valid(candidate) and not candidate.dead and candidate.team == unit.team and float(candidate.hp) / float(candidate.max_hp) < threshold:
					return true
			return false
		"unit_dead":
			return world.get_unit_by_slot(unit.team, int(condition.get("slot", 0))) == null
		"slot_under_attack":
			var watched: Node2D = world.get_unit_by_slot(unit.team, int(condition.get("slot", 0)))
			return watched != null and float(watched.strategy_under_attack_time) > 0.0
		"unit_crossed_river":
			var crossing: Node2D = world.get_unit_by_slot(unit.team, int(condition.get("slot", 0)))
			return crossing != null and (crossing.position.y < 592.0 if unit.team == "blue" else crossing.position.y > 688.0)
		"unit_reached_position":
			var moving: Node2D = world.get_unit_by_slot(unit.team, int(condition.get("slot", 0)))
			if moving == null:
				return false
			var target: Variant = movement_destination(moving, {"type": "move", "position": String(condition.get("position", ""))})
			return target != null and moving.position.distance_to(target) < 48.0
		"resource_depleted", "no_resource_available":
			return world.get_nearest_resource(unit, String(condition.get("resource", ""))) == null
		"enemy_type_dead":
			for candidate in world.units:
				if is_instance_valid(candidate) and not candidate.dead and candidate.team != unit.team and candidate.unit_type == String(condition.get("unit_type", "")):
					return false
			return true
		"enemy_count_in_area":
			var area := String(condition.get("area", ""))
			var center_x := BRIDGE_LEFT_X if area == "left_bridge" else BRIDGE_RIGHT_X
			var count := 0
			for candidate in world.units:
				if is_instance_valid(candidate) and not candidate.dead and candidate.team != unit.team and absf(candidate.position.x - center_x) < 48.0 and candidate.position.y > 560.0 and candidate.position.y < 720.0:
					count += 1
			return count >= int(condition.get("value", 3))
	return false

func nearest_node(origin: Vector2, candidates: Array) -> Node2D:
	var nearest: Node2D
	var best := INF
	for candidate in candidates:
		var distance: float = origin.distance_to(candidate.position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest
