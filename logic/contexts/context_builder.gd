class_name ContextBuilder
extends RefCounted
## Builds context for condition evaluation with property caching
##
## Manages property access, caching, and analysis for condition evaluation contexts.

#region Member Variables
var ant: Ant
var condition_configs: Dictionary
var context_cache: Dictionary = {}
var required_properties: Dictionary = {}
var _property_access: PropertyAccess
#endregion

func _init(p_ant: Ant, p_condition_configs: Dictionary) -> void:
	ant = p_ant
	condition_configs = p_condition_configs
	_property_access = PropertyAccess.new({"ant": ant})

#region Property Management
## Registers properties required by a condition configuration
func register_required_properties(condition: Dictionary) -> void:
	match condition.get("type", ""):
		"PropertyCheck":
			if "property" in condition:
				required_properties[condition.property] = true
			if "value_from" in condition:
				required_properties[condition.value_from] = true
		"Operator":
			for operand in condition.get("operands", []):
				if "evaluation" in operand:
					register_required_properties(operand.evaluation)

## Gets a context value, using cache if available
func get_context_value(property_name: String) -> Variant:
	# Check cache first
	if property_name in context_cache:
		DebugLogger.trace(DebugLogger.Category.CONTEXT, 
			"Using cached value for '%s': %s" % [
				property_name, 
				PropertyEvaluator.format_value(context_cache[property_name])
			]
		)
		return context_cache[property_name]
	
	if not property_name in required_properties:
		DebugLogger.warn(DebugLogger.Category.CONTEXT,
			"Accessing unrequired property '%s'" % property_name
		)
		return null
	
	var result = _property_access.get_property(property_name)
	if result.is_error():
		DebugLogger.error(DebugLogger.Category.CONTEXT, result.error_message)
		return null
		
	context_cache[property_name] = result.value
	DebugLogger.trace(DebugLogger.Category.CONTEXT,
		"Evaluating property '%s' = %s" % [
			property_name, 
			PropertyEvaluator.format_value(result.value)
		]
	)
	return result.value
#endregion

#region Context Building
## Builds the complete context dictionary
## Returns: Dictionary with context information
func build() -> Dictionary:
	if not is_instance_valid(ant):
		DebugLogger.error(DebugLogger.Category.CONTEXT, "ContextBuilder: Invalid ant reference")
		return {}
	
	var context = {
		"ant": ant,
		"condition_configs": condition_configs
	}
	
	required_properties.clear()
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			register_required_properties(config.evaluation)
	
	# Log required properties
	var properties_list: Array = required_properties.keys()
	if not properties_list.is_empty():
		var formatted_list = ""
		for prop in properties_list:
			formatted_list += "\n  - " + str(prop)
		DebugLogger.debug(DebugLogger.Category.CONTEXT,
			"Required properties for update:%s" % formatted_list
		)
	
	# Get values for all required properties
	for property_name in required_properties:
		context[property_name] = get_context_value(property_name)
	
	return context

## Clears the context cache
func clear_cache() -> void:
	context_cache.clear()
	DebugLogger.debug(DebugLogger.Category.CONTEXT, "Context cache cleared")
#endregion

#region Debug
## Prints detailed analysis of context and cache usage
func print_context_analysis() -> void:
	var hits = 0
	var misses = 0
	for prop in required_properties:
		if prop in context_cache:
			hits += 1
		else:
			misses += 1
	
	var analysis = "\nContext Analysis:"
	analysis += "\n  Registered properties (%d):" % required_properties.size()
	for prop in required_properties.keys():
		analysis += "\n    - %s" % prop
	
	analysis += "\n  Cached values (%d):" % context_cache.size()
	for key in context_cache.keys():
		analysis += "\n    - %s = %s" % [
			key, 
			PropertyEvaluator.format_value(context_cache[key])
		]
	
	analysis += "\n  Cache statistics:"
	analysis += "\n    Hits: %d" % hits
	analysis += "\n    Misses: %d" % misses
	var hit_ratio = 100.0 * hits / (hits + misses) if (hits + misses) > 0 else 0
	analysis += "\n    Hit ratio: %.1f%%" % hit_ratio
	
	DebugLogger.info(DebugLogger.Category.CONTEXT, analysis)
#endregion
