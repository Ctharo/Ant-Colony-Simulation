class_name Task
extends Node

#region Signals
signal started
signal completed
signal interrupted
signal state_changed(new_state: State)
#endregion

#region Enums
enum State {
	INACTIVE,    ## Task is not running
	ACTIVE,      ## Task is currently running
	COMPLETED,   ## Task has completed successfully
	INTERRUPTED  ## Task was interrupted before completion
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
@export var priority: Priority = Priority.MEDIUM
@export var behaviors: Array[Behavior] = []
@export_multiline var description: String = ""

var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

var active_behavior: Behavior
var ant: Ant
var logic: Logic
var logger: Logger
#endregion

func _init() -> void:
	logger = Logger.new("task", DebugLogger.Category.TASK)
	logic = Logic.new("task_" + str(get_instance_id()))
	
	# Default execution formula - can be customized per task instance
	logic.add_formula(
		"can_execute", 
		"energy > min_energy and not is_busy",
		["energy", "min_energy", "is_busy"]
	)

#region Lifecycle Methods
func update(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if not _validate_active_state():
		return

	logger.trace("Updating Task: %s" % name)
	
	if not _check_conditions():
		return

	_update_behavior(delta)

func reset() -> void:
	if Engine.is_editor_hint():
		return
		
	state = State.INACTIVE
	_stop_active_behavior()
	
	for behavior in behaviors:
		behavior.reset()
#endregion

#region Private Methods
func _validate_active_state() -> bool:
	if state != State.ACTIVE:
		logger.warn("Task %s marked as inactive, cannot update task" % name)
		return false
	return true

func _check_conditions() -> bool:
	if not logic.evaluate_formula("can_execute"):
		logger.info("Task conditions not met, interrupting: %s" % name)
		interrupt()
		return false
	return true

func _update_behavior(delta: float) -> void:
	if active_behavior:
		_handle_active_behavior(delta)
	else:
		_start_new_behavior()

func _handle_active_behavior(delta: float) -> void:
	if active_behavior.is_completed():
		_handle_completed_behavior()
	elif _should_switch_behavior():
		_switch_to_higher_priority_behavior(delta)
	else:
		active_behavior.execute(delta, ant)

func _handle_completed_behavior() -> void:
	var next_behavior = _find_next_valid_behavior()
	if next_behavior:
		_switch_behavior(next_behavior)
	else:
		logger.info("No valid behaviors found")
		_stop_active_behavior()

func _should_switch_behavior() -> bool:
	if not active_behavior:
		return true
	
	var higher_priority_behavior = _find_next_valid_behavior(active_behavior.priority)
	return higher_priority_behavior != null

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

func _group_behaviors_by_priority(min_priority: int = -1) -> Dictionary:
	var priority_groups: Dictionary = {}
	
	for behavior in behaviors:
		if behavior.priority <= min_priority:
			continue
			
		if not behavior.priority in priority_groups:
			priority_groups[behavior.priority] = []
			
		priority_groups[behavior.priority].append(behavior)
		
	return priority_groups

func _switch_behavior(new_behavior: Behavior) -> void:
	logger.info("Switching behaviors: %s -> %s" % [
		active_behavior.name if active_behavior else "None",
		new_behavior.name
	])

	_stop_active_behavior()
	active_behavior = new_behavior
	active_behavior.start(ant)

func _stop_active_behavior() -> void:
	if active_behavior:
		active_behavior.stop()
		active_behavior = null

func _start_new_behavior() -> void:
	var next_behavior = _find_next_valid_behavior()
	if next_behavior:
		_switch_behavior(next_behavior)
#endregion

#region Public Methods
func add_behavior(behavior: Behavior) -> void:
	behaviors.append(behavior)
	logger.trace("Added behavior '%s' to task '%s'" % [behavior.name, name])

func start(p_ant: Ant) -> void:
	if state == State.ACTIVE:
		return

	ant = p_ant
	state = State.ACTIVE
	started.emit()
	logger.info("Started task: %s" % name)

func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		_stop_active_behavior()
		interrupted.emit()
		logger.info("Interrupted task: %s" % name)

func get_active_behavior() -> Behavior:
	return active_behavior if active_behavior and active_behavior.is_active() else null
#endregion
