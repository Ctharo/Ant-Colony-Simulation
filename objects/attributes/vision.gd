class_name Vision
extends Attribute

#region Properties
## Maximum range at which the ant can see
var range: float = 50.0 : set = _set_range, get = _get_range
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init("Vision", _ant)

func _init_properties() -> void:
	_properties_container.expose_properties([
		Property.create("range")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range at which the ant can see")
			.build(),
		Property.create("ants_in_range")
			.of_type(Property.Type.ANTS)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_ants_in_range"))
			.with_dependencies(["vision.range"])  # Depends on range property
			.described_as("Ants within vision range")
			.build(),
		Property.create("foods_in_range")
			.of_type(Property.Type.ANTS)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_foods_in_range"))
			.with_dependencies(["vision.range"])  # Depends on range property
			.described_as("Food items within vision range")
			.build(),
		Property.create("foods_in_range_mass")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_dependencies(["foods_in_range"])
			.with_getter(Callable(self, "_get_foods_in_range_mass"))
			.described_as("Food within reach range mass")
			.build(),
		Property.create("foods_in_range_count")
			.of_type(Property.Type.INT)
			.with_attribute(name)
			.with_dependencies(["foods_in_range"])
			.with_getter(Callable(self, "_get_foods_in_range_count"))
			.described_as("Food within vision range count")
			.build(),
		Property.create("ants_in_range_count")
			.of_type(Property.Type.INT)
			.with_attribute(name)
			.with_dependencies(["ants_in_range"])
			.with_getter(Callable(self, "_get_ants_in_range_count"))
			.described_as("Ants within vision range count")
			.build(),

	])
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
