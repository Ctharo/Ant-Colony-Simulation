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
var olfaction: Olfaction

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
	olfaction = Olfaction.new()
	strength = Strength.new()
	health = Health.new()
	speed = Speed.new()

	_init_property_access()
	_init_attributes()

	
	
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

#region 

## Initialize attribute maps
func _init_attributes() -> void:
	if not attributes_container:
		attributes_container = AttributesContainer.new(self)
	var attributes: Array = [energy, reach, vision, olfaction, strength, health, speed]
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

#region Property Access Helper Methods
## Initialize property access
func _init_property_access() -> void:
	_property_access = PropertyAccess.new({
		"ant": self,
		"attributes_container": attributes_container
	})
	
	# Set up property access caching
	_property_access.set_cache_ttl(0.5) # Half second cache

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
