class_name Energy
extends Node

signal depleted

## The maximum energy level
var max_level: float = 100.0

var low_energy_threshold = 20.0

## The current energy level
var current_level: float = max_level :
	set(value):
		current_level = max(value, 0.0)
		if is_zero_approx(current_level):
			depleted.emit()

## Get the energy level as a percentage
func percentage() -> float:
	return (current_level / max_level) * 100.0

## Check if energy is critically low
func is_critically_low() -> bool:
	return percentage() < low_energy_threshold

## Check if energy is at maximum
func is_full() -> bool:
	return current_level == max_level

## Get the amount of energy that can be replenished
func replenishable_amount() -> float:
	return max_level - current_level
