class_name Task
extends RefCounted

#region Signals
signal started
signal completed
signal interrupted
signal state_changed(new_state: State)
#endregion

#region Enums
## Task states
enum State {
	INACTIVE,    ## Task is not running
	ACTIVE,      ## Task is currently running
	COMPLETED,   ## Task has completed successfully
	INTERRUPTED  ## Task was interrupted before completion
}

## Task priority levels
enum Priority {
	LOWEST = 0,
	LOW = 25,
	MEDIUM = 50,
	HIGH = 75,
	HIGHEST = 100
}
#endregion

#region Builder
## Builder class for constructing tasks
class Builder:

	var _task: Task
	var _conditions: Array[Condition] = []
	var _behaviors: Array[Dictionary] = []

	func _init(priority: Task.Priority = Task.Priority.MEDIUM) -> void:
		_task = Task.new(priority)

	## Add a condition to the task
	func with_condition(condition: Condition) -> Builder:
		_conditions.append(condition)
		return self

	## Add a behavior with custom priority
	func with_behavior(behavior: Behavior, priority: Behavior.Priority = Behavior.Priority.MEDIUM) -> Builder:
		_behaviors.append({
			"behavior": behavior,
			"priority": priority
		})
		return self

	## Build and return the configured task
	func build() -> Task:
		# Add conditions
		for condition in _conditions:
			_task.add_condition(condition)

		# Add behaviors
		for behavior_data in _behaviors:
			var behavior: Behavior = behavior_data.behavior
			behavior.priority = behavior_data.priority
			_task.add_behavior(behavior)

		return _task

## Static method to create a new builder instance
static func builder(priority: Priority = Priority.MEDIUM) -> Builder:
	return Builder.new(priority)
#endregion

#region Properties
## Current state of the task
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

## Name of the task for debugging
var name: String = "":
	set(value):
		name = value

## Priority level of this task
var priority: int = Priority.MEDIUM:
	set(value):
		priority = value

## Reference to the ant performing the task
var ant: Ant:
	set(value):
		ant = value
		_update_behavior_references()

## Array of behaviors available to this task
var behaviors: Array[Behavior] = []:
	set(value):
		behaviors = value
		if is_instance_valid(ant):
			_update_behavior_references()

# Add condition system reference
var _condition_system: ConditionSystem :
	set(value):
		if value == null:
			assert(false)
		_condition_system = value


## Array of conditions for this task
var conditions: Array[Condition] = []:
	set(value):
		conditions = value

## Currently active behavior
var active_behavior: Behavior:
	set(value):
		if value == active_behavior:
			return
		active_behavior = value

## Whether higher priority behaviors can interrupt lower priority ones
var allow_interruption: bool = true

var logger: Logger

## Dictionary of task configurations loaded from JSON
static var _task_configs: Dictionary

## Maps behavior types to their corresponding action types
const BEHAVIOR_TO_ACTION = {
	"WanderForFood": {
		"type": Action.RandomMove,
		"params": {
			"move_duration": 2.0
		}
	},
	"FollowFoodPheromones": {
		"type": Action.FollowPheromone,
		"params": {
			"pheromone_type": "food"
		}
	},
	"MoveToFood": {
		"type": Action.Move,
		"params": {
			"rate_modifier": 1.0
		}
	},
	"HarvestFood": {
		"type": Action.Harvest,
		"params": {
			"harvest_rate_modifier": 1.0
		}
	},
	"MoveToHome": {
		"type": Action.Move,
		"params": {
			"rate_modifier": 1.0
		}
	}
}

#endregion

#region Initialization
func _init(p_priority: int = Priority.MEDIUM, condition_system: ConditionSystem = null) -> void:
	priority = p_priority
	_condition_system = condition_system
	logger = Logger.new("task", DebugLogger.Category.TASK)

#endregion

#region Public Methods
## Update the task and its behaviors
func update(delta: float, context: Dictionary) -> void:
	logger.trace("Updating Task: %s" % name)

	if not _condition_system:
		logger.error("Missing condition system, cannot update task")
		return
		
	if state != Task.State.ACTIVE:
		logger.warn("Task %s marked as inactive, cannot update task" % name)
		return 

	logger.trace("Current active behavior: %s (State: %s)" % [
		active_behavior.name if active_behavior else "None",
		Behavior.State.keys()[active_behavior.state] if active_behavior else "N/A"
	])

	# Check task conditions using the condition system
	if not _check_conditions(context):
		logger.info("Task conditions not met, interrupting: %s" % name)
		interrupt()
		return

	# First check if current behavior should continue
	if active_behavior:
		if active_behavior.state == Behavior.State.COMPLETED:
			if active_behavior.should_activate(context):
				# Check if any higher priority behaviors are now valid
				var higher_priority_behavior = _check_higher_priority_behaviors(active_behavior.priority, context)
				if higher_priority_behavior:
					_switch_behavior(higher_priority_behavior)
				else:
					# Restart the current behavior as it's still the best choice
					logger.info("Restarting completed behavior '%s' as it's still optimal" % active_behavior.name)
					active_behavior.reset()
					active_behavior.start(ant, _condition_system)
			else:
				# Look for next valid behavior
				var next_behavior = _find_next_valid_behavior(context)
				if next_behavior:
					_switch_behavior(next_behavior)
				else:
					assert(false, "No behavior found, should loop") #TODO: Can we make a way to detect if behaviors loop forever/failsafe default?
					# Loop could be two primary behaviors - moving away from colony and moving toward colony
		elif active_behavior.should_activate(context):
			# Normal update flow for active behavior
			var higher_priority_behavior = _check_higher_priority_behaviors(active_behavior.priority, context)
			if higher_priority_behavior:
				_switch_behavior(higher_priority_behavior)
			else:
				logger.trace("Continuing current behavior")
				active_behavior.update(delta, context)
		else:
			# Current behavior no longer valid
			var next_behavior = _find_next_valid_behavior(context)
			if next_behavior:
				_switch_behavior(next_behavior)
			else:
				logger.info("No valid behaviors found")
				active_behavior.interrupt()
				active_behavior = null
	else:
		# No active behavior, find one to start
		var next_behavior = _find_next_valid_behavior(context)
		if next_behavior:
			_switch_behavior(next_behavior)

## Add a behavior to this task
func add_behavior(behavior: Behavior) -> void:
	if not is_instance_valid(behavior):
		logger.error("Cannot add invalid behavior to task")
		return

	behaviors.append(behavior)
	behavior.name = behavior.name if not behavior.name.is_empty() else "Behavior" + str(behaviors.size())

	if is_instance_valid(ant):
		behavior.ant = ant

	logger.trace("Added behavior '%s' to task '%s'" % [behavior.name, name])

## Add a condition to this task
func add_condition(condition: Condition) -> void:
	if not is_instance_valid(condition):
		logger.error("Cannot add invalid condition to task")
		return

	conditions.append(condition)
	logger.trace("Added condition to task '%s'" % name)

## Start the task
func start(p_ant: Ant) -> void:
	if state == State.ACTIVE:
		return

	if not is_instance_valid(p_ant):
		logger.error("Cannot start task with invalid ant reference")
		return

	ant = p_ant
	state = State.ACTIVE
	started.emit()
	logger.info("Started task: %s" % name)

## Interrupt the task
func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		if is_instance_valid(active_behavior):
			active_behavior.interrupt()
		active_behavior = null
		interrupted.emit()
		logger.info("Interrupted task: %s" % name)

## Reset the task to its initial state
func reset() -> void:
	state = State.INACTIVE

	if active_behavior:
		active_behavior.interrupt()
	active_behavior = null

	# Reset all behaviors
	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.reset()

## Get the current active behavior
func get_active_behavior() -> Behavior:
	if not is_instance_valid(active_behavior):
		return null

	if active_behavior.state != Behavior.State.ACTIVE:
		return null

	return active_behavior

## Get all conditions for this task
func get_conditions() -> Array[Condition]:
	return conditions

## Get debug information about the task
func get_debug_info() -> Dictionary:
	return {
		"name": name,
		"state": State.keys()[state],
		"priority": priority,
		"behavior_count": behaviors.size(),
		"active_behavior": active_behavior.name if is_instance_valid(active_behavior) else "None",
		"condition_count": conditions.size()
	}
#endregion

#region Private Methods
## Check if all conditions are met
func _check_conditions(context: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	if not _condition_system:
		logger.error("No condition system available for task '%s'" % name)
		assert(false, "Should always have a condition system")
		return false

	for condition: Condition in conditions:
		if not is_instance_valid(condition):
			continue

		if not _condition_system.evaluate_condition(condition, context):
			return false
	return true

## Check only behaviors with higher priority than the current one
func _check_higher_priority_behaviors(current_priority: int, context: Dictionary) -> Behavior:
	# Group behaviors by priority
	var priority_groups = _group_behaviors_by_priority(current_priority)

	# Sort priorities in descending order
	var priorities = priority_groups.keys()
	priorities.sort()
	priorities.reverse()
	var msg: String = "\nChecking higher priority behaviors (current priority: %d)" % current_priority

	# Check behaviors by priority level
	for _priority in priorities:
		msg += "\n	Checking priority level: %d" % _priority

		var behaviors_at_priority = priority_groups[_priority]
		var any_conditions_met = false

		for behavior in behaviors_at_priority:
			msg += "\n		Checking behavior: %s" % behavior.name

			var should_activate = behavior.should_activate(context)
			msg += "\n			Should activate: %s" % should_activate

			if should_activate:
				logger.trace(msg)
				return behavior

			any_conditions_met = any_conditions_met or should_activate

		if not any_conditions_met:
			msg += "\n	No behaviors at priority %d could activate, stopping checks" % _priority
			break
	msg += "\nNo higher priority behaviors could activate"
	logger.trace(msg)
	return null

## Find the next valid behavior
func _find_next_valid_behavior(context: Dictionary) -> Behavior:
	# Group behaviors by priority
	var priority_groups = _group_behaviors_by_priority()

	# Sort priorities in descending order
	var priorities = priority_groups.keys()
	priorities.sort()
	priorities.reverse()

	# Check behaviors in priority order
	for _priority in priorities:
		var behaviors_at_priority = priority_groups[_priority]
		for behavior: Behavior in behaviors_at_priority:
			logger.trace("Checking behavior: %s (Priority: %d)" % [behavior.name, behavior.priority])
			if behavior.should_activate(context):
				return behavior
		logger.trace("No behaviors at priority %d could activate" % _priority)
	return null

## Helper function to group behaviors by priority
func _group_behaviors_by_priority(min_priority: int = -1) -> Dictionary:
	var priority_groups: Dictionary = {}
	for behavior in behaviors:
		if not is_instance_valid(behavior):
			continue
		if behavior.priority <= min_priority:
			continue
		if not behavior.priority in priority_groups:
			priority_groups[behavior.priority] = []
		priority_groups[behavior.priority].append(behavior)
	return priority_groups

## Switch to a new behavior - handles all the transition logic
func _switch_behavior(new_behavior: Behavior) -> void:
	var transition_info = "Switching behaviors:"
	transition_info += " %s -> %s" % [
		active_behavior.name if active_behavior else "None",
		new_behavior.name if new_behavior else "None"
	]
	logger.info(transition_info)

	if active_behavior:
		active_behavior.interrupt()

	# Use direct assignment to avoid recursion
	active_behavior = new_behavior
	# Start behavior with condition system
	active_behavior.start(ant, _condition_system)

	logger.trace(
		"After switch - New behavior: %s (State: %s)" % [
			active_behavior.name,
			Behavior.State.keys()[active_behavior.state]
		]
	)

## Update ant references in all behaviors
func _update_behavior_references() -> void:
	if not is_instance_valid(ant):
		return

	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.ant = ant

## Check if all behaviors have completed
func _all_behaviors_completed() -> bool:
	for behavior in behaviors:
		if not is_instance_valid(behavior):
			continue

		if behavior.state != Behavior.State.COMPLETED:
			return false
	return true
#endregion

## Create an action from its type and configuration
static func create_action(action_type: GDScript, params: Dictionary, ant: Ant) -> Action:
	# Use the action's own static create method
	var builder = action_type.create()
	builder.with_ant(ant)

	# Add all params
	for key in params:
		builder.with_param(key, params[key])

	return builder.build()

## Create a task's behaviors from task configuration
static func create_task_behaviors(task_type: String, ant: Ant, condition_system: ConditionSystem) -> Array[Behavior]:
	if not task_type in _task_configs:
		push_error("Unknown task type: %s" % task_type)
		return []
		
	var task_config = _task_configs[task_type]
	var behaviors: Array[Behavior] = []
	
	# Add task behaviors
	if "behaviors" in task_config:
		for behavior_data in task_config.behaviors:
			var behavior = create_behavior_from_config(behavior_data, ant, condition_system)
			if behavior:
				behaviors.append(behavior)
				
	return behaviors

## Create a behavior from behavior configuration
static func create_behavior_from_config(config: Dictionary, ant: Ant, condition_system: ConditionSystem) -> Behavior:
	var behavior_type = config.type
	if not behavior_type in BEHAVIOR_TO_ACTION:
		push_error("Unknown behavior type: %s" % behavior_type)
		return null
		
	# Start building the behavior
	var builder = (Behavior.builder(Priority[config.get("priority", "MEDIUM")])
		.with_name(behavior_type)
		.with_ant(ant)
		.with_condition_system(condition_system))
	
	# Add behavior conditions
	if "conditions" in config:
		for condition_data in config.conditions:
			builder.with_condition(ConditionSystem.create_condition(condition_data))
	
	# Create action using factory method
	var action_config = BEHAVIOR_TO_ACTION[behavior_type]
	var action_params = action_config.params.duplicate()
	
	# Merge with behavior-specific params
	if "params" in config:
		action_params.merge(config.params)
	
	# Add the action to the behavior
	builder.with_action(create_action(action_config.type, action_params, ant))
	
	return builder.build()

## Load task configurations from JSON file
static func load_task_configs(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ERR_FILE_NOT_FOUND

	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	if result != OK:
		return result

	_task_configs = json.data.tasks
	return OK
