class_name Move
extends Action

@export var influences: Array[Influence]
@export var face_direction: bool = false
@export var TARGET_DISTANCE: float = 100.0
@export var RECALCULATION_THRESHOLD: float = 5.0 # Distance from target to trigger recalculation

func execute_tick(entity: Node, state: ActionState, delta: float) -> void:
	entity = entity as Ant
	var current_pos = entity.global_position
	var should_recalculate = false

	# Ensure last_pos is initialized in state
	if not state.has_meta("last_pos"):
		state.set_meta("last_pos", current_pos)

	# Simplified recalculation checks
	if not entity.target_position:
		should_recalculate = true
	elif entity.is_navigation_finished():
		should_recalculate = true
	elif not entity.nav_agent.is_target_reachable():
		should_recalculate = true

	# Quick recalculation without complex validation
	if should_recalculate:
		var target_pos = state.influence_manager.calculate_target_position(TARGET_DISTANCE, influences)
		# Basic navigation validation
		var nav_region = entity.get_tree().get_first_node_in_group("navigation") as NavigationRegion2D
		if nav_region:
			var map_rid = nav_region.get_navigation_map()
			target_pos = NavigationServer2D.map_get_closest_point(map_rid, target_pos)
		entity.target_position = target_pos
		return

	# Movement calculation with avoidance
	var next_pos = entity.nav_agent.get_next_path_position()
	var direction = (next_pos - current_pos).normalized()
	var target_velocity = direction * entity.movement_rate

	entity.set_velocity(entity.velocity.lerp(target_velocity, 0.15))

	# Direction facing
	if face_direction and entity.velocity.length() > 0.0:
		var angle = entity.velocity.angle()
		entity.set_global_rotation(angle)

	entity.move_and_slide()

	# Energy calculation using last_pos from state
	var last_pos = state.get_meta("last_pos") as Vector2
	var moved_length: float = last_pos.distance_to(current_pos)
	if moved_length > 0:
		energy_loss(entity, energy_coefficient * delta)

	# Update last_pos in state
	state.set_meta("last_pos", current_pos)
