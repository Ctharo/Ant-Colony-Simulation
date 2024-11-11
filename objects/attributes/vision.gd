class_name Vision
extends PropertyGroup

#region Properties
## Maximum range at which the ant can see
var range: float = 50.0 : set = _set_range, get = _get_range
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init("vision", _ant)

func _init_properties() -> void:
	# Create range property
	var range_prop = (Property.create("range")
		.as_property(Property.Type.FLOAT)
		.with_getter(Callable(self, "_get_range"))
		.with_setter(Callable(self, "_set_range"))
		.described_as("Maximum range at which the ant can see")
		.build())

	# Create ants container with properties
	var ants = (Property.create("ants")
		.as_container()
		.described_as("Properties related to ants in vision range")
		.with_child(
			(Property.create("in_range")
				.as_property(Property.Type.ANTS)
				.with_getter(Callable(self, "_get_ants_in_range"))
				.with_dependency("vision.range")
				.described_as("Ants within vision range")
				.build())
		).with_child(
			(Property.create("count")
				.as_property(Property.Type.INT)
				.with_getter(Callable(self, "_get_ants_in_range_count"))
				.with_dependency("vision.ants.in_range")
				.described_as("Ants within vision range count")
				.build())
		).build())

	# Create foods container with properties
	var foods = (Property.create("foods")
		.as_container()
		.described_as("Properties related to food in vision range")
		.with_child(
			(Property.create("in_range")
				.as_property(Property.Type.FOODS)
				.with_getter(Callable(self, "_get_foods_in_range"))
				.with_dependency("vision.range")
				.described_as("Food items within vision range")
				.build())
		).with_child(
			(Property.create("count")
				.as_property(Property.Type.INT)
				.with_getter(Callable(self, "_get_foods_in_range_count"))
				.with_dependency("vision.foods.in_range")
				.described_as("Food within vision range count")
				.build())
		).with_child(
			(Property.create("mass")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_foods_in_range_mass"))
				.with_dependency("vision.foods.in_range")
				.described_as("Total mass of food within vision range")
				.build())
		).build())

	# Register all properties
	register_property(range_prop)
	register_property(ants)
	register_property(foods)

#endregion

#region Public Methods
func is_within_range(point: Vector2) -> bool:
	return point.distance_to(ant.global_position) <= range
#endregion

#region Private Methods
func _get_range() -> float:
	return range

func _get_ants_in_range() -> Ants:
	return Ants.in_range(ant, range)

func _get_ants_in_range_count() -> int:
	return _get_ants_in_range().size()

func _get_foods_in_range() -> Foods:
	return Foods.in_range(ant.global_position, range, true)

func _get_foods_in_range_mass() -> float:
	return _get_foods_in_range().mass()

func _get_foods_in_range_count() -> int:
	return _get_foods_in_range().size()

func _set_range(value: float) -> void:
	if range != value:
		range = value
#endregion
