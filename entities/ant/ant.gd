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

#endregion
#region Movement
const STUCK_THRESHOLD: float = 5.0  # Distance to consider as "not moving"
const STUCK_TIME_THRESHOLD: float = 2.0  # Time before considering ant as stuck
enum PHEROMONE_TYPES { HOME, FOOD }
var _last_position: Vector2
var _time_at_position: float = 0.0
var _was_stuck: bool = false

## Movement target position
var movement_target: Vector2
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

var _carried_food: Food

#region Components
@onready var influence_manager: InfluenceManager = $InfluenceManager
@onready var evaluation_system: EvaluationSystem = $EvaluationSystem
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D
@onready var sight_area: Area2D = %SightArea
@onready var sense_area: Area2D = %SenseArea
@onready var reach_area: Area2D = %ReachArea
@onready var mouth_marker: Marker2D = %MouthMarker
#endregion

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

var dead: bool = false :
	set(value):
		if dead:
			return
		dead = value
		if dead:
			died.emit(self)

var vision_range: float = 100.0 # TODO: Should be tied to sight_area.radius
var olfaction_range: float = 200.0 # TODO: Should be tied to sense_area.radius
var movement_rate: float = 25.0
var harvesting_rate: float = 60.0
var storing_rate: float = 60.0
var resting_rate: float = 20.0

const ENERGY_DRAIN_FACTOR = 0.000015 # 0.000015 for reference, drains pretty slow
var energy_drain: float :
	get:
		return ENERGY_DRAIN_FACTOR * ((50 if is_carrying_food() else 0) + ant_mass) * pow(movement_rate, 1.2)

var ant_mass: float = 10.0
var energy_max: float = 100
var energy_level: float = energy_max :
	set(value):
		var first: int = int(energy_level)
		energy_level = min(maxf(value, 0.0), energy_max)
		if first != int(energy_level):
			energy_changed.emit()
		dead = energy_level == 0.0

var carry_max: int = 1
var health_max: float = 100
var health_level: float = health_max :
	set(value):
		health_level = min(maxf(value, 0.0), health_max)
		dead = health_level == 0.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var doing_task: bool = false

func _init() -> void:
	logger = Logger.new("ant", DebugLogger.Category.ENTITY)

func _ready() -> void:
	# Initialize influence manager
	influence_manager.initialize(self)
	influence_manager.add_profile(load("res://resources/influences/profiles/look_for_food.tres").duplicate())
	influence_manager.add_profile(load("res://resources/influences/profiles/go_home.tres").duplicate())
	# Register to heatmap
	heatmap = get_tree().get_first_node_in_group("heatmap")
	heatmap.register_entity(self)

	# Emit ready signal
	spawned.emit()

func _physics_process(delta: float) -> void:
	task_update_timer += delta
	# Don't process movement if dead
	if dead:
		return

	# Energy consumption
	if energy_level > 0 and not colony_in_range():
		var energy_cost = calculate_energy_cost(delta)
		energy_level -= energy_cost

	if doing_task:
		return

	# Attempt actions based on immediate conditions
	if get_foods_in_reach() and not is_carrying_food():
		harvest_food()
		return

	# If we're at colony with food, store it
	if colony_in_range() and is_carrying_food():
		store_food()
		return

	# Rest at colony if needed
	if colony_in_range() and should_rest():
		rest_until_full()
		return

	if not doing_task:
		# Basic movement processing if we're moving
		_process_movement(delta)

## Moves the ant to the specified position
func move_to(target_pos: Vector2) -> void:
	movement_target = target_pos

	# Set the navigation target
	nav_agent.set_target_position(target_pos)

## Stops the current movement
func stop_movement() -> void:
	velocity = Vector2.ZERO
	movement_completed.emit(false)

func rest_until_full() -> void:
	doing_task = true
	while not is_fully_rested():
		await get_tree().create_timer(0.5).timeout
		_process_resting(0.5)
	doing_task = false

func _process_resting(delta: float) -> void:
	health_level += resting_rate * delta
	energy_level += resting_rate * delta

func store_food() -> void:
	doing_task = true
	await get_tree().create_timer(1.0).timeout
	colony.store_food(_carried_food)
	_carried_food = null
	doing_task = false

func _process_movement(delta: float) -> void:
	if not is_instance_valid(nav_agent):
		return

	var current_pos = global_position
	_process_pheromones(delta)

	# Stuck detection logic
	if _check_if_stuck(current_pos, delta):
		# Enable best direction pathfinding
		influence_manager.use_best_direction = true
		_was_stuck = true
	else:
		# If not stuck, disable best direction
		influence_manager.use_best_direction = false
		_was_stuck = false

	if influence_manager.should_recalculate_target():
		influence_manager.update_movement_target()

	var next_pos = nav_agent.get_next_path_position()
	var move_direction = (next_pos - current_pos).normalized()
	var target_velocity = move_direction * movement_rate

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(target_velocity)
	else:
		target_velocity = velocity.lerp(target_velocity, 0.15)
		_on_navigation_agent_2d_velocity_computed(target_velocity)

func _process_pheromones(delta: float):
	var pheromone_factor: float = 1.0
	var pheromone_type: int = PHEROMONE_TYPES.FOOD if is_carrying_food() else PHEROMONE_TYPES.HOME

	if is_carrying_food():
		pheromone_factor += 2.0

	# emit pheromones
	heatmap.update_entity_heat(self, delta, pheromone_type, pheromone_factor)

func _check_if_stuck(current_pos: Vector2, delta: float) -> bool:
	if not _last_position:
		_last_position = current_pos
		return false

	# Check if we've moved less than the threshold
	if current_pos.distance_to(_last_position) < STUCK_THRESHOLD:
		_time_at_position += delta

		# Check if we've been stuck for longer than the threshold
		if _time_at_position >= STUCK_THRESHOLD:
			return true
	else:
		# Reset stuck timer if we've moved
		_time_at_position = 0.0
		_last_position = current_pos

	return false

func calculate_energy_cost(delta: float) -> float:
	var movement_cost = energy_drain * velocity.length()
	return movement_cost * delta

#region Navigation Agent Callbacks
func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	if safe_velocity.length() > 0.0:
		var target_angle = safe_velocity.angle()
		global_rotation = target_angle
	move_and_slide()

func _on_navigation_agent_2d_target_reached() -> void:
	if velocity != Vector2.ZERO:
		movement_completed.emit(true)

func _on_navigation_agent_2d_path_changed() -> void:
	# Could update path visualization here
	if nav_agent.debug_enabled:
		show_nav_path(true)
	# Path changed, continue movement
#endregion

func harvest_food():
	doing_task = true
	var foods_in_reach = get_foods_in_reach()
	if foods_in_reach.is_empty():
		return

	# Sort foods by distance
	foods_in_reach.sort_custom(func(a: Food, b: Food) -> bool:
		var dist_a = global_position.distance_squared_to(a.global_position)
		var dist_b = global_position.distance_squared_to(b.global_position)
		return dist_a < dist_b
	)

	var food = foods_in_reach[0]
	if is_instance_valid(food) and food.is_available:
		food.carried = true # Mark as carried so another doesn't try to take it
		await get_tree().create_timer(1).timeout
		food.reparent(mouth_marker)
		_carried_food = food
		doing_task = false
	return


#region Colony Management
func set_colony(p_colony: Colony) -> void:
	if colony != p_colony:
		colony = p_colony
#endregion

func is_carrying_food() -> bool:
	return is_instance_valid(_carried_food)

func is_carrying_max() -> bool:
	return is_carrying_food()

func is_navigation_finished() -> bool:
	return nav_agent.is_navigation_finished()

func should_rest() -> bool:
	return health_level < 0.9 * health_max or energy_level < 0.9 * energy_max


func is_fully_rested() -> bool:
	return health_level == health_max and energy_level == energy_max

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

func get_pheromone_direction(pheromone_type: int, follow_concentration: bool = true) -> Vector2:
	# Early exit if heatmap or colony not valid
	if not is_instance_valid(heatmap) or not is_instance_valid(colony):
		return Vector2.ZERO

	# Get base heat direction - this already handles proper thread safety internally
	var direction: Vector2 = heatmap.get_heat_direction(self, global_position, pheromone_type)

	# When follow_concentration is true, move towards higher concentrations (inverse direction)
	# When false, move away from high concentrations (keep original direction)
	return -direction if follow_concentration else direction

func get_food_pheromone_direction(follow_concentration: bool = true):
	return get_pheromone_direction(PHEROMONE_TYPES.FOOD, follow_concentration)

func get_home_pheromone_direction(follow_concentration: bool = true):
	return get_pheromone_direction(PHEROMONE_TYPES.HOME, follow_concentration)

func get_ants_in_view() -> Array:
	var ants: Array = []
	for ant in sight_area.get_overlapping_bodies():
		if ant is Ant and ant != null:
			ants.append(ant)
	return ants

func get_colonies_in_view() -> Array:
	var colonies: Array = []
	for p_colony in sight_area.get_overlapping_bodies():
		if p_colony is Colony:
			colonies.append(p_colony)
	return colonies

func get_colonies_in_reach() -> Array:
	var colonies: Array = []
	for p_colony in reach_area.get_overlapping_bodies():
		if p_colony is Colony:
			colonies.append(p_colony)
	return colonies

func filter_friendly_ants(ants: Array, friendly: bool = true) -> Array:
	return ants.filter(func(ant): return friendly == (ant.colony == colony))

func get_foods_in_reach() -> Array:
	var _foods: Array = []
	for food in reach_area.get_overlapping_bodies():
		if food is Food and food != null and food.is_available:
			_foods.append(food)
	return _foods

func colony_in_range() -> bool:
	return colony.global_position.distance_to(global_position) < colony.radius

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

func show_nav_path(enabled: bool):
	nav_agent.debug_enabled = enabled

func _exit_tree() -> void:
	if nav_agent and nav_agent.get_rid().is_valid():
		NavigationServer2D.free_rid(nav_agent.get_rid())
	heatmap.unregister_entity(self)
