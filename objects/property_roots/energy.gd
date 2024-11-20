class_name Energy
extends PropertyNode
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
	# First create self as container
	super._init("energy", Type.CONTAINER, _entity)

	# Then build and copy children
	var tree = PropertyNode.create_tree(_entity)\
		.container("levels", "Energy level information")\
			.value("maximum", Property.Type.FLOAT,
				Callable(self, "_get_max_level"),
				Callable(self, "_set_max_level"),
				[],
				"Maximum energy level")\
			.value("current", Property.Type.FLOAT,
				Callable(self, "_get_current_level"),
				Callable(self, "_set_current_level"),
				[],
				"Current energy level")\
		.up()\
		.container("status", "Energy status information")\
			.value("percentage", Property.Type.FLOAT,
				Callable(self, "_get_percentage"),
				Callable(),
				["energy.levels.current", "energy.levels.maximum"],
				"Current energy level as a percentage of max energy")\
			.value("replenishable", Property.Type.FLOAT,
				Callable(self, "_get_replenishable_amount"),
				Callable(),
				["energy.levels.current", "energy.levels.maximum"],
				"Amount of energy that can be replenished")\
			.value("is_full", Property.Type.BOOL,
				Callable(self, "_get_is_full"),
				Callable(),
				["energy.levels.current", "energy.levels.maximum"],
				"Whether energy is at maximum level")\
			.value("is_depleted", Property.Type.BOOL,
				Callable(self, "_get_is_depleted"),
				Callable(),
				["energy.levels.current"],
				"Whether energy is completely depleted")\
		.build()

	# Copy children from built tree
	for child in tree.children.values():
		add_child(child)

	_trace("Energy property tree initialized")

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
