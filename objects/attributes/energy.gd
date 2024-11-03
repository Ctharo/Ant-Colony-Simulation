class_name Energy
extends Attribute

signal depleted

var _max_level: float = 100.0
var _low_energy_threshold = 20.0
var _current_level: float = _max_level :
	set(value):
		_current_level = max(value, 0.0)
		if is_zero_approx(_current_level):
			depleted.emit()

func _init() -> void:
	expose_property(
		"max_level",
		Callable(self, "max_level"),
		PropertyType.FLOAT,
		func(v): _max_level = v,
		"Maximum energy level the ant can have"
	)
	
	expose_property(
		"current_level",
		Callable(self, "current_level"),
		PropertyType.FLOAT,
		func(v): _current_level = v,
		"Current energy level of the ant"
	)
	
	expose_property(
		"percentage",
		Callable(self, "percentage"),
		PropertyType.FLOAT,
		Callable(),
		"Current energy level as a percentage of max energy"
	)
	
	expose_property(
		"is_critically_low",
		Callable(self, "is_critically_low"),
		PropertyType.BOOL,
		Callable(),
		"Whether energy is below critical threshold"
	)
	
	expose_property(
		"is_full",
		Callable(self, "is_full"),
		PropertyType.BOOL,
		Callable(),
		"Whether energy is at maximum level"
	)
	
	expose_property(
		"replenishable_amount",
		Callable(self, "replenishable_amount"),
		PropertyType.FLOAT,
		Callable(),
		"Amount of energy that can be replenished before reaching max"
	)

## Calculate energy level as a percentage of maximum
func percentage() -> float:
	return (_current_level / _max_level) * 100.0

func current_level() ->float:
	return _current_level

func max_level() ->float:
	return _max_level

## Check if energy is below critical threshold
func is_critically_low() -> bool:
	return percentage() < _low_energy_threshold

## Check if energy is at maximum level
func is_full() -> bool:
	return current_level == max_level

## Calculate how much energy can be replenished
func replenishable_amount() -> float:
	return _max_level - _current_level
