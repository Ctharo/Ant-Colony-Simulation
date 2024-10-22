class_name Strength
extends Node

## The strength level of the entity
var level: int = 10

## Calculate the maximum carry capacity based on strength
func carry_max() -> float:
	return 20.0 * level

## Check if the entity can carry a given weight
func can_carry(weight: float) -> bool:
	return weight <= carry_max()
