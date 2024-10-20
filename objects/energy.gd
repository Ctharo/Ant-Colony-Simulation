class_name Energy
extends Node

signal depleted

## The maximum energy level
var max_level: float

## The current energy level
var current_level: float = max_level :
	set(value):
		current_level = max(value, 0.0)
		if is_zero_approx(current_level):
			depleted.emit()

## Get the energy level as a percentage
func energy_percentage() -> float:
	return (current_level / max_level) * 100.0

## Check if energy is critically low
func is_critically_low() -> bool:
	return energy_percentage() < 10.0

## Check if energy is at maximum
func is_full() -> bool:
	return current_level == max_level

## Get the amount of energy that can be replenished
func replenishable_amount() -> float:
	return max_level - current_level
