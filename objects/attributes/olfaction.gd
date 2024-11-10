class_name Olfaction
extends Attribute

#region Properties
## Max range at which the ant can sense scents
var range: float = 100.0 : get = _get_range, set = _set_range
var pheromones_in_range: Pheromones : get = _get_pheromones_in_range
var food_pheromones_in_range: Pheromones : get = _get_food_pheromones_in_range
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init("Olfaction", _ant)

func _init_properties() -> void:
	_properties_container.expose_properties([
		Property.create("range")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range at which the ant can smell things")
			.build(),
		Property.create("pheromones_in_range")
			.of_type(Property.Type.PHEROMONES)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_pheromones_in_range"))
			.with_dependencies(["range"])  # Depends on range property
			.described_as("List of pheromones within olfactory range")
			.build(),
		Property.create("pheromones_in_range_count")
			.of_type(Property.Type.INT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_pheromones_in_range_count"))
			.with_dependencies(["pheromones_in_range"])  # Depends on range property
			.described_as("Count of pheromones within olfactory range")
			.build(),
		Property.create("food_pheromones_in_range")
			.of_type(Property.Type.PHEROMONES)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_food_pheromones_in_range"))
			.with_dependencies(["olfaction.pheromones_in_range"])  # Use full path for cross-property dependencies
			.described_as("List of food pheromones within olfactory range")
			.build(),
		Property.create("food_pheromones_in_range_count")
			.of_type(Property.Type.INT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_food_pheromones_in_range_count"))
			.with_dependencies(["olfaction.food_pheromones_in_range"])  # Use full path for cross-property dependencies
			.described_as("Count of food pheromones within olfactory range")
			.build(),
		Property.create("home_pheromones_in_range")
			.of_type(Property.Type.PHEROMONES)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_home_pheromones_in_range"))
			.with_dependencies(["olfaction.pheromones_in_range"])  # Use full path for cross-property dependencies
			.described_as("List of home pheromones within olfactory range")
			.build(),
		Property.create("home_pheromones_in_range_count")
			.of_type(Property.Type.INT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_home_pheromones_in_range_count"))
			.with_dependencies(["olfaction.home_pheromones_in_range"])  # Use full path for cross-property dependencies
			.described_as("Count of home pheromones within olfactory range")
			.build(),
	])
#endregion

#region Public Methods
func is_within_range(point: Vector2) -> bool:
	return ant.global_position.distance_to(point) < range
#endregion

#region Private Methods
func _get_range() -> float:
	return range

func _get_pheromones_in_range() -> Pheromones:
	return Pheromones.in_range(ant.global_position, range)

func _get_pheromones_in_range_count() -> int:
	return _get_pheromones_in_range().size()

func _get_food_pheromones_in_range() -> Pheromones:
	return Pheromones.in_range(ant.global_position, range, "food")

func _get_food_pheromones_in_range_count() -> int:
	return _get_food_pheromones_in_range().size()

func _get_home_pheromones_in_range() -> Pheromones:
	return Pheromones.in_range(ant.global_position, range, "home")

func _get_home_pheromones_in_range_count() -> int:
	return _get_home_pheromones_in_range().size()

func _set_range(value: float) -> void:
	if range != value:
		range = value
#endregion
