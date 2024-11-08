class_name Attribute
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
var PropertyType = PropertyResult.PropertyType
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
	return properties_container.get_property("%s" % prop_name)

## Get a property's value
## Returns: PropertyResult with value or error information
func get_property_value(prop_name: String) -> Variant:
	return properties_container.get_property_value("%s" % prop_name)

## Get an array of PropertyResults
## Returns: PropertyResult
func get_properties() -> Array[PropertyResult]:
	return properties_container.get_properties()
#endregion

#region Helper Methods
## Check if a getter requires arguments
## Returns: bool indicating if the getter needs arguments
static func _getter_requires_args(getter: Callable) -> bool:
	return getter.get_argument_count() > 0
#endregion

func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "component"}
	)
