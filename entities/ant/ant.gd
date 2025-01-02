@icon("res://assets/entities/Ant.svg")
class_name Ant
extends CharacterBody2D

#region Signals
signal spawned
signal energy_changed
@warning_ignore("unused_signal")
signal damaged
signal died(ant: Ant)
## Signal emitted when movement is completed
signal movement_completed(success: bool)

## Enum for movement states
enum MoveState {
	IDLE,
	MOVING,
	INTERRUPTED
}

#endregion
## Current movement state
var move_state: MoveState = MoveState.IDLE
## Movement target position
var movement_target: Vector2
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
@onready var influence_manager: InfluenceManager = $InfluenceManager
@onready var evaluation_system: EvaluationSystem = $InfluenceManager/EvaluationSystem
#endregion
@export var influences: Array[Influence]

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

var vision_range: float = 50.0 # TODO: Should be tied to sight_area.radius
var olfaction_range: float = 200.0 # TODO: Should be tied to sense_area.radius
var movement_rate: float = 25.0
const ENERGY_DRAIN_FACTOR = 0.000005
var energy_drain: float :
	get:
		return ENERGY_DRAIN_FACTOR * (foods.mass + ant_mass) * pow(movement_rate, 1.2)

var ant_mass: float = 10.0
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

func _ready() -> void:
	# Initialize components

	# Initialize state
	_initialize_state()

	influence_manager.initialize(self)
	influence_manager.add_profile(load("res://resources/influences/profiles/look_for_food.tres").duplicate())
	influence_manager.add_profile(load("res://resources/influences/profiles/go_home.tres").duplicate())
	# Setup navigation
	heatmap = get_tree().get_first_node_in_group("heatmap")
	heatmap.register_entity(self)

	# Emit ready signal
	spawned.emit()

func _initialize_state() -> void:
	energy_level = energy_max
	health_level = health_max


func _physics_process(delta: float) -> void:
	task_update_timer += delta
	# Don't process movement if dead
	if dead:
		return

	# Energy consumption
	if energy_level > 0:
		var energy_cost = calculate_energy_cost(delta)
		energy_level -= energy_cost

	# Try to harvest food if we have capacity
	if foods.mass < carry_max:
		if harvest_food():
			return  # Skip movement this frame if we harvested food

	_process_movement(delta)

## Moves the ant to the specified position
func move_to(target_pos: Vector2) -> void:
	# Update movement state
	move_state = MoveState.MOVING
	movement_target = target_pos

	# Set the navigation target
	nav_agent.set_target_position(target_pos)

## Stops the current movement
func stop_movement() -> void:
	move_state = MoveState.INTERRUPTED
	velocity = Vector2.ZERO
	movement_completed.emit(false)

func harvest_food() -> bool:
	# Don't harvest if we're at capacity
	if foods.mass >= carry_max:
		return false

	var foods_in_reach = get_foods_in_reach()
	if foods_in_reach.is_empty():
		return false

	# Sort foods by distance to optimize harvesting
	foods_in_reach.sort_custom(func(a: Food, b: Food) -> bool:
		var dist_a = global_position.distance_squared_to(a.global_position)
		var dist_b = global_position.distance_squared_to(b.global_position)
		return dist_a < dist_b
	)

	var amount_harvested := 0.0
	for food in foods_in_reach:
		if not is_instance_valid(food) or not food.is_available:
			continue

		var space_remaining = carry_max - foods.mass
		if space_remaining <= 0:
			break

		var amount_to_take = minf(space_remaining, food.mass)
		foods.add_food(amount_to_take)
		food.remove_amount(amount_to_take)
		amount_harvested += amount_to_take

		# Remove depleted food
		if food.mass <= 0.0:
			food.queue_free()

		if foods.mass >= carry_max:
			break

	return amount_harvested > 0

#region Movement Processing
func _process_movement(delta: float) -> void:
	var current_pos = global_position
	
	# Check if we need a new target - delegated to InfluenceManager
	if influence_manager.should_recalculate_target():
		influence_manager.update_movement_target()
	
	# If we have no valid path, stop moving
	if not nav_agent.is_target_reachable():
		velocity = Vector2.ZERO
		return
		
	# Calculate movement
	var next_pos = nav_agent.get_next_path_position()
	var move_direction = (next_pos - current_pos).normalized()
	var target_velocity = move_direction * movement_rate
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(target_velocity)
	else:
		target_velocity = velocity.lerp(target_velocity, 0.15)
		_on_navigation_agent_2d_velocity_computed(target_velocity)

func calculate_energy_cost(delta: float) -> float:
	var movement_cost = energy_drain * velocity.length()
	return movement_cost * delta
#endregion

#region Navigation Agent Callbacks
func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	if safe_velocity.length() > 0.0:
		var target_angle = safe_velocity.angle()
		global_rotation = target_angle
	move_and_slide()

func _on_navigation_agent_2d_target_reached() -> void:
	if move_state == MoveState.MOVING:
		move_state = MoveState.IDLE
		movement_completed.emit(true)

func _on_navigation_agent_2d_path_changed() -> void:
	# Could update path visualization here
	if nav_agent.debug_enabled:
		show_nav_path(true)
	move_state = MoveState.MOVING
#endregion


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

func get_pheromone_direction(follow_concentration: bool = true) -> Vector2:
	# When follow_concentration is true, move towards higher concentrations
	# When false, move away from high concentrations
	var dir: int = -1 if follow_concentration else 1
	return heatmap.get_heat_direction(colony, global_position) * dir

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

func get_nearest_food_direction() -> Vector2:
	var nearest_food: Food = get_nearest_item(get_food_in_view())
	if nearest_food and nearest_food is Food:
		return global_position.direction_to(nearest_food.global_position)
	return Vector2.ZERO

func show_influence_vectors(_enabled: bool):
	pass

func show_nav_path(enabled: bool):
	nav_agent.debug_enabled = enabled

func _exit_tree() -> void:
	if nav_agent and nav_agent.get_rid().is_valid():
		NavigationServer2D.free_rid(nav_agent.get_rid())
	heatmap.unregister_entity(self)
