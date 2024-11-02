class_name Vision
extends Attribute

var distance: float

func _init():
	expose_property("distance", 
		func(): return distance,
		PropertyType.FLOAT,
		func(v): distance = v
	)
	expose_property("is_within_vision", 
		func(point: Vector2, from_position: Vector2): return is_within_vision(point, from_position),
		PropertyType.BOOL
	)

func is_within_vision(point: Vector2, from_position: Vector2) -> bool:
	return point.distance_to(from_position) <= distance
