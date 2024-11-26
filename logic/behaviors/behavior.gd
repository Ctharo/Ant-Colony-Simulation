class_name Behavior
extends RefCounted

#region Signals
signal started
signal completed
signal interrupted
signal state_changed(new_state: State)
#endregion

#region Enums
enum State { INACTIVE, ACTIVE, COMPLETED, INTERRUPTED }
enum Priority { LOWEST = 0, LOW = 25, MEDIUM = 50, HIGH = 75, HIGHEST = 100 }
#endregion

#region Builder
## Builder class for constructing behaviors
class Builder:

	var _name: String = ""
	var _priority: int
	var _ant: Ant
	var _actions: Array[Action] = []
	var _conditions: Array[ConditionSystem.Condition] = []
	var _condition_system: ConditionSystem
	var logger: Logger

	func _init(priority: int = Behavior.Priority.MEDIUM) -> void:
		logger = Logger.new("behavior.builder", DebugLogger.Category.BEHAVIOR)
		_priority = priority

	## Set a name for the behavior
	func with_name(name: String) -> Builder:
		_name = name
		return self

	## Add an action to the behavior
	func with_action(action: Action) -> Builder:
		_actions.append(action)
		return self

	## Add multiple actions to the behavior
	func with_actions(actions: Array[Action]) -> Builder:
		_actions.append_array(actions)
		return self

	## Add a condition to the behavior
	func with_condition_system(condition_system: ConditionSystem) -> Builder:
		_condition_system = condition_system
		return self


	## Add a condition to the behavior
	func with_condition(condition: ConditionSystem.Condition) -> Builder:
		_conditions.append(condition)
		return self

	## Add multiple conditions to the behavior
	func with_conditions(conditions: Array[ConditionSystem.Condition]) -> Builder:
		_conditions.append_array(conditions)
		return self

	## Set the ant that will perform this behavior
	func with_ant(ant: Ant) -> Builder:
		_ant = ant
		return self

	## Set the priority level for this behavior
	func with_priority(priority: int) -> Builder:
		_priority = priority
		return self

	## Build and return the configured behavior
	func build() -> Behavior:
		var behavior := Behavior.new(_priority)

		if not _name.is_empty():
			behavior.name = _name

		if _ant:
			behavior.ant = _ant

		for condition in _conditions:
			behavior.add_condition(condition)

		for action in _actions:
			if _ant and not action.ant:
				action.ant = _ant
			behavior.add_action(action)

		return behavior

## Static method to create a new builder instance
static func builder(priority: int = Priority.MEDIUM) -> Builder:
	return Builder.new(priority)
#endregion

#region Properties
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

var name: String = "":
	set(value):
		name = value

var priority: int = Priority.MEDIUM:
	set(value):
		priority = value

var ant: Ant:
	set(value):
		ant = value
		_update_action_references()

var conditions: Array[ConditionSystem.Condition] = []:
	set(value):
		conditions = value

var actions: Array[Action] = []:
	set(value):
		actions = value
		if is_instance_valid(ant):
			_update_action_references()

## Reference to the condition evaluation system
var _condition_system: ConditionSystem
var logger: Logger
#endregion

#region Initialization
func _init(p_priority: int = Priority.MEDIUM, condition_system: ConditionSystem = null) -> void:
	priority = p_priority
	_condition_system = condition_system
	logger = Logger.new("behavior", DebugLogger.Category.BEHAVIOR)

#endregion

#region Public Methods
## Add a condition to this behavior
func add_condition(condition: ConditionSystem.Condition) -> void:
	conditions.append(condition)
	logger.info("Added condition to behavior '%s'" % name)

## Add an action to this behavior
func add_action(action: Action) -> void:
	actions.append(action)
	if is_instance_valid(ant):
		action.ant = ant
	logger.info("Added action to behavior '%s': %s" % [name, action.get_script().resource_path.get_file()])

## Get all conditions for this behavior
func get_conditions() -> Array[ConditionSystem.Condition]:
	return conditions

## Start the behavior
func start(p_ant: Ant, p_condition_system: ConditionSystem = null) -> void:
	if not is_instance_valid(p_ant):
		logger.error("Cannot start behavior '%s' with invalid ant reference" % name)
		return

	if not p_condition_system and not conditions.is_empty():
		logger.warn("Starting behavior '%s' with conditions but no condition system" % name)
	else:
		logger.info("Starting behavior '%s' (Current state: %s)" % [name, State.keys()[state]])

	ant = p_ant
	_condition_system = p_condition_system
	state = State.ACTIVE

	logger.trace("Behavior '%s' state set to: %s" % [name, State.keys()[state]])
	started.emit()

	for action in actions:
		action.start(ant)
		logger.trace("Started action: %s" % action.get_script().resource_path.get_file())

## Check if the behavior should activate
func should_activate(context: Dictionary) -> bool:
	var conditions_met = _check_conditions(context)
	var _should_activate = state != State.COMPLETED and conditions_met

	logger.trace("Checking activation for '%s':\n" % name +
		"  Current state: %s\n" % State.keys()[state] +
		"  Conditions met: %s\n" % conditions_met +
		"  Should activate: %s" % _should_activate)

	return _should_activate

## Update the behavior
func update(delta: float, context: Dictionary) -> void:
	logger.trace("Updating behavior '%s' (State: %s)" % [name, State.keys()[state]])

	if state != State.ACTIVE:
		return

	if not _check_conditions(context):
		logger.info("Conditions no longer met for '%s', interrupting" % name)
		interrupt()
		return

	_update_actions(delta)
	logger.trace("After update - Behavior '%s' state: %s" % [name, State.keys()[state]])

## Interrupt the behavior
func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		logger.info("Interrupting behavior '%s'" % name)

		for action in actions:
			action.interrupt()
			logger.trace("Interrupted action: %s" % action.get_script().resource_path.get_file())

		interrupted.emit()

## Reset the behavior to its initial state
func reset() -> void:
	state = State.INACTIVE
	logger.info("Reset behavior '%s'" % name)

	for action in actions:
		action.reset()
		logger.trace("Reset action: %s" % action.get_script().resource_path.get_file())
#endregion

#region Private Methods
## Check if all conditions are met using the context
func _check_conditions(context: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	if not _condition_system:
		logger.error("No condition system available for behavior '%s'" % name)
		return false

	for condition in conditions:
		if not _condition_system.evaluate_condition(condition, context):
			return false
	return true

## Update all actions
func _update_actions(delta: float) -> void:
	var all_completed := true

	for action in actions:
		if not action.is_completed():
			action.update(delta)
			all_completed = false

	if all_completed and not actions.is_empty():
		state = State.COMPLETED
		completed.emit()
		logger.info("Behavior '%s' completed (all actions finished)" % name)

## Update ant references in actions when ant changes
func _update_action_references() -> void:
	if not is_instance_valid(ant):
		return

	for action in actions:
		action.ant = ant
		logger.trace("Updated ant reference for action: %s" % action.get_script().resource_path.get_file())
#endregion

#region Debug Methods
## Get debug information about the behavior
func get_debug_info() -> Dictionary:
	var info = {
		"name": name,
		"priority": priority,
		"state": State.keys()[state],
		"conditions": conditions.size(),
		"actions": actions.size()
	}

	logger.debug("\nBehavior Debug Info for '%s':" % name +
		"\n  Priority: %d" % priority +
		"\n  State: %s" % State.keys()[state] +
		"\n  Conditions: %d" % conditions.size() +
		"\n  Actions: %d" % actions.size())

	return info
#endregion
