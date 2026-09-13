class_name StrategyInterruptMatrix
extends RefCounted

const INTERRUPT_RANK := {"TACTICAL_MOVE": 100, "COMBAT": 200, "EMERGENCY_SURVIVAL": 300, "SYSTEM_FORCE": 400}

func can_interrupt(active_action: Dictionary, candidate: Dictionary) -> bool:
	if active_action.is_empty(): return true
	var interrupt_class := str(candidate.get("interruptClass", "TACTICAL_MOVE"))
	var allowed: Array = active_action.get("interruptibleBy", [])
	if interrupt_class in allowed: return true
	if interrupt_class == "SYSTEM_FORCE" and not bool(active_action.get("uninterruptibleSystem", false)): return true
	return false
