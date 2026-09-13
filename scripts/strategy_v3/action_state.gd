class_name StrategyActionState
extends RefCounted

var active_by_resource: Dictionary = {}
var started_tick_by_rule: Dictionary = {}

func commit(bundle: Dictionary, tick: int) -> bool:
	var rule_id := str(bundle.get("id", ""))
	if rule_id.is_empty(): return false
	for claim in bundle.get("resourceClaims", []):
		if claim.get("mode", "exclusive") == "exclusive": active_by_resource[str(claim.get("resource", ""))] = bundle
	started_tick_by_rule[rule_id] = tick
	return true

func release_rule(rule_id: String) -> void:
	for resource in active_by_resource.keys():
		if str(active_by_resource[resource].get("id", "")) == rule_id: active_by_resource.erase(resource)
	started_tick_by_rule.erase(rule_id)

func leases() -> Dictionary:
	return active_by_resource.duplicate(true)
