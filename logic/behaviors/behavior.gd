## Extended behavior.gd with JSON serialization and improved documentation
class_name Behavior
extends RefCounted

## Signal emitted when behavior state changes
signal state_changed(new_state: State)

## Signal emitted when behavior starts executing
signal started

## Signal emitted when behavior completes
signal completed

## Signal emitted when behavior fails
signal failed

## Enum to represent the current state of a behavior
enum State {
	INACTIVE,   ## Behavior is not currently active
	ACTIVE,     ## Behavior is currently executing
	COMPLETED,  ## Behavior has completed successfully
	FAILED      ## Behavior has failed to complete
}

## Priority levels for different behaviors
enum Priority {
	VERY_LOW = 0,    ## Lowest priority behaviors (e.g., idle wandering)
	LOW = 25,        ## Low priority behaviors (e.g., exploration)
	MEDIUM = 50,     ## Medium priority behaviors (e.g., routine tasks)
	HIGH = 75,       ## High priority behaviors (e.g., responding to threats)
	VERY_HIGH = 100, ## Very high priority behaviors (e.g., critical resource gathering)
	CRITICAL = 200   ## Survival-critical behaviors (e.g., energy management)
}

## Unique identifier for this behavior
var id: String:
	get:
		return id
	set(value):
		id = value

## Name of the behavior
var name: String:
	get:
		return name
	set(value):
		name = value

## Priority of the behavior (higher values indicate higher priority)
var priority: int = 0:
	get:
		return priority
	set(value):
		priority = value

## List of conditions that must be met for this behavior to execute
var conditions: Array[Condition] = []:
	get:
		return conditions
	set(value):
		conditions = value

## List of sub-behaviors that this behavior may execute
var sub_behaviors: Array[Behavior] = []:
	get:
		return sub_behaviors
	set(value):
		sub_behaviors = value

## List of actions that this behavior will perform
var actions: Array[Action] = []:
	get:
		return actions
	set(value):
		actions = value

## Reference to the ant executing this behavior
var ant: Ant:
	get:
		return ant
	set(value):
		ant = value

## Current state of the behavior
var state: State = State.INACTIVE:
	get:
		return state
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)
			match state:
				State.ACTIVE:
					started.emit()
				State.COMPLETED:
					completed.emit()
				State.FAILED:
					failed.emit()

## Currently executing sub-behavior, if any
var current_sub_behavior: Behavior = null

## Index of the current action being executed
var current_action_index: int = 0

## Cache for condition results during a single update cycle
var condition_cache: Dictionary = {}

## Initialize the behavior with a priority level
func _init(_priority: Priority) -> void:
	priority = _priority
	name = get_script().get_path().get_file().get_basename()
	if name.begins_with("@"):
		name = "Behavior"
	name = "%s (Priority: %d)" % [name, priority]

## Start the behavior for the given ant
func start(_ant: Ant) -> void:
	ant = _ant
	condition_cache.clear()
	state = State.ACTIVE
	current_action_index = 0
	for sub_behavior in sub_behaviors:
		sub_behavior.start(ant)

## Serialize the behavior to a dictionary
func to_dict() -> Dictionary:
	var data := {
		"id": id,
		"name": name,
		"priority": priority,
		"state": state,
		"conditions": [],
		"actions": [],
		"sub_behaviors": []
	}
	
	# Serialize conditions
	for condition in conditions:
		if condition.has_method("to_dict"):
			data["conditions"].append(condition.to_dict())
	
	# Serialize actions
	for action in actions:
		if action.has_method("to_dict"):
			data["actions"].append(action.to_dict())
	
	# Serialize sub-behaviors
	for sub_behavior in sub_behaviors:
		data["sub_behaviors"].append(sub_behavior.to_dict())
	
	return data

## Create a behavior from a dictionary
static func from_dict(data: Dictionary) -> Behavior:
	var behavior := Behavior.new(data["priority"])
	behavior.id = data["id"]
	behavior.name = data["name"]
	behavior.state = data["state"]
	
	# Deserialize conditions
	for condition_data in data["conditions"]:
		if condition_data.has("type"):
			var condition = load(condition_data["type"]).new()
			condition.from_dict(condition_data)
			behavior.conditions.append(condition)
	
	# Deserialize actions
	for action_data in data["actions"]:
		if action_data.has("type"):
			var action = load(action_data["type"]).new()
			action.from_dict(action_data)
			behavior.actions.append(action)
	
	# Deserialize sub-behaviors
	for sub_behavior_data in data["sub_behaviors"]:
		behavior.sub_behaviors.append(Behavior.from_dict(sub_behavior_data))
	
	return behavior

## Save behavior tree to JSON file
static func save_to_json(behavior: Behavior, filepath: String) -> Error:
	var data := behavior.to_dict()
	var json_string := JSON.stringify(data, "\t")
	
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
		
	file.store_string(json_string)
	return OK

## Load behavior tree from JSON file
static func load_from_json(filepath: String) -> Behavior:
	var json = JSON.new()
	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: %s" % filepath)
		return null
		
	var json_string := file.get_as_text()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse JSON: %s" % json.get_error_message())
		return null
		
	return Behavior.from_dict(json.data)

## Update the behavior, returns true if the behavior is complete or inactive
# In behavior.gd
func update(delta: float, params: Dictionary) -> bool:
	print("\nUpdating behavior: %s (State: %s)" % [name, State.keys()[state]])
	print("Number of conditions: %d" % conditions.size())
	print("Number of sub-behaviors: %d" % sub_behaviors.size())
	
	if state != State.ACTIVE:
		print("%s not active, returning" % name)
		return true

	print("Checking conditions for: %s" % name)
	if not should_execute(params):
		print("Conditions not met for: %s" % name)
		state = State.INACTIVE
		return true
	print("Conditions met for: %s" % name)

	# Handle current sub-behavior if one exists
	if current_sub_behavior:
		print("Updating current sub-behavior: %s" % current_sub_behavior.name)
		if current_sub_behavior.update(delta, params):
			print("Sub-behavior completed, clearing current sub-behavior")
			current_sub_behavior = null
			return true  # Important: Return true when sub-behavior completes
		elif current_sub_behavior.state == State.FAILED:
			print("Sub-behavior failed, failing this behavior")
			state = State.FAILED
			return true
		else:
			return false

	# Try to select and start a new sub-behavior
	var highest_priority := -1
	var selected_behavior: Behavior = null
	
	print("Checking %d sub-behaviors for %s" % [sub_behaviors.size(), name])
	for sub_behavior in sub_behaviors:
		print("  Checking sub-behavior: %s (Priority: %d)" % [sub_behavior.name, sub_behavior.priority])
		if sub_behavior.should_execute(params) and sub_behavior.priority > highest_priority:
			highest_priority = sub_behavior.priority
			selected_behavior = sub_behavior
	
	if selected_behavior:
		print("Selected sub-behavior: %s" % selected_behavior.name)
		current_sub_behavior = selected_behavior
		current_sub_behavior.state = State.ACTIVE
		current_sub_behavior.start(ant)
		return false

	# If we have actions, execute them
	if current_action_index < actions.size():
		var action = actions[current_action_index]
		if action.is_completed():
			current_action_index += 1
			return false
		else:
			action.update(delta)
			return false
	else:
		# No more actions to execute
		state = State.COMPLETED
		return true

## Check if all conditions for this behavior are met
func should_execute(params: Dictionary) -> bool:
	print("Checking %d conditions for %s" % [conditions.size(), name])
	for condition in conditions:
		print("Checking condition type: %s" % condition.get_class())
		if not condition.is_met(ant, condition_cache, params):
			return false
	return true

## Add a sub-behavior to this behavior
func add_sub_behavior(behavior: Behavior) -> void:
	sub_behaviors.append(behavior)

## Add an action to this behavior
func add_action(action: Action) -> void:
	actions.append(action)

## Add a condition to this behavior
func add_condition(condition: Condition) -> void:
	conditions.append(condition)

## Add multiple conditions to this behavior
func add_conditions(new_conditions: Array[Condition]) -> void:
	conditions.append_array(new_conditions)

## Clear the condition cache at the end of each update cycle
func clear_condition_cache() -> void:
	condition_cache.clear()

## Reset the behavior to its initial state
func reset() -> void:
	state = State.INACTIVE
	current_sub_behavior = null
	current_action_index = 0
	condition_cache.clear()
	
	for sub_behavior in sub_behaviors:
		sub_behavior.reset()
	
	for action in actions:
		action.reset()

## Builder class for constructing behaviors
class BehaviorBuilder:
	var behavior: Behavior
	var behavior_class: GDScript
	var _priority: Priority
	var _conditions: Array[Condition] = []
	var _actions: Array[Action] = []
	var _sub_behaviors: Array[Dictionary] = []  # Array of {behavior: Behavior, priority: Priority}
	
	func _init(b_class: GDScript, p: Priority) -> void:
		behavior_class = b_class
		_priority = p
	
	## Add a condition to the behavior
	func with_condition(condition: Condition) -> BehaviorBuilder:
		_conditions.append(condition)
		return self
	
	## Add an action to the behavior
	func with_action(action: Action) -> BehaviorBuilder:
		_actions.append(action)
		return self
	
	## Add a sub-behavior with custom priority
	func with_sub_behavior(sub_behavior: Behavior, priority: Priority = Priority.MEDIUM) -> BehaviorBuilder:
		_sub_behaviors.append({"behavior": sub_behavior, "priority": priority})
		return self
	
	## Build and return the configured behavior
	func build() -> Behavior:
		behavior = behavior_class.new(_priority)
		
		# Add conditions
		for condition in _conditions:
			behavior.add_condition(condition)
		
		# Add actions
		for action in _actions:
			behavior.add_action(action)
				
		return behavior

## Base class for food collection behaviors
class CollectFood extends Behavior:
	static func create(_priority: Priority = Priority.MEDIUM) -> BehaviorBuilder:
		return BehaviorBuilder.new(CollectFood, _priority)\
			.with_condition(
				Operator.not_condition(
					Condition.LowEnergy.create()\
						.with_param("threshold", 20.0)\
						.build()
				)
			)

## Search behavior and its sub-behaviors
class SearchForFood extends Behavior:
	static func create(_priority: Priority = Priority.MEDIUM) -> BehaviorBuilder:
		return BehaviorBuilder.new(SearchForFood, _priority)\
			.with_condition(
				Operator.not_condition(
					Operator.or_condition([
						Condition.OverloadedWithFood.create()\
							.with_param("threshold", 0.9)\
							.build(),
						Condition.LowEnergy.create()\
							.with_param("threshold", 20.0)\
							.build(),
						Condition.CarryingFood.create().build()
					])
				)
			)

## Behavior for harvesting food
class HarvestFood extends Behavior:
	static func create(_priority: Priority = Priority.HIGH) -> BehaviorBuilder:
		return BehaviorBuilder.new(HarvestFood, _priority)\
			.with_condition(
				Operator.and_condition([
					Condition.FoodInView.create().build(),
					Operator.not_condition(
						Operator.or_condition([
							Condition.OverloadedWithFood.create()\
								.with_param("threshold", 0.9)\
								.build(),
							Condition.LowEnergy.create()\
								.with_param("threshold", 20.0)\
								.build()
						])
					)
				])
			)\
			.with_action(
				Action.MoveToFood.create()\
					.with_param("movement_rate", 1.0)\
					.build()
			)\
			.with_action(
				Action.Harvest.create()\
					.with_param("harvest_rate", 1.0)\
					.build()
			)

## Behavior for returning to the colony
class ReturnToColony extends Behavior:
	static func create(_priority: Priority = Priority.HIGH) -> BehaviorBuilder:
		return BehaviorBuilder.new(ReturnToColony, _priority)\
			.with_condition(
				Operator.or_condition([
					Condition.LowEnergy.create()\
						.with_param("threshold", 20.0)\
						.build(),
					Condition.OverloadedWithFood.create()\
						.with_param("threshold", 0.9)\
						.build()
				])
			)

## Behavior for storing food in the colony
class StoreFood extends Behavior:
	static func create(_priority: Priority = Priority.VERY_HIGH) -> BehaviorBuilder:
		return BehaviorBuilder.new(StoreFood, _priority)\
			.with_condition(
				Operator.and_condition([
					Condition.AtHome.create()\
						.with_param("home_threshold", 10.0)\
						.build(),
					Condition.CarryingFood.create().build()
				])
			)\
			.with_action(
				Action.Store.create()\
					.with_param("store_rate_modifier", 1.0)\
					.build()
			)

## Behavior for resting when energy is low
class Rest extends Behavior:
	static func create(_priority: Priority = Priority.CRITICAL) -> BehaviorBuilder:
		return BehaviorBuilder.new(Rest, _priority)\
			.with_condition(
				Operator.and_condition([
					Condition.LowEnergy.create()\
						.with_param("threshold", 20.0)\
						.build(),
					Condition.AtHome.create()\
						.with_param("home_threshold", 10.0)\
						.build()
				])
			)\
			.with_action(
				Action.Rest.create()\
					.with_param("rate_modifier", 10.0)\
					.build()
			)

## Behavior for following home pheromones
class FollowHomePheromones extends Behavior:
	static func create(_priority: Priority = Priority.HIGH) -> BehaviorBuilder:
		return BehaviorBuilder.new(FollowHomePheromones, _priority)\
			.with_condition(
				Condition.HomePheromoneSensed.create().build()
			)\
			.with_action(
				Action.FollowPheromone.create()\
					.with_param("pheromone_type", "home")\
					.with_param("rate_modifier", 1.0)\
					.build()
			)

## Behavior for following food pheromones
class FollowFoodPheromones extends Behavior:
	static func create(_priority: Priority = Priority.MEDIUM) -> BehaviorBuilder:
		return BehaviorBuilder.new(FollowFoodPheromones, _priority)\
			.with_condition(
				Condition.FoodPheromoneSensed.create().build()
			)\
			.with_action(
				Action.FollowPheromone.create()\
					.with_param("pheromone_type", "food")\
					.with_param("rate_modifier", 1.0)\
					.build()
			)
			
## Behavior for wandering when searching for home
class WanderForHome extends Behavior:
	static func create(_priority: Priority = Priority.MEDIUM) -> BehaviorBuilder:
		return BehaviorBuilder.new(WanderForHome, _priority)\
			.with_condition(
				Operator.not_condition(
					Condition.HomePheromoneSensed.create().build()
				)
			)\
			.with_action(
				Action.RandomMove.create()\
					.with_param("move_duration", 2.0)\
					.with_param("rate_modifier", 1.0)\
					.build()
			)

## Behavior for wandering when searching for food
class WanderForFood extends Behavior:
	static func create(_priority: Priority = Priority.LOW) -> BehaviorBuilder:
		return BehaviorBuilder.new(WanderForFood, _priority)\
			.with_condition(
				Operator.not_condition(
					Condition.FoodPheromoneSensed.create().build()
				)
			)\
			.with_action(
				Action.RandomMove.create()\
					.with_param("move_duration", 2.0)\
					.with_param("rate_modifier", 1.0)\
					.build()
			)
