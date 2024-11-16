class_name Energy
extends PropertyGroup
## Component responsible for managing energy state

#region Signals
## Emitted when energy is completely depleted
signal depleted
#endregion

#region Constants
const DEFAULT_MAX_ENERGY := 100.0
#endregion

#region Member Variables
## Maximum possible energy level
var _max_level: float = DEFAULT_MAX_ENERGY

## Current energy level
var _current_level: float = DEFAULT_MAX_ENERGY
#endregion

func _init(_entity: Node) -> void:
	super._init("energy", _entity)

func _init_properties() -> void:
	_debug("Initializing energy properties...")

	# Create levels container
	var levels_prop = (Property.create("levels")
		.as_container()
		.described_as("Energy level information")
		.with_children([
			Property.create("maximum")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_max_level"))
				.with_setter(Callable(self, "_set_max_level"))
				.described_as("Maximum energy level")
				.build(),
			Property.create("current")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_current_level"))
				.with_setter(Callable(self, "_set_current_level"))
				.described_as("Current energy level")
				.build()
		])
		.build())

	_log_structure(levels_prop, "Created levels container")

	# Create status container
	var status_prop = (Property.create("status")
		.as_container()
		.described_as("Energy status information")
		.with_children([
			Property.create("percentage")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_percentage"))
				.with_dependencies([
					"energy.levels.current",
					"energy.levels.maximum"
				])
				.described_as("Current energy level as a percentage of max energy")
				.build(),
			Property.create("replenishable")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_replenishable_amount"))
				.with_dependencies([
					"energy.levels.current",
					"energy.levels.maximum"
				])
				.described_as("Amount of energy that can be replenished")
				.build(),
			Property.create("is_full")
				.as_property(Property.Type.BOOL)
				.with_getter(Callable(self, "_get_is_full"))
				.with_dependencies([
					"energy.levels.current",
					"energy.levels.maximum"
				])
				.described_as("Whether energy is at maximum level")
				.build(),
			Property.create("is_depleted")
				.as_property(Property.Type.BOOL)
				.with_getter(Callable(self, "_get_is_depleted"))
				.with_dependency("energy.levels.current")
				.described_as("Whether energy is completely depleted")
				.build()
		])
		.build())

	_log_structure(status_prop, "Created status container")

	# Register properties
	_debug("Registering energy.levels property...")
	var result = register_at_path(Path.parse("energy"), levels_prop)
	if not result.success():
		_error("Failed to register energy.levels property: %s" % result.get_error())
		return

	_debug("Registering energy.status property...")
	result = register_at_path(Path.parse("energy"), status_prop)
	if not result.success():
		_error("Failed to register energy.status property: %s" % result.get_error())
		return

	_trace("Successfully initialized all energy properties with structure:")
	_log_structure(_root)

#region Property Getters and Setters
func _get_max_level() -> float:
	return _max_level

func _set_max_level(value: float) -> void:
	if is_zero_approx(value):
		_warn(
			"Attempted to set energy.levels.maximum to zero -> Action not allowed"
		)
		return

	if value < _current_level:
		_set_current_level(value)  # Adjust current level if new max is lower

	var old_value = _max_level
	_max_level = value

	if old_value != _max_level:
		_trace("Maximum energy updated: %.2f -> %.2f" % [old_value, _max_level])

func _get_current_level() -> float:
	return _current_level

func _set_current_level(value: float) -> void:
	var old_value = _current_level
	_current_level = clamp(value, 0.0, _max_level)

	if old_value != _current_level:
		_trace("Current energy updated: %.2f -> %.2f" % [old_value, _current_level])

		if is_zero_approx(_current_level):
			_trace("Energy depleted!")
			depleted.emit()

func _get_percentage() -> float:
	return (_current_level / _max_level) * 100.0

func _get_replenishable_amount() -> float:
	return _max_level - _current_level

func _get_is_full() -> bool:
	return is_equal_approx(_current_level, _max_level)

func _get_is_depleted() -> bool:
	return is_zero_approx(_current_level)
#endregion

#region Public Methods
## Check if energy is at maximum level
func is_full() -> bool:
	return _get_is_full()

## Add energy points, not exceeding maximum
func replenish(amount: float) -> void:
	if amount < 0:
		_error("Cannot replenish negative amount")
		return

	_set_current_level(_current_level + amount)

## Consume energy points, not going below zero
## Returns true if had enough energy to consume
func consume(amount: float) -> bool:
	if amount < 0:
		_error("Cannot consume negative amount")
		return false

	if amount > _current_level:
		return false

	_set_current_level(_current_level - amount)
	return true

## Reset energy to maximum level
func restore_full_energy() -> void:
	_set_current_level(_max_level)
	_trace("Energy restored to maximum")

## Reset energy to default values
func reset() -> void:
	_max_level = DEFAULT_MAX_ENERGY
	_current_level = DEFAULT_MAX_ENERGY
	_trace("Energy reset to default: %.2f/%.2f" % [_current_level, _max_level])
#endregion
