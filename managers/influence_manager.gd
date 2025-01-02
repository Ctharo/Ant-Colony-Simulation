class_name InfluenceManager
extends Node2D


signal profile_changed


#region Movement Properties
const TARGET_DISTANCE = 50.0
var target_recalculation_cooldown: float = 0.5
var _target_recalc_timer: float = 0.0
#endregion

#region Properties
## The entity this influence manager is attached to
var entity: Node

## Reference to the evaluation system
@onready var eval_system: EvaluationSystem = $"../EvaluationSystem"

## Currently active influence profile
var active_profile: InfluenceProfile:
	set(value):
		if active_profile != value:
			active_profile = value
			_on_active_profile_changed()

## Available influence profiles
@export var profiles: Array[InfluenceProfile] = []
@export var profile_check_interval: float = 1.0
var _profile_check_timer: float = 0.0
## Logger instance for debugging
var logger: Logger
#endregion

#region Initialization
func _init() -> void:
	name = "influence_manager"
	logger = Logger.new(name, DebugLogger.Category.INFLUENCE)

func is_profile_valid(profile: InfluenceProfile) -> bool:
	## Default is true
	if profile.enter_conditions.is_empty():
		return true

	## Otherwise check each condition and if any are true, then return true
	for condition: Logic in profile.enter_conditions:
		if condition.get_value(eval_system):
			return true

	return false

func _physics_process(delta: float) -> void:
	_profile_check_timer += delta
	_target_recalc_timer += delta
	
	if _profile_check_timer >= profile_check_interval:
		for profile: InfluenceProfile in profiles:
			if is_profile_valid(profile):
				active_profile = profile
				break
		_profile_check_timer = 0.0

#region Movement Management
## Checks if target position should be recalculated
func should_recalculate_target() -> bool:
	if _target_recalc_timer < target_recalculation_cooldown:
		return false
		
	var nav_agent = entity.nav_agent
	if not nav_agent:
		return false

	if not nav_agent.target_position:
		return true

	if nav_agent.is_navigation_finished():
		return true

	if not nav_agent.is_target_reachable():
		return true

	return false

## Updates the movement target based on current influences
func update_movement_target() -> void:
	_target_recalc_timer = 0.0
	var new_target = _calculate_target_position()
	
	# Only update if we have a meaningful new target
	if new_target and new_target != entity.global_position and entity.has_method("move_to"):
	
		# Ensure the target is different enough to warrant movement
		if new_target.distance_to(entity.global_position) > 1.0:
			entity.move_to(new_target)
			logger.trace("New target set: %s" % new_target)

## Calculates the new target position based on influences
func _calculate_target_position() -> Vector2:
	if not entity or not active_profile:
		return Vector2.ZERO
	
	# Get new target from influence system
	var target_pos = entity.global_position + _calculate_weighted_direction(active_profile.influences) * TARGET_DISTANCE
	if not target_pos:
		return Vector2.ZERO
	
	# Validate target is within navigation bounds
	var nav_region = entity.get_tree().get_first_node_in_group("navigation") as NavigationRegion2D
	if nav_region:
		var map_rid = nav_region.get_navigation_map()
		target_pos = NavigationServer2D.map_get_closest_point(map_rid, target_pos)

	return target_pos
#endregion

func initialize(p_entity: Node) -> void:
	if not p_entity:
		push_error("Cannot initialize with null entity")
		return

	entity = p_entity
	if not eval_system:
		push_error("EvaluationSystem not found")
		return

	eval_system.initialize(entity)
	# Register existing profiles
	for profile in profiles:
		_register_profile_influences(profile)
#endregion

#region Profile Management
func add_profile(influence_profile: InfluenceProfile) -> void:
	if not influence_profile:
		push_error("Cannot add null profile")
		return

	if influence_profile not in profiles:
		profiles.append(influence_profile)
		_register_profile_influences(influence_profile)

		# If no active profile set, set first one as active
		if active_profile==null:
			active_profile = influence_profile

func remove_profile(influence_profile: InfluenceProfile) -> void:
	if not influence_profile:
		return

	if influence_profile in profiles:
		_unregister_profile_influences(influence_profile)
		profiles.erase(influence_profile)

	if active_profile == influence_profile:
		active_profile = null

func _register_profile_influences(profile: InfluenceProfile) -> void:
	if not profile or not eval_system:
		return

	for condition: Logic in profile.enter_conditions:
		eval_system.register_expression(condition)

	for influence in profile.influences:
		if influence and influence.direction_logic and influence.weight_logic:
			eval_system.register_expression(influence.direction_logic)
			eval_system.register_expression(influence.weight_logic)


func _unregister_profile_influences(profile: InfluenceProfile) -> void:
	if not profile or not eval_system:
		return

	# TODO: Implement unregister in EvaluationSystem
	pass

func _on_active_profile_changed() -> void:
	profile_changed.emit()

#endregion

#region Calculations

## Calculates the weighted direction from all influences
func _calculate_weighted_direction(influences: Array[Influence]) -> Vector2:
	if not eval_system or not influences:
		return Vector2.ZERO

	var total_weight := 0.0
	var weighted_direction := Vector2.ZERO
	var evaluated_influences := []

	# First pass: evaluate all influences and calculate total weight
	for influence in influences:
		if not influence:
			continue

		var weight = eval_system.get_value(influence.weight_logic)

		if not weight:
			continue
		
		var dir = eval_system.get_value(influence.direction_logic)
		dir = dir.normalized() if dir else Vector2.ZERO

		if not dir:
			continue

		# Store evaluated values for second pass
		evaluated_influences.append({
			"id": influence.id,
			"weight": weight,
			"direction": dir
		})
		total_weight += weight

	# Second pass: normalize weights and calculate final direction
	if total_weight > 0:
		for eval_influence in evaluated_influences:
			# Normalize weight by dividing by total
			var normalized_weight = eval_influence.weight / total_weight
			weighted_direction += eval_influence.direction * normalized_weight

			logger.trace("Influence %s evaluated: Weight: %s, Normalized: %s, Direction: %s" % [
				eval_influence.id,
				str(eval_influence.weight),
				str(normalized_weight),
				str(eval_influence.direction)
			])

	return weighted_direction
#endregion
