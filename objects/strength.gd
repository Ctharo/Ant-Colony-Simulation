class_name Strength 
extends Attribute

var level: int = 10

func _ready():
	expose_property("level", 
		func(): return level,
		func(v): level = v
	)
	expose_property("carry_max", func(): return carry_max())
	expose_property("can_carry", 
		func(weight: float): return can_carry(weight)
	)

func carry_max() -> float:
	return 20.0 * level

func can_carry(weight: float) -> bool:
	return weight <= carry_max()
