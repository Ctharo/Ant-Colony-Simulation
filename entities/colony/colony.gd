class_name Colony
extends Node2D
## Colony class managing ant spawning, tracking, and role management

#region Member Variables
@onready var collision_area: Area2D = $CollisionArea
@export var dirt_color = Color(Color.SADDLE_BROWN, 0.8)  # Earthy brown
@export var darker_dirt = Color(Color.BROWN, 0.9) # Darker brown for depth
@export var profile: ColonyProfile
@export var ant_profiles: Array[ColonyAntProfile]

## Dictionary tracking spawned ants by their profile ID
var _profile_ant_map: Dictionary = {}
var _last_spawn_ticks: int

## Colony radius in units
@export var radius: float = 60.0:
	set(value):
		radius = value
		queue_redraw()  # Redraw when radius changes

## Inner radius as a ratio of the main radius
var inner_radius_ratio: float = 0.2
## Collection of food resources
var foods: Foods = Foods.new()
## Ants belonging to this colony
var ants: Ants = Ants.new([])
## Whether this colony is highlighted
var is_highlighted: bool = false
## Whether to highlight all ants belonging to this colony
var highlight_ants_enabled: bool = false

## Whether to show navigation agent debug visualization
var nav_debug_enabled: bool = false
var heatmap_enabled: bool = false :
	set(value):
		heatmap_enabled = value
		heatmap.debug_draw(self, value)
var eval_system: EvaluationSystem
#endregion

var logger: Logger
var heatmap: HeatmapManager
var sandbox

#region Initialization
func _init() -> void:
	logger = Logger.new("colony", DebugLogger.Category.ENTITY)
	eval_system = EvaluationSystem.new()
	
func _ready() -> void:
	heatmap = get_tree().get_first_node_in_group("heatmap")
	heatmap.register_entity(self)
	eval_system.initialize(self)

func init_colony_profile(p_profile: ColonyProfile) -> void:
	profile = p_profile
	ant_profiles.clear()
	_profile_ant_map.clear()
	
	for ant_profile: ColonyAntProfile in p_profile.ant_profiles:
		ant_profiles.append(ant_profile)
		_profile_ant_map[ant_profile.ant_profile.id] = []

func _physics_process(_delta: float) -> void:
	for p_profile: ColonyAntProfile in ant_profiles:
		if p_profile.spawn_condition.get_value(eval_system):
			spawn_ant(p_profile.ant_profile)

func _exit_tree() -> void:
	heatmap.unregister_entity(self)
	delete_all()

func delete_all():
	for ant in ants:
		if ant != null:
			AntManager.remove_ant(ant)
	_profile_ant_map.clear()

## Returns the time in milliseconds since the last ant spawn
func ticks_since_spawn() -> int:
	return Time.get_ticks_msec() - _last_spawn_ticks

## Returns all ants in the colony
func get_ants() -> Array:
	return ants.to_array()

## Returns ants of a specific profile
func get_ants_by_profile(profile_id: String) -> Array:
	return _profile_ant_map.get(profile_id, [])

func _draw() -> void:
	# Rich brown/dirt color with some transparency
	var inner_radius = radius * inner_radius_ratio

	# Draw the darker rim first
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, darker_dirt, 3.0)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 32, darker_dirt, 2.0)

	# Create points for the filled area
	var points_outer = []
	var points_inner = []
	var num_points = 32

	# Create outer circle points
	for i in range(num_points + 1):
		var angle = i * TAU / num_points
		points_outer.append(Vector2(cos(angle), sin(angle)) * radius)

	# Create inner circle points (in reverse order)
	for i in range(num_points + 1):
		var angle = (num_points - i) * TAU / num_points
		points_inner.append(Vector2(cos(angle), sin(angle)) * inner_radius)

	# Combine points and draw filled polygon
	var points = points_outer + points_inner
	draw_colored_polygon(points, dirt_color)

func add_ant(ant: Ant) -> Result:
	if not ant:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Invalid ant")
	ants.append(ant)
	
	# Track ant in profile map
	if ant.role in _profile_ant_map:
		_profile_ant_map[ant.role].append(ant)
	
	if sandbox:
		sandbox.ant_container.add_child(ant)
	else:
		add_child(ant)
	ant.set_colony(self)
	return Result.new()

func store_food(food: Food) -> void:
	food.stored = true
	food.carried = false
	foods.add_food(food)

func spawn_ants(num: int, physics_at_spawn: bool = true) -> Array[Ant]:
	var _ants: Array[Ant] = AntManager.spawn_ants(self, num, physics_at_spawn)
	for ant in _ants:
		randomize()
		add_ant(ant)
		ant.global_rotation = randf_range(-PI, PI)
		var wiggle_x: float = randf_range(-15,15)
		var wiggle_y: float = randf_range(-15,15)
		ant.global_position = global_position + Vector2(wiggle_x, wiggle_y)
	logger.info("Spawned %s %s from %s" % [_ants.size(), "ant" if _ants.size() == 1 else "ants", name])
	_last_spawn_ticks = Time.get_ticks_msec()
	return _ants
	
func spawn_ant(ant_profile: AntProfile) -> Ant:
	var ant: Ant = AntManager.spawn_ant(self)
	ant.movement_rate = ant_profile.movement_rate
	ant.vision_range = ant_profile.vision_range
	ant.olfaction_range = ant_profile.olfaction_range
	ant.reach_range = ant_profile.reach_range
	ant.pheromones = ant_profile.pheromones
	ant.role = ant_profile.name.to_snake_case() # FIXME: Redundant
	
	randomize()
	add_ant(ant)
	ant.global_rotation = randf_range(-PI, PI)
	var wiggle_x: float = randf_range(-15,15)
	var wiggle_y: float = randf_range(-15,15)
	ant.global_position = global_position + Vector2(wiggle_x, wiggle_y)
	_last_spawn_ticks = Time.get_ticks_msec()
	ant.died.connect(_on_ant_died)
	return ant
#endregion

func _on_ant_died(ant: Ant) -> void:
	if ant in ants.elements:
		ants.elements.erase(ant)
		# Remove from profile tracking
		if ant.role in _profile_ant_map:
			_profile_ant_map[ant.role].erase(ant)

## Returns the count of ants with a specific role
## The role parameter can be a partial match
func ant_count_by_role(role: String) -> int:
	if role.is_empty():
		return 0
		
	var normalized_role = role.to_lower().strip_edges()
	if normalized_role.is_empty():
		return 0
		
	var result = 0
	for ant: Ant in ants:
		if not is_instance_valid(ant):
			continue
			
		var ant_role = ant.role.to_lower()
		# Check both if role contains ant's role or ant's role contains the search role
		if ant_role.contains(normalized_role) or normalized_role.contains(ant_role):
			result += 1
	return result
