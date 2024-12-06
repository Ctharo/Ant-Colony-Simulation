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
	var _action: Action
	var _conditions: Array[Condition] = []
	var _condition_system: ConditionSystem
	var logger: Logger

	func _init(priority: int = Behavior.Priority.MEDIUM) -> void:
		logger = Logger.new("behavior.builder", DebugLogger.Category.BEHAVIOR)
		_priority = priority

	## Set a name for the behavior
	func with_name(name: String) -> Builder:
		_name = name
		return self

	## Set the action for the behavior
	func with_action(action: Action) -> Builder:
		_action = action
		return self

	## Add a condition to the behavior
	func with_condition_system(condition_system: ConditionSystem) -> Builder:
		_condition_system = condition_system
		return self

	## Add a condition to the behavior
	func with_condition(condition: Condition) -> Builder:
		_conditions.append(condition)
		return self

	## Add multiple conditions to the behavior
	func with_conditions(conditions: Array[Condition]) -> Builder:
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

		if _action:
			behavior.set_action(_action)

		if _condition_system:
			behavior._condition_system = _condition_system

		for condition in _conditions:
			behavior.add_condition(condition)

		return behavior

## Static method to create a new builder instance
static func builder(_priority: int = Priority.MEDIUM) -> Builder:
	return Builder.new(_priority)
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
		if action:
			action.ant = value

## The single action this behavior manages
var action: Action:
	set(value):
		action = value
		if is_instance_valid(ant):
			action.ant = ant

var conditions: Array[Condition] = []
var config: BehaviorConfig
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
func add_condition(condition: Condition) -> void:
	conditions.append(condition)
	logger.trace("Added condition to behavior '%s': %s" % [name, condition.config])

func set_action(p_action: Action) -> void:
	action = p_action
	if is_instance_valid(ant):
		action.ant = ant
	logger.trace("Set action for behavior '%s': %s" % [name, action.name])

func start(p_ant: Ant, p_condition_system: ConditionSystem = null) -> void:
	if not is_instance_valid(p_ant):
		logger.error("Cannot start behavior '%s' with invalid ant reference" % name)
		return

	if not action:
		logger.error("Cannot start behavior '%s' with no action set" % name)
		return

	ant = p_ant
	_condition_system = p_condition_system
	state = State.ACTIVE

	logger.info("Starting behavior '%s' (Action: %s)" % [name, action.name])
	action.start(ant)
	started.emit()

func should_activate(context: Dictionary) -> bool:
	return _check_conditions(context)

func update(delta: float, context: Dictionary) -> void:
	if state != State.ACTIVE:
		return

	if not _check_conditions(context):
		logger.trace("Conditions no longer met for '%s', interrupting" % name)
		interrupt()
		return

	action.update(delta)

	if action.is_completed():
		state = State.COMPLETED
		completed.emit()
		logger.trace("Behavior '%s' completed (action finished)" % name)

func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		logger.info("Interrupting behavior '%s'" % name)
		action.interrupt()
		interrupted.emit()

func reset() -> void:
	state = State.INACTIVE
	action.reset()
	logger.trace("Reset behavior '%s'" % name)


#endregion

#region Private Methods
func _check_conditions(context: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	if not _condition_system:
		logger.error("No condition system available for behavior '%s'" % name)
		return false

	for condition in conditions:
		if not _evaluate_condition(condition, context):
			return false
	return true

func _evaluate_condition(condition: Condition, context: Dictionary) -> bool:
	var result = _condition_system.evaluate_condition(condition, context)
	logger.debug("Evaluated condition for task '%s': %s -> %s" % [name, _format_condition(condition.config), result])
	return result

## Helper function to format conditions for debug output
func _format_condition(_config: ConditionConfig) -> String:
	match config.type:
		"Operator":
			var operator_config := _config as OperatorConfig
			var formatted_operands = operator_config.operands.map(func(op): return _format_condition(op))

			# Formatting operators with human-readable logic
			match operator_config.operator_type:
				"not":
					return "not (" + formatted_operands[0] + ")"
				"and":
					return "(" + " and ".join(formatted_operands) + ")"
				"or":
					return "(" + " or ".join(formatted_operands) + ")"
		"Custom":
			var custom_config := _config as CustomConditionConfig
			return custom_config.condition_name
		"PropertyCheck":
			var property_config := _config as PropertyCheckConfig
			return "(%s %s %s)" % [
				property_config.property,
				property_config.operator.to_lower(),
				property_config.value if property_config.value_from.is_empty() else property_config.value_from
			]

	return "Unknown Condition"
#endregion

#region Debug Methods
## Get debug information about the behavior
func get_debug_info() -> Dictionary:
	var info = {
		"name": name,
		"priority": priority,
		"state": State.keys()[state],
		"conditions": conditions.size(),
		"action": action.name if action else "None"
	}

	logger.debug("\nBehavior Debug Info for '%s':" % name +
		"\n  Priority: %d" % priority +
		"\n  State: %s" % State.keys()[state] +
		"\n  Action: %s" % (action.name if action else "None") +
		"\n  Conditions: %d" % conditions.size())

	return info
#endregion
