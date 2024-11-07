class_name Reach
extends Attribute

#region Properties
## Maximum range the ant can reach
var range: float = 15.0 : get = _get_range, set = _set_range 
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init(_ant, "Reach")

func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("range")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range the ant can reach from its current position")
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
