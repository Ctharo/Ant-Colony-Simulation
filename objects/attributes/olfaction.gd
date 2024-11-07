class_name Olfaction
extends Attribute

#region Properties
## Max range at which the ant can sense scents
var range: float = 100.0 : get = _get_range, set = _set_range 
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init(_ant, "Olfaction")

func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("range")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range at which the ant can smell things")
			.build()
	])
#endregion

#region Public Methods
## Determines if the point is within the maximum range of smell
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
