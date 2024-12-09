class_name Behavior
extends Evaluatable

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
## Represents the current state of the behavior
enum State { 
	INACTIVE,    ## Behavior is not running
	ACTIVE,      ## Behavior is currently executing
	COMPLETED,   ## Behavior has completed successfully
	INTERRUPTED  ## Behavior was interrupted before completion
}

## Defines priority levels for behavior execution
enum Priority { 
	LOWEST = 0,
	LOW = 25,
	MEDIUM = 50,
	HIGH = 75,
	HIGHEST = 100 
}
#endregion

#region Properties
## Current state of the behavior
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

## Execution priority of this behavior
var priority: int = Priority.MEDIUM

## Action to be executed by this behavior
var action: Action

## Conditions that must be met for behavior execution
var conditions: Array[Logic] = []

## Reference to the ant being controlled
var ant: Ant
#endregion

#region Initialization
func _init(p_priority: int = Priority.MEDIUM) -> void:
	priority = p_priority
	logger = Logger.new("behavior", DebugLogger.Category.BEHAVIOR)

## Initialize the behavior and its components
func initialize(p_evaluation_system: EvaluationSystem) -> void:
	super(p_evaluation_system)
	_initialize_conditions()
#endregion

#region Public Methods
## Add a new condition to the behavior
func add_condition(condition: Logic) -> void:
	if not condition:
		logger.warn("Attempted to add null condition to behavior '%s'" % name)
		return
		
	conditions.append(condition)
	if evaluation_system:
		condition.initialize(evaluation_system)
		add_dependency(condition.id)

## Set the action for this behavior
func set_action(p_action: Action) -> void:
	if not p_action:
		logger.warn("Attempted to set null action for behavior '%s'" % name)
		return
		
	action = p_action
	logger.trace("Set action for behavior '%s': %s" % [name, action.name])

## Start behavior execution
func start(p_ant: Ant = null) -> void:
	if p_ant:
		ant = p_ant
		
	if not _validate_can_start():
		return
		
	state = State.ACTIVE
	logger.info("Starting behavior '%s'" % name)
	started.emit()

## Check if behavior can be activated
func should_activate() -> bool:
	return evaluate() and can_execute()

## Check if behavior can execute its action
func can_execute() -> bool:
	return action != null and action.can_execute()

## Execute the behavior's action
func execute(delta: float, p_ant: Ant = null) -> void:
	if p_ant:
		ant = p_ant
		
	if not _validate_execution_state():
		return
		
	if not _validate_conditions():
		return
		
	_execute_action(delta)
	_check_completion()

## Stop behavior execution
func stop() -> void:
	if state != State.ACTIVE:
		return
		
	state = State.INTERRUPTED
	logger.info("Stopping behavior '%s'" % name)
	
	if action:
		action.stop()
		
	interrupted.emit()

## Reset behavior to initial state
func reset() -> void:
	state = State.INACTIVE
	if action:
		action.reset()
	logger.trace("Reset behavior '%s'" % name)

## Check if behavior is currently active
func is_active() -> bool:
	return state == State.ACTIVE

## Check if behavior has completed
func is_completed() -> bool:
	return state == State.COMPLETED
#endregion

#region Protected Methods
## Calculate if all conditions are met
func _calculate() -> bool:
	for condition in conditions:
		if not condition.evaluate():
			return false
	return true
#endregion

#region Private Methods
## Initialize all behavior conditions
func _initialize_conditions() -> void:
	for condition in conditions:
		condition.initialize(evaluation_system)
		add_dependency(condition.id)

## Validate behavior can start execution
func _validate_can_start() -> bool:
	if state == State.ACTIVE:
		logger.warn("Behavior '%s' is already active" % name)
		return false
		
	if not action:
		logger.error("Behavior '%s' has no action set" % name)
		return false
		
	return true

## Validate current execution state
func _validate_execution_state() -> bool:
	if state != State.ACTIVE:
		logger.warn("Cannot execute inactive behavior '%s'" % name)
		return false
		
	if not ant:
		logger.error("No ant reference set for behavior '%s'" % name)
		return false
		
	return true

## Validate all conditions are still met
func _validate_conditions() -> bool:
	if not evaluate():
		logger.trace("Conditions no longer met for '%s'" % name)
		stop()
		return false
	return true

## Execute the behavior's action
func _execute_action(delta: float) -> void:
	action.execute(delta)

## Check if behavior has completed
func _check_completion() -> void:
	if action.is_completed():
		state = State.COMPLETED
		completed.emit()
		logger.trace("Behavior '%s' completed" % name)
#endregion
