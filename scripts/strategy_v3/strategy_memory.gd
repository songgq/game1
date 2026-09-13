class_name StrategyMemoryV3
extends RefCounted

var values: Dictionary = {}

func set_value(key: String, value: Variant) -> bool:
	if not (value == null or value is bool or value is int or value is float or value is String): return false
	if value is float and (is_nan(value) or is_inf(value)): return false
	values[key] = value
	return true

func get_value(key: String, default_value: Variant = null) -> Variant:
	return values.get(key, default_value)

func clear_value(key: String) -> void:
	values.erase(key)
