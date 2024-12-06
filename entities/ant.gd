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
var _colony: Colony : set = set_colony

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

## Property access system
var _property_access: PropertyAccess :
	get:
		return _property_access

var logger: Logger
#endregion


var vision_range = 50.0
var movement_rate = 10.0
var storing_rate = 13.0
var harvesting_rate = 4.0

func _init(init_as_active: bool = false) -> void:
	logger = Logger.new("ant", DebugLogger.Category.ENTITY)
	_init_property_access()
	_init_property_groups()

	# In case we don't want to start behavior immediately
	if init_as_active:
		_init_task_tree()



func _ready() -> void:
	spawned.emit()
	# Setup navigation
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0

func _physics_process(delta: float) -> void:
	if velocity:
		move_and_slide()


#region Colony Management
func set_colony(p_colony: Colony) -> void:
	if _colony != p_colony:
		_colony = p_colony
#endregion

#region Event Handlers
func _on_active_behavior_changed(_new_behavior: Behavior) -> void:
	pass

func _on_active_task_changed(_new_task: Task) -> void:
	pass
#endregion

#region Action Methods
## Placeholder for actions
func perform_action(action: Action, _args: Dictionary = {}) -> void:
	var event_str: String = "Ant is performing action:"
	event_str += " "
	event_str += action.description if action.description else "N/A"
	logger.trace(event_str)

	match action.base_name:
		"store":
			if foods.is_empty():
				action_completed.emit()
			else:
				await get_tree().create_timer(action.duration).timeout
				foods.clear()

		"move":
			if get_property_value("proprioception.status.at_target"):
				action_completed.emit()
			else:
				await get_tree().create_timer(action.duration).timeout
				var target_position: Vector2 = get_property_value("proprioception.base.target_position")
				if target_position and global_position != target_position:
					global_position = target_position
					logger.debug("Ant moved to position: %s" % target_position)

		"harvest":
			if get_property_value("storage.status.is_full"):
				action_completed.emit()
			else:
				await get_tree().create_timer(action.duration).timeout
				# TODO: Add actual harvesting logic here
				foods.add_food(get_property_value("storage.capacity.max"))

		"follow_pheromone":
			await get_tree().create_timer(action.duration).timeout
			# TODO: Add pheromone following logic here
			action_completed.emit()

		"random_move":
			await get_tree().create_timer(action.duration).timeout
			# Movement handled by action params setting target position
			action_completed.emit()

		"rest":
			await get_tree().create_timer(action.duration).timeout
			# TODO: Add rest/energy recovery logic here
			action_completed.emit()

		_:
			logger.warn("Unknown action type: %s" % action.base_name)
			await get_tree().create_timer(action.duration).timeout
			action_completed.emit()
#endregion

#region Property System
## Initialize the property access system
func _init_property_access() -> void:
	logger.debug("Initializing new property access system")
	_property_access = PropertyAccess.new(self)





## Initialize all component property nodes
func _init_property_groups() -> void:
	logger.trace("Initializing ant property nodes...")

	var trees = [
		Proprioception.new(self),
		Vision.new(self),
		World.new(self)
	]

	var successes: int = 0
	var failures: int = 0

	for tree: PropertyNode in trees:
		var result = _property_access.register_node_tree(tree)
		if result.success():
			successes += 1
			logger.trace("Ant property %s registered successfully" % tree.name)
		else:
			failures += 1
			logger.error("Ant property %s failed to register" % tree.name)

	logger.trace("Ant property group initialization complete - %d components registered successfully, %d failed" % [successes, failures])
## Register colony-specific properties

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

#region Property Access Interface
## Get a property node with validation and error handling
func get_property(path: Variant) -> PropertyNode:
	# Validate system state
	if not _validate_system_state():
		return null

	return _property_access.get_property(path)

## Get a property value with comprehensive error handling
func get_property_value(path: Variant) -> Variant:
	# Validate system state
	if not _validate_system_state():
		return null

	return _property_access.get_property_value(path)

## Set a property value with validation and error handling
func set_property_value(path: Variant, value: Variant) -> Result:
	# Validate system state
	if not _validate_system_state():
		return Result.new(
			Result.ErrorType.SYSTEM_ERROR,
			"PropertyAccess not initialized for ant"
		)

	return _property_access.set_property_value(path, value)

#endregion

#region Helper Methods
## Validate that the property system is initialized
func _validate_system_state() -> bool:
	if not _property_access:
		return false
	return true

## Validate a property node exists
func _validate_property_node(node: PropertyNode, path: Path) -> bool:
	if not node:
		return false
	return true
#endregion

#region Type Checking and Validation
## Check if a property exists
func has_property(path: Variant) -> bool:
	var node = get_property(path)
	return node != null

## Get the type of a property
func get_property_type(path: Variant) -> Property.Type:
	var node = get_property(path)
	if not node:
		return Property.Type.UNKNOWN
	return node.value_type

## Check if a property is a specific type
func is_property_type(path: Variant, type: Property.Type) -> bool:
	return get_property_type(path) == type
#endregion
