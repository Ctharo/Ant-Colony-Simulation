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
			.with_getter(Callable(self, "_get_range"))
			.with_setter(Callable(self, "_set_range"))
			.described_as("Maximum range at which the ant can see")
			.build(),
		Property.create("ants_in_range")
			.of_type(Property.Type.ANTS)
			.with_getter(Callable(self, "_get_ants_in_range"))
			.with_dependencies(["vision.range"])  # Depends on range property
			.described_as("Ants within vision range")
			.build(),
		Property.create("foods_in_range")
			.of_type(Property.Type.ANTS)
			.with_getter(Callable(self, "_get_foods_in_range"))
			.with_dependencies(["vision.range"])  # Depends on range property
			.described_as("Food items within vision range")
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

#TODO Implement
func _get_ants_in_range() -> Ants:
	return Ants.new([])

#TODO Implement
func _get_foods_in_range() -> Foods:
	return Foods.new([])

func _set_range(value: float) -> void:
	if range != value:
		range = value
#endregion
