class_name Ant
extends CharacterBody2D

#region Signals
signal spawned
signal food_spotted
signal ant_spotted
signal action_completed
signal pheromone_sensed
signal damaged
signal died
#endregion

#region Member Variables
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
	set(value):
		carried_food = value
		carried_food.mark_as_carried()

## The task tree for this ant
var task_tree: TaskTree

## The navigation agent for this ant
var nav_agent: NavigationAgent2D

## Task update timer
var task_update_timer: float = 0.0

## Property access system
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
#endregion

func _init() -> void:
	_init_property_groups()

	task_tree = TaskTree.create(self).with_root_task("CollectFood").build()

	if task_tree and task_tree.get_active_task():
		task_tree.active_task_changed.connect(_on_active_task_changed)
		task_tree.active_behavior_changed.connect(_on_active_behavior_changed)

	add_to_group("ant")

func _ready() -> void:
	spawned.emit()

func _process(delta: float) -> void:
	task_update_timer += delta
	if task_update_timer >= 1.0:
		task_tree.update(delta)
		task_update_timer = 0.0

#region Colony Management
func set_colony(_colony: Colony) -> void:
	if colony != _colony:
		colony = _colony
		# Register colony properties if available
		if colony and colony.has_method("get_property_group"):
			var colony_group = colony.get_property_group()
			var result = _property_access.register_group(colony_group)
			if not result.success():
				DebugLogger.error(
					DebugLogger.Category.PROPERTY,
					"Failed to register colony properties: %s" % result.error_message
				)
#endregion

#region Event Handlers
func _on_active_behavior_changed(_new_behavior: Behavior) -> void:
	pass

func _on_active_task_changed(_new_task: Task) -> void:
	pass
#endregion

#region Action Methods
func take_damage(amount: float) -> void:
	if amount <= 0:
		return

	var current_health = get_property_value(Path.parse("health.levels.current"))
	damaged.emit()

	# Update health through property system
	_property_access.set_property_value(
		Path.parse("health.levels.current"),
		current_health - amount
	)

func emit_pheromone(type: String, concentration: float) -> void:
	print("Emitting pheromone of type %s and concentration %.2f" % [type, concentration])
	#var new_pheromone = Pheromone.new(position, type, concentration, self)
	# Add the pheromone to the world (implementation depends on your world management system)

func perform_action(_action: Action) -> void:
	# Implement ant behavior here
	action_completed.emit()

func consume_food(amount: float) -> void:
	var consumed = carried_food.consume(amount)
	if consumed > 0:
		# Replenish energy through property system
		var current_energy = get_property_value(Path.parse("energy.levels.current"))
		_property_access.set_property_value(
			Path.parse("energy.levels.current"),
			current_energy + consumed
		)

func move(direction: Vector2, delta: float) -> void:
	var speed = get_property_value(Path.parse("speed.rates.movement"))
	if not speed:
		speed = 1.0
	var vector = direction * speed * delta
	_move_to(global_position + vector)

func _move_to(location: Vector2) -> void:
	#nav_agent.target_position = global_position + location
	DebugLogger.info(DebugLogger.Category.ACTION, "Ant would be moving now to location %s" % location, {"from": "ant"})

func store_food(_colony: Colony, _time: float) -> float:
	var storing_amount: float = carried_food.mass()
	var total_stored = _colony.foods.add_food(storing_amount)
	DebugLogger.info(DebugLogger.Category.ACTION, "Stored %.2f food -> colony total: %.2f food stored" % [storing_amount, total_stored])
	carried_food.clear()
	return storing_amount

func attack(current_target_entity: Ant, _delta: float) -> void:
	DebugLogger.info(DebugLogger.Category.ACTION, "Attack action called against %s" % current_target_entity.name)
#endregion

#region Property System
func _init_property_access() -> void:
	_property_access = PropertyAccess.new(self)
	_trace("Property access system initialized")

func _init_property_groups() -> void:
	if not _property_access:
		_init_property_access()

	var groups = [
		Energy.new(self),
		Reach.new(self),
		Vision.new(self),
		Olfaction.new(self),
		Strength.new(self),
		Health.new(self),
		Speed.new(self),
		Proprioception.new(self)
	]

	for group in groups:
		var result = _property_access.register_group(group)
		if not result.success():
			DebugLogger.error(
				DebugLogger.Category.PROPERTY,
				"Failed to register property group %s: %s" % [
					group.name,
					result.get_error()
				]
			)
		else:
			_trace("Registered property group: %s" % group.name)

#region Property Access Interface
func get_property(path: Path) -> NestedProperty:
	return _property_access.get_property(path)

func get_property_group(group_name: String) -> PropertyGroup:
	return _property_access.get_group(group_name)

func get_property_value(path: Path) -> Variant:
	return _property_access.get_property_value(path)

func set_property_value(path: String, value: Variant) -> Result:
	return _property_access.set_property_value(Path.parse(path), value)
#endregion

#region Property Group Access
func get_group_properties(group_name: String) -> Array[NestedProperty]:
	return _property_access.get_group_properties(group_name)

func get_group_names() -> Array[String]:
	return _property_access.get_group_names()
#endregion


#region Logging Methods
func _trace(message: String) -> void:
	DebugLogger.trace(
		DebugLogger.Category.ENTITY,
		message,
		{"from": "ant"}
	)

## Log an error message
func _error(message: String) -> void:
	DebugLogger.error(DebugLogger.Category.ENTITY,
		message,
		{"from": "ant"}
	)

## Log a warning message
func _warn(message: String) -> void:
	DebugLogger.warn(DebugLogger.Category.ENTITY,
		message,
		{"from": "ant"}
	)
#endregion
