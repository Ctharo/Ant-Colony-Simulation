class_name Reach
extends Attribute

var distance: float:
	set(value):
		if distance != value:
			distance = value

func _ready():
	# Expose distance with getter/setter
	expose_property("distance", 
		func(): return distance,
		func(v): distance = v
	)
	
	# Expose is_within_range as read-only method
	expose_property("is_within_range",
		func(point: Vector2, from_position: Vector2) -> bool:
			return point.distance_to(from_position) <= distance
	)

func is_within_range(point: Vector2, from_position: Vector2) -> bool:
	return point.distance_to(from_position) <= distance
