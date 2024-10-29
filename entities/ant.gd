class_name Ant
extends CharacterBody2D

signal spawned
signal food_spotted
signal ant_spotted
signal action_completed
signal pheromone_sensed
signal damaged
signal died

## The unique identifier for this ant
var id: int

## The role of this ant in the colony
var role: String

## The colony this ant belongs to
var colony: Colony :
	get:
		if not colony:
			colony = Colony.new()
		return colony

## The reach capabilities of the ant
var reach: Reach

## The vision capabilities of the ant
var vision: Vision

## The sense capabilities of the ant
var sense: Sense

## The energy levels of the ant
var energy: Energy

## The strength capabilities of the ant
var strength: Strength

## The health status of the ant
var health: Health

## The foods being carried by the ant
var carried_food: Foods :
	get:
		if not carried_food:
			carried_food = Foods.new()
		return carried_food

## The speed capabilities of the ant
var speed: Speed

## The task tree for this ant
var task_tree: TaskTree

## The navigation agent for this ant
var nav_agent: NavigationAgent2D

## Task update timer
var task_update_timer: float = 0.0

## Cache storage for various sensory and contextual data
var _cache: Dictionary = {}

## Track when cache entries were last updated (in seconds)
var _cache_timestamps: Dictionary = {}

## How long cached values remain valid (in seconds)
const CACHE_DURATIONS = {
	"pheromones": 0.1,  # Pheromone data stays valid for 0.1 seconds
	"food": 0.1,        # Food detection stays valid for 0.1 seconds
	"ants": 0.1,        # Nearby ants data stays valid for 0.1 seconds
	"colony": 0.2,      # Colony-related data stays valid for 0.2 seconds
	"stats": 0.0        # Stats are always recalculated (0.0 means no caching)
}


func _init():
	
	reach = Reach.new()
	vision = Vision.new()
	sense = Sense.new()
	energy = Energy.new()
	strength = Strength.new()
	health = Health.new()
	speed = Speed.new()
	
	task_tree = TaskTree.create(self).with_root_task("CollectFood").build()
	
	if task_tree and task_tree.get_active_task():
		print("Successfully loaded task %s to ant %d" % [task_tree.get_active_task().name, id])
		task_tree.print_task_hierarchy()
		task_tree.active_task_changed.connect(_on_active_task_changed)
		task_tree.active_behavior_changed.connect(_on_active_behavior_changed)

func _ready() -> void:
	spawned.emit()

func _process(delta: float) -> void:
	task_update_timer += delta
	if task_update_timer >= 1.0:
		task_tree.update(delta)
		task_update_timer = 0.0

## Clear all cached data
func clear_cache() -> void:
	_cache.clear()
	_cache_timestamps.clear()

## Get cached value or compute if expired
func _get_cached(key: String, category: String, computer: Callable) -> Variant:
	var cache_duration = CACHE_DURATIONS[category]
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Always recompute if cache duration is 0
	if cache_duration == 0.0:
		return computer.call()
	
	# Check if cache exists and is still valid
	if key in _cache and key in _cache_timestamps:
		var age = current_time - _cache_timestamps[key]
		if age < cache_duration:
			return _cache[key]
	
	# Compute new value and cache it
	var value = computer.call()
	_cache[key] = value
	_cache_timestamps[key] = current_time
	return value

func _on_active_behavior_changed(_new_behavior: Behavior) -> void:
	pass
	
func _on_active_task_changed(_new_task: Task) -> void:
	pass



## Handle the ant taking damage
func take_damage(amount: float) -> void:
	health.current_level -= amount
	damaged.emit()
	if health.current_level <= 0:
		died.emit()

## Handle the ant consuming food for energy
func consume_food(amount: float) -> void:
	var consumed = carried_food.consume(amount)
	energy.current_level += consumed

## Move the ant to a new position
func move(direction: Vector2, delta: float) -> void:
	var vector = direction * speed.movement_rate * delta 
	_move_to(global_position + vector)

func _move_to(location: Vector2) -> void:
	#nav_agent.target_position = global_position + location
	print("Ant would be moving now to location %s" % location)
	
## Harvest food from a source over a given time period
func harvest_food(food_source: Food, time: float) -> float:
	var potential_harvest = speed.harvesting_rate * time
	var harvested_amount = min(food_source.amount, potential_harvest)
	harvested_amount = min(harvested_amount, available_carry_mass())
	
	food_source.amount -= harvested_amount
	carried_food.add(Food.new(harvested_amount))
		
	return harvested_amount

## Store food into colony over a given time period[br]
##Returns amount stored[br]
##** Note, not currently using argument _time **
func store_food(_colony: Colony, _time: float) -> float:
	var storing_amount: float = carried_food.mass()
	var total_stored = _colony.foods.add_food(storing_amount)
	print("Stored %.2f food -> colony total: %.2f food stored" % [storing_amount, total_stored])
	carried_food.clear()
	return storing_amount

## Emit a pheromone at the current position
func emit_pheromone(type: String, concentration: float) -> void:
	print("Emitting pheromone of type %s and concentration %.2f" % [type, concentration])
	#var new_pheromone = Pheromone.new(position, type, concentration, self)
	# Add the pheromone to the world (implementation depends on your world management system)

## Perform an action (placeholder for more complex behavior)
func perform_action() -> void:
	# Implement ant behavior here
	action_completed.emit()

func attack(current_target_entity: Ant, _delta: float) -> void:
	print("Attack action called against %s" % current_target_entity.name)

# Connect signals
func _connect_signals() -> void:
	health.depleted.connect(func(): died.emit())
	energy.depleted.connect(func(): take_damage(1))  # Ant takes damage when out of energy



#region Sensory helper methods
## Get pheromones sensed by the ant
func _pheromones_sensed(type: String = "") -> Pheromones:
	var cache_key = "pheromones_sensed_%s" % type
	return _get_cached(cache_key, "pheromones", func():
		var all_pheromones = Pheromones.all() 
		var sensed = all_pheromones.sensed(global_position, sense.distance)
		return sensed if type.is_empty() else sensed.of_type(type)
	)

## Get food items within reach
func _food_in_reach() -> Foods:
	return _get_cached("food_in_reach", "food", func():
		return Foods.in_reach(global_position, reach.distance)
	)

## Get food items in view
func _food_in_view() -> Foods:
	return _get_cached("food_in_view", "food", func():
		return Foods.in_view(global_position, vision.distance)
	)

## Get pheromones sensed by the ant
func _pheromones_sensed_count(type: String = "") -> int:
	var cache_key = "pheromones_count_%s" % type
	return _get_cached(cache_key, "pheromones", func():
		return _pheromones_sensed(type).size()
	)

func _ants_in_view() -> Ants:
	return _get_cached("ants_in_view", "ants", func():
		return Ants.in_view(global_position, vision.distance)
	)

#endregion

#region Contextual Information
## Get distance to colony
func distance_to_colony() -> float:
	return _get_cached("colony_distance", "colony", func():
		return global_position.distance_to(colony.global_position)
	)

## Get colony radius
func colony_radius() -> float:
	return _get_cached("colony_radius", "colony", func():
		return colony.radius
	)

## Get current energy level
func energy_level() -> float:
	return _get_cached("energy_level", "stats", func():
		return energy.current_level
	)

## Get low energy threshold
func low_energy_threshold() -> float:
	return _get_cached("low_energy_threshold", "stats", func():
		return energy.low_energy_threshold
	)

## Get carry capacity
func carry_capacity() -> float:
	return _get_cached("carry_capacity", "stats", func():
		return strength.carry_max()
	)

## Get array of ants in view
func ants_in_view_array() -> Array:
	return _get_cached("ants_in_view_array", "ants", func():
		return _ants_in_view().as_array()
	)

## Get food pheromones sensed
func food_pheromones_sensed() -> Array:
	return _get_cached("food_pheromones", "pheromones", func():
		return _pheromones_sensed("food").to_array()
	)

## Get food pheromones count
func food_pheromones_sensed_count() -> int:
	return _get_cached("food_pheromones_count", "pheromones", func():
		return _pheromones_sensed_count("food")
	)

## Check if food pheromones are sensed
func is_food_pheromones_sensed() -> bool:
	return _get_cached("is_food_pheromones", "pheromones", func():
		return not _pheromones_sensed("food").is_empty()
	)

## Get home pheromones sensed
func home_pheromones_sensed() -> Array:
	return _get_cached("home_pheromones", "pheromones", func():
		return _pheromones_sensed("home").to_array()
	)

## Get home pheromones count
func home_pheromones_sensed_count() -> int:
	return _get_cached("home_pheromones_count", "pheromones", func():
		return _pheromones_sensed_count("home")
	)

## Check if home pheromones are sensed
func is_home_pheromones_sensed() -> bool:
	return _get_cached("is_home_pheromones", "pheromones", func():
		return not _pheromones_sensed("home").is_empty()
	)

## Get carried food mass
func carried_food_mass() -> float:
	return _get_cached("carried_food_mass", "stats", func():
		return carried_food.mass()
	)

## Check if carrying food
func is_carrying_food() -> bool:
	return _get_cached("is_carrying_food", "stats", func():
		return carried_food.mass() > 0
	)

## Get available carry mass
func available_carry_mass() -> float:
	return _get_cached("available_carry_mass", "stats", func():
		return strength.carry_max() - carried_food.mass()
	)

## Get food in view count
func food_in_view_count() -> int:
	return _get_cached("food_in_view_count", "food", func():
		return _food_in_view().size()
	)

## Get food in reach count
func food_in_reach_count() -> int:
	return _get_cached("food_in_reach_count", "food", func():
		return _food_in_reach().size()
	)

	
#endregion
