class_name Energy
extends Attribute

signal depleted

var max_level: float = 100.0
var low_energy_threshold = 20.0
var current_level: float = max_level :
	set(value):
		current_level = max(value, 0.0)
		if is_zero_approx(current_level):
			depleted.emit()

func _ready():
	expose_property("max_level", 
		func(): return max_level,
		func(v): max_level = v
	)
	expose_property("current_level", 
		func(): return current_level,
		func(v): current_level = v
	)
	expose_property("percentage", func(): return percentage())
	expose_property("is_critically_low", func(): return is_critically_low())
	expose_property("is_full", func(): return is_full())
	expose_property("replenishable_amount", func(): return replenishable_amount())

func percentage() -> float:
	return (current_level / max_level) * 100.0

func is_critically_low() -> bool:
	return percentage() < low_energy_threshold

func is_full() -> bool:
	return current_level == max_level

func replenishable_amount() -> float:
	return max_level - current_level
