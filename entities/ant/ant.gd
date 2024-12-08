class_name Ant
extends CharacterBody2D

#region Signals
signal spawned
signal food_spotted(food: Node2D)
signal ant_spotted(ant: Ant)
signal action_completed
signal pheromone_sensed(pheromone: Node2D)
signal damaged(amount: float)
signal died
#endregion

#region Constants
const DEFAULT_CONFIG_ROOT = "res://config/"
const DEFAULT_VISION_RANGE = 50.0
const DEFAULT_MOVEMENT_RATE = 10.0
const DEFAULT_ENERGY_MAX = 100
const DEFAULT_CARRY_MAX = 100
#endregion

#region Properties
## The unique identifier for this ant
var id: int

## The role of this ant in the colony
var role: String

## The colony this ant belongs to
var colony: Colony:
	set(value):
		if colony != value:
			colony = value
			_on_colony_changed()

## The foods being carried by the ant
var foods: Foods:
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

## Current target position for movement
var target_position: Vector2:
	set(value):
		if target_position != value:
			target_position = value
			if nav_agent:
				nav_agent.target_position = value

## Vision range for detecting objects
var vision_range: float = DEFAULT_VISION_RANGE

## Movement speed
var movement_rate: float = DEFAULT_MOVEMENT_RATE

## Current energy level
var energy_level: float = DEFAULT_ENERGY_MAX * 0.8:
	set(value):
		energy_level = clampf(value, 0, energy_max)
		if energy_level <= 0:
			_handle_death()

## Maximum energy capacity
var energy_max: float = DEFAULT_ENERGY_MAX

## Maximum carry capacity
var carry_max: float = DEFAULT_CARRY_MAX

## Logger instance
var logger: Logger
#endregion

#region Initialization
func _init(init_as_active: bool = true) -> void:
	logger = Logger.new("ant", DebugLogger.Category.ENTITY)
	
	if init_as_active:
		_init_task_tree()

func _ready() -> void:
	_setup_navigation()
	_initialize_position()
	_setup_colony()
	_load_behaviors()
	
	spawned.emit()

func _physics_process(delta: float) -> void:
	if velocity:
		move_and_slide()
		_update_energy(delta)
#endregion

#region Public Methods
## Handle the ant taking damage
func take_damage(amount: float) -> void:
	energy_level -= amount
	damaged.emit(amount)
	
## Check if ant can carry more items
func can_carry_more() -> bool:
	return foods.get_total_weight() < carry_max

## Get current carried weight
func get_carried_weight() -> float:
	return foods.get_total_weight()

## Get remaining carry capacity
func get_remaining_capacity() -> float:
	return carry_max - get_carried_weight()
#endregion

#region Private Methods
## Initialize the task tree system
func _init_task_tree() -> void:
	logger.trace("Initializing ant task_tree")
	
	task_tree = TaskTree.create(self).build()
	task_tree.root_task = load("res://resources/tasks/collect_food.tres") as Task
	add_child(task_tree, true)
	
	if task_tree and task_tree.get_active_task():
		logger.trace("Ant task_tree initialized successfully")
		task_tree.active_task_changed.connect(_on_active_task_changed)
		task_tree.active_behavior_changed.connect(_on_active_behavior_changed)
	else:
		logger.error("Ant task_tree failed to be initialized")

## Setup navigation agent parameters
func _setup_navigation() -> void:
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.velocity_computed.connect(_on_velocity_computed)

## Initialize starting position
func _initialize_position() -> void:
	global_position = _get_random_position()

## Setup colony association
func _setup_colony() -> void:
	if not colony:
		var new_colony: Colony = ColonyManager.spawn_colony()
		new_colony.global_position = _get_random_position()
		set_colony(new_colony)

## Load and initialize behaviors
func _load_behaviors() -> void:
	var behavior_configs := _load_behavior_configs()
	for config in behavior_configs:
		config.initialize(self)

## Load behavior configurations
func _load_behavior_configs() -> Array:
	var configs: Array = []
	var dir := DirAccess.open(DEFAULT_CONFIG_ROOT + "behaviors")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				var config = load(DEFAULT_CONFIG_ROOT + "behaviors/" + file)
				if config is BehaviorConfig:
					configs.append(config)
	return configs

## Update energy based on activities
func _update_energy(delta: float) -> void:
	# Basic energy consumption from movement
	if velocity.length() > 0:
		energy_level -= delta * 0.1 * velocity.length() / movement_rate
	
	# Energy consumption from carrying items
	if not foods.is_empty():
		energy_level -= delta * 0.05 * foods.get_total_weight() / carry_max

## Handle ant death
func _handle_death() -> void:
	logger.info("Ant %s has died" % id)
	died.emit()
	queue_free()

## Get a random position within viewport
func _get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)
#endregion
#region Colony Management
func set_colony(p_colony: Colony) -> void:
	if colony != p_colony:
		colony = p_colony
#endregion
#region Event Handlers
func _on_active_behavior_changed(new_behavior: Behavior) -> void:
	if new_behavior:
		logger.trace("Behavior changed to: %s" % new_behavior.name)

func _on_active_task_changed(new_task: Task) -> void:
	if new_task:
		logger.trace("Task changed to: %s" % new_task.name)

func _on_colony_changed() -> void:
	logger.info("Ant %s assigned to colony %s" % [id, colony.id if colony else "None"])

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity * movement_rate
#endregion
