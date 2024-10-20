class_name Vision
extends Node

## The vision distance of the entity
var distance: float

## Check if a point is within vision
func is_within_vision(point: Vector2, from_position: Vector2) -> bool:
	return point.distance_to(from_position) <= distance
