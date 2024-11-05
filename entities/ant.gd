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

var _property_access: PropertyAccess

var attributes_container: AttributesContainer :
	set(value):
		attributes_container = value
	get:
		return attributes_container
		
var properties_container: PropertiesContainer :
	set(value):
		properties_container = value
	get:
		return properties_container

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

func _init():
	energy = Energy.new()
	reach = Reach.new()
	vision = Vision.new()
	sense = Sense.new()
	strength = Strength.new()
	health = Health.new()
	speed = Speed.new()

	_init_property_access()
	_init_attributes()
	_init_properties()
	
	
	task_tree = TaskTree.create(self).with_root_task("CollectFood").build()
	
	if task_tree and task_tree.get_active_task():
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
func _init_properties() -> void:
	properties_container = PropertiesContainer.new(self)
	
	var properties: Array[PropertyResult.PropertyInfo] = [
		PropertyResult.PropertyInfo.create("food_in_view")
			.of_type(Component.PropertyType.ARRAY)
			.with_getter(Callable(self, "food_in_view"))
			.in_category("Food")
			.described_as("Array of food items currently in view")
			.build(),
			
		PropertyResult.PropertyInfo.create("food_in_view_count")
			.of_type(Component.PropertyType.INT)
			.with_getter(Callable(self, "food_in_view_count"))
			.in_category("Food")
			.described_as("Number of food items currently in view")
			.build(),
			
		PropertyResult.PropertyInfo.create("food_in_reach")
			.of_type(Component.PropertyType.ARRAY)
			.with_getter(Callable(self, "food_in_reach"))
			.in_category("Food")
			.described_as("Array of food items currently in reach")
			.build(),
			
		PropertyResult.PropertyInfo.create("food_in_reach_count")
			.of_type(Component.PropertyType.INT)
			.with_getter(Callable(self, "food_in_reach_count"))
			.in_category("Food")
			.described_as("Number of food items currently in reach")
			.build(),
			
		PropertyResult.PropertyInfo.create("carried_food_mass")
			.of_type(Component.PropertyType.FLOAT)
			.with_getter(Callable(self, "carried_food_mass"))
			.in_category("Food")
			.described_as("Mass of food currently being carried")
			.build(),
			
		PropertyResult.PropertyInfo.create("available_carry_mass")
			.of_type(Component.PropertyType.FLOAT)
			.with_getter(Callable(self, "available_carry_mass"))
			.in_category("Food")
			.described_as("Remaining carrying capacity available")
			.build(),
			
		PropertyResult.PropertyInfo.create("distance_to_colony")
			.of_type(Component.PropertyType.FLOAT)
			.with_getter(Callable(self, "distance_to_colony"))
			.in_category("Colony")
			.described_as("Current distance to the colony")
			.build(),
			
		PropertyResult.PropertyInfo.create("colony_radius")
			.of_type(Component.PropertyType.FLOAT)
			.with_getter(Callable(self, "colony_radius"))
			.in_category("Colony")
			.described_as("Radius of the colony")
			.build(),
			
		PropertyResult.PropertyInfo.create("ants_in_view")
			.of_type(Component.PropertyType.ARRAY)
			.with_getter(Callable(self, "ants_in_view"))
			.in_category("Sensing")
			.described_as("Array of ants currently in view")
			.build(),
			
		PropertyResult.PropertyInfo.create("ants_in_view_count")
			.of_type(Component.PropertyType.INT)
			.with_getter(Callable(self, "ants_in_view_count"))
			.in_category("Sensing")
			.described_as("Number of ants currently in view")
			.build(),
			
		PropertyResult.PropertyInfo.create("food_pheromones_sensed")
			.of_type(Component.PropertyType.ARRAY)
			.with_getter(Callable(self, "food_pheromones_sensed"))
			.in_category("Sensing")
			.described_as("Array of food pheromones currently sensed")
			.build(),
			
		PropertyResult.PropertyInfo.create("food_pheromones_sensed_count")
			.of_type(Component.PropertyType.INT)
			.with_getter(Callable(self, "food_pheromones_sensed_count"))
			.in_category("Sensing")
			.described_as("Number of food pheromones currently sensed")
			.build(),
			
		PropertyResult.PropertyInfo.create("home_pheromones_sensed")
			.of_type(Component.PropertyType.ARRAY)
			.with_getter(Callable(self, "home_pheromones_sensed"))
			.in_category("Sensing")
			.described_as("Array of home pheromones currently sensed")
			.build(),
			
		PropertyResult.PropertyInfo.create("home_pheromones_sensed_count")
			.of_type(Component.PropertyType.INT)
			.with_getter(Callable(self, "home_pheromones_sensed_count"))
			.in_category("Sensing")
			.described_as("Number of home pheromones currently sensed")
			.build(),
		]
		
	var results: Array[PropertyResult] = properties_container.expose_properties(properties)
	for property in properties:
		var result = properties_container.expose_property(property)
		if result.is_error():
			DebugLogger.error(DebugLogger.Category.PROPERTY,"Failed to register property %s -> %s" % [property.name, result.error_message])
		else:
			DebugLogger.trace(DebugLogger.Category.PROPERTY, "Successfully registered property %s" % result.value.name)
		
## Initialize attribute maps
func _init_attributes() -> void:
	if not attributes_container:
		attributes_container = AttributesContainer.new(self)
	var attributes: Array = [energy, reach, vision, sense, strength, health, speed]
	for attribute: Attribute in attributes:
		var result = attributes_container.register_attribute(attribute)
		if result.is_error():
			DebugLogger.error(DebugLogger.Category.PROPERTY, "Failed to register attribute %s -> %s" % [attribute.attribute_name, result.error_message])
		else:
			DebugLogger.trace(DebugLogger.Category.PROPERTY, "Successfully registered attribute %s" % attribute.attribute_name)

#endregion



func _on_active_behavior_changed(_new_behavior: Behavior) -> void:
	pass
	
func _on_active_task_changed(_new_task: Task) -> void:
	pass

## Handle the ant taking damage
func take_damage(amount: float) -> void:
	health.set_current_level(health.current_level() - amount)
	damaged.emit()
	if health.current_level() <= 0:
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
	energy._current_level += consumed

## Move the ant to a new position
func move(direction: Vector2, delta: float) -> void:
	var vector = direction * speed.movement_rate() * delta 
	_move_to(global_position + vector)


func _move_to(location: Vector2) -> void:
	#nav_agent.target_position = global_position + location
	DebugLogger.info(DebugLogger.Category.ACTION, "Ant would be moving now to location %s" % location)

### Harvest food from a source over a given time period
#func harvest_food(food_source: Food, time: float) -> float:
	#var potential_harvest = speed.harvesting_rate() * time
	#var harvested_amount = min(food_source.amount, potential_harvest)
	#harvested_amount = min(harvested_amount, available_carry_mass())
	#
	#food_source.amount -= harvested_amount
	#carried_food.add(Food.new(harvested_amount))
		#
	#return harvested_amount

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
		var sensed = all_pheromones.sensed(global_position, sense.distance())
		return sensed if type.is_empty() else sensed.of_type(type)
	)

func _food_in_reach() -> Foods:
	return _get_cached("food_in_reach", "food", func():
		return Foods.in_reach(global_position, reach.distance())
	)

func _food_in_view() -> Foods:
	return _get_cached("food_in_view", "food", func():
		return Foods.in_view(global_position, vision.distance())
	)

func _ants_in_view() -> Ants:
	return _get_cached("ants_in_view", "ants", func():
		return Ants.in_view(global_position, vision.distance())
	)

#endregion

#region Contextual Information

## Private methods that do the actual computation
func _compute_distance_to_colony() -> float:
	return global_position.distance_to(colony.global_position)

func _compute_colony_radius() -> float:
	return colony.radius()

func _compute_carried_food_mass() -> float:
	return carried_food.mass()

func _compute_available_carry_mass() -> float:
	return strength.carry_max() - carried_food_mass()

func _compute_food_pheromones() -> Array:
	return _pheromones_sensed("food").to_array()

func _compute_home_pheromones() -> Array:
	return _pheromones_sensed("home").to_array()

## Get distance to colony
func distance_to_colony() -> float:
	# The getter should just do direct computation
	return _compute_distance_to_colony()

## Get colony radius
func colony_radius() -> float:
	return _compute_colony_radius()

## Get array of ants in view
func ants_in_view() -> Array:
	return _ants_in_view().to_array()

## Returns count of ants in view
func ants_in_view_count() -> int:
	return ants_in_view().size()

## Get food pheromones sensed
func food_pheromones_sensed() -> Array:
	return _compute_food_pheromones()

## Get food pheromones count
func food_pheromones_sensed_count() -> int:
	return food_pheromones_sensed().size()

## Get home pheromones sensed
func home_pheromones_sensed() -> Array:
	return _compute_home_pheromones()

## Get home pheromones count
func home_pheromones_sensed_count() -> int:
	return home_pheromones_sensed().size()

## Get carried food mass
func carried_food_mass() -> float:
	return _compute_carried_food_mass()

## Get available carry mass
func available_carry_mass() -> float:
	return _compute_available_carry_mass()

## Get food in view
func food_in_view() -> Array:
	return _food_in_view().to_array()

## Get food in view count
func food_in_view_count() -> int:
	return food_in_view().size()

## Get food in reach
func food_in_reach() -> Array:
	return _food_in_reach().to_array()

## Get food in reach count
func food_in_reach_count() -> int:
	return food_in_reach().size()

#region Property Access Helper Methods

## Initialize property access
func _init_property_access() -> void:
	_property_access = PropertyAccess.new({
		"ant": self,
		"properties_container": properties_container,
		"attributes_container": attributes_container
	})
	
	# Set up property access caching
	_property_access.set_cache_ttl(0.5) # Half second cache

## Clear property cache
func clear_property_cache() -> void:
	if _property_access:
		_property_access.clear_cache()
	if properties_container:
		properties_container.invalidate_all_caches()

#region Attribute Property Access
## Get all properties from an attribute
func get_attribute_properties(attribute_name: String) -> Dictionary:
	return attributes_container.get_attribute_properties(attribute_name)

## Get specific attribute property
func get_attribute_property(attribute_name: String, property_name: String) -> PropertyResult:
	return _property_access.get_property("%s.%s" % [attribute_name, property_name])

## Set attribute property
func set_attribute_property(attribute_name: String, property_name: String, value: Variant) -> PropertyResult:
	return _property_access.set_property("%s.%s" % [attribute_name, property_name], value)

## Get all attribute properties
func get_all_attribute_properties() -> Dictionary:
	var result = {}
	for attr in attributes_container.get_attributes():
		result[attr] = get_attribute_properties(attr)
	return result
#endregion

#region Caching methods
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
