class_name Move
extends Action

@export var influences: Array[Influence]
@export var face_direction: bool = false
@export var TARGET_DISTANCE: float = 45.0
@export var RECALCULATION_THRESHOLD: float = 5.0 # Distance from target to trigger recalculation

var last_pos: Vector2

func execute_tick(entity: Node, state: ActionManager.ActionState, delta: float) -> void:
	entity = entity as Ant
	var current_pos = entity.global_position
	var should_recalculate = false
	
	# Check if we need to recalculate path
	if not entity.target_position:
		should_recalculate = true
	elif not entity.nav_agent.is_target_reachable():
		should_recalculate = true
	elif entity.nav_agent.is_target_reached():
		should_recalculate = true
	elif entity.nav_agent.is_navigation_finished():
		should_recalculate = true

	# Recalculate target if needed
	if should_recalculate:
		var target_pos = state.influence_manager.calculate_target_position(TARGET_DISTANCE, influences)
		entity.target_position = target_pos
		return
		
	# Get next path position and move
	var next_pos = entity.nav_agent.get_next_path_position()
	var direction = (next_pos - current_pos).normalized()
	var target_velocity = direction * entity.movement_rate
	
	# Smooth velocity transition
	entity.set_velocity(entity.velocity.lerp(target_velocity, min(delta * 10.0, 0.15)))
	
	# Update rotation if needed
	if face_direction and entity.velocity.length() > 0.1:
		var angle = entity.velocity.angle()
		if abs(entity.global_rotation - angle) > 0.1:
			entity.set_global_rotation(angle)
	
	# Apply movement
	entity.move_and_slide()
	
	# Handle energy loss from movement
	var moved_length: float = last_pos.distance_to(current_pos) if last_pos and current_pos else 0.0
	if moved_length > 0:
		energy_loss(entity, energy_coefficient * delta)
	
	last_pos = current_pos
