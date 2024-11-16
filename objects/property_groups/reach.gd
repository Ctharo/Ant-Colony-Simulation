class_name Reach
extends PropertyGroup

#region Constentitys
const DEFAULT_RANGE := 15.0
#endregion

#region Member Variables
## The maximum reach distance of the entity
var _range: float = DEFAULT_RANGE
#endregion

func _init(_entity: Node) -> void:
	super._init("reach", _entity)

## Initialize all properties for the Reach component
func _init_properties() -> void:
	# Create range property with validation
	var range_prop = (Property.create("range")
		.as_property(Property.Type.FLOAT)
		.with_getter(Callable(self, "_get_range"))
		.with_setter(Callable(self, "_set_range"))
		.described_as("Maximum distance the entity can reach to interact with objects")
		.build())

	# Create foods container with nested properties
	# Create foods container with properties
	var foods_prop = (Property.create("foods")
		.as_container()
		.described_as("Properties related to food in reach range")
		.with_child(
			(Property.create("in_range")
				.as_property(Property.Type.FOODS)
				.with_getter(Callable(self, "_get_foods_in_range"))
				.with_dependency("reach.range")
				.described_as("Food items within reach range")
				.build())
		).with_child(
			(Property.create("count")
				.as_property(Property.Type.INT)
				.with_getter(Callable(self, "_get_foods_in_range_count"))
				.with_dependency("reach.foods.in_range")
				.described_as("Food within reach range count")
				.build())
		).with_child(
			(Property.create("mass")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_foods_in_range_mass"))
				.with_dependency("reach.foods.in_range")
				.described_as("Total mass of food within reach range")
				.build())
		).build())

	# Register properties with error handling
	var result = register_at_path(Path.parse("reach") ,range_prop)
	if not result.success():
		_error("Failed to register reach.range property: %s" % result.get_error())
		return

	result = register_at_path(Path.parse("reach") ,foods_prop)
	if not result.success():
		_error("Failed to register reach.foods property: %s" % result.get_error())
		return


#region Property Getters and Setters
func _get_range() -> float:
	return _range

func _set_range(value: float) -> void:
	if value <= 0:
		_error("Reach range must be positive")
		return

	var old_value = _range
	_range = value
	_trace("Range updated: %.2f -> %.2f" % [old_value, _range])

func _get_foods_in_range() -> Foods:
	if not entity:
		_error("Cannot get foods in range: entity reference is null")
		return null

	return Foods.in_range(entity.global_position, _range)

func _get_foods_in_range_count() -> int:
	var foods = _get_foods_in_range()
	if not foods:
		return 0
	return foods.size()

func _get_foods_in_range_mass() -> float:
	var foods = _get_foods_in_range()
	var mass: float = 0.0
	if not foods:
		return 0
	for food in foods:
		mass += food.mass
	return mass
#endregion

#region Public Methods
## Reset reach distance to default value
func reset_range() -> void:
	_set_range(DEFAULT_RANGE)
	_trace("Range reset to default: %.2f" % DEFAULT_RANGE)

## Check if a specific position is within reach
func is_position_in_range(position: Vector2) -> bool:
	if not entity:
		_error("Cannot check position: entity reference is null")
		return false

	return entity.global_position.distance_to(position) <= _range
#endregion
