class_name Strength 
extends Attribute

var level: int = 10

func _init():
	expose_property("level", 
		func(): return level,
		PropertyType.FLOAT,
		func(v): level = v
	)
	expose_property("carry_max", func(): return carry_max(), PropertyType.FLOAT)
	expose_property("can_carry", 
		func(weight: float): return can_carry(weight),
		PropertyType.BOOL
	)

func carry_max() -> float:
	return 20.0 * level

func can_carry(weight: float) -> bool:
	return weight <= carry_max()
