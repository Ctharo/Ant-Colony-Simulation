class_name Proprioception
extends PropertyNode
## The component responsible for sense of direction and position

@export var config: ProprioceptionResource

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("proprioception", Type.CONTAINER, _entity)

	if not config:
		config = ProprioceptionResource.new()

	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)

	# Copy the configured tree into this instance
	copy_from(node)

	logger.trace("Proprioception property tree initialized")

#region Property Getters
func _get_position() -> Vector2:
	if not entity:
		logger.error("Cannot get position: entity reference is null")
		return Vector2.ZERO
	return entity.global_position

func _get_colony_position() -> Vector2:
	if not entity:
		logger.error("Cannot get colony position: entity reference is null")
		return Vector2.ZERO
	var colony_pos = entity.get_property_value("colony.position")
	if not colony_pos:
		logger.trace("Could not get colony position")
		return Vector2.ZERO
	return colony_pos

func _get_target_position() -> Vector2:
	if not entity:
		logger.error("Cannot get target position: entity reference is null")
		return Vector2.ZERO
	return entity.target_position

func _set_target_position(target_position: Vector2) -> void:
	if not entity:
		logger.error("Cannot set target position: entity reference is null")
		return
	entity.target_position = target_position

func _get_distance_to_colony() -> float:
	if not entity:
		logger.error("Cannot get colony distance: entity reference is null")
		return 0.0
	var colony_pos = _get_colony_position()
	if colony_pos == Vector2.ZERO:
		return 0.0
	return _get_position().distance_to(colony_pos)

func _get_direction_to_colony() -> Vector2:
	if not entity:
		logger.error("Cannot get colony direction: entity reference is null")
		return Vector2.ZERO
	var colony_pos = _get_colony_position()
	if colony_pos == Vector2.ZERO:
		return Vector2.ZERO
	return _direction_to(colony_pos)

func _is_at_target() -> bool:
	var current_pos: Vector2 = entity.get_property_value("proprioception.base.position")
	var target_pos: Vector2 = entity.get_property_value("proprioception.base.target_position")
	if not current_pos:
		return false
	return current_pos.distance_to(target_pos) < 10 # TODO: Magic number

func _is_at_colony() -> bool:
	return is_zero_approx(_get_distance_to_colony())

func _has_moved() -> bool:
	return not is_zero_approx(_get_position().length())
#endregion

#region Public Methods
## Get direction from entity's current position to a specific location
func get_direction_to(location: Vector2) -> Vector2:
	if not entity:
		logger.error("Cannot get direction: entity reference is null")
		return Vector2.ZERO
	return _direction_to(location)

## Get distance from entity's current position to a specific location
func get_distance_to(location: Vector2) -> float:
	if not entity:
		logger.error("Cannot get distance: entity reference is null")
		return 0.0
	return _get_position().distance_to(location)
#endregion

#region Private Methods
## Calculate direction vector to a given location
func _direction_to(location: Vector2) -> Vector2:
	return _get_position().direction_to(location)
#endregion
