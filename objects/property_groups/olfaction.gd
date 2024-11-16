class_name Olfaction
extends PropertyGroup
## Component responsible for ant's sense of smell and pheromone detection

#region Constants
const DEFAULT_RANGE := 100.0
#endregion

#region Member Variables
## Maximum range at which the ant can detect scents
var _range: float = DEFAULT_RANGE
#endregion

func _init(_entity: Node) -> void:
	super._init("olfaction", _entity)

## Initialize all properties for the Olfaction component
func _init_properties() -> void:
	# Create range property
	var range_prop = (Property.create("range")
		.as_property(Property.Type.FLOAT)
		.with_getter(Callable(self, "_get_range"))
		.with_setter(Callable(self, "_set_range"))
		.described_as("Maximum range at which to smell things")
		.build())

	# Create pheromones container with nested properties
	var pheromones_prop = (Property.create("pheromones")
		.as_container()
		.described_as("Information about pheromones within detection range")
		.with_children([
			# All pheromones
			Property.create("list")
				.as_property(Property.Type.PHEROMONES)
				.with_getter(Callable(self, "_get_pheromones_in_range"))
				.with_dependency("olfaction.range")
				.described_as("All pheromones within olfactory range")
				.build(),

			Property.create("count")
				.as_property(Property.Type.INT)
				.with_getter(Callable(self, "_get_pheromones_in_range_count"))
				.with_dependency("olfaction.pheromones.all")
				.described_as("Count of all pheromones within range")
				.build(),

			# Food pheromones
			Property.create("food")
				.as_container()
				.described_as("Food-related pheromone information")
				.with_children([
					Property.create("list")
						.as_property(Property.Type.PHEROMONES)
						.with_getter(Callable(self, "_get_food_pheromones_in_range"))
						.with_dependency("olfaction.range")
						.described_as("Food pheromones within range")
						.build(),

					Property.create("count")
						.as_property(Property.Type.INT)
						.with_getter(Callable(self, "_get_food_pheromones_in_range_count"))
						.with_dependency("olfaction.pheromones.food.list")
						.described_as("Count of food pheromones within range")
						.build()
				])
				.build(),

			# Home pheromones
			Property.create("home")
				.as_container()
				.described_as("Home-related pheromone information")
				.with_children([
					Property.create("list")
						.as_property(Property.Type.PHEROMONES)
						.with_getter(Callable(self, "_get_home_pheromones_in_range"))
						.with_dependency("olfaction.range")
						.described_as("Home pheromones within range")
						.build(),

					Property.create("count")
						.as_property(Property.Type.INT)
						.with_getter(Callable(self, "_get_home_pheromones_in_range_count"))
						.with_dependency("olfaction.pheromones.home.list")
						.described_as("Count of home pheromones within range")
						.build()
				])
				.build()
		])
		.build())

	# Register properties with error handling
	var result = register_at_path(Path.parse("olfaction"),range_prop)
	if not result.success():
		_error("Failed to register olfaction.range property: %s" % result.get_error())
		return

	result = register_at_path(Path.parse("olfaction"), pheromones_prop)
	if not result.success():
		_error("Failed to register olfaction.pheromones property: %s" % result.get_error())
		return


#region Property Getters and Setters
func _get_range() -> float:
	return _range

func _set_range(value: float) -> void:
	if value <= 0:
		push_error("Olfaction range must be positive")
		return

	var old_value = _range
	_range = value

	if old_value != _range:
		_trace("Range updated: %.2f -> %.2f" % [old_value, _range])

func _get_pheromones_in_range() -> Pheromones:
	if not entity:
		push_error("Cannot get pheromones: entity reference is null")
		return null

	return Pheromones.in_range(entity.global_position, _range)

func _get_pheromones_in_range_count() -> int:
	var pheromones = _get_pheromones_in_range()
	return pheromones.size() if pheromones else 0

func _get_food_pheromones_in_range() -> Pheromones:
	if not entity:
		push_error("Cannot get food pheromones: entity reference is null")
		return null

	return Pheromones.in_range(entity.global_position, _range, "food")

func _get_food_pheromones_in_range_count() -> int:
	var pheromones = _get_food_pheromones_in_range()
	return pheromones.size() if pheromones else 0

func _get_home_pheromones_in_range() -> Pheromones:
	if not entity:
		push_error("Cannot get home pheromones: entity reference is null")
		return null

	return Pheromones.in_range(entity.global_position, _range, "home")

func _get_home_pheromones_in_range_count() -> int:
	var pheromones = _get_home_pheromones_in_range()
	return pheromones.size() if pheromones else 0
#endregion

#region Public Methods
## Check if a point is within olfactory range
func is_within_range(point: Vector2) -> bool:
	if not entity:
		push_error("Cannot check range: entity reference is null")
		return false

	return entity.global_position.distance_to(point) < _range

## Reset olfactory range to default value
func reset_range() -> void:
	_set_range(DEFAULT_RANGE)
	_trace("Range reset to default: %.2f" % DEFAULT_RANGE)
#endregion
