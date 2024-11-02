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
		DebugLogger.trace(DebugLogger.Category.CONTEXT, 
			"Using cached value for '%s': %s" % [property_name, _context_cache[property_name]]
		)
		return _context_cache[property_name]
	
	if property_name in _required_properties:
		var value = ant.get_method_result(property_name)
		_context_cache[property_name] = value
		DebugLogger.trace(DebugLogger.Category.CONTEXT,
			"Evaluating property '%s' = %s" % [property_name, value]
		)
		return value
	
	DebugLogger.warn(DebugLogger.Category.CONTEXT,
		"Accessing unrequired property '%s'" % property_name
	)
	return null

func build() -> Dictionary:
	if not is_instance_valid(ant):
		DebugLogger.error(DebugLogger.Category.CONTEXT, "ContextBuilder: Invalid ant reference")
		return {}
	
	var context = {}
	context["condition_configs"] = condition_configs
	
	_required_properties.clear()
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			register_required_properties(config.evaluation)
	
	# Log required properties in a more organized way
	var properties_list: Array = _required_properties.keys()
	if not properties_list.is_empty():
		var formatted_list = ""
		for prop in properties_list:
			formatted_list += "\n  - " + str(prop)
		DebugLogger.debug(DebugLogger.Category.CONTEXT,
			"Required properties for update:%s" % formatted_list
		)
	
	for property_name in _required_properties:
		context[property_name] = get_context_value(property_name)
	
	return context

func clear_cache() -> void:
	_context_cache.clear()
	DebugLogger.debug(DebugLogger.Category.CONTEXT, "Context cache cleared")

func print_context_analysis() -> void:
	var hits = 0
	var misses = 0
	for prop in _required_properties:
		if prop in _context_cache:
			hits += 1
		else:
			misses += 1
	
	var analysis = "\nContext Analysis:"
	analysis += "\n  Registered properties (%d):" % _required_properties.size()
	for prop in _required_properties.keys():
		analysis += "\n    - %s" % prop
	
	analysis += "\n  Cached values (%d):" % _context_cache.size()
	for key in _context_cache.keys():
		analysis += "\n    - %s = %s" % [key, _context_cache[key]]
	
	analysis += "\n  Cache statistics:"
	analysis += "\n    Hits: %d" % hits
	analysis += "\n    Misses: %d" % misses
	var hit_ratio = 100.0 * hits / (hits + misses) if (hits + misses) > 0 else 0
	analysis += "\n    Hit ratio: %.1f%%" % hit_ratio
	
	DebugLogger.info(DebugLogger.Category.CONTEXT, analysis)
