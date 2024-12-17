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

	var distance_to_target = current_pos.distance_to(entity.target_position) if entity.target_position else INF
	if not entity.target_position:
		should_recalculate = true
	elif entity.is_navigation_finished():
		should_recalculate = true
		# Only recalculate influences when needed
	if should_recalculate:
		var target_pos = state.influence_manager.calculate_target_position(TARGET_DISTANCE, influences)
		entity.target_position = target_pos
		return
			
	var next_pos = entity.nav_agent.get_next_path_position()
	var direction = (next_pos - current_pos).normalized()
	var target_velocity = direction * entity.movement_rate
	entity.set_velocity(entity.velocity.lerp(target_velocity, 0.15))
	
	if face_direction and entity.velocity:
		var angle = entity.velocity.angle()
		if entity.global_rotation != angle:
			entity.set_global_rotation(angle)
			
	entity.move_and_slide()
	
	var moved_length: float = last_pos.distance_to(current_pos) if last_pos and current_pos else 0.0
	if moved_length > 0:
		energy_loss(entity, energy_coefficient * moved_length * delta)
		
	last_pos = current_pos
