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

@export var config: SpeedResource
#endregion

func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("speed", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = SpeedResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Speed property tree initialized")

#region Property Getters and Setters
func _get_movement_rate() -> float:
	return _movement_rate

func _set_movement_rate(rate: float) -> void:
	if is_zero_approx(rate):
		logger.warn(
			"Attempted to set speed.base.movement to zero -> Action not allowed"
		)
		return

	var old_rate = _movement_rate
	_movement_rate = max(rate, 0.0)

	if old_rate != _movement_rate:
		logger.trace("Movement rate updated: %.2f -> %.2f" % [old_rate, _movement_rate])

func _get_harvesting_rate() -> float:
	return _harvesting_rate

func _set_harvesting_rate(rate: float) -> void:
	if is_zero_approx(rate):
		logger.warn("Attempted to set speed.base.harvesting to zero -> Action not allowed")
		return

	var old_rate = _harvesting_rate
	_harvesting_rate = max(rate, 0.0)

	if old_rate != _harvesting_rate:
		logger.trace("Harvesting rate updated: %.2f -> %.2f" % [old_rate, _harvesting_rate])

func _get_storing_rate() -> float:
	return _storing_rate

func _set_storing_rate(rate: float) -> void:
	if is_zero_approx(rate):
		logger.warn("Attempted to set speed.base.storing to zero -> Action not allowed")
		return

	var old_rate = _storing_rate
	_storing_rate = max(rate, 0.0)

	if old_rate != _storing_rate:
		logger.trace("Storing rate updated: %.2f -> %.2f" % [old_rate, _storing_rate])

func _get_time_per_unit() -> float:
	return 1.0 / _movement_rate if _movement_rate > 0 else INF

func _get_harvest_per_second() -> float:
	return _harvesting_rate

func _can_move() -> bool:
	return _movement_rate > 0.0

func _can_harvest() -> bool:
	return _harvesting_rate > 0.0

func _can_store() -> bool:
	return _storing_rate > 0.0
#endregion

#region Public Methods
## Calculate time required to move a given distance
func time_to_move(distance: float) -> float:
	if distance < 0:
		logger.error("Cannot calculate time for negative distance")
		return INF
	return distance / _movement_rate if _movement_rate > 0 else INF

## Calculate amount that can be harvested in a given time period
func harvest_amount(time: float) -> float:
	if time < 0:
		logger.error("Cannot calculate harvest amount for negative time")
		return 0.0
	return _harvesting_rate * time

## Reset all rates to their default values
func reset() -> void:
	_set_movement_rate(DEFAULT_RATE)
	_set_harvesting_rate(DEFAULT_RATE)
	_set_storing_rate(DEFAULT_RATE)
	logger.trace("All rates reset to default: %.2f" % DEFAULT_RATE)
#endregion
