class_name Move
extends Action

@export var influences: Array[Influence]
@export var face_direction: bool = false

@export var TARGET_DISTANCE: float = 45.0

func execute_tick(entity: Node, state: ActionManager.ActionState, delta: float) -> void:
	entity = entity as Ant
	var target_pos = state.influence_manager.calculate_target_position(TARGET_DISTANCE, influences)

	var current_pos = entity.global_position
	var distance_to_target = current_pos.distance_to(entity.target_position) if entity.target_position else INF

	if distance_to_target <= entity.nav_agent.target_desired_distance * 1.5 or \
	   (entity.is_navigation_finished() and distance_to_target > entity.nav_agent.target_desired_distance * 2) or \
	   not entity.target_position:
		entity.target_position = target_pos
		return

	var next_pos = entity.nav_agent.get_next_path_position()
	var direction = (next_pos - current_pos).normalized()
	var target_velocity = direction * entity.movement_rate

	entity.set_velocity(entity.velocity.lerp(target_velocity, 0.15))
	if face_direction and entity.velocity:
		entity.set_global_rotation(entity.velocity.angle())
	entity.move_and_slide()
	energy_loss(entity, energy_coefficient * entity.velocity.length() * delta)
		
