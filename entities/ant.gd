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
		_register_colony_properties()


#endregion

#region Event Handlers
func _on_active_behavior_changed(_new_behavior: Behavior) -> void:
	pass

func _on_active_task_changed(_new_task: Task) -> void:
	pass
#endregion

#region Action Methods
## Placeholder for actions
func perform_action(action: Action, args: Dictionary = {}) -> void:
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

## Register a property node at the specified path
func register_property_node(node: PropertyNode, at_path: Path = null) -> Result:
	if not node:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Node to register invalid"
		)

	if not _property_access:
		return Result.new(
			Result.ErrorType.SYSTEM_ERROR,
			"Failed to register property node %s: property access not yet initialized" % [node.name]
		)
	return _property_access.register_node_at_path(node, at_path)


## Initialize all component property nodes
func _init_property_groups() -> void:
	logger.trace("Initializing ant property nodes...")
	
	var nodes = [
		PropertyNode.create_tree(PropertyFactory.create_energy_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_health_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_speed_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_strength_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_storage_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_vision_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_olfaction_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_reach_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_proprioception_resource(), self),
		PropertyNode.create_tree(PropertyFactory.create_colony_resource(), self),
	]
	
	var successes: int = 0
	var failures: int = 0
	
	for node in nodes:
		var result = register_property_node(node)
		if result.success():
			successes += 1
			logger.trace("Ant property %s registered successfully" % node.name)
		else:
			failures += 1
			logger.error("Ant property %s failed to register" % node.name)
			
	logger.trace("Ant property group initialization complete - %d components registered successfully, %d failed" % [successes, failures])
## Register colony-specific properties
func _register_colony_properties() -> void:
	if not _colony:
		logger.warn("Cannot register colony properties: no colony reference available")
		return

	var node: PropertyNode = _colony.get_as_node()
	if not node:
		logger.error("Failed to get colony property node for ant property registration")
		return

	var result: Result = register_property_node(node)
	if result.success():
		logger.trace("Colony properties registered successfully to ant")
	else:
		logger.error("Colony properties not registered to ant -> %s" % result.error_message)

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
## Get a property node by path
func get_property(path: Path) -> PropertyNode:
	if not _property_access:
		logger.error("Cannot get ant property: ant property access system not initialized")
		return null
	return _property_access.get_property(path)

## Get a property value by path
#TODO initial value should be direct? Or to property_access because we want this method to be the public entry
func get_property_value(path_string: String) -> Variant:
	if not _property_access:
		logger.error("Cannot get ant property value: ant property access system not initialized")
		return null
	return _property_access.get_property_value(Path.parse(path_string))

## Set a property value by path string
func set_property_value(path_string: String, value: Variant) -> Result:
	if not _property_access:
		return Result.new(
			Result.ErrorType.SYSTEM_ERROR,
			"Cannot set ant property value: ant property access system not initialized"
		)
	return _property_access.set_property_value(Path.parse(path_string), value)

## Find a property node by path
func find_property_node(path: Path) -> PropertyNode:
	if not _property_access:
		logger.error("Cannot find ant property node: ant property access system not initialized")
		return null

	if path.is_root():
		return null

	var root_node = get_root_node(path.get_root_name())
	if not root_node:
		return null

	if path.is_root_node():
		return root_node

	return root_node.find_node(path)
#endregion

#region Root Node Access
## Get a root node by name
func get_root_node(root_name: String) -> PropertyNode:
	if not _property_access:
		logger.error("Cannot get ant property root: %s -> Ant property access system not initialized" % root_name)
		return null
	return _property_access.get_root_node(root_name)

## Get all value nodes in a root by root name
func get_root_values(root_name: String) -> Array[PropertyNode]:
	if not _property_access:
		logger.error("Cannot get ant property root values: %s -> Ant property access system not initialized" % root_name)
		return []
	return _property_access.get_root_values(root_name)

## Get all registered root names
func get_root_names() -> Array[String]:
	if not _property_access:
		logger.error("Cannot get ant property root names -> Ant property access system not initialized")
		return []
	return _property_access.get_root_names()

## Get all containers under a root node
func get_root_containers(root_name: String) -> Array[PropertyNode]:
	if not _property_access:
		logger.error("Cannot get ant property containers for root: %s -> Ant property access system not initialized" % root_name)
		return []
	return _property_access.get_root_containers(root_name)
#endregion
