class_name StrategyTargetRoles
extends RefCounted

var roles: Dictionary = {}
var generation := 0

func acquire(role: String, value: Variant, owner_rule_id: String, tick: int, lock_until_tick: int, release_policy: String) -> Dictionary:
	if not can_acquire(role, owner_rule_id, tick): return roles[role].duplicate(true)
	generation += 1
	var record := {"role": role, "value": value, "ownerRuleId": owner_rule_id, "acquiredTick": tick,
		"lockUntilTick": lock_until_tick, "generation": generation, "releasePolicy": release_policy}
	roles[role] = record
	return record.duplicate(true)

func can_acquire(role: String, owner_rule_id: String, tick: int) -> bool:
	var current: Dictionary = roles.get(role, {})
	return current.is_empty() or str(current.get("ownerRuleId", "")) == owner_rule_id or tick >= int(current.get("lockUntilTick", 0))

func get_role(role: String) -> Dictionary:
	return roles.get(role, {}).duplicate(true)

func value(role: String) -> Variant:
	return roles.get(role, {}).get("value")

func is_owned(role: String, owner_rule_id: String, expected_generation: int) -> bool:
	var record: Dictionary = roles.get(role, {})
	return not record.is_empty() and record.get("ownerRuleId") == owner_rule_id and int(record.get("generation", -1)) == expected_generation

func release_for_rule(owner_rule_id: String, target_invalid := false) -> void:
	for role in roles.keys():
		var record: Dictionary = roles[role]
		var policy := str(record.get("releasePolicy", "on_rule_end"))
		if record.get("ownerRuleId") == owner_rule_id and (policy == "on_rule_end" or (policy == "on_target_invalid" and target_invalid)):
			roles.erase(role)

func release_role(role: String, owner_rule_id := "") -> bool:
	if not roles.has(role): return false
	if not owner_rule_id.is_empty() and str(roles[role].get("ownerRuleId", "")) != owner_rule_id: return false
	roles.erase(role)
	return true

func target_is_valid(role: String) -> bool:
	if not roles.has(role): return false
	var target: Variant = roles[role].get("value")
	if target == null: return false
	if target is Object:
		if not is_instance_valid(target): return false
		if "dead" in target and bool(target.get("dead")): return false
	if target is Dictionary:
		if target.has("is_alive") and not bool(target.get("is_alive")): return false
	return true
