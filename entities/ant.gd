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
var colony: Colony : set = set_colony

## The foods being carried by the ant
var carried_food: Foods :
	get:
		if not carried_food:
			carried_food = Foods.new()
		return carried_food

## The task tree for this ant
var task_tree: TaskTree

## The navigation agent for this ant
var nav_agent: NavigationAgent2D

## Task update timer
var task_update_timer: float = 0.0

var _property_access: PropertyAccess :
	get:
		if not _property_access:
			_init_property_access()
		return _property_access

## How long cached values remain valid (in seconds)
const CACHE_DURATIONS = {
	"pheromones": 0.1,  # Pheromone data stays valid for 0.1 seconds
	"food": 0.1,        # Food detection stays valid for 0.1 seconds
	"ants": 0.1,        # Nearby ants data stays valid for 0.1 seconds
	"colony": 0.2,      # Colony-related data stays valid for 0.2 seconds
	"stats": 0.0        # Stats are always recalculated
}

func _init():
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


func set_colony(_colony: Colony) -> void:
	if colony != _colony:
		colony = _colony
		var a: Attribute = create_attribute_from_node(colony, "Colony")
		_property_access.register_attribute(a)

func create_attribute_from_node(node: Node, _name: String) -> Attribute:
	var a: Attribute = Attribute.new(_name)
	a._properties_container = node.properties_container
	return a

func _on_active_behavior_changed(_new_behavior: Behavior) -> void:
	pass

func _on_active_task_changed(_new_task: Task) -> void:
	pass

## Handle the ant taking damage
func take_damage(amount: float) -> void:
	var current_health = get_property_value(Path.parse("health.current_value"))
	damaged.emit()

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

## Move the ant to a new position
func move(direction: Vector2, delta: float) -> void:
	var vector = direction * get_property_value(Path.parse("speed.movement_rate")) * delta
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

#region Property Access Helper Methods
## Initialize property access
func _init_property_access() -> void:
	_property_access = PropertyAccess.new(self)

func _init_attributes() -> void:
	if not _property_access:
		DebugLogger.error(
			DebugLogger.Category.PROPERTY,
			"Property access not configured for attribute initialization"
		)
		return

	var attributes = [
		Energy.new(self),
		Reach.new(self),
		Vision.new(self),
		Olfaction.new(self),
		Strength.new(self),
		Health.new(self),
		Speed.new(self),
		Proprioception.new(self)
	]

	for attribute in attributes:
		var result = _property_access.register_attribute(attribute)
		if not result.success():
			DebugLogger.error(
				DebugLogger.Category.PROPERTY,
				"Failed to register attribute %s: %s" % [
					attribute.name,
					result.error_message
				]
			)
#endregion

#region Property Access Interface
## Core Property Access
func get_property(path: Path) -> Property:
	return _property_access.get_property(path)

func get_property_value(path: Path) -> Variant:
	return _property_access.get_property_value(path)
#endregion

#region Attribute Access Interface
## Get properties for a specific attribute
func get_attribute_properties(attribute: String) -> Array[Property]:
	if attribute.is_empty() or not _property_access:
		return []

	return _property_access.get_attribute_properties(attribute)

## Get all attribute names
func get_attribute_names() -> Array[String]:
	if not _property_access:
		return []
	return _property_access.get_attribute_names()
#endregion
