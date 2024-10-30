class_name Health
extends Attribute

signal depleted

var max_level: float = 100.0
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
	expose_property("percentage", func(): return health_percentage())
	expose_property("is_critically_low", func(): return is_critically_low())
	expose_property("is_full", func(): return is_full())
	expose_property("restorable_amount", func(): return restorable_amount())

func health_percentage() -> float:
	return (current_level / max_level) * 100.0

func is_critically_low() -> bool:
	return health_percentage() < 20.0

func is_full() -> bool:
	return is_equal_approx(current_level, max_level)

func restorable_amount() -> float:
	return max_level - current_level
