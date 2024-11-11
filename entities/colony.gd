class_name Colony
extends Node2D
## The ant colony node that manages colony-wide properties and resources

#region Member Variables
## Colony radius in units
var _radius: float = 10.0

## Collection of food resources
var foods: Foods

## Property management system
var _property_group: PropertyGroup
#endregion

func _ready() -> void:
	_property_group = _create_property_group()
	_trace("Colony initialized with radius: %.2f" % _radius)


## Create the colony's property group with all properties
func _create_property_group() -> PropertyGroup:
	var group = (PropertyGroup.new("Colony")
		.with_name("colony")
		.with_owner(self)
		.build())

	_init_properties(group)
	return group

## Initialize all properties for the colony
func _init_properties(group: PropertyGroup) -> void:
	# Create base properties container
	var base_prop = (Property.create("base")
		.as_container()
		.described_as("Basic colony properties")
		.with_children([
			Property.create("position")
				.as_property(Property.Type.VECTOR2)
				.with_getter(Callable(self, "_get_position"))
				.described_as("Location of the colony in global coordinates")
				.build(),

			Property.create("radius")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_radius"))
				.with_setter(Callable(self, "_set_radius"))
				.described_as("Size of the colony radius in units")
				.build()
		])
		.build())

	# Create metrics container with computed properties
	var metrics_prop = (Property.create("metrics")
		.as_container()
		.described_as("Colony size metrics")
		.with_children([
			Property.create("area")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_area"))
				.with_dependency("colony.base.radius")
				.described_as("Size of the colony area in units squared")
				.build(),

			Property.create("perimeter")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_perimeter"))
				.with_dependency("colony.base.radius")
				.described_as("Length of colony perimeter in units")
				.build()
		])
		.build())

	# Create resources container
	var resources_prop = (Property.create("resources")
		.as_container()
		.described_as("Colony resource information")
		.with_children([
			Property.create("food_count")
				.as_property(Property.Type.INT)
				.with_getter(Callable(self, "_get_food_count"))
				.described_as("Number of food items in colony storage")
				.build(),

			Property.create("total_food_mass")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_total_food_mass"))
				.described_as("Total mass of stored food")
				.build()
		])
		.build())

	# Register properties with error handling
	var result = group.register_property(base_prop)
	if not result.is_ok():
		push_error("Failed to register base properties: %s" % result.get_error())
		return

	result = group.register_property(metrics_prop)
	if not result.is_ok():
		push_error("Failed to register metrics properties: %s" % result.get_error())
		return

	result = group.register_property(resources_prop)
	if not result.is_ok():
		push_error("Failed to register resources properties: %s" % result.get_error())
		return

	_trace("Colony properties initialized successfully")

#region Property Getters and Setters
func _get_position() -> Vector2:
	return global_position

func _get_radius() -> float:
	return _radius

func _set_radius(value: float) -> void:
	if value <= 0:
		push_error("Colony radius must be positive")
		return

	var old_value = _radius
	_radius = value

	if old_value != _radius:
		_trace("Colony radius updated: %.2f -> %.2f" % [old_value, _radius])

func _get_area() -> float:
	return PI * _radius * _radius

func _get_perimeter() -> float:
	return 2 * PI * _radius

func _get_food_count() -> int:
	return foods.size() if foods else 0

func _get_total_food_mass() -> float:
	return foods.total_mass() if foods else 0.0
#endregion

#region Public Property Interface
## Get the colony's property group
func get_property_group() -> PropertyGroup:
	return _property_group

## Get a property value by path
func get_property_value(path: String) -> Variant:
	var property = _property_group.get_property(path)
	if not property:
		push_error("Property not found: %s" % path)
		return null

	return property.get_value()

## Set a property value by path
func set_property_value(path: String, value: Variant) -> Result:
	var property = _property_group.get_property(path)
	if not property:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Property not found: %s" % path
		)

	return property.set_value(value)
#endregion

#region Helper Methods
func _trace(message: String) -> void:
	DebugLogger.trace(
		DebugLogger.Category.PROPERTY,
		message,
		{"From": "colony"}
	)
#endregion
