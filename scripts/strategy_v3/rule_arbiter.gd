class_name StrategyRuleArbiter
extends RefCounted

const PRIORITY := {"IDLE": 0, "FOLLOW": 100, "TACTICAL_MOVE": 200, "COMBAT": 300,
	"COMBAT_POSITIONING": 400, "CRITICAL_SKILL": 500, "PROTECTION": 600,
	"EMERGENCY_SURVIVAL": 700, "SYSTEM": 800}
const SPECIFICITY := {"DEFAULT": 0, "SCOPED": 1, "EXACT": 2}

static func compare_rules(a: Dictionary, b: Dictionary) -> bool:
	var ap := int(PRIORITY.get(a.get("priorityClass"), -1))
	var bp := int(PRIORITY.get(b.get("priorityClass"), -1))
	if ap != bp: return ap > bp
	var am := int(a.get("priorityModifier", 0))
	var bm := int(b.get("priorityModifier", 0))
	if am != bm: return am > bm
	var aspec := int(SPECIFICITY.get(a.get("specificityClass"), -1))
	var bspec := int(SPECIFICITY.get(b.get("specificityClass"), -1))
	if aspec != bspec: return aspec > bspec
	var ao := int(a.get("sourceOrder", 0))
	var bo := int(b.get("sourceOrder", 0))
	if ao != bo: return ao > bo
	return str(a.get("id", "")) < str(b.get("id", ""))

func winners_by_channel(rules: Array) -> Dictionary:
	var grouped := {}
	for rule in rules:
		var channel := str(rule.get("channel", ""))
		if not grouped.has(channel): grouped[channel] = []
		grouped[channel].append(rule)
	var result := {}
	for channel in grouped:
		var candidates: Array = grouped[channel]
		candidates.sort_custom(compare_rules)
		if not candidates.is_empty(): result[channel] = candidates[0]
	return result
