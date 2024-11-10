class_name Reach
extends Attribute

#region Properties
## Maximum range the ant can reach
var range: float = 15.0 : get = _get_range, set = _set_range
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init("Reach", _ant)

func _init_properties() -> void:
	_properties_container.expose_properties([
		Property.create("range")
			.of_type(Property.Type.FLOAT)
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range the ant can reach from its current position")
			.build(),
		Property.create("foods_in_range")
			.of_type(Property.Type.FOODS)
			.with_attribute(name)
			.with_dependencies(["range", "proprioception.position"])
			.with_getter(Callable(self, "_get_foods_in_range"))
			.described_as("Food within reach range")
			.build(),
		Property.create("foods_in_range_count")
			.of_type(Property.Type.INT)
			.with_attribute(name)
			.with_dependencies(["foods_in_range"])
			.with_getter(Callable(self, "_get_foods_in_range_count"))
			.described_as("Food within reach range count")
			.build(),
		Property.create("ants_in_range")
			.of_type(Property.Type.ANTS)
			.with_attribute(name)
			.with_dependencies(["range", "proprioception.position"])
			.with_getter(Callable(self, "_get_ants_in_range"))
			.described_as("Ants within reach range")
			.build(),
		Property.create("ants_in_range_count")
			.of_type(Property.Type.INT)
			.with_attribute(name)
			.with_dependencies(["ants_in_range"])
			.with_getter(Callable(self, "_get_ants_in_range_count"))
			.described_as("Ants within reach range count")
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

func _get_foods_in_range() -> Foods:
	return Foods.in_range(ant.global_position, range, true)

func _get_foods_in_range_count() -> int:
	return _get_foods_in_range().size()

func _get_ants_in_range() -> Ants:
	return Ants.in_range(ant, range)

func _get_ants_in_range_count() -> int:
	return _get_ants_in_range().size()

func _set_range(value: float) -> void:
	if range != value:
		range = value
#endregion
