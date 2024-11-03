class_name Vision
extends Attribute

var _distance: float

func _init() -> void:
	expose_property(
		"distance",
		Callable(self, "distance"),
		PropertyType.FLOAT,
		Callable(self, "set_distance"),
		"Maximum distance at which the ant can see"
	)

func distance() -> float:
	return _distance

func set_distance(value: float) -> void:
	_distance = value

func is_within_vision(point: Vector2, from_position: Vector2) -> bool:
	return point.distance_to(from_position) <= _distance
