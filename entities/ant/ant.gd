@icon("res://assets/entities/Ant.svg")
class_name Ant
extends CharacterBody2D

## TODO: Functional programming

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
#endregion

#region Member Variables
## The unique identifier for this ant
var id: int
## The role of this ant in the colony
var role: String
var profile: AntProfile
## The colony this ant belongs to
var colony: Colony : set = set_colony
var is_carrying_food: bool
var _carried_food: Food :
	set(value):
		_carried_food = value
		if _carried_food:
			is_carrying_food = true
		else:
			is_carrying_food = false

#region Components
## Action manager for handling actions
@onready var action_manager: AntActionManager = $ActionManager
@onready var influence_manager: InfluenceManager = $InfluenceManager
@onready var behavior_manager: AntBehaviorManager
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D
@onready var sight_area: Area2D = %SightArea
@onready var sense_area: Area2D = %SenseArea
@onready var reach_area: Area2D = %ReachArea
@onready var mouth_marker: Marker2D = %MouthMarker
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

## Currently active action profiles
var active_profiles: Array[AntActionProfile] = []
#endregion

var target_position: Vector2 :
	get:
		return nav_agent.target_position
	set(value):
		nav_agent.set_target_position(value)

## Task update timer
var task_update_timer: float = 0.0
var logger: Logger
#endregion

var is_dead: bool = false

var vision_range: float = 100.0 :
	set(value):
		vision_range = value
		$SightArea/CollisionShape2D.shape.radius = vision_range

var movement_rate: float = 25.0
var resting_rate: float = 20.0

const ENERGY_DRAIN_FACTOR = 0.000015 # 0.000015 for reference, drains pretty slow
var energy_drain: float :
	get:
		return ENERGY_DRAIN_FACTOR * ((50 if is_carrying_food else 0) + 1) * pow(movement_rate, 1.2)

var energy_max: float = 100
var energy_level: float = energy_max :
	set(value):
		var first: int = int(energy_level)
		energy_level = min(maxf(value, 0.0), energy_max)
		if first != int(energy_level):
			energy_changed.emit()
		if energy_level == 0.0:
			suicide()

var carry_max: int = 1
var health_max: float = 100
var health_level: float = health_max :
	set(value):
		health_level = min(maxf(value, 0.0), health_max)
		if health_level == 0.0:
			suicide()

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var doing_task: bool = false

func _init() -> void:
	logger = Logger.new("ant", DebugLogger.Category.ENTITY)

func _ready() -> void:
	# Initialize influence manager
	influence_manager.initialize(self)
	behavior_manager = AntBehaviorManager.new()
	add_child(behavior_manager)

	# Add behaviors based on ant profile
	_setup_behaviors()
	
	# Register to heatmap
	HeatmapManager.register_entity(self)
	for pheromone in pheromones:
		HeatmapManager.create_heatmap_type(pheromone)

	# Ensure food is positioned correctly with respect to ant reach and carry position
	var food: Food = load("res://entities/food/food.tscn").instantiate()
	$ReachArea/CollisionShape2D.shape.radius = mouth_marker.position.x - food.get_size()
	food.queue_free()

	# Initialize action manager
	action_manager.initialize(self)

	# If profile was set before _ready, apply action profiles now
	if profile:
		_apply_action_profiles()

	# Connect signals
	action_manager.action_started.connect(_on_action_started)
	action_manager.action_completed.connect(_on_action_completed)
	action_manager.action_failed.connect(_on_action_failed)

	# Emit ready signal
	spawned.emit()

func init_profile(p_profile: AntProfile) -> void:
	if not is_instance_valid(p_profile):
		logger.error("Cannot initialize with invalid profile")
		return

	# Store reference to profile
	profile = p_profile

	# Set basic properties from profile
	movement_rate = profile.movement_rate
	vision_range = profile.vision_range
	role = profile.name.to_snake_case()

	# Copy pheromones (avoid using reference to prevent modifying original)
	pheromones.clear()
	for pheromone in profile.pheromones:
		pheromones.append(pheromone)

	# Initialize influence system if available
	if influence_manager:
		for influence_profile in profile.movement_influences:
			influence_manager.add_profile(influence_profile)

	# Setup action system with contextual behaviors
	if is_inside_tree() and is_instance_valid(action_manager):
		_setup_contextual_actions()

	logger.debug("Profile applied to %s: %s" % [name, profile.name])



# Helper method to apply action profiles, called from init_profile and _ready
func _apply_action_profiles() -> void:
	if not is_instance_valid(profile) or not is_instance_valid(action_manager):
		return

	# Apply all action profiles from the ant profile
	if profile.action_profiles:
		for action_profile in profile.action_profiles:
			if is_instance_valid(action_profile):
				apply_action_profile(action_profile)

func _setup_behaviors() -> void:
	# Common behaviors for all ant types
	behavior_manager.add_behavior(create_flee_behavior())
	behavior_manager.add_behavior(create_rest_behavior())
	
	# Role-specific behaviors
	match role:
		"forager":
			behavior_manager.add_behavior(create_foraging_behavior())
			behavior_manager.add_behavior(create_return_behavior())
		"scout":
			behavior_manager.add_behavior(create_scouting_behavior())
		"soldier":
			behavior_manager.add_behavior(create_patrol_behavior())
			behavior_manager.add_behavior(create_attack_behavior())

func create_foraging_behavior() -> AntBehavior:
	var behavior = AntBehavior.new()
	behavior.name = "Foraging"
	behavior.priority = 50
	
	# Conditions to activate this behavior
	behavior.activation_conditions = [
		load("res://resources/expressions/conditions/should_look_for_food.tres")
	]
	
	# Movement profile for exploration
	behavior.movement_profile = load("res://resources/influences/profiles/look_for_food.tres")
	
	# Available actions during foraging
	behavior.available_actions = [
		create_harvest_food_action()  # Action to pick up food when found
	]
	
	# Pheromones to emit while foraging
	behavior.active_pheromones = [
		load("res://entities/pheromone/resources/home_pheromone.tres")
	]
	
	return behavior

## Set up contextual actions based on ant role
func _setup_contextual_actions() -> void:
	# Clear existing actions
	action_manager.available_actions.clear()
	
	# Create role-specific behavior actions
	match role:
		"forager":
			var foraging = ActionProfileFactory.create_foraging_behavior()
			action_manager.add_action(foraging)
			
		"scout":
			# For scouts we might want different behaviors
			var patrol_action = PatrolAction.new()
			patrol_action.name = "Patrol"
			patrol_action.use_random_waypoints = true
			patrol_action.random_waypoint_radius = 200.0
			patrol_action.priority = 60
			patrol_action.movement_profile = load("res://resources/influences/profiles/look_for_food.tres")
			action_manager.add_action(patrol_action)
			
		"soldier":
			# For soldiers, specialized behaviors
			var defend_action = CompositeAction.new()
			defend_action.name = "DefendColony"
			defend_action.priority = 70
			# Set up soldier behaviors...
			action_manager.add_action(defend_action)
			
		_:  # Default/fallback for all ant types
			# Always add these basic behaviors
			var foraging = ActionProfileFactory.create_foraging_behavior()
			action_manager.add_action(foraging)
	
	# Add common actions for all ant types
	var flee_action = ActionProfileFactory.create_flee_behavior()
	action_manager.add_action(flee_action)
	
	var rest_action = ActionProfileFactory.create_rest_behavior()
	action_manager.add_action(rest_action)

func _physics_process(delta: float) -> void:
	task_update_timer += delta
	# Don't process movement if is_dead
	if is_dead:
		return

	_process_carrying()

	# Energy consumption
	if energy_level > 0 and not is_colony_in_range():
		var energy_cost = calculate_energy_cost(delta)
		energy_level -= energy_cost

	# Process action profiles to add/remove profiles as conditions change
	_process_action_profiles(delta)

	# The action manager handles action execution
	# No need for manual action handling

	if not doing_task:
		# Basic movement processing if we're moving
		_process_movement(delta)

## Apply an action profile
func apply_action_profile(p_profile: AntActionProfile) -> void:
	if not is_instance_valid(p_profile) or p_profile in active_profiles:
		return

	p_profile.apply_to(self)
	active_profiles.append(p_profile)
	logger.debug("Applied action profile: %s" % p_profile.name)

## Remove an action profile
func remove_action_profile(p_profile: AntActionProfile) -> void:
	if not is_instance_valid(p_profile) or not p_profile in active_profiles:
		return

	p_profile.remove_from(self)
	active_profiles.erase(p_profile)
	logger.debug("Removed action profile: %s" % p_profile.name)

## Process action profiles (call in _physics_process)
func _process_action_profiles(_delta: float) -> void:
	if profile and profile.action_profiles:
		for p_profile in profile.action_profiles:
			if is_instance_valid(p_profile):
				var is_active = p_profile.is_active_for(self)
				var is_applied = p_profile in active_profiles

				if is_active and not is_applied:
					apply_action_profile(p_profile)
				elif not is_active and is_applied:
					remove_action_profile(p_profile)

func _on_action_started(action: AntAction) -> void:
	logger.debug("Ant %s started action: %s" % [name, action.name])

	# Special handling for movement actions
	if action is MoveToAction and action.name == "Return To Colony":
		# Dynamically set colony as target
		if is_instance_valid(colony):
			action.target_position = colony.global_position

func _on_action_completed(action: AntAction) -> void:
	logger.debug("Ant %s completed action: %s" % [name, action.name])

func _on_action_failed(action: AntAction, reason: String) -> void:
	logger.debug("Ant %s failed action: %s - %s" % [name, action.name, reason])

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

func rest_until_full() -> void:
	doing_task = true
	while not is_fully_rested():
		await get_tree().create_timer(0.5).timeout
		_process_resting(0.5)
	doing_task = false

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
	colony.store_food(_carried_food)
	_carried_food = null
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

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(target_velocity)
	else:
		target_velocity = velocity.lerp(target_velocity, 0.15)
		_on_navigation_agent_2d_velocity_computed(target_velocity)

## Pheromone handles checking condition and emitting if necessary
func _process_pheromones(delta: float):
	for pheromone: Pheromone in pheromones:
		pheromone.check_and_emit(self, delta)

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
		food.set_state(Food.State.CARRIED)
		await get_tree().create_timer(1).timeout
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
	died.emit(self)


func is_navigation_finished() -> bool:
	return nav_agent.is_navigation_finished()

func should_rest() -> bool:
	return health_level < 0.9 * health_max or energy_level < 0.9 * energy_max

func suicide():
	self._on_died()

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

## Returns a vector pointing away from the nearest enemy ant
func get_enemy_avoidance_vector() -> Vector2:
	var enemy_ants = get_ants_in_view().filter(func(other_ant): 
		return other_ant.colony != colony
	)
	
	if enemy_ants.is_empty():
		return Vector2.ZERO
	
	# Find the nearest enemy
	var nearest_enemy = null
	var min_distance = INF
	
	for enemy in enemy_ants:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			nearest_enemy = enemy
			min_distance = distance
	
	if not nearest_enemy:
		return Vector2.ZERO
	
	# Vector pointing away from enemy, strength inversely proportional to distance
	var direction = global_position.direction_to(nearest_enemy.global_position) * -1
	var strength = 1.0 / max(min_distance / 50.0, 0.1)  # Normalize by expected range
	
	return direction * strength

## Returns a weighted sum of vectors pointing away from all nearby enemies
func get_enemy_group_avoidance_vector() -> Vector2:
	var enemy_ants = get_ants_in_view().filter(func(other_ant): 
		return other_ant.colony != colony
	)
	
	if enemy_ants.is_empty():
		return Vector2.ZERO
	
	var avoidance = Vector2.ZERO
	
	for enemy in enemy_ants:
		var direction = global_position.direction_to(enemy.global_position) * -1
		var distance = global_position.distance_to(enemy.global_position)
		var strength = 1.0 / max(distance / 50.0, 0.1)
		avoidance += direction * strength
	
	return avoidance.normalized()


func get_foods_in_reach() -> Array:
	var _foods: Array = []
	for food in reach_area.get_overlapping_bodies():
		if food is Food and food != null and food.is_available:
			_foods.append(food)
	return _foods

func is_colony_in_sight() -> bool:
	var a = colony.global_position.distance_to(global_position) - colony.radius
	var b = %SightArea.get_child(0).shape.radius
	return a <= b

func is_colony_in_range() -> bool:
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

func show_nav_path(enabled: bool):
	nav_agent.debug_enabled = enabled


#region Pheromone Sensing
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

		# Only store unique cell positions, replace if exists
		var existing_index = -1
		for i in range(samples.size()):
			if samples[i].cell_pos == cell_pos:
				existing_index = i
				break

		if existing_index != -1:
			samples[existing_index] = ConcentrationSample.new(cell_pos, concentration)
		else:
			if samples.size() >= max_samples:
				samples.pop_front()
			samples.push_back(ConcentrationSample.new(cell_pos, concentration))

	func get_concentration_vector() -> Vector2:
		if samples.size() < 2:
			return Vector2.ZERO

		var current_time: int = Time.get_ticks_msec()
		var direction: Vector2 = Vector2.ZERO
		var total_weight: float = 0.0

		# Compare each sample with more recent samples
		for i in range(samples.size() - 1):
			for j in range(i + 1, samples.size()):
				var sample1: ConcentrationSample = samples[i]
				var sample2: ConcentrationSample = samples[j]

				var concentration_diff: float = sample2.concentration - sample1.concentration
				if concentration_diff == 0:
					continue

				# Calculate time weight - more recent comparisons have higher weight
				var time_factor: float = 1.0 - float(current_time - sample2.timestamp) / memory_duration
				var weight: float = time_factor * absf(concentration_diff)

				# Convert cell positions to world coordinates for direction
				var world_pos1: Vector2 = HeatmapManager.cell_to_world(sample1.cell_pos)
				var world_pos2: Vector2 = HeatmapManager.cell_to_world(sample2.cell_pos)

				# Direction from lower to higher concentration
				var sample_direction: Vector2 = (world_pos2 - world_pos1).normalized()
				direction += sample_direction * weight * signf(concentration_diff)
				total_weight += weight

		return direction.normalized() if total_weight > 0 else Vector2.ZERO
