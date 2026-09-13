class_name StrategySelectorEngine
extends RefCounted

const MAX_CANDIDATES := 128

func select(selector: Dictionary, candidates: Array, self_unit: Variant = null) -> Array:
	var filtered: Array = []
	var stable_candidates: Array = candidates.slice(0, mini(candidates.size(), MAX_CANDIDATES))
	for candidate in stable_candidates:
		if _matches_all(candidate, selector.get("filters", []), self_unit): filtered.append(candidate)
	var sort_rules: Array = selector.get("sort", []).duplicate(true)
	filtered.sort_custom(func(a, b): return _less(a, b, sort_rules, self_unit))
	return filtered.slice(0, mini(int(selector.get("limit", 1)), filtered.size()))

func _matches_all(candidate: Variant, filters: Array, self_unit: Variant) -> bool:
	for filter in filters:
		var left: Variant = _field(candidate, str(filter.get("field", "")), self_unit)
		var raw_value: Variant = filter.get("value")
		var right: Variant = raw_value.get("value") if raw_value is Dictionary and raw_value.get("node") == "const" else raw_value
		match str(filter.get("op", "")):
			"eq":
				if left != right: return false
			"neq":
				if left == right: return false
			"gt":
				if not left > right: return false
			"gte":
				if not left >= right: return false
			"lt":
				if not left < right: return false
			"lte":
				if not left <= right: return false
			"in":
				if not right is Array or left not in right: return false
			"not_in":
				if right is Array and left in right: return false
			_: return false
	return true

func _less(a: Variant, b: Variant, sort_rules: Array, self_unit: Variant) -> bool:
	for rule in sort_rules:
		var av: Variant = _field(a, str(rule.get("field", "")), self_unit)
		var bv: Variant = _field(b, str(rule.get("field", "")), self_unit)
		if av == bv: continue
		return av < bv if rule.get("order") == "asc" else av > bv
	var a_slot := int(_field(a, "slot_no", self_unit) if _field(a, "slot_no", self_unit) != null else 2147483647)
	var b_slot := int(_field(b, "slot_no", self_unit) if _field(b, "slot_no", self_unit) != null else 2147483647)
	if a_slot != b_slot: return a_slot < b_slot
	return str(_field(a, "id", self_unit)) < str(_field(b, "id", self_unit))

func _field(entity: Variant, field: String, self_unit: Variant) -> Variant:
	if field == "distance_to_self" and entity is Node2D and self_unit is Node2D: return entity.position.distance_to(self_unit.position)
	if entity is Dictionary: return entity.get(field)
	if entity is Object:
		if field == "slot_no" and "strategy_slot" in entity: return entity.get("strategy_slot")
		if field == "id" and "replay_id" in entity: return entity.get("replay_id")
		if field == "is_alive" and "dead" in entity: return not bool(entity.get("dead"))
		if field == "hp_percent" and "hp" in entity and "max_hp" in entity: return float(entity.get("hp")) / maxf(1.0, float(entity.get("max_hp")))
		if field == "intended_target_slot" and "target" in entity:
			var intended: Variant = entity.get("target")
			return int(intended.get("strategy_slot")) if intended is Object and is_instance_valid(intended) and "strategy_slot" in intended else 0
		return entity.get(field)
	return null
