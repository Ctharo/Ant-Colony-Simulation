class_name Behavior
extends Node

#region Signals
## Emitted when behavior starts execution
signal started
## Emitted when behavior completes successfully
signal completed
## Emitted when behavior is interrupted
signal interrupted
## Emitted when behavior state changes
signal state_changed(new_state: State)
#endregion

#region Enums
enum State { 
	INACTIVE,
	ACTIVE,
	COMPLETED,
	INTERRUPTED
}

enum Priority { 
	LOWEST = 0,
	LOW = 25,
	MEDIUM = 50,
	HIGH = 75,
	HIGHEST = 100 
}
#endregion

#region Properties
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

var priority: int = Priority.MEDIUM
var action: Action
var ant: Ant
var logic: Logic
var logger: Logger
#endregion

func _init(p_priority: int = Priority.MEDIUM) -> void:
	priority = p_priority
	logger = Logger.new("behavior", DebugLogger.Category.BEHAVIOR)
	logic = Logic.new("behavior_" + str(get_instance_id()))
	
	# Default activation formula - can be customized per behavior instance
	logic.add_formula(
		"should_activate",
		"target_distance < activation_range and has_resources",
		["target_distance", "activation_range", "has_resources"]
	)

func start(p_ant: Ant = null) -> void:
	if p_ant:
		ant = p_ant
		
	if not _validate_can_start():
		return
		
	state = State.ACTIVE
	logger.info("Starting behavior '%s'" % name)
	started.emit()

func should_activate() -> bool:
	return logic.evaluate_formula("should_activate") and can_execute()

func can_execute() -> bool:
	return action != null and action.can_execute()

func execute(delta: float, p_ant: Ant = null) -> void:
	if p_ant:
		ant = p_ant
		
	if not _validate_execution_state():
		return
		
	if not _check_conditions():
		return
		
	_execute_action(delta)
	_check_completion()

func stop() -> void:
	if state != State.ACTIVE:
		return
		
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

#region Private Methods
func _validate_can_start() -> bool:
	if state == State.ACTIVE:
		logger.warn("Behavior '%s' is already active" % name)
		return false
		
	if not action:
		logger.error("Behavior '%s' has no action set" % name)
		return false
		
	return true

func _validate_execution_state() -> bool:
	if state != State.ACTIVE:
		logger.warn("Cannot execute inactive behavior '%s'" % name)
		return false
		
	if not ant:
		logger.error("No ant reference set for behavior '%s'" % name)
		return false
		
	return true

func _check_conditions() -> bool:
	if not should_activate():
		logger.trace("Conditions no longer met for '%s'" % name)
		stop()
		return false
	return true

func _execute_action(delta: float) -> void:
	action.execute(delta)

func _check_completion() -> void:
	if action.is_completed():
		state = State.COMPLETED
		completed.emit()
		logger.trace("Behavior '%s' completed" % name)
#endregion
