class_name Speed
extends Node

## The movement rate of the Ant
var movement_rate: float

## The harvesting rate of the Ant
var harvesting_rate: float

## The storing food rate of the Ant
var storing_rate: float

func _init(_movement_rate: float = 1.0, _harvesting_rate: float = 0.5, _storing_rate: float = 10.0):
	movement_rate = _movement_rate
	harvesting_rate = _harvesting_rate
	storing_rate = _storing_rate

## Adjust movement rate
func set_movement_rate(rate: float) -> void:
	movement_rate = max(rate, 0.0)  # Ensure non-negative value

## Adjust harvesting rate
func set_harvesting_rate(rate: float) -> void:
	harvesting_rate = max(rate, 0.0)  # Ensure non-negative value

## Calculate time to move a certain distance
func time_to_move(distance: float) -> float:
	return distance / movement_rate if movement_rate > 0 else INF

## Calculate amount that can be harvested in a given time
func harvest_amount(time: float) -> float:
	return harvesting_rate * time
