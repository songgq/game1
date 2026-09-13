class_name StrategyRuleStateMachine
extends RefCounted

const STATES := ["INACTIVE", "PENDING", "ACTIVE", "SUSPENDED", "COMPLETED", "FAILED", "CANCELLED"]
const TERMINAL := ["COMPLETED", "FAILED", "CANCELLED"]
const TRANSITIONS := {
	"INACTIVE": ["PENDING", "CANCELLED"],
	"PENDING": ["ACTIVE", "INACTIVE", "FAILED", "CANCELLED"],
	"ACTIVE": ["SUSPENDED", "COMPLETED", "FAILED", "CANCELLED"],
	"SUSPENDED": ["ACTIVE", "FAILED", "CANCELLED"],
	"COMPLETED": ["INACTIVE"],
	"FAILED": ["INACTIVE"],
	"CANCELLED": ["INACTIVE"],
}

var records: Dictionary = {}

func register_rule(rule: Dictionary, initial_tick := 0) -> void:
	var rule_id := str(rule.get("id", ""))
	assert(not rule_id.is_empty() and not records.has(rule_id))
	records[rule_id] = {
		"state": "INACTIVE", "entered_tick": initial_tick, "active_since_tick": -1,
		"terminal_tick": -1, "observed_false_after_terminal": false,
		"reason": "REGISTERED", "activation": 0,
	}

func state(rule_id: String) -> String:
	return str(records.get(rule_id, {}).get("state", ""))

func transition(rule_id: String, next_state: String, tick: int, reason: String) -> bool:
	if not records.has(rule_id) or next_state not in STATES:
		return false
	var record: Dictionary = records[rule_id]
	var current := str(record["state"])
	if next_state not in TRANSITIONS.get(current, []):
		return false
	record["state"] = next_state
	record["entered_tick"] = tick
	record["reason"] = reason
	if next_state == "ACTIVE":
		record["active_since_tick"] = tick
		if current == "PENDING":
			record["activation"] = int(record["activation"]) + 1
	if next_state in TERMINAL:
		record["terminal_tick"] = tick
		record["observed_false_after_terminal"] = false
	return true

func observe_condition(rule: Dictionary, condition_true: bool, tick: int) -> String:
	var rule_id := str(rule["id"])
	var current := state(rule_id)
	if current == "INACTIVE" and condition_true:
		transition(rule_id, "PENDING", tick, "WHEN_ENTERED")
	elif current == "PENDING" and not condition_true:
		transition(rule_id, "INACTIVE", tick, "WHEN_LEFT_BEFORE_COMMIT")
	elif current in TERMINAL:
		var record: Dictionary = records[rule_id]
		if not condition_true:
			record["observed_false_after_terminal"] = true
		var execution: Dictionary = rule.get("execution", {})
		var policy := str(execution.get("retriggerPolicy", "never"))
		var cooldown := int(execution.get("cooldownTicks", 0))
		if policy == "on_condition_reenter" and bool(record["observed_false_after_terminal"]) and condition_true and tick >= int(record["terminal_tick"]) + cooldown:
			transition(rule_id, "INACTIVE", tick, "REARMED")
			transition(rule_id, "PENDING", tick, "WHEN_REENTERED")
	return state(rule_id)

func commit(rule_id: String, tick: int) -> bool:
	return transition(rule_id, "ACTIVE", tick, "ACTION_COMMITTED")

func complete_if_allowed(rule: Dictionary, until_true: bool, tick: int) -> bool:
	var record: Dictionary = records.get(str(rule.get("id", "")), {})
	if record.is_empty() or record.get("state") != "ACTIVE" or not until_true:
		return false
	var minimum := int(rule.get("execution", {}).get("minActiveTicks", 0))
	if tick - int(record.get("active_since_tick", tick)) < minimum:
		return false
	return transition(str(rule["id"]), "COMPLETED", tick, "UNTIL_SATISFIED")

func interrupt(rule: Dictionary, tick: int) -> bool:
	var policy := str(rule.get("execution", {}).get("recoveryPolicy", "cancel"))
	if policy == "cancel":
		return transition(str(rule["id"]), "CANCELLED", tick, "PREEMPTED_CANCEL")
	return transition(str(rule["id"]), "SUSPENDED", tick, "PREEMPTED")

func resume(rule: Dictionary, tick: int, context_valid: bool) -> bool:
	if state(str(rule["id"])) != "SUSPENDED":
		return false
	if not context_valid:
		return transition(str(rule["id"]), "FAILED", tick, "RESUME_CONTEXT_INVALID")
	return transition(str(rule["id"]), "ACTIVE", tick, "RESUMED")
