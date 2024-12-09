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

var vision_range = 50.0
var movement_rate = 10.0
var energy_level = 80
var energy_max = 100
var carry_max = 100


func _init(init_as_active: bool = false) -> void:
	logger = Logger.new("ant", DebugLogger.Category.ENTITY)
	
	colony = ColonyManager.spawn_colony()
	colony.add_ant(self)
	colony.global_position = Vector2(randf_range(0, 1000), randf_range(0, 1000))
	
	action_manager = ActionManager.new()
	action_manager.initialize(self)


func _ready() -> void:
	spawned.emit()
	# Setup navigation
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0

	global_position = _get_random_position()
	if not colony:
		var c: Colony = ColonyManager.spawn_colony()
		c.global_position = _get_random_position()
		set_colony(c)
	
	var food: Food = FoodManager.spawn_food()
	food.global_position = global_position
	var rand_move: Action = load("res://resources/actions/wander_for_food.tres") as Action
	action_manager.register_action(rand_move)
	var store_food: Action = load("res://resources/actions/store_food.tres")
	action_manager.register_action(store_food)
	var move_to_food: Action = load("res://resources/actions/move_to_food.tres")
	action_manager.register_action(move_to_food)

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
