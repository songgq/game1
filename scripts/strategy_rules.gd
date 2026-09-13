class_name StrategyRules
extends RefCounted

const TOP_KEYS := [
	"schema_version", "compiler_version", "strategy_name", "directives", "message_resolution",
	"unit_results", "unit_summaries", "warnings"
]
const RESULT_STATUSES := ["accepted", "partial", "rejected", "acknowledged"]
const CHANNELS := ["movement", "combat", "survival", "support", "economy", "constraint"]
const ACTION_MODES := ["all", "sequence"]
const ACTIONS := ["move", "hold", "follow", "protect", "heal", "attack", "gather", "retreat", "set_target", "stay_in_zone"]
const UNIT_TYPES := ["archer", "lancer", "worker", "monk", "warrior"]
const RESOURCES := ["gold", "stone", "wood", "meat"]
const ACTION_CHANNELS := {
	"move": ["movement"], "hold": ["movement"], "follow": ["movement"], "protect": ["movement"],
	"heal": ["support"], "attack": ["combat"], "set_target": ["combat"], "gather": ["economy"],
	"retreat": ["movement", "survival"], "stay_in_zone": ["constraint"],
}

static func validate_document(value: Variant, lineup: Array) -> bool:
	if not value is Dictionary or lineup.size() != 5:
		return false
	var document: Dictionary = value
	if document.size() != TOP_KEYS.size():
		return false
	for key in TOP_KEYS:
		if not document.has(key):
			return false
	if String(document.get("schema_version", "")) != "2.0" or String(document.get("compiler_version", "")) != "strategy-2.0.0":
		return false
	var directives: Variant = document.get("directives")
	if not directives is Array or directives.size() > 40:
		return false
	var directive_ids: Dictionary = {}
	for value_directive in directives:
		if not value_directive is Dictionary:
			return false
		var directive: Dictionary = value_directive
		for key in ["id", "slots", "channel", "priority", "when", "action_mode", "actions", "source_messages"]:
			if not directive.has(key):
				return false
		var directive_id := String(directive.get("id", ""))
		if directive_id == "" or directive_ids.has(directive_id):
			return false
		directive_ids[directive_id] = true
		if String(directive.get("channel", "")) not in CHANNELS or String(directive.get("action_mode", "")) not in ACTION_MODES:
			return false
		var channel := String(directive.get("channel", ""))
		if not _is_json_integer(directive.get("priority")) or int(directive["priority"]) < 0 or int(directive["priority"]) > 1000:
			return false
		if not directive.get("slots") is Array or not directive.get("when") is Array or not directive.get("actions") is Array:
			return false
		if directive["slots"].is_empty() or directive["actions"].is_empty():
			return false
		var seen_slots: Dictionary = {}
		for slot in directive["slots"]:
			if not _is_json_integer(slot) or int(slot) < 1 or int(slot) > 5:
				return false
			if seen_slots.has(int(slot)):
				return false
			seen_slots[int(slot)] = true
		if String(directive["action_mode"]) == "all" and directive["actions"].size() != 1:
			return false
		for value_action in directive["actions"]:
			if not value_action is Dictionary:
				return false
			var action: Dictionary = value_action
			var action_type := str(action.get("type", ""))
			if action_type not in ACTIONS or channel not in ACTION_CHANNELS[action_type]:
				return false
			if action.has("target_type") and (typeof(action["target_type"]) != TYPE_STRING or str(action["target_type"]) not in UNIT_TYPES):
				return false
			if action.has("coordination") and (typeof(action["coordination"]) != TYPE_STRING or str(action["coordination"]) not in ["focus", "spread"]):
				return false
			if action.has("zone") and (typeof(action["zone"]) != TYPE_STRING or str(action["zone"]) not in ["ally_side", "enemy_side", "anywhere"]):
				return false
			if action.has("max_attackers") and (not _is_json_integer(action["max_attackers"]) or int(action["max_attackers"]) < 1 or int(action["max_attackers"]) > 5):
				return false
			if action.has("resource") and str(action["resource"]) not in RESOURCES:
				return false
			if action.has("route") and str(action["route"]) not in ["left_bridge", "right_bridge", "nearest_bridge", "auto"]:
				return false
			if action.has("position") and str(action["position"]) not in ["home_platform", "river_edge", "ally_side", "enemy_side"]:
				return false
			if action.has("target_sort") and str(action["target_sort"]) not in ["nearest", "lowest_hp", "backline", "monk", "archer", "lancer", "warrior", "worker"]:
				return false
			if action.has("fallback") and str(action["fallback"]) not in ["nearest", "idle"]:
				return false
			if action.has("target_slot") and (not _is_json_integer(action["target_slot"]) or int(action["target_slot"]) < 1 or int(action["target_slot"]) > 5):
				return false
			if action.has("amount") and (not _is_json_integer(action["amount"]) or int(action["amount"]) < 1 or int(action["amount"]) > 999):
				return false
			if action.has("exclude_types") and (not action["exclude_types"] is Array or Array(action["exclude_types"]).any(func(item: Variant) -> bool: return str(item) not in UNIT_TYPES)):
				return false
			for slot_value in directive["slots"]:
				var unit_type := String(lineup[int(slot_value) - 1])
				if action_type == "heal" and unit_type != "monk":
					return false
				if action_type == "gather" and unit_type != "worker":
					return false
				if action_type == "follow" and int(action.get("target_slot", 0)) == int(slot_value):
					return false
		if String(directive["action_mode"]) == "sequence":
			if directive["actions"].size() < 2:
				return false
			for action_index in directive["actions"].size():
				var sequence_action: Dictionary = directive["actions"][action_index]
				if str(sequence_action.get("type", "")) != "gather" or (action_index < directive["actions"].size() - 1 and not sequence_action.has("amount")):
					return false
	var results: Variant = document.get("unit_results")
	if not results is Array or results.size() != 5:
		return false
	var result_slots: Dictionary = {}
	for value_result in results:
		if not value_result is Dictionary:
			return false
		var result: Dictionary = value_result
		for key in ["slot", "status", "accepted_directive_ids", "rejections"]:
			if not result.has(key):
				return false
		var slot := int(result.get("slot", 0))
		if slot < 1 or slot > 5 or result_slots.has(slot):
			return false
		result_slots[slot] = true
		if String(result.get("status", "")) not in RESULT_STATUSES:
			return false
		if not result.get("accepted_directive_ids") is Array or not result.get("rejections") is Array:
			return false
	var summaries: Variant = document.get("unit_summaries")
	if not summaries is Dictionary:
		return false
	for slot in range(1, 6):
		if not summaries.has(str(slot)):
			return false
	return true

static func _is_json_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floorf(float(value))

static func result_for_slot(document: Dictionary, slot: int) -> Dictionary:
	for value in document.get("unit_results", []):
		if value is Dictionary and int(value.get("slot", 0)) == slot:
			return value
	return {"slot": slot, "status": "acknowledged", "accepted_directive_ids": [], "rejections": []}

static func build_reply(result: Dictionary, unit_type: String, slot: int, revision: int, summary := "") -> String:
	var status := String(result.get("status", "acknowledged"))
	if status in ["accepted", "acknowledged"]:
		if summary != "" and summary != "默认AI处理":
			return "%d号收到：%s" % [slot, summary]
		var accepted := ["%d号收到！", "明白，%d号按计划行动！", "%d号听清楚了！"]
		return String(accepted[_variant_index(unit_type, slot, revision, accepted.size())]) % slot
	var rejections: Array = result.get("rejections", []) if result.get("rejections", []) is Array else []
	var reason := "UNSUPPORTED_ACTION"
	if not rejections.is_empty() and rejections[0] is Dictionary:
		reason = String(rejections[0].get("reason_code", reason))
	var variants := _reply_variants(reason, unit_type)
	var refusal := String(variants[_variant_index(reason + unit_type, slot, revision, variants.size())])
	if status == "partial":
		return "能做的部分收到！不过" + refusal
	return refusal

static func failure_reply(unit_type: String, slot: int) -> String:
	var variants := [
		"风太大了，%d号没听清，再说一次吧！",
		"这道命令有点绕，%d号请求重新下达！",
		"信号断了一下，%d号没收到完整策略。"
	]
	return String(variants[(slot + unit_type.length()) % variants.size()]) % slot

static func _reply_variants(reason: String, unit_type: String) -> Array:
	match reason:
		"CAPABILITY_GATHER_FORBIDDEN":
			match unit_type:
				"warrior": return ["我这把剑是打仗的，不是砍树的！", "让我砍敌人行，砍树可真不行！", "我没带斧头呀，只有这把剑！"]
				"lancer": return ["长枪这么长，也不是用来刨矿的呀！", "我会扎敌人，可不会挖石头！", "拿长枪砍树，会被大家笑话的！"]
				"archer": return ["箭能扎在树上，可我不会伐木呀！", "我只带了箭，没带采集工具！", "射树容易，搬木头可不是我的活！"]
				"monk": return ["我会治疗，不会挖矿啦！", "法杖可不是镐子呀！", "让我照顾伤员吧，采集真不会！"]
				_: return ["我没有采集工具呀！", "这个资源我可采不了！", "采集不是我的工作啦！"]
		"CAPABILITY_HEAL_FORBIDDEN":
			match unit_type:
				"worker": return ["我只会干活，不会治疗术啊！", "扳手和锤子都有，就是没有治疗法杖！", "包扎我会一点，治疗术真不会呀！"]
				"warrior": return ["我能挡刀，可不会治疗术！", "让我保护他行，治疗得找僧侣！", "我的剑治不了伤呀！"]
				"lancer": return ["长枪可治不了伤，去找僧侣吧！", "我能守住他，但不会治疗！", "让我打敌人，救人得请僧侣！"]
				"archer": return ["箭袋里没有药呀，找僧侣吧！", "我能掩护他，可不会治疗！", "射箭我在行，治疗真不行！"]
				_: return ["我不会治疗术呀！", "治伤还是得找僧侣！", "这个我真治不了！"]
		"WORKER_COMBAT_LOCKED":
			return ["先让我干活，他们都倒下以后我再上！", "现在轮不到我打架，我得先采资源！", "别急，最后需要我的时候我一定抄家伙！"]
		"SELF_FOLLOW":
			return ["我跟着我自己？那不是原地转圈吗？", "我就在这里，要怎么跟着自己呀？", "这个队形会绕晕我的，换个人跟吧！"]
		"FOLLOW_CYCLE":
			return ["大家互相跟着会转圈圈的！", "这个跟随顺序打结啦，重新排一下吧！", "我们会绕成一团的，换个带队人吧！"]
		"AMBIGUOUS_REFERENCE":
			return ["你说的是谁呀？给我一个号码吧！", "这个命令有点含糊，我怕跟错人！", "请说清楚几号，我马上照办！"]
		_:
			return ["这招我还没学会呢！", "这个做不到，换个命令试试吧！", "这可超出我的本事啦！"]

static func _variant_index(seed_text: String, slot: int, revision: int, count: int) -> int:
	return absi(hash(seed_text + ":%d:%d" % [slot, revision])) % maxi(1, count)
