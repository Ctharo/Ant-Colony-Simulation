class_name Vision
extends PropertyNode
## Component responsible for managing entity's visual perception

#region Constants
const DEFAULT_RANGE := 50.0
#endregion

#region Member Variables
## Maximum range at which the entity can see
var _range: float = DEFAULT_RANGE
#endregion
@export var config: VisionResource


func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("vision", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = VisionResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Vision property tree initialized")

#region Property Getters and Setters
func _get_range() -> float:
	return _range

func _set_range(value: float) -> void:
	if value <= 0:
		logger.error("Attempted to set vision.range.current to non-positive value -> Action not allowed")
		return

	var old_value = _range
	_range = value

	if old_value != _range:
		logger.trace("Range updated: %.2f -> %.2f" % [old_value, _range])

func _get_ants_in_range() -> Ants:
	if not entity:
		logger.error("Cannot get ants in range: entity reference is null")
		return null
	return Ants.in_range(entity, _range)

func _get_ants_in_range_count() -> int:
	var ants = _get_ants_in_range()
	return ants.size() if ants else 0

func _get_foods_in_range() -> Foods:
	if not entity:
		logger.error("Cannot get foods in range: entity reference is null")
		return null
	return Foods.in_range(entity.global_position, _range, true)

func _get_nearest_food() -> Food:
	if not entity:
		logger.error("Cannot get nearest food in range: entity reference is null")
		return null
	return Foods.nearest_food(entity.global_position, _range, true)

func _get_nearest_food_position() -> Vector2:
	if not entity:
		logger.error("Cannot get nearest food position: entity reference is null")
		return Vector2.ZERO
	var food: Food = _get_nearest_food()
	return food.global_position if food else Vector2.ZERO

func _get_foods_in_range_count() -> int:
	var foods = _get_foods_in_range()
	return foods.size() if foods else 0

func _get_foods_in_range_mass() -> float:
	var foods = _get_foods_in_range()
	return foods.get_mass() if foods else 0.0
#endregion

#region Public Methods
## Check if a point is within visual range
func is_within_range(point: Vector2) -> bool:
	if not entity:
		logger.error("Cannot check range: entity reference is null")
		return false
	return point.distance_to(entity.global_position) <= _range

## Reset vision range to default value
func reset() -> void:
	_set_range(DEFAULT_RANGE)
	logger.trace("Range reset to default: %.2f" % DEFAULT_RANGE)
#endregion
