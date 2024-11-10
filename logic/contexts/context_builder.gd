## Builds and manages context for condition evaluation in behavior trees
##
## The ContextBuilder class handles:
## - Property registration and tracking
## - Value caching for efficient access # TODO: Probably shouldn't have caching
## - Context building for condition evaluation
## - Property access management
class_name ContextBuilder
extends RefCounted

#region Properties
## The ant agent this context builder is associated with
var ant: Ant

## Configuration dictionary for conditions
var condition_configs: Dictionary

## Dictionary tracking which properties are required by conditions
## Key: Full path string, Value: Path object
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

	required_properties.clear()

	# Register required properties from conditions
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			register_required_properties(config.evaluation)

	_log_required_properties()

	# Get values for all required properties using Path objects
	for path_str in required_properties:
		var path: Path = required_properties[path_str]
		context[path_str] = get_context_value(path)

	return context

## Registers properties required by a condition configuration
## [param condition] The condition configuration dictionary
func register_required_properties(condition: Dictionary) -> void:
	match condition.get("type", ""):
		"PropertyCheck":
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
func get_context_value(path: Path) -> Variant:
	if not path.full in required_properties:
		_warn("Accessing unrequired property '%s'" % path.full)
		return null

	var property = _property_access.get_property(path)
	_trace("Evaluated property '%s' = %s" % [path.full, Property.format_value(property.value)])
	return property.value
#endregion

#region Private Methods
## Registers a single property in the required properties list
## [param property_path_str] The path to the property to register
func _register_property(property_path_str: String) -> void:
	if property_path_str.is_empty():
		return

	# Store both string and Path object for compatibility
	var path := Path.parse(property_path_str)
	required_properties[path.full] = path
	_trace("Registered required property: %s" % path.full)

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
