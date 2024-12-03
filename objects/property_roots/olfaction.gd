class_name Olfaction
extends PropertyNode
## Component responsible for ant's sense of smell and pheromone detection

#region Constants
const DEFAULT_RANGE := 100.0
#endregion

#region Member Variables
## Maximum range at which the ant can detect scents
var _range: float = DEFAULT_RANGE
#endregion
@export var config: OlfactionResource

func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("olfaction", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = OlfactionResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	

	logger.trace("Olfaction property tree initialized")

#region Property Getters and Setters
func _get_range() -> float:
	return _range

func _set_range(value: float) -> void:
	if value <= 0:
		logger.error("Attempted to set olfaction.base.range to non-positive value -> Action not allowed")
		return

	var old_value = _range
	_range = value

	if old_value != _range:
		logger.trace("Range updated: %.2f -> %.2f" % [old_value, _range])

func _get_pheromones_in_range() -> Pheromones:
	if not entity:
		logger.error("Cannot get pheromones: entity reference is null")
		return null
	return Pheromones.in_range(entity.global_position, _range)

func _get_pheromones_in_range_count() -> int:
	var pheromones = _get_pheromones_in_range()
	return pheromones.size() if pheromones else 0

func _get_food_pheromones_in_range() -> Pheromones:
	if not entity:
		logger.error("Cannot get food pheromones: entity reference is null")
		return null
	return Pheromones.in_range(entity.global_position, _range, "food")

func _get_food_pheromones_in_range_count() -> int:
	var pheromones = _get_food_pheromones_in_range()
	return pheromones.size() if pheromones else 0

func _get_home_pheromones_in_range() -> Pheromones:
	if not entity:
		logger.error("Cannot get home pheromones: entity reference is null")
		return null
	return Pheromones.in_range(entity.global_position, _range, "home")

func _get_home_pheromones_in_range_count() -> int:
	var pheromones = _get_home_pheromones_in_range()
	return pheromones.size() if pheromones else 0

func _is_detecting_any() -> bool:
	return _get_pheromones_in_range_count() > 0

func _is_detecting_food() -> bool:
	return _get_food_pheromones_in_range_count() > 0

func _is_detecting_home() -> bool:
	return _get_home_pheromones_in_range_count() > 0
#endregion

#region Public Methods
## Check if a point is within olfactory range
func is_within_range(point: Vector2) -> bool:
	if not entity:
		logger.error("Cannot check range: entity reference is null")
		return false
	return entity.global_position.distance_to(point) < _range

## Reset olfactory range to default value
func reset() -> void:
	_set_range(DEFAULT_RANGE)
	logger.trace("Range reset to default: %.2f" % DEFAULT_RANGE)
#endregion
