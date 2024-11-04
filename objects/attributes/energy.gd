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
	super._init("Energy")
	
func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("max_level")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "max_level"))
			.with_setter(func(v): _max_level = v)
			.described_as("Maximum energy level the ant can have")
			.build(),
			
		PropertyResult.PropertyInfo.create("current_level")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "current_level"))
			.with_setter(func(v): _current_level = v)
			.described_as("Current energy level of the ant")
			.build(),
			
		PropertyResult.PropertyInfo.create("percentage")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "percentage"))
			.described_as("Current energy level as a percentage of max energy")
			.build(),
		
		PropertyResult.PropertyInfo.create("replenishable_amount")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "replenishable_amount"))
			.described_as("Amount of energy that can be replenished before reaching max")
			.build()
	])

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
