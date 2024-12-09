class_name Task
extends Evaluatable

#region Signals
## Emitted when task starts execution
signal started
## Emitted when task successfully completes
signal completed
## Emitted when task is interrupted before completion
signal interrupted
## Emitted when task state changes
signal state_changed(new_state: State)
#endregion

#region Enums
## Represents the current state of the task
enum State {
	INACTIVE,    ## Task is not running
	ACTIVE,      ## Task is currently running
	COMPLETED,   ## Task has completed successfully
	INTERRUPTED  ## Task was interrupted before completion
}

## Defines priority levels for task execution
enum Priority {
	LOWEST = 0,
	LOW = 25,
	MEDIUM = 50,
	HIGH = 75,
	HIGHEST = 100
}
#endregion

#region Exported Properties
## Task execution priority
@export var priority: Priority = Priority.MEDIUM

## Collection of behaviors associated with this task
@export var behaviors: Array[Behavior] = []

## Collection of conditions that must be met for task execution
@export var conditions: Array[Logic] = []

## Description of what the task does
@export_multiline var description: String = ""
#endregion

#region Runtime Properties
## Current state of the task
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

## Currently executing behavior
var active_behavior: Behavior

## Reference to the ant this task is controlling
var ant: Ant
#endregion

#region Lifecycle Methods

## Initialize the task and its components
func initialize(p_evaluation_system: EvaluationSystem) -> void:
	if Engine.is_editor_hint():
		return
		
	super(p_evaluation_system)
	_initialize_conditions()
	_initialize_behaviors()

## Update task state and behavior
func update(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if not _validate_active_state():
		return

	logger.trace("Updating Task: %s" % name)
	
	if not _check_conditions():
		return

	_update_behavior(delta)

## Reset task to initial state
func reset() -> void:
	if Engine.is_editor_hint():
		return
		
	state = State.INACTIVE
	_stop_active_behavior()
	
	for behavior in behaviors:
		behavior.reset()
#endregion

#region Protected Methods
## Calculate if all conditions are met
func _calculate() -> bool:
	if Engine.is_editor_hint():
		return false
		
	for condition in conditions:
		if not condition.evaluate():
			return false
	return true
#endregion

#region Private Methods
## Initialize all task conditions
func _initialize_conditions() -> void:
	for condition in conditions:
		condition.initialize(evaluation_system)
		add_dependency(condition.id)

## Initialize all task behaviors
func _initialize_behaviors() -> void:
	for behavior in behaviors:
		behavior.initialize(evaluation_system)

## Validate task is in active state
func _validate_active_state() -> bool:
	if state != State.ACTIVE:
		logger.warn("Task %s marked as inactive, cannot update task" % name)
		return false
	return true

## Check if task conditions are met
func _check_conditions() -> bool:
	if not evaluate():
		logger.info("Task conditions not met, interrupting: %s" % name)
		interrupt()
		return false
	return true

## Update current behavior execution
func _update_behavior(delta: float) -> void:
	if active_behavior:
		_handle_active_behavior(delta)
	else:
		_start_new_behavior()

## Handle active behavior state and execution
func _handle_active_behavior(delta: float) -> void:
	if active_behavior.is_completed():
		_handle_completed_behavior()
	elif _should_switch_behavior():
		_switch_to_higher_priority_behavior(delta)
	else:
		active_behavior.execute(delta, ant)

## Handle switching to a higher priority behavior
func _switch_to_higher_priority_behavior(delta: float) -> void:
	if not active_behavior:
		return
		
	var higher_priority_behavior = _find_next_valid_behavior(active_behavior.priority)
	
	if higher_priority_behavior:
		logger.trace("Found higher priority behavior: %s (priority: %d)" % [
			higher_priority_behavior.name, 
			higher_priority_behavior.priority
		])
		_switch_behavior(higher_priority_behavior)
	else:
		logger.trace("No higher priority behaviors available, continuing with: %s" % active_behavior.name)
		active_behavior.execute(delta, ant)

## Handle completed behavior state
func _handle_completed_behavior() -> void:
	var next_behavior = _find_next_valid_behavior()
	if next_behavior:
		_switch_behavior(next_behavior)
	else:
		logger.info("No valid behaviors found")
		_stop_active_behavior()

## Check if behavior should be switched
func _should_switch_behavior() -> bool:
	if not active_behavior:
		return true
	
	var higher_priority_behavior = _find_next_valid_behavior(active_behavior.priority)
	return higher_priority_behavior != null

## Find next valid behavior above given priority
func _find_next_valid_behavior(min_priority: int = -1) -> Behavior:
	var priority_groups = _group_behaviors_by_priority(min_priority)
	if priority_groups.is_empty():
		return null

	var priorities = priority_groups.keys()
	priorities.sort()
	priorities.reverse()

	for priority in priorities:
		var behaviors_at_priority = priority_groups[priority]
		for behavior in behaviors_at_priority:
			if behavior.should_activate():
				return behavior
	
	return null

## Group behaviors by priority level
func _group_behaviors_by_priority(min_priority: int = -1) -> Dictionary:
	var priority_groups: Dictionary = {}
	
	for behavior in behaviors:
		if behavior.priority <= min_priority:
			continue
			
		if not behavior.priority in priority_groups:
			priority_groups[behavior.priority] = []
			
		priority_groups[behavior.priority].append(behavior)
		
	return priority_groups

## Switch to a new behavior
func _switch_behavior(new_behavior: Behavior) -> void:
	logger.info("Switching behaviors: %s -> %s" % [
		active_behavior.name if active_behavior else "None",
		new_behavior.name
	])

	_stop_active_behavior()
	active_behavior = new_behavior
	active_behavior.start()

## Stop the currently active behavior
func _stop_active_behavior() -> void:
	if active_behavior:
		active_behavior.stop()
		active_behavior = null

## Start a new behavior if available
func _start_new_behavior() -> void:
	var next_behavior = _find_next_valid_behavior()
	if next_behavior:
		_switch_behavior(next_behavior)
#endregion

#region Public Methods
## Add a new behavior to the task
func add_behavior(behavior: Behavior) -> void:
	behaviors.append(behavior)
	if not Engine.is_editor_hint():
		behavior.initialize(evaluation_system)
	logger.trace("Added behavior '%s' to task '%s'" % [behavior.name, name])

## Add a new condition to the task
func add_condition(condition: Logic) -> void:
	conditions.append(condition)
	if not Engine.is_editor_hint():
		condition.initialize(evaluation_system)
		add_dependency(condition.id)
	logger.trace("Added condition to task '%s'" % name)

## Start task execution
func start(p_ant: Ant) -> void:
	if state == State.ACTIVE:
		return

	ant = p_ant
	state = State.ACTIVE
	started.emit()
	logger.info("Started task: %s" % name)

## Interrupt task execution
func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		_stop_active_behavior()
		interrupted.emit()
		logger.info("Interrupted task: %s" % name)

## Get currently active behavior
func get_active_behavior() -> Behavior:
	return active_behavior if active_behavior and active_behavior.is_active() else null

## Get task conditions
func get_conditions() -> Array[Logic]:
	return conditions
#endregion
