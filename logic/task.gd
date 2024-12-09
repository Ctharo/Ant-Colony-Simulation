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

#region Properties
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)

var name: String = ""
var priority: int = Priority.MEDIUM
var ant: Ant
var behaviors: Array[Behavior] = []
var conditions: Array[Logic] = []
var active_behavior: Behavior
var allow_interruption: bool = true
var logger: Logger

#endregion

#region Initialization
func _init(p_priority: int = Priority.MEDIUM) -> void:
	priority = p_priority
	logger = Logger.new("task", DebugLogger.Category.TASK)
#endregion

#region Public Methods
func update(delta: float) -> void:
	if state != Task.State.ACTIVE:
		logger.warn("Task %s marked as inactive, cannot update task" % name)
		return

	logger.trace("Updating Task: %s" % name)
	
	# Check task-level conditions
	if not _check_task_conditions():
		logger.info("Task conditions not met, interrupting: %s" % name)
		interrupt()
		return

	_update_behavior(delta)

func add_behavior(behavior: Behavior) -> void:
	behaviors.append(behavior)
	behavior.name = behavior.name if not behavior.name.is_empty() else "Behavior" + str(behaviors.size())
	logger.trace("Added behavior '%s' to task '%s'" % [behavior.name, name])

func add_condition(condition: Logic) -> void:
	if condition:
		conditions.append(condition)
		logger.trace("Added condition to task '%s'" % name)

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

func reset() -> void:
	state = State.INACTIVE
	_stop_active_behavior()
	
	for behavior in behaviors:
		behavior.reset()

func get_active_behavior() -> Behavior:
	return active_behavior if active_behavior and active_behavior.is_active() else null

func get_conditions() -> Array[Logic]:
	return conditions

func get_debug_info() -> Dictionary:
	return {
		"name": name,
		"state": State.keys()[state],
		"priority": priority,
		"behavior_count": behaviors.size(),
		"active_behavior": active_behavior.name if active_behavior else "None",
		"condition_count": conditions.size()
	}
#endregion

#region Private Methods
func _check_task_conditions() -> bool:
	for condition in conditions:
		if not condition.evaluate():
			return false
	return true

func _update_behavior(delta: float) -> void:
	if active_behavior:
		if active_behavior.is_completed():
			if _should_activate_behavior(active_behavior):
				var higher_priority_behavior = _find_next_valid_behavior(active_behavior.priority)
				if higher_priority_behavior:
					_switch_behavior(higher_priority_behavior)
				else:
					logger.info("Restarting completed behavior '%s' as it's still optimal" % active_behavior.name)
					active_behavior.reset()
					active_behavior.start()
			else:
				var next_behavior = _find_next_valid_behavior()
				if next_behavior:
					_switch_behavior(next_behavior)
				else:
					assert(false, "No behavior found, should loop")
		elif _should_activate_behavior(active_behavior):
			var higher_priority_behavior = _find_next_valid_behavior(active_behavior.priority)
			if higher_priority_behavior:
				_switch_behavior(higher_priority_behavior)
			else:
				logger.trace("Continuing current behavior")
				active_behavior.execute(delta, ant)
		else:
			var next_behavior = _find_next_valid_behavior()
			if next_behavior:
				_switch_behavior(next_behavior)
			else:
				logger.info("No valid behaviors found")
				_stop_active_behavior()
	else:
		var next_behavior = _find_next_valid_behavior()
		if next_behavior:
			_switch_behavior(next_behavior)

func _should_activate_behavior(behavior: Behavior) -> bool:
	return behavior.should_activate() and behavior.can_execute()

func _find_next_valid_behavior(current_priority: int = -1) -> Behavior:
	var priority_groups = _group_behaviors_by_priority()
	if priority_groups.is_empty():
		return null

	var priorities = priority_groups.keys()
	priorities.sort()
	priorities.reverse()

	for priority in priorities:
		if current_priority >= 0 and priority <= current_priority:
			break

		var behaviors_at_priority = priority_groups[priority]
		for behavior in behaviors_at_priority:
			if _should_activate_behavior(behavior):
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
	active_behavior.start()

func _stop_active_behavior() -> void:
	if active_behavior:
		active_behavior.stop()
		active_behavior = null
#endregion
