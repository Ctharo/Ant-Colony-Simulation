class_name Health
extends PropertyGroup
## Component responsible for managing ant's health state

#region Signals
## Emitted when health reaches zero
signal depleted
#endregion

#region Constants
const DEFAULT_MAX_HEALTH := 100.0
#endregion

#region Member Variables
## Maximum possible health level
var _max_level: float = DEFAULT_MAX_HEALTH

## Current health level
var _current_level: float = DEFAULT_MAX_HEALTH
#endregion

func _init(_ant: Ant) -> void:
	super._init("health", _ant)

## Initialize all properties for the Health component
func _init_properties() -> void:
	# Create levels container with health level properties
	var levels_prop = (Property.create("levels")
		.as_container()
		.described_as("Health level information")
		.with_children([
			Property.create("maximum")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_max_level"))
				.with_setter(Callable(self, "_set_max_level"))
				.described_as("Maximum health level the ant can have")
				.build(),

			Property.create("current")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_current_level"))
				.with_setter(Callable(self, "_set_current_level"))
				.described_as("Current health level of the ant")
				.build()
		])
		.build())

	# Create status container with computed health properties
	var status_prop = (Property.create("status")
		.as_container()
		.described_as("Health status information")
		.with_children([
			Property.create("percentage")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_percentage"))
				.with_dependencies([
					"health.levels.current",
					"health.levels.maximum"
				])
				.described_as("Current health level as a percentage of max health")
				.build(),

			Property.create("replenishable")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_replenishable_amount"))
				.with_dependencies([
					"health.levels.current",
					"health.levels.maximum"
				])
				.described_as("Amount of health that can be restored")
				.build(),

			Property.create("is_full")
				.as_property(Property.Type.BOOL)
				.with_getter(Callable(self, "_get_is_full"))
				.with_dependencies([
					"health.levels.current",
					"health.levels.maximum"
				])
				.described_as("Whether health is at maximum level")
				.build()
		])
		.build())

	# Register properties with error handling
	var result = register_at_path(Path.parse("health"), levels_prop)
	if not result.success():
		_error("Failed to register health.levels property: %s" % result.get_error())
		return

	result = register_at_path(Path.parse("health"), status_prop)
	if not result.success():
		_error("Failed to register health.status property: %s" % result.get_error())
		return


#region Property Getters and Setters
func _get_max_level() -> float:
	return _max_level

func _set_max_level(value: float) -> void:
	if is_zero_approx(value):
		_warn(
			"Attempted to set health.levels.maximum to zero -> Action not allowed"
		)
		return

	if value < _current_level:
		_set_current_level(value)  # Adjust current level if new max is lower

	var old_value = _max_level
	_max_level = value

	if old_value != _max_level:
		_trace("Maximum health updated: %.2f -> %.2f" % [old_value, _max_level])

func _get_current_level() -> float:
	return _current_level

func _set_current_level(value: float) -> void:
	var old_value = _current_level
	_current_level = clamp(value, 0.0, _max_level)

	if old_value != _current_level:
		_trace("Current health updated: %.2f -> %.2f" % [old_value, _current_level])

		if is_zero_approx(_current_level):
			_trace("Health depleted!")
			depleted.emit()

func _get_percentage() -> float:
	return (_current_level / _max_level) * 100.0

func _get_replenishable_amount() -> float:
	return _max_level - _current_level

func _get_is_full() -> bool:
	return is_equal_approx(_current_level, _max_level)
#endregion

#region Public Methods
## Check if health is at maximum level
func is_full() -> bool:
	return _get_is_full()

## Add health points, not exceeding maximum
func heal(amount: float) -> void:
	if amount < 0:
		_error("Cannot heal negative amount")
		return

	_set_current_level(_current_level + amount)

## Subtract health points, not going below zero
func damage(amount: float) -> void:
	if amount < 0:
		_error("Cannot damage negative amount")
		return

	_set_current_level(_current_level - amount)

## Reset health to maximum level
func restore_full_health() -> void:
	_set_current_level(_max_level)
	_trace("Health restored to maximum")

## Reset health to default values
func reset() -> void:
	_max_level = DEFAULT_MAX_HEALTH
	_current_level = DEFAULT_MAX_HEALTH
	_trace("Health reset to default: %.2f/%.2f" % [_current_level, _max_level])
#endregion
