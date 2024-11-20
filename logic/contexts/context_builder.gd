class_name ContextBuilder
extends BaseRefCounted
## Builds and manages context for condition evaluation in behavior trees

#region Properties

## Configuration dictionary for conditions
var condition_configs: Dictionary

## Dictionary tracking which properties are required by conditions
## Key: Full path string, Value: Path object
var required_properties: Dictionary = {}

## Property access manager for retrieving values
var _property_access: PropertyAccess
#endregion

#region Initialization
func _init(p_ant: Ant, p_condition_configs: Dictionary) -> void:
	condition_configs = p_condition_configs
	_property_access = p_ant._property_access
#endregion

#region Public Methods
## Builds a complete context dictionary for condition evaluation
func build() -> Dictionary:
	if not _property_access:
		_error("ContextBuilder: Invalid ant reference")
		return {}

	var context = {
		"condition_configs": condition_configs
	}

	required_properties.clear()

	# Register required properties from conditions
	for condition_name in condition_configs:
		var config = condition_configs[condition_name]
		if "evaluation" in config:
			register_required_properties(config.evaluation)

	_log_required_properties()

	# Get values for all required properties
	for path_str in required_properties:
		var path: Path = required_properties[path_str]
		context[path_str] = get_property_value(path)

	return context

## Registers properties required by a condition configuration
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

## Gets a context value for a property path
func get_property_value(path: Path) -> Variant:
	if not path.full in required_properties:
		_warn("Accessing unrequired property '%s'" % path.full)
		return null

	var value = _property_access.get_property_value(path)
	if value != null:
		_trace("Evaluated property '%s' = %s" % [path.full, Property.format_value(value)])
	return value
#endregion

#region Private Methods
## Registers a single property in the required properties list
func _register_property(property_path_str: String) -> void:
	if property_path_str.is_empty():
		return

	var path := Path.parse(property_path_str)
	if path.is_root():
		_warn("Cannot register root path as required property")
		return

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
