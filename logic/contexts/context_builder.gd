## Builds and manages context for condition evaluation in behavior trees
##
## The ContextBuilder class handles:
## - Property registration and tracking
## - Value caching for efficient access
## - Context building for condition evaluation
## - Property access management
class_name ContextBuilder
extends RefCounted

#region Properties
## The ant agent this context builder is associated with
var ant: Ant

## Configuration dictionary for conditions
var condition_configs: Dictionary

## Cache of property values for quick lookup
var _cache: Cache

## Dictionary tracking which properties are required by conditions
var required_properties: Dictionary = {}

## Property access manager for retrieving values
var _property_access: PropertyAccess
#endregion

#region Initialization
## Initializes a new ContextBuilder instance
## [param p_ant] The ant agent to associate with this builder
## [param p_condition_configs] Dictionary of condition configurations
func _init(p_ant: Ant, p_condition_configs: Dictionary) -> void:
	ant = p_ant
	condition_configs = p_condition_configs
	_cache = Cache.new()
	_property_access = ant._property_access
#endregion

#region Public Methods
## Builds a complete context dictionary for condition evaluation
## [return] Dictionary containing all context information including property values
func build() -> Dictionary:
	if not is_instance_valid(ant):
		_error("ContextBuilder: Invalid ant reference")
		return {}

	var context = {
		"ant": ant,
		"condition_configs": condition_configs
	}

	# Clear existing properties and cache
	required_properties.clear()
	_cache.clear()

	# Register required properties from conditions
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			register_required_properties(config.evaluation)

	# Log required properties
	_log_required_properties()

	# Get values for all required properties
	for property_path in required_properties:
		context[property_path] = get_context_value(property_path)

	return context

## Registers properties required by a condition configuration
## [param condition] The condition configuration dictionary
func register_required_properties(condition: Dictionary) -> void:
	match condition.get("type", ""):
		"PropertyCheck":
			# Handle both direct properties and attribute properties
			if "property" in condition:
				_register_property(condition.property)
			if "value_from" in condition:
				_register_property(condition.value_from)
		"Operator":
			for operand in condition.get("operands", []):
				if "evaluation" in operand:
					register_required_properties(operand.evaluation)

## Gets a context value, using cache if available
## [param property_path] The path to the property to retrieve
## [return] The value of the property
func get_context_value(property_path: String) -> Variant:
	# Check cache first
	if property_path in _cache:
		_trace("Using cached value for '%s': %s" % [
				property_path,
				Property.format_value(_cache[property_path])
			]
		)
		return _cache[property_path]

	# Verify property is required
	if not property_path in required_properties:
		_warn("Accessing unrequired property '%s'" % property_path)
		return null

	# Try to get value through property system
	var property = _property_access.get_property(Path.parse(property_path))

	# Cache and return the value
	_cache[property_path] = property.value
	_trace("Evaluated property '%s' = %s" % [property_path, Property.format_value(_cache[property_path])])
	return _cache[property_path]

## Clears the context cache and property access cache
func clear_cache() -> void:
	_cache.clear()
	_property_access.clear_cache()
	_trace("Context cache cleared")

## Prints detailed analysis of context and cache usage for debugging
func print_context_analysis() -> void:
	var hits = 0
	var misses = 0
	for prop in required_properties:
		if prop in _cache:
			hits += 1
		else:
			misses += 1

	var analysis = "\nContext Analysis:"
	analysis += "\n  Registered properties (%d):" % required_properties.size()
	for prop in required_properties.keys():
		analysis += "\n    - %s" % prop

	analysis += "\n  Cached values (%d):" % _cache.size()
	for key in _cache:
		analysis += "\n    - %s = %s" % [
			key,
			Property.format_value(_cache[key])
		]

	analysis += "\n  Cache statistics:"
	analysis += "\n    Hits: %d" % hits
	analysis += "\n    Misses: %d" % misses
	var hit_ratio = 100.0 * hits / (hits + misses) if (hits + misses) > 0 else 0
	analysis += "\n    Hit ratio: %.1f%%" % hit_ratio

	_info(analysis)
#endregion

#region Private Methods
## Registers a single property in the required properties list
## [param property_path] The path to the property to register
func _register_property(property_path: String) -> void:
	if property_path.is_empty():
		return

	required_properties[property_path] = true
	_trace("Registered required property: %s" % property_path)

## Logs the list of required properties for debugging
func _log_required_properties() -> void:
	var properties_list = required_properties.keys()
	if properties_list.is_empty():
		return

	var formatted_list = ""
	for prop in properties_list:
		formatted_list += "\n  - " + str(prop)

	_trace("Required properties for update:%s" % formatted_list)
#endregion

#region Logging Methods
## Logs a trace level message
## [param message] The message to log
func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.CONTEXT,
		message,
		{"From": "context_builder"}
	)

## Logs a warning level message
## [param message] The message to log
func _warn(message: String) -> void:
	DebugLogger.warn(DebugLogger.Category.CONTEXT,
		message
	)

## Logs a debug level message
## [param message] The message to log
func _debug(message: String) -> void:
	DebugLogger.debug(DebugLogger.Category.CONTEXT,
		message
	)

## Logs an info level message
## [param message] The message to log
func _info(message: String) -> void:
	DebugLogger.info(DebugLogger.Category.CONTEXT,
		message
	)

## Logs an error level message
## [param message] The message to log
func _error(message: String) -> void:
	DebugLogger.error(DebugLogger.Category.CONTEXT,
		message
	)
#endregion
