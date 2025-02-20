@icon("res://assets/entities/Ant.svg")
class_name Ant
extends CharacterBody2D

## Ant implementation using functional programming principles
## Complex calculations are delegated to utility functions that operate on primitives

#region Signals
signal spawned
signal energy_changed
@warning_ignore("unused_signal")
signal damaged
signal died(ant: Ant)
signal movement_completed(success: bool)
#endregion

@export var pheromones: Array[Pheromone]
var pheromone_memories: Dictionary[String, PheromoneMemory] = {}  # String -> PheromoneMemory

#region Movement
enum PHEROMONE_TYPES { HOME, FOOD }
var movement_target: Vector2
#endregion

#region Constants
const DEFAULT_CONFIG_ROOT = "res://config/"
#endregion

#region Member Variables
var id: int
var role: String
var profile: AntProfile
var colony: Colony : set = set_colony
var _carried_food: Food

#region Components
@onready var influence_manager: InfluenceManager = $InfluenceManager
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
#endregion

var target_position: Vector2 :
	get:
		return nav_agent.target_position
	set(value):
		nav_agent.set_target_position(value)

var task_update_timer: float = 0.0
var logger: Logger
var is_dead: bool = false

var vision_range: float = 100.0 :
	set(value):
		vision_range = value
		$SightArea/CollisionShape2D.shape.radius = vision_range
		
var movement_rate: float = 25.0
var resting_rate: float = 20.0

var energy_drain: float :
	get:
		var carrying_weight: float = 50.0 if is_carrying_food() else 0.0
		return AntUtils.EnergyCalculator.calculate_energy_drain(movement_rate, carrying_weight)

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
	influence_manager.initialize(self)
	
	if profile:
		init_profile(profile)
	
	HeatmapManager.register_entity(self)
	for pheromone in pheromones:
		HeatmapManager.create_heatmap_type(pheromone)

	# Ensure food is positioned correctly with respect to ant reach and carry position
	var food: Food = load("res://entities/food/food.tscn").instantiate()
	$ReachArea/CollisionShape2D.shape.radius = mouth_marker.position.x - food.get_size()
	food.queue_free()

	spawned.emit()

func init_profile(p_profile: AntProfile) -> void:
	profile = p_profile
	if not influence_manager:
		return
	
	for influence: InfluenceProfile in p_profile.movement_influences:
		influence_manager.add_profile(influence)

func _physics_process(delta: float) -> void:
	task_update_timer += delta
	if is_dead:
		return

	_process_carrying()
	
	# Energy consumption using functional utility
	if energy_level > 0 and not is_colony_in_range():
		var energy_cost = calculate_energy_cost(delta)
		energy_level -= energy_cost

	if doing_task:
		return

	# Task priority checks
	if get_foods_in_reach() and not is_carrying_food():
		harvest_food()
		return

	if is_colony_in_range() and is_carrying_food():
		store_food()
		return

	if is_colony_in_range() and should_rest():
		rest_until_full()
		return

	if not doing_task:
		_process_movement(delta)

func move_to(target_pos: Vector2) -> bool:
	movement_target = target_pos
	nav_agent.set_target_position(target_pos)
	return true
	
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

func _process_pheromones(delta: float):
	for pheromone: Pheromone in pheromones:
		pheromone.check_and_emit(self, delta)

func calculate_energy_cost(delta: float) -> float:
	return AntUtils.EnergyCalculator.calculate_movement_energy_cost(
		energy_drain,
		velocity.length(),
		delta
	)

#region Navigation Agent Callbacks
func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	if safe_velocity.length() > 0.0:
		global_rotation = safe_velocity.angle()
	move_and_slide()

func _on_navigation_agent_2d_target_reached() -> void:
	if velocity != Vector2.ZERO:
		movement_completed.emit(true)
#endregion

func harvest_food():
	doing_task = true
	var foods_in_reach = get_foods_in_reach()
	if foods_in_reach.is_empty():
		return

	# Extract positions and sort them
	var positions: Array[Vector2] = foods_in_reach.map(func(f): return f.global_position)
	var sorted_positions = NavigationUtils.sort_positions_by_distance(positions, global_position)
	
	# Reorder foods array based on sorted positions
	var sorted_foods: Array = []
	for pos in sorted_positions:
		for food in foods_in_reach:
			if food.global_position == pos:
				sorted_foods.append(food)
				break
	foods_in_reach = sorted_foods

	var food = foods_in_reach[0]
	if is_instance_valid(food) and food.is_available:
		food.set_state(Food.State.CARRIED)
		await get_tree().create_timer(1).timeout
		food.global_position = mouth_marker.global_position
		_carried_food = food
		doing_task = false
	return

func set_colony(p_colony: Colony) -> void:
	if colony != p_colony:
		colony = p_colony

func _on_died() -> void:
	if is_carrying_food():
		_carried_food.set_state(Food.State.AVAILABLE)
	is_dead = true
	died.emit(self)

func is_carrying_food() -> bool:
	return is_instance_valid(_carried_food)

func is_navigation_finished() -> bool:
	return nav_agent.is_navigation_finished()

func should_rest() -> bool:
	return AntUtils.StatusUtils.should_rest(health_level, health_max, energy_level, energy_max)

func is_fully_rested() -> bool:
	return AntUtils.StatusUtils.is_fully_rested(health_level, health_max, energy_level, energy_max)

func suicide():
	self._on_died()

func get_food_in_view() -> Array:
	var fiv: Array = []
	for food in sight_area.get_overlapping_bodies():
		if food is Food and food != null and food.is_available:
			fiv.append(food)
	return fiv

func get_pheromone_direction(pheromone_name: String, follow_concentration: bool = true) -> Vector2:
	if not is_instance_valid(colony):
		return Vector2.ZERO
		
	if not pheromone_memories.has(pheromone_name):
		pheromone_memories[pheromone_name] = PheromoneMemory.new()
	
	var current_cell: Vector2i = HeatmapManager.world_to_cell(global_position)
	var current_concentration: float = HeatmapManager.get_heat_at_position(
		self,
		pheromone_name
	)
	
	pheromone_memories[pheromone_name].add_sample(current_cell, current_concentration)
	var direction: Vector2 = pheromone_memories[pheromone_name].get_concentration_vector()
	
	return direction if follow_concentration else -direction
	
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

func is_colony_in_range() -> bool:
	return NavigationUtils.is_point_in_range(
		global_position,
		colony.global_position,
		colony.radius
	)

func get_nearest_item(list: Array) -> Variant:
	if list.is_empty():
		return null
		
	var positions: Array[Vector2] = list.map(func(item): return item.global_position)
	var nearest_pos = NavigationUtils.get_nearest_point(global_position, positions)
	
	for item in list:
		if item.global_position == nearest_pos:
			return item
			
	return null

#region Pheromone Memory Class
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
	var current_cell: Vector2i
	
	func add_sample(cell_pos: Vector2i, concentration: float) -> void:
		var current_time: int = Time.get_ticks_msec()
		
		if current_cell == cell_pos:
			return
			
		current_cell = cell_pos
		
		samples = samples.filter(func(sample): 
			return current_time - sample.timestamp < memory_duration
		)
		
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
		var current_time: int = Time.get_ticks_msec()
		
		# Extract primitive arrays from samples
		var positions: Array[Vector2] = []
		var concentrations: Array[float] = []
		var timestamps: Array[int] = []
		
		for sample in samples:
			positions.append(HeatmapManager.cell_to_world(sample.cell_pos))
			concentrations.append(sample.concentration)
			timestamps.append(sample.timestamp)
			
		return AntUtils.PheromoneUtils.calculate_concentration_vector(
			positions,
			concentrations,
			timestamps,
			current_time,
			memory_duration
		)
#endregion
