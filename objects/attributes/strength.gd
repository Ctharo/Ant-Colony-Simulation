class_name Strength
extends Attribute

#region Properties
## Base strength level of the ant
var level: int = 10 : get = _get_level, set = _set_level

## Maximum number of units the ant can carry at a time
var carry_max: float : get = _get_carry_max

## Mass carryable ([member carry_max]) is equal to [member level] * [member strength_factor]
const STRENGTH_FACTOR: float = 20.0
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init("Strength", _ant)

func _init_properties() -> void:
	_properties_container.expose_properties([
		Property.create("level")
			.of_type(Property.Type.INT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_level"))
			.with_setter(Callable(self, "_set_level"))
			.described_as("Base strength level of the ant")
			.build(),

		Property.create("carry_max")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_carry_max"))
			.described_as("Maximum weight the ant can carry based on strength level")
			.build()
	])
#endregion

#region Public Methods
func can_carry(weight: float) -> bool:
	return weight <= carry_max
#endregion

#region Private Methods
func _get_level() -> int:
	return level

func _set_level(value: int) -> void:
	level = value

func _get_carry_max() -> float:
	return STRENGTH_FACTOR * level
#endregion
