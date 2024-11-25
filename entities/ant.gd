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
var nav_agent: NavigationAgent2D

## Task update timer
var task_update_timer: float = 0.0

## Property access system
var _property_access: PropertyAccess :
	get:
		return _property_access

#endregion

## Default category for logging
@export var log_category: DebugLogger.Category = DebugLogger.Category.ENTITY

## Source identifier for logging
@export var log_from: String :
	set(value):
		log_from = value
		_configure_logger()

## Array of additional categories this node can log to
@export var additional_log_categories: Array[DebugLogger.Category] = []

func _init(init_as_active: bool = false) -> void:
	log_from = "ant"
	
	_init_property_access()
	_init_property_groups()
	
	# In case we don't want to start behavior immediately
	if init_as_active:
		_init_task_tree()
	

func _ready() -> void:
	spawned.emit()

func _process(delta: float) -> void:
	task_update_timer += delta
	if task_update_timer >= 1.0:
		task_tree.update(delta)
		task_update_timer = 0.0

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
func perform_action(_action: Action, args = []) -> void:
	# Implement ant behavior here
	var time_for_action: float = 1.0
	var event_str: String = "Ant is performing action:"
	event_str += " "
	event_str += _action.name if _action else "N/A"
	event_str += " "
	event_str += "%.2f" % time_for_action
	event_str += " "
	event_str += "second" if time_for_action == 1.0 else "seconds"
	event_str += " "
	event_str += "with %s %s" % ["argument" if args.size() == 1 else "arguments", args]
	_debug(event_str)
	await get_tree().create_timer(1).timeout
	action_completed.emit()
#endregion

#region Property System
## Initialize the property access system
func _init_property_access() -> void:
	_debug("Initializing new property access system")
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
	_trace("Initializing ant property nodes...")

	var nodes = [
		Energy.new(self),        # Energy management
		Health.new(self),        # Health management
		Speed.new(self),         # Movement and action rates
		Strength.new(self),      # Base strength attributes
		Storage.new(self),       # Item storage capacity
		Vision.new(self),        # Visual perception
		Olfaction.new(self),     # Scent detection
		Reach.new(self),         # Interaction range
		Proprioception.new(self) # Position awareness
	]
	var successes: int = 0
	var failures: int = 0

	for node in nodes:
		var result = register_property_node(node)
		if result.success():
			successes += 1
			_trace("Ant property %s registered successfully" % node.name)
		else:
			failures += 1
			_error("Ant property %s failed to register" % node.name)

	_trace("Ant property group initialization complete - %d components registered successfully, %d failed" % [successes, failures])

## Register colony-specific properties
func _register_colony_properties() -> void:
	if not _colony:
		_warn("Cannot register colony properties: no colony reference available")
		return

	var node: PropertyNode = _colony.get_as_node()
	if not node:
		_error("Failed to get colony property node for ant property registration")
		return

	var result: Result = register_property_node(node)
	if result.success():
		_trace("Colony properties registered successfully to ant")
	else:
		_error("Colony properties not registered to ant -> %s" % result.error_message)

func _init_task_tree() -> void:
	_trace("Initializing ant task_tree")
	task_tree = TaskTree.create(self)\
		.with_root_task("CollectFood")\
		.build()
	if task_tree and task_tree.get_active_task():
		_trace("Ant task_tree initialized successfully")
		task_tree.active_task_changed.connect(_on_active_task_changed)
		task_tree.active_behavior_changed.connect(_on_active_behavior_changed)
	else:
		_error("Ant task_tree failed to be initialized")

#region Property Access Interface
## Get a property node by path
func get_property(path: Path) -> PropertyNode:
	if not _property_access:
		_error("Cannot get ant property: ant property access system not initialized")
		return null
	return _property_access.get_property(path)

## Get a property value by path
func get_property_value(path: Path) -> Variant:
	if not _property_access:
		_error("Cannot get ant property value: ant property access system not initialized")
		return null
	return _property_access.get_property_value(path)

## Set a property value by path string
func set_property_value(path: Path, value: Variant) -> Result:
	if not _property_access:
		return Result.new(
			Result.ErrorType.SYSTEM_ERROR,
			"Cannot set ant property value: ant property access system not initialized"
		)
	return _property_access.set_property_value(path, value)

## Find a property node by path
func find_property_node(path: Path) -> PropertyNode:
	if not _property_access:
		_error("Cannot find ant property node: ant property access system not initialized")
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
		_error("Cannot get ant property root: %s -> Ant property access system not initialized" % root_name)
		return null
	return _property_access.get_root_node(root_name)

## Get all value nodes in a root by root name
func get_root_values(root_name: String) -> Array[PropertyNode]:
	if not _property_access:
		_error("Cannot get ant property root values: %s -> Ant property access system not initialized" % root_name)
		return []
	return _property_access.get_root_values(root_name)

## Get all registered root names
func get_root_names() -> Array[String]:
	if not _property_access:
		_error("Cannot get ant property root names -> Ant property access system not initialized")
		return []
	return _property_access.get_root_names()

## Get all containers under a root node
func get_root_containers(root_name: String) -> Array[PropertyNode]:
	if not _property_access:
		_error("Cannot get ant property containers for root: %s -> Ant property access system not initialized" % root_name)
		return []
	return _property_access.get_root_containers(root_name)
#endregion

func _configure_logger() -> void:
	var categories = [log_category] as Array[DebugLogger.Category]
	categories.append_array(additional_log_categories)
	DebugLogger.configure_source(log_from, true, categories)

#region Logging Methods
func _trace(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.trace(category, message, {"from": log_from})

func _debug(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.debug(category, message, {"from": log_from})

func _info(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.info(category, message, {"from": log_from})

func _warn(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.warn(category, message, {"from": log_from})

func _error(message: String, category: DebugLogger.Category = log_category) -> void:
	DebugLogger.error(category, message, {"from": log_from})
#endregion
