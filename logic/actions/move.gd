class_name Move
extends Action

@export var influences: Array[Influence]
@export var face_direction: bool = false
@export var TARGET_DISTANCE: float = 45.0
@export var RECALCULATION_THRESHOLD: float = 5.0 # Distance from target to trigger recalculation
var _is_processing_tick := false

var last_pos: Vector2

func _execute_tick_internal(entity: Node, state: ActionManager.ActionState, delta: float) -> void:
	entity = entity as Ant
	var current_pos = entity.global_position
	var should_recalculate = false
	
	# Check if we need to recalculate path
	if not entity.target_position:
		print("No target position")
		should_recalculate = true
	elif entity.nav_agent.is_navigation_finished():
		print("Navigation finished")
		should_recalculate = true

	# Recalculate target if needed
	if should_recalculate:
		var target_pos = state.influence_manager.calculate_target_position(TARGET_DISTANCE, influences)
		entity.target_position = target_pos
		print("Set new target: %s" % target_pos)
		await entity.get_tree().physics_frame  # Wait for navigation to process
		return
		
	var path = entity.nav_agent.get_current_navigation_path()
	print("Current path size: %d" % path.size())
	
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
	_is_processing_tick = false

func execute_tick(entity: Node, state: ActionManager.ActionState, delta: float) -> void:
	# If we're already processing a tick, skip this one
	if _is_processing_tick:
		return
		
	_is_processing_tick = true
	
	# Execute tick logic
	await _execute_tick_internal(entity, state, delta)
	
	_is_processing_tick = false
