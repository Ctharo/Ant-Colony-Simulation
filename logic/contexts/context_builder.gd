class_name ContextBuilder
extends RefCounted

## Reference to the ant and conditions configuration
var ant: Ant
var condition_configs: Dictionary

## Cache for ant property and method access types
var _access_cache: Dictionary = {}

## Cache for evaluated context values
var _context_cache: Dictionary = {}

## Set of required properties for this update cycle
var _required_properties: Dictionary = {}

## Initialize with ant and conditions configuration
func _init(_ant: Ant, _condition_configs: Dictionary) -> void:
	ant = _ant
	condition_configs = _condition_configs
	_cache_ant_accessors()

## Types of property/method access
enum AccessorType {
	PROPERTY,  ## Direct property access
	GETTER,    ## Via get_property method
	METHOD     ## Via method call
}

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
	
	# Cache methods
	for method in ant.get_method_list():
		var name = method.name
		if name.begins_with("_"):  # Skip private methods
			continue
			
		# Skip getters we already cached
		if name.begins_with("get_") and name.trim_prefix("get_") in _access_cache:
			continue
			
		_access_cache[name] = AccessorType.METHOD

## Register properties needed for condition evaluation
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

## Get context value, evaluating only if needed
func get_context_value(property_name: String) -> Variant:
	# Return cached value if available
	if property_name in _context_cache:
		if OS.is_debug_build():
			print("    Using cached value for %s" % property_name)
		return _context_cache[property_name]
	
	# Evaluate and cache if this is a required property
	if property_name in _required_properties:
		var value = _get_value(property_name)
		_context_cache[property_name] = value
		if OS.is_debug_build():
			print("    Evaluating and caching %s = %s" % [property_name, value])
		return value
	
	if OS.is_debug_build():
		print("    Warning: Accessing unrequired property %s" % property_name)
	return null

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
	
	var context = {}
	
	# Add condition configs reference
	context["condition_configs"] = condition_configs
	
	# Process each condition configuration to register required properties
	_required_properties.clear()
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			register_required_properties(config.evaluation)
	
	if OS.is_debug_build():
		print("\nRequired properties for this update: ", _required_properties.keys())
	
	# Only evaluate required properties
	for property_name in _required_properties:
		context[property_name] = get_context_value(property_name)
	
	return context

## Clear the context cache
func clear_cache() -> void:
	_context_cache.clear()

## Debug method to analyze context usage
func print_context_analysis() -> void:
	print("\nContext Analysis:")
	print("  Registered properties:", _required_properties.keys())
	print("  Cached values:", _context_cache.keys())
	print("  Available accessors:", _access_cache.keys())
	
	# Analyze cache hits/misses
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
