class_name Strength 
extends Attribute

var _level: int = 10

func _init() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("level")
			.of_type(PropertyType.INT)
			.with_getter(Callable(self, "level"))
			.with_setter(Callable(self, "set_level"))
			.described_as("Base strength level of the ant")
			.build(),
			
		PropertyResult.PropertyInfo.create("carry_max")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "carry_max"))
			.described_as("Maximum weight the ant can carry based on strength level")
			.build()
	])

func level() -> int:
	return _level

func set_level(value: int) -> void:
	_level = value

func carry_max() -> float:
	return 20.0 * _level

func can_carry(weight: float) -> bool:
	return weight <= carry_max()
