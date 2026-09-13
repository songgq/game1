class_name StrategyRuntimeV3
extends RefCounted

const CONDITION := preload("res://scripts/strategy_v3/condition_evaluator.gd")
const STATE_MACHINE := preload("res://scripts/strategy_v3/rule_state_machine.gd")
const RULE_ARBITER := preload("res://scripts/strategy_v3/rule_arbiter.gd")
const RESOURCE_ARBITER := preload("res://scripts/strategy_v3/action_resource_arbiter.gd")
const ACTION_STATE := preload("res://scripts/strategy_v3/action_state.gd")
const TARGET_ROLES := preload("res://scripts/strategy_v3/target_roles.gd")
const MEMORY := preload("res://scripts/strategy_v3/strategy_memory.gd")
const SELECTOR := preload("res://scripts/strategy_v3/selector_engine.gd")
const PHASE_MACHINE := preload("res://scripts/strategy_v3/phase_machine.gd")

var plan: Dictionary = {}
var actor_id := ""
var tick := 0
var evaluator := CONDITION.new()
var states := STATE_MACHINE.new()
var channel_arbiter := RULE_ARBITER.new()
var resource_arbiter := RESOURCE_ARBITER.new()
var action_state := ACTION_STATE.new()
var target_roles := TARGET_ROLES.new()
var memory := MEMORY.new()
var selector_engine := SELECTOR.new()
var phase_machine := PHASE_MACHINE.new()
var decision_events: Array = []
var last_replan_tick_by_rule: Dictionary = {}

func setup(runtime_plan: Dictionary, unit_actor_id: String) -> bool:
	plan = runtime_plan.duplicate(true)
	actor_id = unit_actor_id
	if not plan.get("units", {}).has(actor_id): return false
	for rule in rules(): states.register_rule(rule)
	if not phase_machine.setup(plan.get("phaseMachines", []), actor_id): return false
	return true

func rules() -> Array:
	return plan.get("units", {}).get(actor_id, {}).get("rules", [])

func replan(context: Dictionary, current_tick: int) -> Dictionary:
	tick = current_tick
	var visible_rule_states: Dictionary = context.get("ruleStates", {}).duplicate(true)
	for known_rule_id in states.records: visible_rule_states[known_rule_id] = states.state(str(known_rule_id))
	decision_events.append_array(phase_machine.advance(visible_rule_states, tick))
	var pending: Array = []
	for rule in rules():
		var rule_id := str(rule["id"])
		if not _rule_replan_due(rule, context):
			continue
		last_replan_tick_by_rule[rule_id] = tick
		var when_true := _prerequisites_met(rule, context) and evaluator.evaluate(rule.get("when", {}), context)
		states.observe_condition(rule, when_true, tick)
		if states.state(rule_id) == "ACTIVE" and rule.get("targetBinding") != null:
			var role := str(rule["targetBinding"].get("writeRole", ""))
			if not role.is_empty() and target_roles.get_role(role).get("ownerRuleId") == rule_id and not target_roles.target_is_valid(role):
				target_roles.release_for_rule(rule_id, true)
				if not _activate_fallback(rule, "TARGET_INVALID"):
					action_state.release_rule(rule_id)
					states.transition(rule_id, "FAILED", tick, "TARGET_INVALID")
					decision_events.append({"tick":tick,"type":"RULE_FAILED","ruleId":rule_id,"reason":"TARGET_INVALID"})
		if states.state(rule_id) == "ACTIVE" and rule.get("until") != null:
			if states.complete_if_allowed(rule, evaluator.evaluate(rule["until"], context), tick):
				action_state.release_rule(rule_id)
				target_roles.release_for_rule(rule_id)
				decision_events.append({"tick":tick,"type":"RULE_COMPLETED","ruleId":rule_id,"reason":"UNTIL_SATISFIED"})
		if states.state(rule_id) == "ACTIVE" and not str(rule.get("action", {}).get("completeOnEvent", "")).is_empty():
			var expected_event := str(rule["action"]["completeOnEvent"])
			if context.get("events", []).any(func(event): return str(event.get("type", "")) == expected_event):
				states.transition(rule_id, "COMPLETED", tick, "ACTION_EVENT_COMPLETED")
				action_state.release_rule(rule_id)
				target_roles.release_for_rule(rule_id)
				decision_events.append({"tick":tick,"type":"RULE_COMPLETED","ruleId":rule_id,"reason":"ACTION_EVENT_COMPLETED","event":expected_event})
		if states.state(rule_id) == "ACTIVE" and int(rule.get("action", {}).get("durationTicks", 0)) > 0:
			var record: Dictionary = states.records[rule_id]
			if tick - int(record.get("active_since_tick", tick)) >= int(rule["action"]["durationTicks"]):
				states.transition(rule_id, "COMPLETED", tick, "DURATION_COMPLETED")
				action_state.release_rule(rule_id)
				target_roles.release_for_rule(rule_id)
				decision_events.append({"tick":tick,"type":"RULE_COMPLETED","ruleId":rule_id,"reason":"DURATION_COMPLETED"})
		if states.state(rule_id) in ["PENDING", "ACTIVE", "SUSPENDED"] and when_true:
			var prepared := _prepare_candidate(rule, context)
			if prepared.is_empty():
				if states.state(rule_id) == "PENDING": states.transition(rule_id, "FAILED", tick, "SELECTOR_NO_RESULT")
			else: pending.append(prepared)
	var by_channel := channel_arbiter.winners_by_channel(pending)
	var resources := resource_arbiter.arbitrate(by_channel, action_state.leases())
	var committed: Array = []
	for rule in resources["granted"]:
		var rule_id := str(rule["id"])
		if states.state(rule_id) == "ACTIVE":
			var current_bundle: Dictionary = action_state.active_by_resource.get(_primary_resource(rule), {})
			if bool(current_bundle.get("_usingFallback", false)) and not bool(rule.get("_usingFallback", false)):
				action_state.release_rule(rule_id)
				if action_state.commit(rule, tick):
					_acquire_candidate_target(rule)
					decision_events.append({"tick":tick,"type":"FALLBACK_RECOVERED","ruleId":rule_id,"reason":"PRIMARY_TARGET_AVAILABLE"})
			continue
		# Commit is the transaction boundary.  State and ownership only change
		# after the complete action bundle has acquired every resource.
		if not action_state.commit(rule, tick):
			decision_events.append({"tick":tick,"type":"COMMIT_ROLLBACK","ruleId":rule_id,"reason":"ACTION_COMMIT_FAILED"})
			continue
		for active in resources.get("preempted", []):
			var active_id := str(active.get("id", ""))
			if active_id == rule_id or states.state(active_id) != "ACTIVE": continue
			action_state.release_rule(active_id)
			var original := _rule_by_id(active_id)
			states.interrupt(original, tick)
			if str(original.get("execution", {}).get("recoveryPolicy", "cancel")) != "resume": target_roles.release_for_rule(active_id)
			decision_events.append({"tick":tick,"type":"RULE_PREEMPTED","ruleId":active_id,"reason":"PREEMPTED","byRuleId":rule_id})
		_acquire_candidate_target(rule)
		var activated := false
		if states.state(rule_id) == "PENDING": activated = states.commit(rule_id, tick)
		elif states.state(rule_id) == "SUSPENDED": activated = states.resume(_rule_by_id(rule_id), tick, true)
		if activated:
			committed.append(rule)
			decision_events.append({"tick": tick, "type": "RULE_COMMITTED", "ruleId": rule_id, "reason": "ACTION_COMMITTED"})
			_execute_immediate_action(rule)
	return {"channelWinners": by_channel, "granted": resources["granted"], "rejected": resources["rejected"],
		"preempted": resources.get("preempted", []), "committed": committed}

func _rule_replan_due(rule: Dictionary, context: Dictionary) -> bool:
	var rule_id := str(rule.get("id", ""))
	if not last_replan_tick_by_rule.has(rule_id): return true
	var interval := maxi(1, int(rule.get("execution", {}).get("replanIntervalTicks", 1)))
	if tick - int(last_replan_tick_by_rule[rule_id]) >= interval: return true
	var event_names: Array = context.get("events", []).map(func(event): return str(event.get("type", "")))
	for event_name in rule.get("execution", {}).get("replanEvents", []):
		if str(event_name) in event_names: return true
	var action: Dictionary = rule.get("action", {})
	if not str(action.get("completeOnEvent", "")).is_empty() and str(action["completeOnEvent"]) in event_names: return true
	if states.state(rule_id) == "ACTIVE" and rule.get("targetBinding") is Dictionary:
		var role := str(rule["targetBinding"].get("writeRole", ""))
		if not role.is_empty() and not target_roles.target_is_valid(role): return true
	if states.state(rule_id) == "ACTIVE" and int(action.get("durationTicks", 0)) > 0:
		var record: Dictionary = states.records.get(rule_id, {})
		if tick - int(record.get("active_since_tick", tick)) >= int(action["durationTicks"]): return true
	return false

func _prepare_candidate(rule: Dictionary, context: Dictionary) -> Dictionary:
	var candidate: Dictionary = rule.duplicate(true)
	var binding: Variant = candidate.get("targetBinding")
	if binding is Dictionary:
		var role := str(binding.get("writeRole", ""))
		if not target_roles.can_acquire(role, str(rule.get("id", "")), tick): return {}
		var owned: Dictionary = target_roles.get_role(role)
		if states.state(str(rule.get("id", ""))) == "SUSPENDED" and str(rule.get("execution", {}).get("recoveryPolicy", "")) == "resume" \
				and owned.get("ownerRuleId") == str(rule.get("id", "")) and target_roles.target_is_valid(role):
			candidate["_resolvedTarget"] = owned.get("value")
			candidate["_preserveTargetGeneration"] = true
			return candidate
		var selector: Dictionary = binding.get("selector", {})
		var candidates: Array = context.get("candidateScopes", {}).get(str(selector.get("scope", "")), [])
		var selected := selector_engine.select(selector, candidates, context.get("selfUnit"))
		if selected.is_empty():
			var fallback: Variant = candidate.get("fallback")
			if not fallback is Dictionary: return {}
			candidate["action"] = fallback.duplicate(true)
			_apply_interrupt_defaults(candidate["action"], rule.get("action", {}))
			candidate["targetBinding"] = null
			candidate["resourceClaims"] = candidate.get("resourceClaims", []).filter(func(claim): return not str(claim.get("resource", "")).begins_with("TARGET_ROLE:"))
			candidate["_usingFallback"] = true
		else:
			candidate["_resolvedTarget"] = selected[0]
	# Actions may consume a role written by another rule.  Missing roles are
	# not guessed; the rule waits, or uses its explicit fallback.
	var target_ref := str(candidate.get("action", {}).get("targetRef", ""))
	if candidate.get("targetBinding") == null and not target_ref.is_empty() and target_roles.get_role(target_ref).is_empty():
		var fallback: Variant = candidate.get("fallback")
		if fallback is Dictionary:
			candidate["action"] = fallback.duplicate(true)
			_apply_interrupt_defaults(candidate["action"], rule.get("action", {}))
			candidate["_usingFallback"] = true
		else: return {}
	return candidate

func _primary_resource(rule: Dictionary) -> String:
	for claim in rule.get("resourceClaims", []):
		var resource := str(claim.get("resource", ""))
		if resource in ["MOVE", "PRIMARY_COMBAT", "FACING"] or resource.begins_with("SKILL_SLOT:"): return resource
	return str(rule.get("resourceClaims", [{}])[0].get("resource", "")) if not rule.get("resourceClaims", []).is_empty() else ""

func _acquire_candidate_target(candidate: Dictionary) -> void:
	var binding: Variant = candidate.get("targetBinding")
	if not binding is Dictionary or not candidate.has("_resolvedTarget"): return
	if bool(candidate.get("_preserveTargetGeneration", false)): return
	var role := str(binding.get("writeRole", ""))
	if role.is_empty(): return
	var lock_ticks := int(binding.get("lockTicks", 0))
	target_roles.acquire(role, candidate["_resolvedTarget"], str(candidate["id"]), tick, tick + lock_ticks,
		str(binding.get("releasePolicy", "on_target_invalid")))

func _activate_fallback(rule: Dictionary, reason: String) -> bool:
	var fallback: Variant = rule.get("fallback")
	if not fallback is Dictionary: return false
	var bundle: Dictionary = rule.duplicate(true)
	bundle["action"] = fallback.duplicate(true)
	_apply_interrupt_defaults(bundle["action"], rule.get("action", {}))
	bundle["_usingFallback"] = true
	bundle["resourceClaims"] = bundle.get("resourceClaims", []).filter(func(claim): return not str(claim.get("resource", "")).begins_with("TARGET_ROLE:"))
	action_state.release_rule(str(rule["id"]))
	if not action_state.commit(bundle, tick): return false
	decision_events.append({"tick":tick,"type":"FALLBACK_COMMITTED","ruleId":str(rule["id"]),"reason":reason})
	return true

func _rule_by_id(rule_id: String) -> Dictionary:
	for rule in rules():
		if str(rule.get("id", "")) == rule_id: return rule
	return {}

func _apply_interrupt_defaults(action: Dictionary, primary: Dictionary) -> void:
	if not action.has("interruptClass"): action["interruptClass"] = primary.get("interruptClass", "TACTICAL_MOVE")
	if not action.has("interruptibleBy"): action["interruptibleBy"] = primary.get("interruptibleBy", ["SYSTEM_FORCE"])

func _execute_immediate_action(rule: Dictionary) -> void:
	var action: Dictionary = rule.get("action", {})
	var opcode := str(action.get("opcode", ""))
	if opcode == "set_memory": memory.set_value(str(action.get("key", "")), action.get("value"))
	elif opcode == "clear_memory": memory.clear_value(str(action.get("key", "")))
	else: return
	states.transition(str(rule["id"]), "COMPLETED", tick, "IMMEDIATE_ACTION_COMPLETED")
	action_state.release_rule(str(rule["id"]))
	target_roles.release_for_rule(str(rule["id"]))

func _prerequisites_met(rule: Dictionary, context: Dictionary) -> bool:
	if context.get("ruleAvailability", {}).has(str(rule.get("id", ""))) and not bool(context["ruleAvailability"][str(rule["id"])]): return false
	var external: Dictionary = context.get("ruleStates", {})
	for prerequisite in rule.get("runtimePrerequisites", []):
		var rule_id := str(prerequisite.get("ruleId", ""))
		var actual := states.state(rule_id) if records_has(rule_id) else str(external.get(rule_id, ""))
		if actual != str(prerequisite.get("requiredState", "COMPLETED")): return false
	return true

func records_has(rule_id: String) -> bool:
	return states.records.has(rule_id)
