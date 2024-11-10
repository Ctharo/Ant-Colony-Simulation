class_name Health
extends Attribute

#region Signals
signal depleted
#endregion

#region Properties
var max_level: float = 100.0 : get = _get_max_level, set = _set_max_level

## Current level of health
var current_level: float = max_level : get = _get_current_level, set = _set_current_level

## Health as a value out of 100
var percentage: float : get = _get_percentage

## Amount missing from full health
var replenishable_amount: float : get = _get_replenishable_amount
#endregion

#region Lifecycle Methods
func _init(_ant: Ant) -> void:
	super._init("Health", _ant)

func _init_properties() -> void:
	_properties_container.expose_properties([
		Property.create("max_level")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_max_level"))
			.described_as("Maximum health level the ant can have")
			.build(),

		Property.create("current_level")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_current_level"))
			.with_setter(Callable(self, "_set_current_level"))
			.described_as("Current health level of the ant")
			.build(),

		Property.create("percentage")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_percentage"))
			.described_as("Current health level as a percentage of max health")
			.build(),

		Property.create("replenishable_amount")
			.of_type(Property.Type.FLOAT)
			.with_attribute(name)
			.with_getter(Callable(self, "_get_replenishable_amount"))
			.described_as("Amount of health that can be restored before reaching max")
			.build()
	])
#endregion

#region Public Methods
## Check if health is at maximum level
func is_full() -> bool:
	return is_equal_approx(current_level, max_level)
#endregion

#region Private Methods
func _get_max_level() -> float:
	return max_level

func _set_max_level(value) -> void:
	if is_zero_approx(value):
		DebugLogger.warn(DebugLogger.Category.PROPERTY, "Attempted to set health.max_level to zero -> Action not allowed")
		return
	if max_level != value:
		max_level = value

func _get_current_level() -> float:
	return current_level

func _set_current_level(value: float) -> void:
	if current_level != value:
		current_level = max(value, 0.0)
		if is_zero_approx(current_level):
			depleted.emit()

func _get_percentage() -> float:
	return (current_level / max_level) * 100.0

func _get_replenishable_amount() -> float:
	return max_level - current_level
#endregion
