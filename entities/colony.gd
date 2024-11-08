class_name Colony
extends Node2D

var _radius: float = 10.0
var foods: Foods
var properties_container: PropertiesContainer

func _init() -> void:
	properties_container = PropertiesContainer.new(self)
	properties_container.property_added.connect(
		func(property): _trace("Property %s added to properties container" % property)
	)
	_init_properties()

# Virtual method that derived classes will implement
func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("position")
			.of_type(Component.PropertyType.VECTOR2)
			.with_getter(Callable(self, "_get_position"))
			.described_as("Location of the colony in global coordinates")
			.build()
	])

func _get_position() -> Vector2:
	return global_position

func area() -> float:
	return PI * _radius * _radius

func radius() -> float:
	return _radius

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
		var error_msg: String = "Property '%s' not found" % name
		DebugLogger.error(DebugLogger.Category.PROPERTY, "Failed to retrieve property value %s -> %s" % [name, error_msg])
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.PROPERTY_NOT_FOUND,
			error_msg
		)
	
	if not property.getter.is_valid():
		var error_msg: String = "Invalid getter for property '%s'" % name
		DebugLogger.error(DebugLogger.Category.PROPERTY, "Failed to retrieve property value %s -> %s" % [name, error_msg])
		return PropertyResult.new(
			null,
			PropertyResult.ErrorType.INVALID_GETTER,
			error_msg
		)
	
	# Get the value
	var value = property.getter.call()
	
	# Validate result
	if value == null:
		var warn_msg: String = "Getter for property '%s' returned null" % name
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "Failed to retrieve property value %s -> %s" % [name, warn_msg])
		DebugLogger.warn(
			DebugLogger.Category.PROPERTY,
			warn_msg
		)
	
	return PropertyResult.new(value)

## Set a property's value
## Returns: PropertyResult indicating success or error
func set_property(name: String, value: Variant) -> PropertyResult:
	return properties_container.set_property_value(name, value)

## Get information about all exposed properties
## Returns: PropertyResult
func get_exposed_properties() -> Array[PropertyResult.PropertyInfo]:
	_trace("Attempting to retrieve %s exposed properties" % properties_container.get_properties().size())
	var properties: Array[PropertyResult.PropertyInfo] = []
	for property_result: PropertyResult in properties_container.get_properties():
		var info = properties_container.get_property_info(property_result.name)
		if info:
			properties.append(info)
	_trace("Retrieved %s exposed properties" % properties.size())
	return properties
#endregion

#region Helper Methods
## Check if a getter requires arguments
## Returns: bool indicating if the getter needs arguments
static func _getter_requires_args(getter: Callable) -> bool:
	return getter.get_argument_count() > 0

## Convert PropertyType to human-readable string
## Returns: String representation of the property type
static func type_to_string(type: Component.PropertyType) -> String:
	match type:
		Component.PropertyType.BOOL: return "Boolean"
		Component.PropertyType.INT: return "Integer"
		Component.PropertyType.FLOAT: return "Float"
		Component.PropertyType.STRING: return "String"
		Component.PropertyType.VECTOR2: return "Vector2"
		Component.PropertyType.VECTOR3: return "Vector3"
		Component.PropertyType.ARRAY: return "Array"
		Component.PropertyType.DICTIONARY: return "Dictionary"
		Component.PropertyType.FOODS: return "Foods"
		Component.PropertyType.ANTS: return "Ants"
		Component.PropertyType.PHEROMONES: return "Pheromones"
		Component.PropertyType.OBJECT: return "Object"
		_: return "Unknown"
#endregion

func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"From": "component"}
	)
