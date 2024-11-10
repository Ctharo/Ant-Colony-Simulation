class_name Attribute
extends RefCounted
## Base component class with property management functionality
##
## Provides a standardized way to expose and access properties with type safety,
## error handling, and property metadata.

#region Member Variables
## Container for managing component properties
var _properties_container: PropertiesContainer
var name: String
var metadata: Dictionary = {}
#endregion

func _init(_name: String) -> void:
	name = _name.to_snake_case() # Ensures lowercase for lookup
	_properties_container = PropertiesContainer.new(self)
	# Log name set so we know if it is a case mismatch causing a lookup error
	DebugLogger.trace(DebugLogger.Category.PROGRAM, "Name for attribute set as %s" % name)
	_init_properties()

# Virtual method that derived classes will implement
func _init_properties() -> void:
	DebugLogger.warn(DebugLogger.Category.PROPERTY, "Attribute %s did not initialize properties" % [name])

#region Property Management
func register_property(property: Property) -> Result:
	return _properties_container.expose_property(property)

## Get property metadata
## Returns: PropertyResult
func get_property(prop_name: String) -> Property:
	return _properties_container.get_property(prop_name)

func get_property_path(prop_name: String) -> Path:
	if not has_property(prop_name):
		return null
	return _properties_container.get_property(prop_name).path

## Get a property's value
## Returns: Variant
func get_property_value(prop_name: String) -> Variant:
	if not has_property(prop_name):
		return null
	return get_property(prop_name).get_property_value(prop_name)

## Sets a property value and returns a PropertyResult
func set_property_value(prop_name: String, value: Variant) -> Result:
	if not has_property(prop_name):
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Property '%s' doesn't exist" % name
		)
	var property: Property = get_property(prop_name)
	var result = property.set_value(value)
	return result

## Get an array of PropertyResults
## Returns: PropertyResult
func get_properties() -> Array[Property]:
	return _properties_container.get_properties()

func has_property(property_name: String) -> bool:
	return _properties_container.has_property(property_name)
#endregion

#region Helper Methods

#endregion

func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "component"}
	)
