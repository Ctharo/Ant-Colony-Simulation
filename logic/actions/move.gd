class_name Move
extends Action

@export var influences: Array[Influence]
@export var face_direction: bool = false
@export var TARGET_DISTANCE: float = 45.0
@export var RECALCULATION_THRESHOLD: float = 5.0 # Distance from target to trigger recalculation

# Note: last_pos should be in the ActionState since it's per-entity
func execute_tick(entity: Node, state: ActionManager.ActionState, delta: float) -> void:
	# Check and set execution state in the ActionState
	if not state.has_meta("is_processing_tick"):
		state.set_meta("is_processing_tick", false)
	if not state.has_meta("last_pos"):
		state.set_meta("last_pos", Vector2.ZERO)
		
	# If we're already processing a tick, skip this one
	if state.get_meta("is_processing_tick"):
		return
		
	state.set_meta("is_processing_tick", true)
	
	# Execute tick logic
	await execute_tick_internal(entity, state, delta)
	
	state.set_meta("is_processing_tick", false)

func execute_tick_internal(entity: Node, state: ActionManager.ActionState, delta: float) -> void:
	entity = entity as Ant
	var current_pos = entity.global_position
	var should_recalculate = false
	var last_pos = state.get_meta("last_pos") as Vector2
	
	# Check if we need to recalculate path
	if not entity.target_position:
		should_recalculate = true
	elif not entity.nav_agent.is_target_reachable():
		should_recalculate = true
	elif entity.nav_agent.is_target_reached():
		should_recalculate = true
	elif current_pos.distance_to(entity.target_position) < RECALCULATION_THRESHOLD:
		should_recalculate = true
	
	# Recalculate target if needed
	if should_recalculate:
		if not await find_new_target(entity, state):
			state.set_meta("is_processing_tick", false)
			return
	
	# Get next path position - only do this once per frame
	var next_path_pos = entity.nav_agent.get_next_path_position()
	
	# Calculate avoidance-aware movement
	var move_direction = (next_path_pos - current_pos).normalized()
	var target_velocity = move_direction * entity.movement_rate
	
	# Use safe velocity from avoidance system
	entity.nav_agent.set_velocity(target_velocity)
	# Wait for avoidance calculation
	await entity.get_tree().physics_frame
	# Get the actual safe velocity to use
	var safe_velocity = entity.nav_agent.velocity
	
	# Smooth velocity transition using safe velocity
	entity.set_velocity(entity.velocity.lerp(safe_velocity, min(delta * 10.0, 0.15)))
	
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
	
	# Update last position in state
	state.set_meta("last_pos", current_pos)

# Helper function to find and set new target
func find_new_target(entity: Ant, state: ActionManager.ActionState) -> bool:
	# Get navigation info
	var nav_region = entity.get_tree().get_first_node_in_group("navigation") as NavigationRegion2D
	if not nav_region:
		push_error("No navigation region found!")
		return false
		
	var map_rid = nav_region.get_navigation_map()
	var target_found = false
	var attempts = 0
	var max_attempts = 5
	var target_pos = Vector2.ZERO
	var current_distance = TARGET_DISTANCE
	
	while attempts < max_attempts and not target_found:
		# Get potential target from influences
		target_pos = state.influence_manager.calculate_target_position(current_distance, influences)
		
		# Get closest valid point on navigation mesh
		var closest_point = NavigationServer2D.map_get_closest_point(map_rid, target_pos)
		var distance_to_valid = closest_point.distance_to(target_pos)
		
		# Check if point is actually navigable
		var path = NavigationServer2D.map_get_path(
			map_rid,
			entity.global_position,
			closest_point,
			true  # optimal path
		)
		
		if path.size() > 0 and distance_to_valid < 5.0:
			target_pos = closest_point
			target_found = true
		else:
			# If target was invalid, reduce distance and try again
			current_distance *= 0.8
			
		attempts += 1
	
	if not target_found:
		push_warning("Could not find valid target after %d attempts" % attempts)
		return false
		
	# Set new target
	entity.target_position = target_pos
	
	# Wait for navigation server to process
	await entity.get_tree().physics_frame
	
	# Verify path was generated
	if entity.nav_agent.get_current_navigation_path().size() == 0:
		push_warning("No path generated to valid target!")
		return false
		
	return true
