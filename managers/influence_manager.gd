class_name InfluenceManager
extends Node2D

signal profile_changed
signal influence_visibility_changed(enabled: bool)

#region Visualization Settings
const STYLE = {
	"INFLUENCE_SETTINGS": {
		"OVERALL_COLOR": Color.WHITE,
		"ARROW_LENGTH": 50.0,
		"ARROW_WIDTH": 2.0,
		"ARROW_HEAD_SIZE": 8.0,
		"OVERALL_SCALE": 1.5,
		"IGNORE_TYPES": ["random"],
		"MIN_WEIGHT_THRESHOLD": 0.01
	}
}

var use_best_direction: bool = true  

var _visualization_enabled: bool = false
var camera: Camera2D
#endregion

#region Movement Properties
const TARGET_DISTANCE_MEAN = 65.0
var TARGET_DISTANCE :
	get:
		return TARGET_DISTANCE_MEAN + randf_range(-0.25 * TARGET_DISTANCE_MEAN, 0.25 * TARGET_DISTANCE_MEAN)
var target_recalculation_cooldown: float = 0.5
var _target_recalc_timer: float = 0.0
#endregion

#region Core Properties
## The entity this influence manager is attached to
var entity: Node

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

#region Initialization and Process
func _init() -> void:
	name = "influence_manager"
	logger = Logger.new(name, DebugLogger.Category.INFLUENCE)
	
func _ready() -> void:
	top_level = true
	camera = get_tree().get_first_node_in_group("camera")

func _process(_delta: float) -> void:
	if _visualization_enabled:
		queue_redraw()

func _physics_process(delta: float) -> void:
	_profile_check_timer += delta
	_target_recalc_timer += delta
	
	if _profile_check_timer >= profile_check_interval:
		for profile: InfluenceProfile in profiles:
			if is_profile_valid(profile):
				active_profile = profile
				break
		_profile_check_timer = 0.0
		
func initialize(p_entity: Node) -> void:
	if not p_entity:
		push_error("Cannot initialize with null entity")
		return

	entity = p_entity

#endregion

#region Profile Management
func is_profile_valid(profile: InfluenceProfile) -> bool:
	## Default is true
	if profile.enter_conditions.is_empty():
		return true

	## Otherwise check each condition and if any are true, then return true
	for condition: Logic in profile.enter_conditions:
		if condition.get_value(entity):
			return true

	return false

func add_profile(influence_profile: InfluenceProfile) -> void:
	if not influence_profile:
		push_error("Cannot add null profile")
		return

	if influence_profile not in profiles:
		profiles.append(influence_profile)

		# If no active profile set, set first one as active
		if active_profile==null:
			active_profile = influence_profile

func remove_profile(influence_profile: InfluenceProfile) -> void:
	if not influence_profile:
		return

	if influence_profile in profiles:
		profiles.erase(influence_profile)

	if active_profile == influence_profile:
		active_profile = null
	
func _on_active_profile_changed() -> void:
	profile_changed.emit()
#endregion

#region Movement Management
func should_recalculate_target() -> bool:
	if _target_recalc_timer < target_recalculation_cooldown:
		return false
		
	var nav_agent: NavigationAgent2D = entity.nav_agent
	if not nav_agent:
		return false

	if not nav_agent.target_position:
		return true

	if nav_agent.is_navigation_finished():
		return true

	if not nav_agent.is_target_reachable():
		return true

	return false

func update_movement_target() -> void:
	entity = entity as Ant
	_target_recalc_timer = 0.0
	var new_target = _calculate_target_position()
	entity.move_to(new_target)
		
	# Only update if we have a meaningful new target
	if new_target and new_target != entity.global_position and entity.has_method("move_to"):
		# Ensure the target is different enough to warrant movement
		if new_target.distance_to(entity.global_position) > 1.0:
			entity.move_to(new_target)
			logger.trace("New target set: %s" % new_target)


func _calculate_target_position() -> Vector2:
	if not entity or not active_profile:
		return Vector2.ZERO
	
	var base_direction = _calculate_direction(active_profile.influences)
	if base_direction == Vector2.ZERO:
		return Vector2.ZERO
		
	var nav_region = entity.get_tree().get_first_node_in_group("navigation") as NavigationRegion2D
	if not nav_region:
		return entity.global_position + base_direction * TARGET_DISTANCE
		
	# Choose between simple or best direction calculation
	if use_best_direction:
		return _get_best_navigable_target(base_direction, nav_region)
	else:
		return _get_simple_navigable_target(base_direction, nav_region)

func _get_simple_navigable_target(direction: Vector2, nav_region: NavigationRegion2D) -> Vector2:
	var target_pos = entity.global_position + direction * TARGET_DISTANCE 
	return NavigationServer2D.map_get_closest_point(nav_region.get_navigation_map(), target_pos)

func _get_best_navigable_target(direction: Vector2, nav_region: NavigationRegion2D) -> Vector2:
	entity = entity as Ant
	var map_rid = nav_region.get_navigation_map()
	var test_angles = [0,PI/16, -PI/16, PI/8, -PI/8, PI/4, -PI/4, PI/2, -PI/2]
	var best_target: Vector2 = entity.global_position
	var best_distance: float = 0.0
	
	for angle in test_angles:
		var test_direction = direction.rotated(angle)
		var test_target = entity.global_position + test_direction * TARGET_DISTANCE 
		var navigable_point = NavigationServer2D.map_get_closest_point(map_rid, test_target)
		
		if NavigationServer2D.map_get_path(
			map_rid, 
			entity.global_position,
			navigable_point,
			true
		).size() > 0:
			var dist_to_original = (test_target - navigable_point).length()
			
			if best_distance == 0.0 or dist_to_original < best_distance:
				best_target = navigable_point
				best_distance = dist_to_original
				
				if dist_to_original < 5.0:
					break
	assert(best_distance > 0)
	return best_target if best_distance > 0.0 else entity.global_position

func _calculate_direction(influences: Array[Logic]) -> Vector2:
	if not influences:
		return Vector2.ZERO
		
	var resultant_vector := Vector2.ZERO
	
	for influence in influences:
		if not influence:
			continue
		
		# If has condition and it evaluates to false, skip
		if influence.condition and not EvaluationSystem.get_value(influence.condition, entity):
			continue
		
		# Get the direction vector which includes magnitude as weight
		var direction = EvaluationSystem.get_value(influence, entity)
		if not direction:
			continue
			
		resultant_vector += direction
		
		logger.trace("Influence %s evaluated: Direction: %s, Magnitude: %s" % [
			influence.id,
			str(direction.normalized()),
			str(direction.length())
		])
	
	return resultant_vector.normalized()
#endregion

#region Visualization
func set_visualization_enabled(enabled: bool) -> void:
	_visualization_enabled = enabled
	influence_visibility_changed.emit(enabled)
	queue_redraw()

func _draw() -> void:
	if not (_visualization_enabled and entity and entity.is_inside_tree()):
		return
	draw_influences()

func should_ignore_influence(influence: Logic) -> bool:
	var influence_type = influence.name.to_snake_case().trim_suffix("_influence")
	return influence_type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES

func draw_influences() -> void:
	if not active_profile:
		return
		
	# Collect influence data and calculate total magnitude
	var total_magnitude = 0.0
	var influence_data = []
	
	for influence in active_profile.influences:
		if should_ignore_influence(influence):
			continue
			
		if not influence.is_valid(entity):
			continue
			
		var direction = EvaluationSystem.get_value(influence, entity)
		var magnitude = direction.length()
		
		if magnitude < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue
			
		total_magnitude += magnitude
		
		# Check for existing color in meta, create if not exists
		var influence_color: Color = influence.color
	
		influence_data.append({
			"magnitude": magnitude,
			"direction": direction.normalized(),
			"color": influence_color,
			"name": influence.name
		})
	
	if total_magnitude < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
		return
		
	# Calculate normalized weights and total direction
	var total_direction = Vector2.ZERO
	for data in influence_data:
		data.normalized_weight = data.magnitude / total_magnitude
		data.weighted_direction = data.direction * data.normalized_weight
		total_direction += data.weighted_direction
	
	# Sort by magnitude for layered rendering
	influence_data.sort_custom(
		func(a, b): return a.magnitude < b.magnitude
	)
	
	# Draw overall influence arrow
	var overall_length = STYLE.INFLUENCE_SETTINGS.ARROW_LENGTH * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
	draw_arrow(
		entity.global_position,
		entity.global_position + total_direction * overall_length,
		STYLE.INFLUENCE_SETTINGS.OVERALL_COLOR,
		STYLE.INFLUENCE_SETTINGS.ARROW_WIDTH * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE,
		STYLE.INFLUENCE_SETTINGS.ARROW_HEAD_SIZE * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
	)
	
	# Draw individual influence arrows
	for data in influence_data:
		var arrow_length = STYLE.INFLUENCE_SETTINGS.ARROW_LENGTH * data.normalized_weight * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
		var arrow_end = entity.global_position + data.direction * arrow_length
		draw_arrow(
			entity.global_position,
			arrow_end,
			data.color,
			STYLE.INFLUENCE_SETTINGS.ARROW_WIDTH,
			STYLE.INFLUENCE_SETTINGS.ARROW_HEAD_SIZE
		)

func draw_arrow(start: Vector2, end: Vector2, color: Color, width: float, head_size: float) -> void:
	draw_line(start, end, color, width)
	
	var direction = (end - start)
	var length = direction.length()
	if length <= head_size:
		return
		
	direction = direction.normalized()
	var right = direction.rotated(PI * 3/4) * head_size
	var left = direction.rotated(-PI * 3/4) * head_size
	
	var arrow_points = PackedVector2Array([
		end,
		end + right,
		end + left
	])
	draw_colored_polygon(arrow_points, color)
#endregion


func is_visualization_enabled() -> bool:
	return _visualization_enabled

func toggle_visualization():
	set_visualization_enabled(!_visualization_enabled)
