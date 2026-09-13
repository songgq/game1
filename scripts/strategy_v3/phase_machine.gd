class_name StrategyPhaseMachine
extends RefCounted

var definitions: Dictionary = {}
var current_state: Dictionary = {}
var transition_events: Array = []

func setup(machines: Array, actor_id: String) -> bool:
	definitions.clear()
	current_state.clear()
	for value in machines:
		if not value is Dictionary or str(value.get("actorId", "")) != actor_id: continue
		var machine: Dictionary = value.duplicate(true)
		var machine_id := str(machine.get("id", ""))
		if machine_id.is_empty() or definitions.has(machine_id): return false
		definitions[machine_id] = machine
		current_state[machine_id] = str(machine.get("initialState", ""))
	return true

func advance(rule_states: Dictionary, tick: int) -> Array:
	var emitted: Array = []
	var machine_ids: Array = definitions.keys()
	machine_ids.sort()
	for machine_id in machine_ids:
		var machine: Dictionary = definitions[machine_id]
		var candidates: Array = machine.get("transitions", []).filter(func(item): return str(item.get("from", "")) == str(current_state[machine_id]))
		candidates.sort_custom(func(a, b):
			if str(a.get("to", "")) != str(b.get("to", "")): return str(a.get("to", "")) < str(b.get("to", ""))
			return str(a.get("whenRuleId", "")) < str(b.get("whenRuleId", "")))
		for transition in candidates:
			if str(rule_states.get(str(transition.get("whenRuleId", "")), "")) != str(transition.get("requiredState", "COMPLETED")): continue
			var event := {"tick":tick,"type":"PHASE_TRANSITION","phaseMachineId":machine_id,
				"from":current_state[machine_id],"to":str(transition["to"]),"reason":"RUNTIME_PREREQUISITE_SATISFIED"}
			current_state[machine_id] = str(transition["to"])
			transition_events.append(event)
			emitted.append(event)
			break
	return emitted
