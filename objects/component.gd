class_name Component
extends RefCounted
## Base component class with property management functionality
##
## Provides a standardized way to expose and access properties with type safety,
## error handling, and property metadata.

#region Member Variables
## Container for managing component properties
var properties_container: PropertiesContainer = PropertiesContainer.new(self)
#endregion

#region Property Types
## Supported property types
enum PropertyType {
	BOOL,
	INT,
	FLOAT,
	STRING,
	VECTOR2,
	VECTOR3,
	ARRAY,
	DICTIONARY,
	OBJECT,
	UNKNOWN
}
#endregion

#region Property Management

## Get property metadata
## Returns: PropertyResult.PropertyInfo or null if not found
func get_property(name: String) -> PropertyResult.PropertyInfo:
	return properties_container.get_property_info(name)

## Get a property's value
## Returns: PropertyResult with value or error information
func get_property_value(name: String) -> PropertyResult:
	var property = get_property(name)
	if not property:
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			"Property '%s' not found" % name
		)
	
	if not property.getter.is_valid():
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_GETTER,
			"Invalid getter for property '%s'" % name
		)
	
	# Get the value
	var value = property.getter.call()
	
	# Validate result
	if value == null:
		DebugLogger.warn(
			DebugLogger.Category.PROPERTY,
			"Getter for property '%s' returned null" % name
		)
	
	return PropertyResult.new(value)

## Set a property's value
## Returns: PropertyResult indicating success or error
func set_property(name: String, value: Variant) -> PropertyResult:
	return properties_container.set_property_value(name, value)

## Get information about all exposed properties
## Returns: PropertyResult
func get_exposed_properties() -> Array[PropertyResult.PropertyInfo]:
	var properties: Array[PropertyResult.PropertyInfo] = []
	for name in properties_container.get_properties():
		var info = properties_container.get_property_info(name)
		if info:
			properties.append(info)
	return properties
#endregion

#region Helper Methods
## Check if a getter requires arguments
## Returns: bool indicating if the getter needs arguments
static func _getter_requires_args(getter: Callable) -> bool:
	return getter.get_argument_count() > 0

## Convert PropertyType to human-readable string
## Returns: String representation of the property type
static func type_to_string(type: PropertyType) -> String:
	match type:
		PropertyType.BOOL: return "Boolean"
		PropertyType.INT: return "Integer"
		PropertyType.FLOAT: return "Float"
		PropertyType.STRING: return "String"
		PropertyType.VECTOR2: return "Vector2"
		PropertyType.VECTOR3: return "Vector3"
		PropertyType.ARRAY: return "Array"
		PropertyType.DICTIONARY: return "Dictionary"
		PropertyType.OBJECT: return "Object"
		_: return "Unknown"
#endregion
