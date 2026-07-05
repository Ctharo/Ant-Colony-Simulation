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

@export var pheromones: Array[Pheromone]
var pheromone_memories: Dictionary[String, PheromoneMemory] = {}  # String -> PheromoneMemory
#region Movement
enum PHEROMONE_TYPES { HOME, FOOD }
## Movement target position
var movement_target: Vector2
#endregion

#region Constants
const DEFAULT_CONFIG_ROOT = "res://config/"

## Methods that AntAction resources are allowed to invoke. Anything not in
## this list is rejected by BehaviorManager — the safety boundary that makes
## runtime/UI-authored behavior safe.
const ACTION_API: Array[String] = [
	"harvest_food",
	"store_food",
	"rest_until_full",
	"move_to",
	"stop_movement",
]

## Fallback rules preserving pre-refactor behavior for profiles that don't
## define their own behavior_rules.
const DEFAULT_BEHAVIOR_RULES: Array[String] = [
	"res://resources/behavior/rules/rule_harvest.tres",
	"res://resources/behavior/rules/rule_store.tres",
	"res://resources/behavior/rules/rule_rest.tres",
]

const _SHOULD_REST: Logic = preload("res://resources/expressions/conditions/should_rest.tres")
const _IS_FULLY_RESTED: Logic = preload("res://resources/expressions/conditions/is_fully_rested.tres")

#endregion

#region Member Variables
## The unique identifier for this ant
var id: int :
	set(value):
		id = value
		logger = iLogger.new("ant_%d" % id, DebugLogger.Category.ENTITY)
## The role of this ant in the colony
var role: String
var profile: AntProfile
## The colony this ant belongs to
var colony: Colony : set = set_colony

var _carried_food: Food 
var is_carrying_food: bool :
	get: return is_instance_valid(_carried_food)

#region Components
@onready var influence_manager: InfluenceManager = $InfluenceManager
var behavior_manager: BehaviorManager
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D
@onready var sight_area: Area2D = %SightArea
@onready var reach_area: Area2D = %ReachArea
@onready var mouth_marker: Marker2D = %MouthMarker
var _senses: AntSenses
#endregion

#region Actions
enum Action {
	MOVE = 0,
	HARVEST = 1,
	STORE = 2,
	REST = 3
}

var action_map: Dictionary[Action, Callable] = {
	Action.MOVE: move_to
}
#endregion

## Setting will call [method NavigationAgent2D.set_target_position]
var target_position: Vector2 :
	get:
		return nav_agent.target_position
	set(value):
		nav_agent.set_target_position(value)
		logger.trace("Target position set to %s" % value)
		

var task_update_timer: float = 0.0
var logger: iLogger
#endregion

var is_dead: bool = false

var vision_range: float = 100.0 :
	set(value):
		vision_range = value
		if is_inside_tree() and $SightArea/CollisionShape2D:
			$SightArea/CollisionShape2D.shape.radius = vision_range

var movement_rate: float = 25.0
var resting_rate: float = 20.0

const ENERGY_MAX: float = 100
const ENERGY_DRAIN_FACTOR: float = 0.015 

var energy_level: float = ENERGY_MAX :
	set(value):
		var first: int = int(energy_level)
		energy_level = min(maxf(value, 0.0), ENERGY_MAX)
		if first != int(energy_level):
			energy_changed.emit()
		if energy_level == 0.0:
			suicide()

const CARRY_MAX: int = 1
const HEALTH_MAX: float = 100
var health_level: float = HEALTH_MAX :
	set(value):
		health_level = min(maxf(value, 0.0), HEALTH_MAX)
		if health_level == 0.0:
			suicide()

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var doing_task: bool = false
var _profile_pending: AntProfile = null  # Store profile for deferred init

func _init() -> void:
	logger = iLogger.new("ant_%s" % id, DebugLogger.Category.ENTITY)

func _ready() -> void:
	var sight_shape: CollisionShape2D = $SightArea/CollisionShape2D
	sight_shape.shape = sight_shape.shape.duplicate()
	var reach_shape: CollisionShape2D = $ReachArea/CollisionShape2D
	reach_shape.shape = reach_shape.shape.duplicate()	
		# Initialize influence manager
	influence_manager.initialize(self)

	# Apply pending profile if set before ready
	if _profile_pending:
		_apply_profile_internal(_profile_pending)
		_profile_pending = null
	elif profile:
		_apply_profile_internal(profile)

	behavior_manager = BehaviorManager.new()
	add_child(behavior_manager)
	behavior_manager.initialize(self)
	for path in DEFAULT_BEHAVIOR_RULES:
		behavior_manager.add_rule(load(path))

	register_to_heatmap()
	
	#FIXME What is this for??
	# Ensure food is positioned correctly with respect to ant reach and carry position
	var food: Food = load("res://entities/food/food.tscn").instantiate()
	$ReachArea/CollisionShape2D.shape.radius = mouth_marker.position.x - food.get_size()
	food.queue_free()

	# Emit ready signal
	spawned.emit()

## Registers self to [class HeatmapManager]
func register_to_heatmap() -> void:
	HeatmapManager.register_entity(self)
	for pheromone in pheromones:
		HeatmapManager.create_heatmap_type(pheromone)

## Initialize with profile - handles both before and after _ready
func init_profile(p_profile: AntProfile) -> void:
	profile = p_profile

	# If not in tree yet, defer the influence setup
	if not is_inside_tree() or not influence_manager:
		_profile_pending = p_profile
		return

	_apply_profile_internal(p_profile)

## Internal method to apply profile when influence_manager is ready
func _apply_profile_internal(p_profile: AntProfile) -> void:
	if not influence_manager:
		push_error("Cannot apply profile - influence_manager not ready")
		return

	for influence: InfluenceProfile in p_profile.movement_influences:
		influence_manager.add_profile(influence)

	# Profile-defined rules replace the defaults; empty means keep defaults
	if behavior_manager and not p_profile.behavior_rules.is_empty():
		behavior_manager.clear_rules()
		behavior_manager.add_rules(p_profile.behavior_rules)

func _physics_process(delta: float) -> void:
	task_update_timer += delta

	if is_dead:
		return

	_process_carrying()
	_consume_energy_process(delta)

	if doing_task:
		return

	# Data-driven behavior: first matching rule (by priority) acts this tick
	if behavior_manager and behavior_manager.process_rules():
		return

	# Default fall-through: influence-driven movement
	_process_movement(delta)
	
func _consume_energy_process(delta: float) -> void:
	if energy_level > 0 and not is_colony_in_range():
		var energy_cost = calculate_energy_cost(delta)
		energy_level -= energy_cost
		
## Moves the ant to the specified position
func move_to(target_pos: Vector2) -> bool:
	movement_target = target_pos

	# Set the navigation target
	nav_agent.set_target_position(target_pos)
	return true

## Stops the current movement
func stop_movement() -> void:
	velocity = Vector2.ZERO
	movement_completed.emit(false)

func _process_carrying() -> void:
	if is_instance_valid(_carried_food):
		_carried_food.global_position = mouth_marker.global_position
		_carried_food.rotation = rotation

func _process_resting(delta: float) -> void:
	health_level += resting_rate * delta
	energy_level += resting_rate * delta

func store_food() -> void:
	doing_task = true
	await get_tree().create_timer(1.0).timeout
	if is_dead or not is_inside_tree():
		doing_task = false
		return
	if is_instance_valid(colony) and is_instance_valid(_carried_food):
		colony.store_food(_carried_food)
	_carried_food = null
	doing_task = false
 
func rest_until_full() -> void:
	doing_task = true
	while not is_fully_rested():
		await get_tree().create_timer(0.5).timeout
		if is_dead or not is_inside_tree():
			doing_task = false
			return
		_process_resting(0.5)
	doing_task = false

func _process_movement(delta: float) -> void:
	if not is_instance_valid(nav_agent):
		return

	var current_pos = global_position
	_process_pheromones(delta)


	if influence_manager.should_recalculate_target():
		influence_manager.update_movement_target()

	var next_pos = nav_agent.get_next_path_position()
	var move_direction = (next_pos - current_pos).normalized()
	var target_velocity = move_direction * movement_rate


	target_velocity = velocity.lerp(target_velocity, 0.15)
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = target_velocity  # agent emits velocity_computed
	else:
		_on_navigation_agent_2d_velocity_computed(target_velocity)

## Pheromone handles checking condition and emitting if necessary
func _process_pheromones(delta: float):
	for pheromone: Pheromone in pheromones:
		pheromone.check_and_emit(self, delta)

func calculate_energy_cost(delta: float) -> float:
	var movement_cost = (ENERGY_DRAIN_FACTOR + float(is_carrying_food) * 0.01) * velocity.length()
	return movement_cost * delta


#region Navigation

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

func is_navigation_finished() -> bool:
	return nav_agent.is_navigation_finished()

func show_nav_path(enabled: bool) -> void:
	nav_agent.debug_enabled = enabled
	
#endregion

func harvest_food():
	doing_task = true
	var foods_in_reach = get_food_in_reach()
	if foods_in_reach.is_empty():
		doing_task = false
		return

	# Sort foods by distance
	foods_in_reach.sort_custom(func(a: Food, b: Food) -> bool:
		var dist_a = global_position.distance_squared_to(a.global_position)
		var dist_b = global_position.distance_squared_to(b.global_position)
		return dist_a < dist_b
	)

	var food = foods_in_reach[0]
	if is_instance_valid(food) and food.is_available:
		food.set_state(Food.State.CARRIED)
		food.global_position = mouth_marker.global_position
		_carried_food = food
		doing_task = false
	return


#region Colony Management
func set_colony(p_colony: Colony) -> void:
	if colony != p_colony:
		colony = p_colony
#endregion

## Cleans up from this perspective, AntManager receives signal and clears from all tracking
func _on_died() -> void:
	if is_carrying_food:
		_carried_food.set_state(Food.State.AVAILABLE)
	is_dead = true
	doing_task = false
	died.emit(self)

func suicide():
	self._on_died()

func _get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)



func should_rest() -> bool:
	return _SHOULD_REST.get_value(self)

func is_fully_rested() -> bool:
	return _IS_FULLY_RESTED.get_value(self)
	
	

#region Get methods
## Expressions evaluate against this facade instead of the ant itself.
func get_expression_context() -> Object:
	if not _senses:
		_senses = AntSenses.new(self)
	return _senses
func _get_in_reach(predicate: Callable) -> Array:
	return reach_area.get_overlapping_bodies().filter(predicate)

func _get_in_view(predicate: Callable) -> Array:
	return sight_area.get_overlapping_bodies().filter(predicate)
	
func get_food_in_view() -> Array:
	return _get_in_view(func(n): return n is Food and n.is_available) 

func get_food_in_reach() -> Array:
	return _get_in_reach(func(n): return n is Food and n.is_available) 

func get_ants_in_view() -> Array:
	return _get_in_view(func(n): return n is Ant and n != null) 

func get_colonies_in_view() -> Array:
	return _get_in_view(func(n): return n is Colony) 

func get_colonies_in_reach() -> Array:
	return _get_in_reach(func(n): return n is Colony) 

#endregion

func is_colony_in_range() -> bool:
	if not colony:
		return false
	return _distance_to_colony() < colony.radius

func is_colony_in_sight() -> bool:
	var a = _distance_to_colony() - colony.radius
	var b = %SightArea.get_child(0).shape.radius
	return a < b

func _distance_to_colony() -> float:
	return colony.global_position.distance_to(global_position)

func filter_friendly_ants(ants_arr: Array, friendly: bool = true) -> Array:
	return ants_arr.filter(func(ant): return friendly == (ant.colony == colony))

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

#region Pheromone Sensing
func get_pheromone_concentration(pheromone_name: String) -> float:
	return HeatmapManager.get_heat_at_position(self, pheromone_name)

## Samples heat at a location (i.e., single cell) and moves on. Develops a
## concentration vector as it continues to move and sample.
func get_pheromone_direction(pheromone_name: String, follow_concentration: bool = true) -> Vector2:
	if not is_instance_valid(colony):
		return Vector2.ZERO

	# Initialize memory for this pheromone type if needed
	if not pheromone_memories.has(pheromone_name):
		pheromone_memories[pheromone_name] = PheromoneMemory.new()

	# Get current cell position
	var current_cell: Vector2i = HeatmapManager.world_to_cell(global_position)

	# Sample current position
	var current_concentration: float = HeatmapManager.get_heat_at_position(
		self,
		pheromone_name
	)

	# Add to memory using cell coordinates
	pheromone_memories[pheromone_name].add_sample(current_cell, current_concentration)

	# Get direction based on concentration history
	var direction: Vector2 = pheromone_memories[pheromone_name].get_concentration_vector()

	# Invert direction if not following concentration
	return direction if follow_concentration else -direction

class ConcentrationSample:
	var cell_pos: Vector2i
	var concentration: float
	var timestamp: int

	func _init(p_cell_pos: Vector2i, p_concentration: float) -> void:
		cell_pos = p_cell_pos
		concentration = p_concentration
		timestamp = Time.get_ticks_msec()

class PheromoneMemory:
	var samples: Array[ConcentrationSample] = []
	var max_samples: int = 20
	var memory_duration: int = 60000  # 60 seconds
	var current_cell: Vector2i  # Track current cell to avoid duplicate samples

	func add_sample(cell_pos: Vector2i, concentration: float) -> void:
		var current_time: int = Time.get_ticks_msec()

		# Don't add sample if we're in the same cell
		if current_cell == cell_pos:
			return

		current_cell = cell_pos

		# Clean old samples
		samples = samples.filter(func(sample):
			return current_time - sample.timestamp < memory_duration
		)

		# Only store unique cell positions
		for sample in samples:
			if sample.cell_pos == cell_pos:
				sample.concentration = concentration
				sample.timestamp = current_time
				return

		# Add new sample
		var new_sample = ConcentrationSample.new(cell_pos, concentration)
		samples.append(new_sample)

		# Trim if over max
		while samples.size() > max_samples:
			samples.pop_front()

	func get_concentration_vector() -> Vector2:
		if samples.size() < 2:
			return Vector2.ZERO

		var weighted_direction := Vector2.ZERO
		var total_weight := 0.0

		# Compare each sample to find gradient
		for i in range(samples.size() - 1):
			var from_sample = samples[i]
			var to_sample = samples[i + 1]

			# Direction from older to newer sample
			var direction = Vector2(to_sample.cell_pos - from_sample.cell_pos).normalized()

			# Weight by concentration difference (positive = increasing concentration)
			var concentration_diff = to_sample.concentration - from_sample.concentration

			# More recent samples have higher weight
			var recency_weight = float(i + 1) / samples.size()

			weighted_direction += direction * concentration_diff * recency_weight
			total_weight += abs(concentration_diff) * recency_weight

		if total_weight > 0:
			return weighted_direction.normalized()
		return Vector2.ZERO
#endregion
