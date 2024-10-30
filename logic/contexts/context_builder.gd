class_name ContextBuilder
extends RefCounted

var ant: Ant
var condition_configs: Dictionary
var _context_cache: Dictionary = {}
var _required_properties: Dictionary = {}

func _init(_ant: Ant, _condition_configs: Dictionary) -> void:
	ant = _ant
	condition_configs = _condition_configs

func register_required_properties(condition: Dictionary) -> void:
	match condition.get("type", ""):
		"PropertyCheck":
			if "property" in condition:
				_required_properties[condition.property] = true
			if "value_from" in condition:
				_required_properties[condition.value_from] = true
		"Operator":
			for operand in condition.get("operands", []):
				if "evaluation" in operand:
					register_required_properties(operand.evaluation)

func get_context_value(property_name: String) -> Variant:
	if property_name in _context_cache:
		if OS.is_debug_build():
			print("    Using cached value for %s" % property_name)
		return _context_cache[property_name]
	
	if property_name in _required_properties:
		# Use new ant.get_method_result() for safe access
		var value = ant.get_method_result(property_name)
		_context_cache[property_name] = value
		if OS.is_debug_build():
			print("    Evaluating and caching %s = %s" % [property_name, value])
		return value
	
	if OS.is_debug_build():
		print("    Warning: Accessing unrequired property %s" % property_name)
	return null

func build() -> Dictionary:
	if not is_instance_valid(ant):
		push_error("ContextBuilder: Invalid ant reference")
		return {}
	
	var context = {}
	context["condition_configs"] = condition_configs
	
	_required_properties.clear()
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			register_required_properties(config.evaluation)
	
	if OS.is_debug_build():
		print("\nRequired properties for this update: ", _required_properties.keys())
	
	for property_name in _required_properties:
		context[property_name] = get_context_value(property_name)
	
	return context

func clear_cache() -> void:
	_context_cache.clear()

func print_context_analysis() -> void:
	print("\nContext Analysis:")
	print("  Registered properties:", _required_properties.keys())
	print("  Cached values:", _context_cache.keys())
	
	var hits = 0
	var misses = 0
	for prop in _required_properties:
		if prop in _context_cache:
			hits += 1
		else:
			misses += 1
	
	print("  Cache statistics:")
	print("    Hits: ", hits)
	print("    Misses: ", misses)
	print("    Hit ratio: %.1f%%" % (100.0 * hits / (hits + misses) if (hits + misses) > 0 else 0))
