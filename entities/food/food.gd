@icon("res://assets/entities/apple-4967157_640.png")
class_name Food
extends Node2D

var _mass: float

var stored: bool = false
var carried: bool = false
var targeted: bool = false
var is_available: bool : get = _is_available


## The mass of food
var mass: float:
	set(value):
		_mass = max(value, 0.0)
	get:
		return _mass

func _init(initial_mass: float = 5.0) -> void:
	mass = initial_mass
	add_to_group("food")

## Check if there's any food left
func is_depleted() -> bool:
	return is_zero_approx(mass)

func _is_available() -> bool:
	return not carried and not stored and not targeted

## Add food to the existing amount
func add_mass(mass_to_add: float) -> void:
	mass += max(mass_to_add, 0.0)

## Remove food from the existing amount [br][br]
##[b]Parameters[/b]:
##removal_amount: The amount of food to attempt to remove [br]
##[b]Returns[/b]: The actual amount of food removed, which may be less than
## the requested amount if there isn't enough food available
func remove_amount(mass_to_remove: float) -> float:
	var actual_removed = min(mass_to_remove, mass)
	mass -= actual_removed
	return actual_removed
