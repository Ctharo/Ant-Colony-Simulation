class_name Energy
extends Attribute

#region Signals
signal depleted
#endregion

#region Properties
## Maximum level of energy
var max_level: float = 100.0 : get = _get_max_level, set = _set_max_level

## Current level of energy
var current_level: float = max_level : get = _get_current_level, set = _set_current_level

var percentage: float : get = _get_percentage
var replenishable_amount: float : get = _get_replenishable_amount
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init(_ant, "Energy")
	
func _init_properties() -> void:
	properties_container.expose_properties([
		PropertyResult.PropertyInfo.create("max_level")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_max_level"))
			.with_setter(Callable(self, "_set_max_level"))
			.described_as("Maximum energy level the ant can have")
			.build(),
			
		PropertyResult.PropertyInfo.create("current_level")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_current_level"))
			.with_setter(Callable(self, "_set_current_level"))
			.described_as("Current energy level of the ant")
			.build(),
			
		PropertyResult.PropertyInfo.create("percentage")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_percentage"))
			.described_as("Current energy level as a percentage of max energy")
			.build(),
		
		PropertyResult.PropertyInfo.create("replenishable_amount")
			.of_type(PropertyType.FLOAT)
			.with_getter(Callable(self, "_get_replenishable_amount"))
			.described_as("Amount of energy that can be replenished before reaching max")
			.build()
	])
#endregion

#region Public Methods
## Check if energy is at maximum level
func is_full() -> bool:
	return is_equal_approx(current_level, max_level)
#endregion

#region Private Methods
func _get_current_level() ->float:
	return current_level
	
func _set_current_level(value: float) -> void:
	if current_level != value:
		current_level = max(value, 0.0)
		if is_zero_approx(current_level):
			depleted.emit()

func _get_max_level() -> float:
	return max_level

func _set_max_level(value) -> void:
	if is_zero_approx(value):
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "Attempted to set energy.max_level to zero -> Action not allowed")
		return
	if max_level != value:
		max_level = value

## Calculate energy level as a percentage of maximum
func _get_percentage() -> float:
	return (current_level / max_level) * 100.0

## Calculate how much energy can be replenished
func _get_replenishable_amount() -> float:
	return max_level - current_level
#endregion
