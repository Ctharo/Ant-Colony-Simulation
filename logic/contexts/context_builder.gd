class_name ContextBuilder
extends RefCounted

## Reference to the ant and conditions configuration
var ant: Ant
var condition_configs: Dictionary
var context: Dictionary = {}

## Cache for ant property and method access
var _access_cache: Dictionary = {}

## Initialize with ant and conditions configuration
func _init(_ant: Ant, _condition_configs: Dictionary) -> void:
	ant = _ant
	condition_configs = _condition_configs
	_cache_ant_accessors()

## Cache both properties and methods for faster lookup
func _cache_ant_accessors() -> void:
	if not is_instance_valid(ant):
		return
		
	# Cache regular properties
	for property in ant.get_property_list():
		var name = property.name
		if name.begins_with("_"):  # Skip private properties
			continue
			
		if ant.has_method("get_" + name):
			_access_cache[name] = AccessorType.GETTER
		else:
			_access_cache[name] = AccessorType.PROPERTY
	
	# Cache methods by getting method list
	for method in ant.get_method_list():
		var name = method.name
		if name.begins_with("_"):  # Skip private methods
			continue
			
		# Skip getters we already cached
		if name.begins_with("get_") and name.trim_prefix("get_") in _access_cache:
			continue
			
		# Cache callable methods
		_access_cache[name] = AccessorType.METHOD

## Types of property/method access
enum AccessorType {
	PROPERTY,  ## Direct property access
	GETTER,    ## Via get_property method
	METHOD     ## Via method call
}

## Get value using the cached access type
func _get_value(name: String) -> Variant:
	if not name in _access_cache:
		push_error("No property or method found: %s" % name)
		return null
		
	if not is_instance_valid(ant):
		push_error("Invalid ant reference while accessing: %s" % name)
		return null
		
	match _access_cache[name]:
		AccessorType.PROPERTY:
			return ant.get(name)
		AccessorType.GETTER:
			return ant.call("get_" + name)
		AccessorType.METHOD:
			return ant.call(name)
		_:
			push_error("Invalid accessor type for: %s" % name)
			return null

## Build and return the context dictionary
func build() -> Dictionary:
	if not is_instance_valid(ant):
		push_error("ContextBuilder: Invalid ant reference")
		return {}
	
	# Add condition configs to context for the evaluator
	context["condition_configs"] = condition_configs
	
	# Process each condition configuration
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			_gather_values_from_evaluation(config.evaluation)
	
	return context

## Recursively gather values from evaluation configuration
func _gather_values_from_evaluation(evaluation: Dictionary) -> void:
	if not evaluation is Dictionary:
		return
		
	match evaluation.get("type", ""):
		"PropertyCheck":
			# Get main property or method value
			if "property" in evaluation:
				var name = evaluation.property
				var value = _get_value(name)
				if value != null:
					context[name] = value
			
			# Get comparison value if needed
			if "value_from" in evaluation:
				var name = evaluation.value_from
				var value = _get_value(name)
				if value != null:
					context[name] = value
		
		"Operator":
			# Recursively process operands for compound conditions
			for operand in evaluation.get("operands", []):
				if "evaluation" in operand:
					_gather_values_from_evaluation(operand.evaluation)

## Debug method to print all available accessors
func print_available_accessors() -> void:
	print("\nAvailable Accessors:")
	
	var properties := []
	var getters := []
	var methods := []
	
	for name in _access_cache:
		match _access_cache[name]:
			AccessorType.PROPERTY:
				properties.append(name)
			AccessorType.GETTER:
				getters.append(name)
			AccessorType.METHOD:
				methods.append(name)
	
	print("Properties:", properties)
	print("Getters:", getters)
	print("Methods:", methods)
