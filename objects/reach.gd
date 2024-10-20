class_name Reach
extends Node

## The reach distance of the entity
var distance: float

## Check if a point is within reach
func is_within_range(point: Vector2, from_position: Vector2) -> bool:
	return point.distance_to(from_position) <= distance
