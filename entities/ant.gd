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

## Dependencies between cached values - base methods provide for derived methods
const CACHE_DEPENDENCIES = {
	# Food sensing dependencies
	"food_in_view": ["_food_in_view"],
	"food_in_view_count": ["food_in_view"],
	"food_in_reach": ["_food_in_reach"],
	"food_in_reach_count": ["food_in_reach"],
	
	# Pheromone sensing dependencies
	"food_pheromones_sensed": ["_pheromones_sensed_food"],
	"food_pheromones_sensed_count": ["food_pheromones_sensed"],
	"is_food_pheromones_sensed": ["food_pheromones_sensed"],
	"home_pheromones_sensed": ["_pheromones_sensed_home"],
	"home_pheromones_sensed_count": ["home_pheromones_sensed"],
	"is_home_pheromones_sensed": ["home_pheromones_sensed"],
	
	# Ant sensing dependencies
	"ants_in_view": ["_ants_in_view"],
	"ants_in_view_count": ["ants_in_view"],
	
	# Food carrying dependencies
	"is_carrying_food": ["carried_food_mass"],
	"available_carry_mass": ["carried_food_mass"]
}

## How long cached values remain valid (in seconds)
const CACHE_DURATIONS = {
	"pheromones": 0.1,  # Pheromone data stays valid for 0.1 seconds
	"food": 0.1,        # Food detection stays valid for 0.1 seconds
	"ants": 0.1,        # Nearby ants data stays valid for 0.1 seconds
	"colony": 0.2,      # Colony-related data stays valid for 0.2 seconds
	"stats": 0.0        # Stats are always recalculated
}

var _exposed_methods = {}

## TODO: Meant to be used as a way to access children for later when
## we have a UI and will allow a user to design conditions based on their data
var exposed_attributes = {
	"reach": reach,
	"vision": vision,
	"sense": sense,
	"energy": energy,
	"strength": strength,
	"health": health,
	"speed": speed
}

func _init():
	
	reach = Reach.new()
	vision = Vision.new()
	sense = Sense.new()
	energy = Energy.new()
	strength = Strength.new()
	health = Health.new()
	speed = Speed.new()
	
	_init_exposed_methods()
	
	task_tree = TaskTree.create(self).with_root_task("CollectFood").build()
	
	if task_tree and task_tree.get_active_task():
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

#region Exposed Method methods
## Initialize method maps
func _init_exposed_methods() -> void:
	# Sensory methods
	_exposed_methods["sensing"] = {
		"ants_in_view": func(): return ants_in_view(),
		"ants_in_view_count": func(): return ants_in_view_count(),
		"food_pheromones_sensed": func(): return food_pheromones_sensed(),
		"food_pheromones_sensed_count": func(): return food_pheromones_sensed_count(),
		"is_food_pheromones_sensed": func(): return is_food_pheromones_sensed(),
		"home_pheromones_sensed": func(): return home_pheromones_sensed(),
		"home_pheromones_sensed_count": func(): return home_pheromones_sensed_count(),
		"is_home_pheromones_sensed": func(): return is_home_pheromones_sensed()
	}
	
	# Food-related methods
	_exposed_methods["food"] = {
		"food_in_view": func(): return food_in_view(),
		"food_in_view_count": func(): return food_in_view_count(),
		"food_in_reach": func(): return food_in_reach(),
		"food_in_reach_count": func(): return food_in_reach_count(),
		"carried_food_mass": func(): return carried_food_mass(),
		"is_carrying_food": func(): return is_carrying_food(),
		"available_carry_mass": func(): return available_carry_mass()
	}
	
	# Colony-related methods
	_exposed_methods["colony"] = {
		"distance_to_colony": func(): return distance_to_colony(),
		"colony_radius": func(): return colony_radius()
	}
	
## Get all methods in a category
func get_methods(category: String) -> Dictionary:
	return _exposed_methods.get(category, {})

## Get a specific method result
func get_method_result(method_name: String, category: String = "") -> Variant:
	if category.is_empty():
		# Search all categories for the method
		for cat in _exposed_methods:
			if method_name in _exposed_methods[cat]:
				return _exposed_methods[cat][method_name].call()
		return null
	
	# Use specific category if provided
	var category_methods = get_methods(category)
	if method_name in category_methods:
		return category_methods[method_name].call()
	return null

## Get all method results
func get_all_method_results() -> Dictionary:
	var results = {}
	for category in _exposed_methods:
		results[category] = {}
		for method_name in _exposed_methods[category]:
			results[category][method_name] = _exposed_methods[category][method_name].call()
	return results
	
#endregion

#region Attribute helpers
# Get all exposed properties from an attribute
func get_attribute_properties(attribute_name: String) -> Dictionary:
	if attribute_name in exposed_attributes:
		return exposed_attributes[attribute_name].get_exposed_properties()
	return {}

# Get a specific property from an attribute
func get_attribute_property(attribute_name: String, property_name: String):
	if attribute_name in exposed_attributes:
		return exposed_attributes[attribute_name].get_property(property_name)
	return null

# Set a specific property on an attribute
func set_attribute_property(attribute_name: String, property_name: String, value) -> bool:
	if attribute_name in exposed_attributes:
		return exposed_attributes[attribute_name].set_property(property_name, value)
	return false

# Get all exposed properties from all attributes
func get_all_attribute_properties() -> Dictionary:
	var properties = {}
	for attr_name in exposed_attributes:
		properties[attr_name] = get_attribute_properties(attr_name)
	return properties
#endregion

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
	
## Emit a pheromone at the current position
func emit_pheromone(type: String, concentration: float) -> void:
	print("Emitting pheromone of type %s and concentration %.2f" % [type, concentration])
	#var new_pheromone = Pheromone.new(position, type, concentration, self)
	# Add the pheromone to the world (implementation depends on your world management system)
	
#region Action methods
## Perform an action (placeholder for more complex behavior)
## Meant to serve as access for all actions prompted by the TaskManager
func perform_action(_action: Action) -> void:
	# Implement ant behavior here
	action_completed.emit()

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
	DebugLogger.info(DebugLogger.Category.ACTION, "Ant would be moving now to location %s" % location)

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
	DebugLogger.info(DebugLogger.Category.ACTION,"Stored %.2f food -> colony total: %.2f food stored" % [storing_amount, total_stored])
	carried_food.clear()
	return storing_amount

func attack(current_target_entity: Ant, _delta: float) -> void:
	DebugLogger.info(DebugLogger.Category.ACTION,"Attack action called against %s" % current_target_entity.name)

#endregion

## Connect signals
func _connect_signals() -> void:
	health.depleted.connect(func(): died.emit())
	energy.depleted.connect(func(): take_damage(1))  # Ant takes damage when out of energy



#region Sensory helper methods
## These methods return custom lists, meant to serve
## as the initial access point for these objects

func _pheromones_sensed(type: String = "") -> Pheromones:
	var cache_key = "pheromones_sensed_%s" % type
	return _get_cached(cache_key, "pheromones", func():
		var all_pheromones = Pheromones.all() 
		var sensed = all_pheromones.sensed(global_position, sense.distance)
		return sensed if type.is_empty() else sensed.of_type(type)
	)

func _food_in_reach() -> Foods:
	return _get_cached("food_in_reach", "food", func():
		return Foods.in_reach(global_position, reach.distance)
	)

func _food_in_view() -> Foods:
	return _get_cached("food_in_view", "food", func():
		return Foods.in_view(global_position, vision.distance)
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
func ants_in_view() -> Array:
	return _get_cached("ants_in_view", "ants", func():
		return _ants_in_view().as_array()
	)
## Returns count of ants in view
func ants_in_view_count() -> int:
	return _get_cached("ants_in_view_count", "ants", func():
		return ants_in_view().size()
	)

## Get food pheromones sensed
func food_pheromones_sensed() -> Array:
	return _get_cached("food_pheromones_sensed", "pheromones", func():
		return _pheromones_sensed("food").to_array()
	)

## Get food pheromones count
func food_pheromones_sensed_count() -> int:
	return _get_cached("food_pheromones_sensed_count", "pheromones", func():
		return food_pheromones_sensed().size()
	)

## Check if food pheromones are sensed
func is_food_pheromones_sensed() -> bool:
	return _get_cached("is_food_pheromones_sensed", "pheromones", func():
		return not food_pheromones_sensed().is_empty()
	)

## Get home pheromones sensed
func home_pheromones_sensed() -> Array:
	return _get_cached("home_pheromones_sensed", "pheromones", func():
		return _pheromones_sensed("home").to_array()
	)

## Get home pheromones count
func home_pheromones_sensed_count() -> int:
	return _get_cached("home_pheromones_sensed_count", "pheromones", func():
		return home_pheromones_sensed().size()
	)

## Check if home pheromones are sensed
func is_home_pheromones_sensed() -> bool:
	return _get_cached("is_home_pheromones_sensed", "pheromones", func():
		return not home_pheromones_sensed().is_empty()
	)

## Get carried food mass
func carried_food_mass() -> float:
	return _get_cached("carried_food_mass", "stats", func():
		return carried_food.mass()
	)

## Check if carrying food
func is_carrying_food() -> bool:
	return _get_cached("is_carrying_food", "stats", func():
		return carried_food_mass() > 0
	)

## Get available carry mass
func available_carry_mass() -> float:
	return _get_cached("available_carry_mass", "stats", func():
		return strength.carry_max() - carried_food_mass()
	)

## Get food in view as an Array
func food_in_view() -> Array:
	return _get_cached("food_in_view", "food", func():
		return _food_in_view().to_array()
	)

## Get food in view count
func food_in_view_count() -> int:
	return _get_cached("food_in_view_count", "food", func():
		return food_in_view().size()
	)

## Get food within reach as an Array
func food_in_reach() -> Array:
	return _get_cached("food_in_reach", "food", func():
		return _food_in_reach().to_array()
	)

## Get food within reach count
func food_in_reach_count() -> int:
	return _get_cached("food_in_reach_count", "food", func():
		return food_in_reach().size()
	)
	
#endregion

#region Caching methods
## Clear all cached data
func clear_cache() -> void:
	_cache.clear()
	_cache_timestamps.clear()

## Get cached value or compute if expired
func _get_cached(key: String, category: String, computer: Callable) -> Variant:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check dependencies first
	if key in CACHE_DEPENDENCIES:
		for dep_key in CACHE_DEPENDENCIES[key]:
			if not _is_cache_valid(dep_key, current_time):
				# If any dependency is invalid, we need to recompute
				#if OS.is_debug_build():
					#print("Cache miss for %s (dependency %s invalid)" % [key, dep_key])
				break
			# If all dependencies are valid, we can use cached value if it exists
			if _is_cache_valid(key, current_time):
				#if OS.is_debug_build():
					#print("Cache hit for %s (using dependencies)" % key)
				return _cache[key]
	
	# If we have a valid cached value, use it
	if _is_cache_valid(key, current_time):
		#if OS.is_debug_build():
			#print("Cache hit for %s" % key)
		return _cache[key]
	
	# Compute new value
	#if OS.is_debug_build():
		#print("Cache miss for %s (computing new value)" % key)
	var value = computer.call()
	_cache[key] = value
	_cache_timestamps[key] = current_time
	return value

## Check if a cached value is still valid
func _is_cache_valid(key: String, current_time: float) -> bool:
	if not key in _cache or not key in _cache_timestamps:
		return false
		
	var category = _get_category_for_key(key)
	var cache_duration = CACHE_DURATIONS[category]
	
	# Always invalid if duration is 0
	if cache_duration == 0.0:
		return false
		
	var age = current_time - _cache_timestamps[key]
	return age < cache_duration

## Get the category for a cache key
func _get_category_for_key(key: String) -> String:
	for category in CACHE_DURATIONS:
		if key.begins_with(category):
			return category
	return "stats"  # Default category
#endregion
