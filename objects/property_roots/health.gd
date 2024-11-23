class_name Health
extends PropertyNode
## Component responsible for managing health state

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

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("health", Type.CONTAINER, _entity)

	# Create the tree with the container name matching self
	var tree = PropertyNode.create_tree(_entity)\
		.container("health", "Health management")\
			.container("capacity", "Health capacity information")\
				.value("max", Property.Type.FLOAT,
					Callable(self, "_get_max_level"),
					Callable(self, "_set_max_level"),
					[],
					"Maximum health level")\
				.value("current", Property.Type.FLOAT,
					Callable(self, "_get_current_level"),
					Callable(self, "_set_current_level"),
					[],
					"Current health level")\
				.value("percentage", Property.Type.FLOAT,
					Callable(self, "_get_percentage"),
					Callable(),
					["health.capacity.current", "health.capacity.max"],
					"Current health level as a percentage of max health")\
			.up()\
			.container("status", "Health status information")\
				.value("replenishable", Property.Type.FLOAT,
					Callable(self, "_get_replenishable_amount"),
					Callable(),
					["health.capacity.current", "health.capacity.max"],
					"Amount of health that can be restored")\
				.value("is_full", Property.Type.BOOL,
					Callable(self, "_get_is_full"),
					Callable(),
					["health.capacity.current", "health.capacity.max"],
					"Whether health is at maximum level")\
			.up()\
		.build()

	# Copy the container children from the built tree's root health node
	var built_health = tree
	for child in built_health.children.values():
		add_child(child)

	_trace("Health property tree initialized")

#region Property Getters and Setters
func _get_max_level() -> float:
	return _max_level

func _set_max_level(value: float) -> void:
	if is_zero_approx(value):
		_warn(
			"Attempted to set health.capacity.max to zero -> Action not allowed"
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
