class_name Health
extends Node

signal depleted

## The maximum health level
var max_level: float = 100.0

## The current health level
var current_level: float = max_level :
	set(value):
		current_level = max(value, 0.0)
		if is_zero_approx(current_level):
			depleted.emit()

## Get the health level as a percentage
func health_percentage() -> float:
	return (current_level / max_level) * 100.0

## Check if health is critically low
func is_critically_low() -> bool:
	return health_percentage() < 20.0

## Check if health is at maximum
func is_full() -> bool:
	return is_equal_approx(current_level, max_level)

## Get the amount of health that can be restored
func restorable_amount() -> float:
	return max_level - current_level
