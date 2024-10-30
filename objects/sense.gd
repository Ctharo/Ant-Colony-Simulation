class_name Sense
extends Attribute

var distance: float

func _ready():
	expose_property("distance", 
		func(): return distance,
		func(v): distance = v
	)
	expose_property("is_within_range", 
		func(point: Vector2, from_position: Vector2): return is_within_range(point, from_position)
	)

func is_within_range(point: Vector2, from_position: Vector2) -> bool:
	return point.distance_to(from_position) <= distance
