class_name Vision
extends Attribute

#region Properties
## Maximum range at which the ant can see
var range: float = 50.0 : set = _set_range, get = _get_range
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init(_ant, "Vision")

func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("range")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range at which the ant can see")
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

func _set_range(value: float) -> void:
	if range != value:
		range = value
#endregion
