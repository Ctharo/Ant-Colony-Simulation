@icon("res://assets/entities/Ant.svg")
class_name Ant
extends CharacterBody2D

#region Signals
signal spawned
signal energy_changed
signal damaged
signal died(ant: Ant)
signal ant_selected(ant: Ant)
signal ant_deselected(ant: Ant)

#endregion

#region Constants
const DEFAULT_CONFIG_ROOT = "res://config/"
#endregion

#region Member Variables
## The unique identifier for this ant
var id: int

## The role of this ant in the colony
var role: String

## The colony this ant belongs to
var colony: Colony : set = set_colony

## The foods being carried by the ant
var foods: Foods :
	get:
		if not foods:
			foods = Foods.new()
		return foods
	set(value):
		foods = value
		foods.mark_as_carried()

#region Managers
var action_manager: ActionManager
#endregion

## The navigation agent for this ant
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D
var target_position: Vector2 :
	get:
		return nav_agent.target_position
	set(value):
		nav_agent.set_target_position(value)

@onready var heatmap = HeatmapManager 


## Task update timer
var task_update_timer: float = 0.0
var logger: Logger
#endregion

@onready var sight_area: Area2D = %SightArea
@onready var sense_area: Area2D = %SenseArea
@onready var reach_area: Area2D = %ReachArea

var dead: bool = false :
	set(value):
		if dead:
			return
		dead = value
		if dead:
			died.emit(self)

var vision_range: float = 50.0
var movement_rate: float = 20.0
var energy_max: float = 100
var energy_level: float = energy_max :
	set(value):
		var first: int = int(energy_level)
		energy_level = maxf(value, 0.0)
		if first != int(energy_level):
			energy_changed.emit()
		dead = energy_level == 0.0
		
var carry_max: float = 100
var health_max: float = 100
var health_level: float = health_max :
	set(value):
		health_level = maxf(value, 0.0)
		dead = health_level == 0.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	logger = Logger.new("ant", DebugLogger.Category.ENTITY)
	action_manager = ActionManager.new()

func _ready() -> void:
	# Initialize components
	action_manager.initialize(self)

	# Initialize state
	_initialize_state()
	_load_actions()
	
	# Setup navigation
	configure_nav_agent()


	# Emit ready signal
	spawned.emit()

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			ant_selected.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Get reference to info panel (adjust the path as needed)
			ant_deselected.emit(self)

func _initialize_state() -> void:
	energy_level = randi_range(50, energy_max)
	health_level = randi_range(50, health_max)

func configure_nav_agent() -> void:
	if not nav_agent:
		logger.error("Navigation agent not initialized")
		return
	
	# Get the navigation region from the scene tree
	var nav_region = get_tree().get_first_node_in_group("navigation") as NavigationRegion2D
	if not nav_region:
		logger.error("No NavigationRegion2D found in scene")
		return
		
	# Verify and wait for navigation map
	var map_rid: RID = nav_region.get_navigation_map()
	if not map_rid.is_valid():
		logger.error("No valid navigation map found")
		return
		
	# Wait for navigation map to be ready
	while not NavigationServer2D.map_is_active(map_rid):
		await get_tree().physics_frame
	
	# Configure navigation agent properties
	nav_agent.radius = 5.0  # Reduced radius for better pathfinding
	nav_agent.neighbor_distance = 50.0  # Reduced for more focused local awareness
	nav_agent.max_neighbors = 10
	nav_agent.max_speed = movement_rate
	nav_agent.path_desired_distance = 10.0  # Shorter distance for more precise movement
	nav_agent.target_desired_distance = 5.0  # Shorter distance to target
	nav_agent.path_max_distance = 50.0  # Shorter max distance for more frequent path updates
	
	# Timing settings
	nav_agent.time_horizon_agents = 1.0
	nav_agent.time_horizon_obstacles = 0.5
	
	# Path processing configuration
	nav_agent.path_metadata_flags = NavigationPathQueryParameters2D.PathMetadataFlags.PATH_METADATA_INCLUDE_ALL
	nav_agent.path_postprocessing = NavigationPathQueryParameters2D.PathPostProcessing.PATH_POSTPROCESSING_CORRIDORFUNNEL
	nav_agent.pathfinding_algorithm = NavigationPathQueryParameters2D.PathfindingAlgorithm.PATHFINDING_ALGORITHM_ASTAR
	
	# Path simplification
	nav_agent.simplify_path = true
	nav_agent.simplify_epsilon = 0.25  # More precise path following
	
	# Navigation layers and masks
	nav_agent.navigation_layers = 1
	nav_agent.avoidance_layers = 1
	nav_agent.avoidance_mask = 1
	nav_agent.avoidance_priority = 1.0
	
	# Set the navigation map
	nav_agent.set_navigation_map(map_rid)
		
func _load_actions() -> void:
	var action_profile := load("res://resources/actions/profiles/harvester.tres").duplicate()
	action_manager.set_profile(action_profile)

func _physics_process(delta: float) -> void:
	if colony:
		action_manager.update(delta)

#region Colony Management
func set_colony(p_colony: Colony) -> void:
	if colony != p_colony:
		colony = p_colony
#endregion

func is_carrying_food() -> bool:
	return foods.mass > 0

func is_navigation_finished() -> bool:
	return nav_agent.is_navigation_finished()

func _get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)

func get_food_in_view() -> Array:
	var fiv: Array = []
	for food in sight_area.get_overlapping_bodies():
		if food is Food and food != null and food.is_available:
			fiv.append(food)
	return fiv

func get_sensed_pheromones(pheromone_type: String = "") -> Array:
	var pheromones: Array = []
	for pheromone in sight_area.get_overlapping_bodies():
		if pheromone is Pheromone and pheromone != null:
			if not pheromone_type or pheromone_type == pheromone.type:
				pheromones.append(pheromone)
	return pheromones

func get_ants_in_view() -> Array:
	var ants: Array = []
	for ant in sight_area.get_overlapping_bodies():
		if ant is Ant and ant != null:
			ants.append(ant)
	return ants

func filter_friendly_ants(ants: Array, friendly: bool = true) -> Array:
	return ants.filter(func(ant): return friendly == (ant.colony == colony))

func get_foods_in_reach() -> Array:
	var _foods: Array = []
	for food in reach_area.get_overlapping_bodies():
		if food is Food and food != null and food.is_available:
			_foods.append(food)
	return _foods

func get_nearest_item(list: Array) -> Variant:
	# Filter out nulls and find nearest item by distance
	var valid_items = list.filter(func(item): return item != null)
	var nearest = null
	var min_distance = INF

	for item in valid_items:
		var distance = global_position.distance_to(item.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = item

	return nearest

func _exit_tree() -> void:
	if nav_agent and nav_agent.get_rid().is_valid():
		NavigationServer2D.free_rid(nav_agent.get_rid())
