class_name StrategyConditionEvaluator
extends RefCounted

const MAX_DEPTH := 12
const MAX_NODES := 128

func evaluate(ast: Variant, context: Dictionary) -> bool:
	var counter := [0]
	var result: Variant = _eval(ast, context, 1, counter)
	return bool(result) if result is bool else false

func value(ast: Variant, context: Dictionary) -> Variant:
	return _eval(ast, context, 1, [0])

func _eval(node: Variant, context: Dictionary, depth: int, counter: Array) -> Variant:
	counter[0] = int(counter[0]) + 1
	if depth > MAX_DEPTH or int(counter[0]) > MAX_NODES or not node is Dictionary:
		return null
	if node.has("node"):
		match str(node.get("node")):
			"const": return node.get("value")
			"field": return _field(context, str(node.get("path", "")))
			"add": return _numbers(node.get("args", []), context, depth, counter, "add")
			"subtract": return _numbers(node.get("args", []), context, depth, counter, "subtract")
			"multiply": return _numbers(node.get("args", []), context, depth, counter, "multiply")
			"divide": return _numbers(node.get("args", []), context, depth, counter, "divide")
			"min": return _numbers(node.get("args", []), context, depth, counter, "min")
			"max": return _numbers(node.get("args", []), context, depth, counter, "max")
		return null
	var op := str(node.get("op", ""))
	if op in ["all", "any"]:
		var results: Array = []
		for child in node.get("args", []): results.append(_eval(child, context, depth + 1, counter))
		return results.all(func(item): return item == true) if op == "all" else results.any(func(item): return item == true)
	if op == "not": return _eval(node.get("arg"), context, depth + 1, counter) == false
	if op in ["exists", "not_exists"]:
		var exists := _eval(node.get("arg"), context, depth + 1, counter) != null
		return exists if op == "exists" else not exists
	var left: Variant = _eval(node.get("left"), context, depth + 1, counter)
	var right: Variant = _eval(node.get("right"), context, depth + 1, counter)
	match op:
		"eq": return left == right
		"neq": return left != right
		"gt": return _comparable(left, right) and left > right
		"gte": return _comparable(left, right) and left >= right
		"lt": return _comparable(left, right) and left < right
		"lte": return _comparable(left, right) and left <= right
		"in": return right is Array and left in right
		"not_in": return right is Array and left not in right
	return null

func _field(context: Dictionary, path: String) -> Variant:
	var current: Variant = context
	for part in path.split("."):
		if not current is Dictionary or not current.has(part): return null
		current = current[part]
	return current

func _comparable(left: Variant, right: Variant) -> bool:
	return (left is int or left is float) and (right is int or right is float) or left is String and right is String

func _numbers(args: Array, context: Dictionary, depth: int, counter: Array, operation: String) -> Variant:
	var numbers: Array = []
	for child in args:
		var item: Variant = _eval(child, context, depth + 1, counter)
		if not (item is int or item is float): return null
		numbers.append(float(item))
	if numbers.is_empty(): return null
	var result: float = numbers[0]
	match operation:
		"add":
			for index in range(1, numbers.size()): result += numbers[index]
		"subtract":
			for index in range(1, numbers.size()): result -= numbers[index]
		"multiply":
			for index in range(1, numbers.size()): result *= numbers[index]
		"divide":
			for index in range(1, numbers.size()):
				if is_zero_approx(numbers[index]): return null
				result /= numbers[index]
		"min": result = numbers.min()
		"max": result = numbers.max()
	return result
