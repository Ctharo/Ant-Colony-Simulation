class_name PropertyStorage
extends RefCounted
## Maintains the state/values for properties in a centralized way

#region Storage Variables
## Dictionary storing all property values by their full path
var _values: Dictionary = {}

## Logger instance for debugging
var logger: Logger
#endregion

func _init() -> void:
	logger = Logger.new("property_storage", DebugLogger.Category.PROPERTY)

#region Value Management
## Get a property value by its path
func get_value(path: String) -> Variant:
	if not _values.has(path):
		logger.warning("Attempting to get non-existent property: %s" % path)
		return null
	return _values[path]

## Set a property value by its path
func set_value(path: String, value: Variant) -> void:
	_values[path] = value
	logger.trace("Set property value: %s = %s" % [path, str(value)])

## Check if a property value exists
func has_value(path: String) -> bool:
	return _values.has(path)

## Remove a property value
func remove_value(path: String) -> void:
	if _values.has(path):
		_values.erase(path)
		logger.trace("Removed property value: %s" % path)

## Clear all stored values
func clear_values() -> void:
	_values.clear()
	logger.trace("Cleared all property values")
#endregion

#region Bulk Operations
## Initialize multiple values at once
func initialize_values(values: Dictionary) -> void:
	for path in values:
		set_value(path, values[path])
	
## Get all stored values
func get_all_values() -> Dictionary:
	return _values.duplicate()
#endregion
