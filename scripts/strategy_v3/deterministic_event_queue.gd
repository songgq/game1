class_name StrategyDeterministicEventQueue
extends RefCounted

var current_events: Array = []
var next_tick_events: Array = []
var sequence := 0

static func event_less(a: Dictionary, b: Dictionary) -> bool:
	for key in ["phaseOrder", "eventTypeOrder"]:
		var av := int(a.get(key, 0)); var bv := int(b.get(key, 0))
		if av != bv: return av < bv
	for key in ["sourceEntityId", "targetEntityId"]:
		var av := str(a.get(key, "")); var bv := str(b.get(key, ""))
		if av != bv: return av < bv
	return int(a.get("eventSequence", 0)) < int(b.get("eventSequence", 0))

func enqueue(event: Dictionary, visible_current_tick := false) -> void:
	sequence += 1
	var stored := event.duplicate(true)
	stored["eventSequence"] = sequence
	if visible_current_tick: current_events.append(stored)
	else: next_tick_events.append(stored)

func collect_for_replan() -> Array:
	current_events.append_array(next_tick_events)
	next_tick_events.clear()
	current_events.sort_custom(event_less)
	var result := current_events.duplicate(true)
	current_events.clear()
	return result
