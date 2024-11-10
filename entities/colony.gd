class_name Colony
extends Node2D

var radius: float = 10.0 : get = _get_radius
var area: float : get = _get_area
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
		Property.create("position")
			.of_type(Property.Type.VECTOR2)
			.with_attribute("Colony")
			.with_getter(Callable(self, "_get_position"))
			.described_as("Location of the colony in global coordinates")
			.build(),
		Property.create("radius")
			.of_type(Property.Type.FLOAT)
			.with_attribute("Colony")
			.with_getter(Callable(self, "_get_radius"))
			.described_as("Size of the colony radius in units")
			.build(),
		Property.create("area")
			.of_type(Property.Type.FLOAT)
			.with_attribute("Colony")
			.with_dependencies(["radius"])
			.with_getter(Callable(self, "_get_area"))
			.described_as("Size of the colony area in units squared")
			.build()
	])

func _get_position() -> Vector2:
	return global_position

func _get_radius() -> float:
	return radius

func _get_area() -> float:
	return PI * radius * radius


#region Property Management
## Get property metadata
## Returns: Property or null if not found
func get_property(name: String) -> Property:
	return properties_container.get_property(name)

## Get a property's value
## Returns: PropertyResult with value or error information
func get_property_value(name: String) -> Variant:
	var property = get_property(name)
	if not property:
		var error_msg: String = "Property '%s' not found" % name
		DebugLogger.error(DebugLogger.Category.PROPERTY, "Failed to retrieve property value %s -> %s" % [name, error_msg])
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			error_msg
		)

	if not property.has_valid_getter():
		var error_msg: String = "Invalid getter for property '%s'" % name
		DebugLogger.error(DebugLogger.Category.PROPERTY, "Failed to retrieve property value %s -> %s" % [name, error_msg])
		return Result.new(
			Result.ErrorType.INVALID_GETTER,
			error_msg
		)

	# Get the value
	var value = property.value

	# Validate result
	if value == null:
		var warn_msg: String = "Getter for property '%s' returned null" % name
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "Failed to retrieve property value %s -> %s" % [name, warn_msg])
		DebugLogger.warn(
			DebugLogger.Category.PROPERTY,
			warn_msg
		)

	return value
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
