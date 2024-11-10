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
			.build()
	])
	_properties_container.expose_properties([
		Property.create("food_in_range")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_dependencies(["range"])
			.with_getter(Callable(self, "_get_food_in_range"))
			.described_as("Food within reach range")
			.build()
	])
#endregion

#region Public Methods
func is_within_range(point: Vector2) -> bool:
	return point.distance_to(ant.global_position) <= range
#endregion

#region Private Methods
func _get_range() -> float:
	return range

func _get_food_in_range() -> Foods:
	return Foods.in_reach(ant.global_position, range)

func _get_food_in_range_count() -> int:
	return _get_food_in_range().size()

func _set_range(value: float) -> void:
	if range != value:
		range = value
#endregion
