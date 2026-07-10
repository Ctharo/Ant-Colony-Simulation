class_name InfluenceManager
extends Node2D
## Drives the ant's default (non-rule) movement: selects the active
## InfluenceProfile from its enter/exit conditions and steers along the sum
## of that profile's influence vectors.
##
## Profile selection (every physics tick — cheap because every condition is
## evaluated through EvaluationSystem, whose per-expression eval policies
## (FRAME/TIMER/STICKY/...) control the real recompute cost; the old
## profile_check_interval timer duplicated that and is gone):
##  - A profile with exit_conditions is STICKY: once active it holds until
##    any exit condition fires, then selection re-runs.
##  - A profile without exit_conditions is not sticky and can be displaced
##    any tick by an earlier-listed eligible profile — this is what lets an
##    always-eligible fallback like "wander" yield to real states.
##  - Eligible = any enter condition true, or no enter conditions at all.
##    First eligible profile in list order wins; fallback is profiles[0].

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

## Available influence profiles, in priority order (first eligible wins)
@export var profiles: Array[InfluenceProfile] = [] as Array[InfluenceProfile]

## Logger instance for debugging
var logger: iLogger
#endregion

#region Initialization and Process
func _init() -> void:
	name = "influence_manager"
	logger = iLogger.new(name, DebugLogger.Category.INFLUENCE)

func _ready() -> void:
	top_level = true
	camera = get_tree().get_first_node_in_group("camera")

func _process(_delta: float) -> void:
	if _visualization_enabled:
		queue_redraw()

func _physics_process(delta: float) -> void:
	_target_recalc_timer += delta
	if entity:
		_update_active_profile()

## Sets the entity reference
func initialize(p_entity: Node) -> void:
	if not p_entity:
		push_error("Cannot initialize with null entity")
		return

	entity = p_entity
#endregion

#region Profile Selection
func _update_active_profile() -> void:
	# Sticky hold: a profile that declares exit conditions keeps control
	# until one of them fires.
	if active_profile and not _exits_of(active_profile).is_empty():
		if not _should_exit(active_profile):
			return
		logger.trace("Profile '%s' released by exit condition" % active_profile.name)

	for profile: InfluenceProfile in profiles:
		if is_profile_valid(profile):
			if active_profile != profile:
				logger.trace("Switching from '%s' to '%s'" % [
					active_profile.name if active_profile else "none",
					profile.name
				])
			active_profile = profile
			return

	# No eligible profile: fall back to the first one.
	if profiles.size() > 0:
		active_profile = profiles[0]


## Eligible when any enter condition passes; no enter conditions = always.
func is_profile_valid(profile: InfluenceProfile) -> bool:
	if profile.enter_conditions.is_empty():
		return true

	for condition: Logic in profile.enter_conditions:
		if condition and EvaluationSystem.get_value(condition, entity):
			return true
	return false


## True when any exit condition of the profile fires.
func _should_exit(profile: InfluenceProfile) -> bool:
	for condition: Logic in _exits_of(profile):
		if condition and EvaluationSystem.get_value(condition, entity):
			return true
	return false


## Null-safe accessor: legacy .tres files (pre-migration go_home.tres) wrote
## `exit_conditions = null` into a typed-array property.
func _exits_of(profile: InfluenceProfile) -> Array:
	var exits = profile.get("exit_conditions")
	return exits if exits != null else []
#endregion

#region Profile Management
## Add resource InfluenceProfile to [member profiles]
func add_profile(influence_profile: InfluenceProfile) -> void:
	if not influence_profile:
		push_error("Cannot add null profile")
		return

	if influence_profile not in profiles:
		profiles.append(influence_profile)

		# If no active profile set, set first one as active
		if active_profile == null:
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

	# Only update if we have a meaningful new target
	if new_target and new_target != entity.global_position and entity.has_method("move_to"):
		# Ensure the target is different enough to warrant movement
		if new_target.distance_to(entity.global_position) > 1.0:
			entity.move_to(new_target)
			logger.trace("New target set: %s" % new_target)
		else:
			logger.trace("Target too close, skipping: %s" % new_target)
	else:
		logger.trace("Invalid target or same position: %s" % new_target)


func _calculate_target_position() -> Vector2:
	if not entity:
		logger.trace("No entity")
		return Vector2.ZERO

	if not active_profile:
		logger.trace("No active profile, using fallback movement")
		# Fallback: basic forward movement
		var fallback_direction = Vector2(1, 0).rotated(entity.global_rotation)
		return entity.global_position + fallback_direction * TARGET_DISTANCE

	var base_direction = _calculate_direction(active_profile.influences)
	if base_direction == Vector2.ZERO:
		logger.trace("Base direction is zero")
		return Vector2.ZERO

	logger.trace("Base direction calculated: %s" % base_direction)

	var nav_region = entity.get_tree().get_first_node_in_group("navigation") as NavigationRegion2D
	if not nav_region:
		logger.trace("No navigation region found, using direct calculation")
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
	var test_angles = [0, PI/16, -PI/16, PI/8, -PI/8, PI/4, -PI/4, PI/2, -PI/2]
	var best_target: Vector2 = entity.global_position
	var best_distance: float = INF

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

			if dist_to_original < best_distance:
				best_target = navigable_point
				best_distance = dist_to_original

				if dist_to_original < 5.0:
					break

	# If no valid path found, fall back to simple navigation
	if best_distance == INF:
		logger.trace("No valid path found in best navigation, falling back to simple")
		return _get_simple_navigable_target(direction, nav_region)

	return best_target

func _calculate_direction(influences: Array[Logic]) -> Vector2:
	# Filter valid influences (gate conditions evaluated via EvaluationSystem
	# inside Influence.is_valid)
	var valid_influences = influences.filter(func(influence):
		return influence is Influence and influence.is_valid(entity)
	)

	logger.trace("Valid influences: %d/%d" % [valid_influences.size(), influences.size()])

	# Map influences to direction vectors with null checking
	var direction_vectors = []
	for influence in valid_influences:
		var vector = EvaluationSystem.get_value(influence, entity)
		if vector != null and vector is Vector2:
			direction_vectors.append(vector)
			logger.trace("Influence '%s': %s" % [influence.name, vector])
		else:
			logger.trace("Influence '%s' returned invalid vector: %s" % [influence.name, vector])

	if direction_vectors.is_empty():
		logger.trace("No valid direction vectors found, using fallback")
		# Fallback: provide a basic forward movement
		var fallback_direction = Vector2(1, 0).rotated(entity.global_rotation)
		logger.trace("Fallback direction: %s" % fallback_direction)
		return fallback_direction

	# Reduce to a single resultant vector
	var resultant = direction_vectors.reduce(
		func(accum, vector): return accum + vector,
		Vector2.ZERO
	)

	logger.trace("Resultant vector before normalization: %s" % resultant)

	if resultant.length_squared() < 0.001:
		logger.trace("Resultant vector too small, returning zero")
		return Vector2.ZERO

	return resultant.normalized()
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
		if not influence is Influence:
			continue

		if should_ignore_influence(influence):
			continue

		if not influence.is_valid(entity):
			continue

		var direction = EvaluationSystem.get_value(influence, entity)
		if not direction is Vector2:
			continue
		var magnitude = direction.length()

		if magnitude < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue

		total_magnitude += magnitude

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
