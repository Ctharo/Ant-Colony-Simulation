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

#region Properties
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

var name: String = ""
var priority: int = Priority.MEDIUM
var action: Action
var conditions: Array[LogicExpression] = []
var logger: Logger
#endregion

#region Initialization
func _init(p_priority: int = Priority.MEDIUM) -> void:
	priority = p_priority
	logger = Logger.new("behavior", DebugLogger.Category.BEHAVIOR)
#endregion

#region Public Methods
func add_condition(condition: LogicExpression) -> void:
	conditions.append(condition)
	logger.trace("Added condition to behavior '%s'" % name)

func set_action(p_action: Action) -> void:
	action = p_action
	logger.trace("Set action for behavior '%s': %s" % [name, action.name])

func start() -> void:
	state = State.ACTIVE
	logger.info("Starting behavior '%s'" % name)
	started.emit()

func should_activate() -> bool:
	return _check_conditions()

func can_execute() -> bool:
	return action != null and action.can_execute()

func execute(delta: float, ant: Ant) -> void:
	if state != State.ACTIVE:
		return

	if not _check_conditions():
		logger.trace("Conditions no longer met for '%s'" % name)
		stop()
		return

	action.execute(delta)

	if action.is_completed():
		state = State.COMPLETED
		completed.emit()
		logger.trace("Behavior '%s' completed" % name)

func stop() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		logger.info("Stopping behavior '%s'" % name)
		if action:
			action.stop()
		interrupted.emit()

func reset() -> void:
	state = State.INACTIVE
	if action:
		action.reset()
	logger.trace("Reset behavior '%s'" % name)

func is_active() -> bool:
	return state == State.ACTIVE

func is_completed() -> bool:
	return state == State.COMPLETED
#endregion

#region Private Methods
func _check_conditions() -> bool:
	if conditions.is_empty():
		return true

	for condition in conditions:
		if not condition.evaluate():
			return false
	return true
#endregion
