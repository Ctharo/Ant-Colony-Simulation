class_name Move
extends Action

#region Properties
## List of influences for this movement
@export var influences: Array[Influence]
## Whether to rotate towards movement direction
@export var face_direction: bool = false
const TARGET_DISTANCE: float = 45.0



func _setup_dependencies(dependencies: Dictionary) -> void:
	super._setup_dependencies(dependencies)

## Check if position is navigable
func _is_navigable(entity: Node, location: Vector2) -> bool:
	var space_state = entity.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = location
	query.collision_mask = 1  # Adjust mask based on your collision layers
	return space_state.intersect_point(query).is_empty()

func calculate_target_position(entity: Node) -> Vector2:
	var total_weight = 0.0
	var weighted_direction = Vector2.ZERO

	for influence: Influence in influences:
		var weight = influence.weight.get_value(entity.action_manager.evaluation_system, true)
		var dir = influence.direction.get_value(entity.action_manager.evaluation_system, true).normalized() # In case it's not normalized from the expression
		total_weight += weight
		weighted_direction += dir * weight

	if total_weight > 0:
		weighted_direction = (weighted_direction / total_weight).normalized()

	# Use entity-specific RNG for random movement
	var distance = entity.rng.randfn(TARGET_DISTANCE, 15)

	return entity.global_position + weighted_direction * distance

func set_target_position(entity: Node, target_pos: Vector2) -> void:
	entity.target_position = target_pos

## Update movement execution
func _update_execution(entity: Node, delta: float) -> void:

	var current_pos = entity.global_position
	var distance_to_target = current_pos.distance_to(entity.target_position) if entity.target_position else INF
	if distance_to_target <= entity.nav_agent.target_desired_distance * 1.5:
		set_target_position(entity, calculate_target_position(entity))
		return

	if entity.is_navigation_finished():
		if distance_to_target > entity.nav_agent.target_desired_distance * 2:
			set_target_position(entity, calculate_target_position(entity))
			return

	if not entity.target_position:
		set_target_position(entity, calculate_target_position(entity))

	var next_pos = entity.nav_agent.get_next_path_position()
	var direction = (next_pos - current_pos).normalized()
	var target_velocity = direction * entity.movement_rate

	# Entity-specific velocity lerping
	entity.set_velocity(entity.velocity.lerp(target_velocity, 0.15))

	if face_direction and entity.velocity:
		entity.set_global_rotation(entity.velocity.angle())

	entity.move_and_slide()
