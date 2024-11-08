class_name Component
extends RefCounted
## Base component class with property management functionality
##
## Provides a standardized way to expose and access properties with type safety,
## error handling, and property metadata.

#region Member Variables
## Container for managing component properties
var properties_container: PropertiesContainer = PropertiesContainer.new(self)
var name: String
var ant: Ant
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
	FOODS,
	PHEROMONES,
	ANTS,
	OBJECT,
	UNKNOWN
}
#endregion

func _init(_ant: Ant, _name: String) -> void:
	ant = _ant
	name = _name.to_snake_case() # Ensures lowercase for lookup
	properties_container = PropertiesContainer.new(self)
	properties_container.property_added.connect(
		func(property): _trace("Property %s added to properties container" % property)
	)
	# Log name set so we know if it is a case mismatch causing a lookup error
	DebugLogger.trace(DebugLogger.Category.PROGRAM, "Name for attribute set as %s" % name)
	_init_properties()


# Virtual method that derived classes will implement
func _init_properties() -> void:
	pass

#region Property Management
## Get property metadata
## Returns: PropertyResult
func get_property(prop_name: String) -> PropertyResult:
	return ant.get_property("%s.%s" % [name, prop_name])

## Get a property's value
## Returns: PropertyResult with value or error information
func get_property_value(prop_name: String) -> Variant:
	return ant.get_property_value("%s.%s" % [name, prop_name])

## Get an array of PropertyResults
## Returns: PropertyResult
func get_properties() -> Array[PropertyResult]:
	return ant.get_attribute_properties(name)
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
		PropertyType.FOODS: return "Foods"
		PropertyType.ANTS: return "Ants"
		PropertyType.PHEROMONES: return "Pheromones"
		PropertyType.OBJECT: return "Object"
		_: return "Unknown"
#endregion

func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "component"}
	)
