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
		if not _property_access:
			_init_property_access()
		return _property_access

## How long cached values remain valid (in seconds)
const CACHE_DURATIONS = {
	"pheromones": 0.1,  # Pheromone data stays valid for 0.1 seconds
	"food": 0.1,        # Food detection stays valid for 0.1 seconds
	"ants": 0.1,        # Nearby ants data stays valid for 0.1 seconds
	"colony": 0.2,      # Colony-related data stays valid for 0.2 seconds
	"stats": 0.0        # Stats are always recalculated
}
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

func _init() -> void:
	log_from = "ant"
	_init_property_groups()
	task_tree = TaskTree.create(self).with_root_task("CollectFood").build()

	if task_tree and task_tree.get_active_task():
		task_tree.active_task_changed.connect(_on_active_task_changed)
		task_tree.active_behavior_changed.connect(_on_active_behavior_changed)

	add_to_group("ant")

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
func take_damage(amount: float) -> void:
	if amount <= 0:
		return

	var current_health = get_property_value(Path.parse("health.levels.current"))
	damaged.emit()

	# Update health through property system
	_property_access.set_property_value(
		Path.parse("health.levels.current"),
		current_health - amount
	)

func emit_pheromone(type: String, concentration: float) -> void:
	_info("Emitting pheromone of type %s and concentration %.2f" % [type, concentration])
	#var new_pheromone = Pheromone.new(position, type, concentration, self)
	# Add the pheromone to the world (implementation depends on your world management system)

func perform_action(_action: Action) -> void:
	# Implement ant behavior here
	action_completed.emit()

func consume_food(amount: float) -> void:
	var consumed = foods.consume(amount)
	if consumed > 0:
		# Replenish energy through property system
		var current_energy = get_property_value(Path.parse("energy.levels.current"))
		_property_access.set_property_value(
			Path.parse("energy.levels.current"),
			current_energy + consumed
		)

func move(direction: Vector2, delta: float) -> void:
	var speed = get_property_value(Path.parse("speed.rates.movement"))
	if not speed:
		speed = 1.0
	var vector = direction * speed * delta
	_move_to(global_position + vector)

func _move_to(location: Vector2) -> void:
	#nav_agent.target_position = global_position + location
	_info("Ant would be moving now to location %s" % location)

func store_food(_colony: Colony, _time: float) -> float:
	var storing_amount: float = foods.mass()
	var total_stored = _colony.foods.add_food(storing_amount)
	_info("Stored %.2f food -> colony total: %.2f food stored" % [storing_amount, total_stored])
	foods.clear()
	return storing_amount

func attack(current_target_entity: Ant, _delta: float) -> void:
	_info("Attack action called against %s" % current_target_entity.name)
#endregion

#region Property System
func _init_property_access() -> void:
	_property_access = PropertyAccess.new(self)
	_trace("Property access system initialized")

func register_property_node(node: PropertyNode, at_path: Path = null) -> void:
	if not node:
		_warn("No node to register")
		return

	_trace("Registering property node: %s" % node.name)
	var result: Result = _property_access.register_group_at_path(node, at_path)
	if not result.success():
		_error("Failed to register property node %s: %s" % [node.name, result.error_message])
	else:
		_debug("Successfully registered property node: %s" % node.name)

func _init_property_groups() -> void:
	_debug("Initializing property nodes...")

	var nodes = [
		Energy.new(self),
		Reach.new(self),
		Vision.new(self),
		Olfaction.new(self),
		Strength.new(self),
		Health.new(self),
		Speed.new(self),
		Storage.new(self),
		Proprioception.new(self)
	]

	for node in nodes:
		register_property_node(node)

	_debug("Property group initialization complete")

func _register_colony_properties() -> void:
	if not _colony:
		_warn("Cannot register colony properties: no colony set")
		return

	var node: PropertyNode = _colony.get_as_node()
	register_property_node(node)
	_debug("Colony properties registered successfully")


#region Property Access Interface
func get_property(path: Path) -> PropertyNode:
	return _property_access.get_property(path)

func get_property_value(path: Path) -> Variant:
	return _property_access.get_property_value(path)

func set_property_value(path: String, value: Variant) -> Result:
	return _property_access.set_property_value(Path.parse(path), value)
#endregion

#region Property Node Access
func get_group_properties(group_name: String) -> Array[PropertyNode]:
	return _property_access.get_group_properties(group_name)

func get_group_names() -> Array[String]:
	return _property_access.get_group_names()
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
