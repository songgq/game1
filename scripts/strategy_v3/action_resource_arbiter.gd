class_name StrategyActionResourceArbiter
extends RefCounted

const RULE_ARBITER := preload("res://scripts/strategy_v3/rule_arbiter.gd")
const INTERRUPT_MATRIX := preload("res://scripts/strategy_v3/interrupt_matrix.gd")

var interrupt_matrix := INTERRUPT_MATRIX.new()

func arbitrate(channel_winners: Dictionary, active_leases := {}) -> Dictionary:
	var candidates: Array = channel_winners.values()
	candidates.sort_custom(RULE_ARBITER.compare_rules)
	var leases: Dictionary = active_leases.duplicate(true)
	var granted: Array = []
	var rejected: Array = []
	var preempted: Array = []
	for candidate in candidates:
		var claims: Array = candidate.get("resourceClaims", [])
		var conflicts: Array = []
		for claim in claims:
			if str(claim.get("mode", "exclusive")) == "exclusive" and leases.has(str(claim.get("resource", ""))):
				var active: Dictionary = leases[str(claim["resource"])]
				if str(active.get("id", "")) != str(candidate.get("id", "")) and not _contains_rule(conflicts, str(active.get("id", ""))):
					conflicts.append(active)
		var can_take := true
		for active in conflicts:
			if not interrupt_matrix.can_interrupt(active.get("action", {}), candidate.get("action", {})):
				can_take = false
				break
		if not can_take:
			rejected.append({"rule": candidate, "reason": "ACTION_LOCKED"})
			continue
		# An action bundle owns all of its leases as a unit.  When it is
		# preempted, release every lease before atomically granting the new
		# bundle; otherwise an orphaned secondary lease can deadlock forever.
		for active in conflicts:
			var active_id := str(active.get("id", ""))
			if not _contains_rule(preempted, active_id): preempted.append(active)
			for resource in leases.keys():
				if str(leases[resource].get("id", "")) == active_id: leases.erase(resource)
		for claim in claims:
			var resource := str(claim.get("resource", ""))
			if str(claim.get("mode", "exclusive")) == "exclusive": leases[resource] = candidate
		granted.append(candidate)
	return {"granted": granted, "rejected": rejected, "preempted": preempted, "leases": leases}

func _contains_rule(items: Array, rule_id: String) -> bool:
	for item in items:
		if str(item.get("id", "")) == rule_id: return true
	return false
