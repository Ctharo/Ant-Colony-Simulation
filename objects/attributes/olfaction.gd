class_name Olfaction
extends Attribute

var _distance: float

func _init() -> void:
	super._init("Olfaction")

func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("distance")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "distance"))
			.with_setter(Callable(self, "set_distance"))
			.described_as("Maximum distance at which the ant can smell things")
			.build()
	])


func distance() -> float:
	return _distance

func set_distance(value: float) -> void:
	_distance = value

func is_within_range(point: Vector2, from_position: Vector2) -> bool:
	return point.distance_to(from_position) <= _distance
