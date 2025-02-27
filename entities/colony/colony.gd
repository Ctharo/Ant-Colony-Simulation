class_name Colony
extends Node2D
## Colony class managing ant spawning, tracking, and role management

#region Member Variables
@onready var collision_area: Area2D = $CollisionArea
@export var dirt_color = Color(Color.SADDLE_BROWN, 0.8)  # Earthy brown
@export var darker_dirt = Color(Color.BROWN, 0.9) # Darker brown for depth
@export var profile: ColonyProfile
@export var ant_profiles: Array[AntProfile]

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
		HeatmapManager.debug_draw(self, value)
#endregion

var logger: Logger
var sandbox

#region Initialization
func _init() -> void:
	logger = Logger.new("colony", DebugLogger.Category.ENTITY)

func _ready() -> void:
	HeatmapManager.register_entity(self)

	# If a profile was set before _ready, spawn initial ants now
	if profile:
		_spawn_initial_ants()

func init_colony_profile(p_profile: ColonyProfile) -> void:
	if not is_instance_valid(p_profile):
		logger.error("Cannot initialize with invalid profile")
		return

	# Store reference to profile
	profile = p_profile

	# Apply colony properties from profile
	radius = profile.radius
	dirt_color = profile.dirt_color
	darker_dirt = profile.darker_dirt

	# Setup ant profiles
	ant_profiles.clear()
	_profile_ant_map.clear()

	for ant_profile in profile.ant_profiles:
		if is_instance_valid(ant_profile):
			ant_profiles.append(ant_profile)
			_profile_ant_map[ant_profile.id] = []

	logger.debug("Colony profile applied: %s" % profile.name)

	# Spawn initial ants if we're already in the tree
	if is_inside_tree():
		_spawn_initial_ants()

## Spawn initial ants based on profile configuration
func _spawn_initial_ants() -> void:
	if not is_instance_valid(profile) or profile.initial_ants.is_empty():
		return

	logger.debug("Spawning initial ants for colony %s" % name)

	# Spawn initial ants according to profile
	for profile_id in profile.initial_ants:
		var count = profile.initial_ants[profile_id]
		var ant_profile = profile.get_ant_profile_by_id(profile_id)

		if is_instance_valid(ant_profile) and count > 0:
			var spawned = spawn_ants(count, ant_profile)
			logger.debug("Spawned %d %s ants" % [spawned.size(), ant_profile.name])

func _physics_process(delta: float) -> void:
	_process_spawning(delta)

#region Spawning Methods
## Spawns multiple ants with optional profile
func spawn_ants(num: int, p_profile: AntProfile = null) -> Array[Ant]:
	if num <= 0:
		logger.error("Cannot spawn non-positive number of ants")
		return []

	return AntManager.spawn_ants(self, num, p_profile)

## Spawns a single ant with the given profile
func spawn_ant(ant_profile: AntProfile) -> Ant:
	if not ant_profile:
		logger.error("Invalid ant profile provided")
		return null

	var _ants = AntManager.spawn_ants(self, 1, ant_profile)
	return _ants[0] if _ants.size() > 0 else null

## Processes automatic ant spawning based on profiles
func _process_spawning(_delta: float) -> void:
	for p_profile: AntProfile in ant_profiles:
		if p_profile.spawn_condition and p_profile.spawn_condition.get_value(self):
			spawn_ant(p_profile)
#endregion

## Adds an ant to this colony's management
func add_ant(ant: Ant) -> Result:
	if not ant:
		return Result.new(Result.ErrorType.INVALID_ARGUMENT, "Invalid ant")

	ants.append(ant)

	# Track ant in profile map
	if ant.role in _profile_ant_map:
		_profile_ant_map[ant.role].append(ant)

	# Add to scene tree
	if sandbox:
		sandbox.ant_container.add_child(ant)
	else:
		add_child(ant)

	ant.set_colony(self)
	return Result.new()

func _exit_tree() -> void:
	HeatmapManager.unregister_entity(self)
	EvaluationSystem.cleanup_entity(self)
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


func store_food(food: Food) -> void:
	food.set_state(Food.State.STORED)
	foods.add_food(food)

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
	for ant in ants:
		if not is_instance_valid(ant):
			continue

		var ant_role = ant.role.to_lower()
		# Check both if role contains ant's role or ant's role contains the search role
		if ant_role.contains(normalized_role) or normalized_role.contains(ant_role):
			result += 1
	return result
