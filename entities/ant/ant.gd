class_name Ant
extends CharacterBody2D

#region Signals
signal spawned
signal food_spotted
signal ant_spotted
signal action_completed
signal pheromone_sensed
signal damaged
signal died
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

var action_manager: ActionManager

## The navigation agent for this ant
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D

var target_position: Vector2


## Task update timer
var task_update_timer: float = 0.0
var logger: Logger
#endregion

@onready var sight_area: Area2D = %SightArea
@onready var sense_area: Area2D = %SenseArea
@onready var reach_area: Area2D = %ReachArea

var vision_range: float = 50.0
var movement_rate: float = 10.0
var energy_level: float = randf_range(50, 100)
var energy_max: float = 100
var carry_max: float = 100
var health_level: float = randf_range(50, 100)
var health_max: float = 100


func _init() -> void:
	logger = Logger.new("ant", DebugLogger.Category.ENTITY)
	action_manager = ActionManager.new()
	
func _ready() -> void:
	# Initialize components
	action_manager.initialize(self)
	
	# Initialize state
	_initialize_state()
	_load_actions()
	
	# Emit ready signal
	spawned.emit()

func _initialize_state() -> void:
	energy_level = randf_range(50, energy_max)
	health_level = randf_range(50, health_max)
	
	# Setup navigation
	%NavigationAgent2D.path_desired_distance = 4.0
	%NavigationAgent2D.target_desired_distance = 4.0
	
	# Set initial position
	global_position = _get_random_position()
	
	# Initialize colony if needed
	if not colony:
		var new_colony := ColonyManager.spawn_colony()
		new_colony.global_position = _get_random_position()
		set_colony(new_colony)

func _load_actions() -> void:
	var actions := [
		preload("res://resources/actions/store_food.tres"),
		preload("res://resources/actions/move_to_food.tres"),
		preload("res://resources/actions/wander_for_food.tres"),
		preload("res://resources/actions/move_to_home.tres"),
		preload("res://resources/actions/harvest_food.tres")
	]
	
	for action in actions:
		action_manager.register_action(action)
	
	action_manager.update()

func _physics_process(delta: float) -> void:
	task_update_timer += delta
	action_manager.update(delta)
	
#region Colony Management
func set_colony(p_colony: Colony) -> void:
	if colony != p_colony:
		colony = p_colony
#endregion

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

func get_pheromones_sensed(pheromone_type: String = "") -> Array:
	var pheromones: Array = []
	for pheromone in sight_area.get_overlapping_bodies():
		if pheromone is Pheromone and pheromone != null:
			if not pheromone_type or pheromone_type == pheromone.type:
				pheromones.append(pheromone)
	if pheromone_type == "penis":
		return Array(["penis"])
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
