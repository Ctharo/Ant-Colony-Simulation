class_name Speed
extends PropertyNode
## Component responsible for managing entity movement and action rates

#region Constants
const DEFAULT_RATE := 1.0
#endregion

#region Member Variables
## Rate at which the entity can move (units/second)
var _movement_rate: float = DEFAULT_RATE

## Rate at which the entity can harvest resources (units/second)
var _harvesting_rate: float = DEFAULT_RATE

## Rate at which the entity can store resources (units/second)
var _storing_rate: float = DEFAULT_RATE
#endregion

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("speed", Type.CONTAINER, _entity)

	# Then build and copy children
	var tree = PropertyNode.create_tree(_entity)\
		.container("rates", "Various speed rates for entity activities")\
			.value("movement", Property.Type.FLOAT,
				Callable(self, "_get_movement_rate"),
				Callable(self, "_set_movement_rate"),
				[],
				"Rate at which the entity can move (units/second)")\
			.value("harvesting", Property.Type.FLOAT,
				Callable(self, "_get_harvesting_rate"),
				Callable(self, "_set_harvesting_rate"),
				[],
				"Rate at which the entity can harvest resources (units/second)")\
			.value("storing", Property.Type.FLOAT,
				Callable(self, "_get_storing_rate"),
				Callable(self, "_set_storing_rate"),
				[],
				"Rate at which the entity can store resources (units/second)")\
		.up()\
		.container("calculators", "Helper properties for speed-based calculations")\
			.value("time_to_move", Property.Type.FLOAT,
				Callable(self, "_get_time_to_move"),
				Callable(),
				["speed.rates.movement"],
				"Time required to move one unit of distance")\
			.value("harvest_per_second", Property.Type.FLOAT,
				Callable(self, "_get_harvest_per_second"),
				Callable(),
				["speed.rates.harvesting"],
				"Amount that can be harvested in one second")\
		.build()

	# Copy children from built tree
	for child in tree.children.values():
		add_child(child)

	_trace("Speed property tree initialized")

#region Property Getters and Setters
func _get_movement_rate() -> float:
	return _movement_rate

func _set_movement_rate(rate: float) -> void:
	if is_zero_approx(rate):
		_warn(
			"Attempted to set speed.rates.movement to zero -> Action not allowed"
		)
		return

	var old_rate = _movement_rate
	_movement_rate = max(rate, 0.0)

	if old_rate != _movement_rate:
		_trace("Movement rate updated: %.2f -> %.2f" % [old_rate, _movement_rate])

func _get_harvesting_rate() -> float:
	return _harvesting_rate

func _set_harvesting_rate(rate: float) -> void:
	if is_zero_approx(rate):
		_warn("Attempted to set speed.rates.harvesting to zero -> Action not allowed")
		return

	var old_rate = _harvesting_rate
	_harvesting_rate = max(rate, 0.0)

	if old_rate != _harvesting_rate:
		_trace("Harvesting rate updated: %.2f -> %.2f" % [old_rate, _harvesting_rate])

func _get_storing_rate() -> float:
	return _storing_rate

func _set_storing_rate(rate: float) -> void:
	if is_zero_approx(rate):
		_warn("Attempted to set speed.rates.storing to zero -> Action not allowed")
		return

	var old_rate = _storing_rate
	_storing_rate = max(rate, 0.0)

	if old_rate != _storing_rate:
		_trace("Storing rate updated: %.2f -> %.2f" % [old_rate, _storing_rate])

func _get_time_to_move() -> float:
	return 1.0 / _movement_rate if _movement_rate > 0 else INF

func _get_harvest_per_second() -> float:
	return _harvesting_rate
#endregion

#region Public Methods
## Calculate time required to move a given distance
func time_to_move(distance: float) -> float:
	if distance < 0:
		_error("Cannot calculate time for negative distance")
		return INF

	return distance / _movement_rate if _movement_rate > 0 else INF

## Calculate amount that can be harvested in a given time period
func harvest_amount(time: float) -> float:
	if time < 0:
		_error("Cannot calculate harvest amount for negative time")
		return 0.0

	return _harvesting_rate * time

## Reset all rates to their default values
func reset() -> void:
	_set_movement_rate(DEFAULT_RATE)
	_set_harvesting_rate(DEFAULT_RATE)
	_set_storing_rate(DEFAULT_RATE)
	_trace("All rates reset to default: %.2f" % DEFAULT_RATE)
#endregion
