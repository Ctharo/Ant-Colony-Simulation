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

## The task tree for this ant
var task_tree: TaskTree

## The navigation agent for this ant
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D

var target_position: Vector2

## Task update timer
var task_update_timer: float = 0.0
var logger: Logger
#endregion

var vision_range = 50.0
var movement_rate = 10.0
var energy_level = 80
var energy_max = 100
var carry_max = 100


func _init(init_as_active: bool = false) -> void:
	logger = Logger.new("ant", DebugLogger.Category.ENTITY)

	# In case we don't want to start behavior immediately
	if init_as_active:
		_init_task_tree()

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

	var test_behavior: BehaviorConfig = load("res://resources/behaviors/wander_for_food.tres")
	test_behavior.initialize(self)
	print(test_behavior.name.to_snake_case() + " is valid: " + str(test_behavior.should_activate()))

func _physics_process(delta: float) -> void:
	if velocity:
		move_and_slide()

#region Colony Management
func set_colony(p_colony: Colony) -> void:
	if colony != p_colony:
		colony = p_colony
#endregion

#region Event Handlers
func _on_active_behavior_changed(_new_behavior: Behavior) -> void:
	pass

func _on_active_task_changed(_new_task: Task) -> void:
	pass
#endregion

#region Action Methods
### Placeholder for actions
#func perform_action(action: Action, _args: Dictionary = {}) -> Result:
	#var event_str: String = "Ant is performing action:"
	#event_str += " "
	#event_str += action.description if action.description else "N/A"
	#logger.trace(event_str)
#
	#match action.base_name:
		#"store":
			#if foods.is_empty():
				#action_completed.emit()
			#else:
				#await get_tree().create_timer(action.duration).timeout
				#foods.clear()
#
		#"move":
			#if get_property_value("proprioception.status.at_target"):
				#action_completed.emit()
			#else:
				#await get_tree().create_timer(action.duration).timeout
				#var target_position: Vector2 = get_property_value("proprioception.base.target_position")
				#if target_position and global_position != target_position:
					#global_position = target_position
					#logger.debug("Ant moved to position: %s" % target_position)
#
		#"harvest":
			#if get_property_value("storage.status.is_full"):
				#action_completed.emit()
			#else:
				#await get_tree().create_timer(action.duration).timeout
				## TODO: Add actual harvesting logic here
				#foods.add_food(get_property_value("storage.capacity.max"))
#
		#"follow_pheromone":
			#await get_tree().create_timer(action.duration).timeout
			## TODO: Add pheromone following logic here
			#action_completed.emit()
#
		#"random_move":
			#await get_tree().create_timer(action.duration).timeout
			## Movement handled by action params setting target position
			#action_completed.emit()
#
		#"rest":
			#await get_tree().create_timer(action.duration).timeout
			## TODO: Add rest/energy recovery logic here
			#action_completed.emit()
#
		#_:
			#logger.warn("Unknown action type: %s" % action.base_name)
			#await get_tree().create_timer(action.duration).timeout
			#action_completed.emit()
	#return Result.new()
#endregion

#region Property System

	
func _init_task_tree() -> void:
	logger.trace("Initializing ant task_tree")
	task_tree = TaskTree.create(self)\
		.with_root_task("CollectFood")\
		.build()
	add_child(task_tree, true)
	if task_tree and task_tree.get_active_task():
		logger.trace("Ant task_tree initialized successfully")
		task_tree.active_task_changed.connect(_on_active_task_changed)
		task_tree.active_behavior_changed.connect(_on_active_behavior_changed)
	else:
		logger.error("Ant task_tree failed to be initialized")

#endregion
func _get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)
