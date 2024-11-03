class_name Strength 
extends Attribute

var _level: int = 10

func _init() -> void:
	expose_property(
		"level",
		Callable(self, "level"),
		PropertyType.INT,
		Callable(self, "set_level"),
		"Base strength level of the ant"
	)
	
	expose_property(
		"carry_max",
		Callable(self, "carry_max"),
		PropertyType.FLOAT,
		Callable(),
		"Maximum weight the ant can carry based on strength level"
	)

func level() -> int:
	return _level

func set_level(value: int) -> void:
	_level = value

func carry_max() -> float:
	return 20.0 * _level

func can_carry(weight: float) -> bool:
	return weight <= carry_max()
