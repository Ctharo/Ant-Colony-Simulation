class_name Energy
extends Attribute

signal depleted

const MAX_LEVEL: float = 100.0
var _low_energy_threshold = 20.0
## Current level of energy
var _current_level: float = MAX_LEVEL : get = get_current_level, set = set_current_level

func _init() -> void:
	super._init("Energy")
	
func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("max_level")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "max_level"))
			.described_as("Maximum energy level the ant can have")
			.build(),
			
		PropertyResult.PropertyInfo.create("current_level")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "get_current_level"))
			.with_setter(Callable(self, "set_current_level"))
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
			.build(),
			
		PropertyResult.PropertyInfo.create("low_energy_threshold")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "replenishable_amount"))
			.described_as("Amount of energy that can be replenished before reaching max")
			.build()
	])

## Calculate energy level as a percentage of maximum
func percentage() -> float:
	return (_current_level / MAX_LEVEL) * 100.0

func get_current_level() ->float:
	return _current_level
	
func set_current_level(value: float) -> void:
	_current_level = max(value, 0.0)
	if is_zero_approx(_current_level):
		depleted.emit()

func low_energy_threshold() -> float:
	return _low_energy_threshold

func max_level() ->float:
	return MAX_LEVEL

## Check if energy is below critical threshold
func is_critically_low() -> bool:
	return percentage() < _low_energy_threshold

## Check if energy is at maximum level
func is_full() -> bool:
	return _current_level == MAX_LEVEL

## Calculate how much energy can be replenished
func replenishable_amount() -> float:
	return MAX_LEVEL - _current_level
