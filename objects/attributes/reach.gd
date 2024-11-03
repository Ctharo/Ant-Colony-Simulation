class_name Reach
extends Attribute

var _distance: float

func _init() -> void:
	expose_property(
		"distance",
		Callable(self, "distance"),
		PropertyType.FLOAT,
		Callable(self, "set_distance"),
		"Maximum distance the ant can reach from its current position"
	)
	
func distance() -> float:
	return _distance

func set_distance(value: float) -> void:
	if _distance != value:
		_distance = value

func is_within_range(point: Vector2, from_position: Vector2) -> bool:
	return point.distance_to(from_position) <= _distance
