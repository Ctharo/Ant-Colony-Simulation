class_name Behavior
extends RefCounted

## Interface between the [class Task] and the [class Action], passing parameters 

## Signals for behavior state changes
signal started
signal completed
signal interrupted
signal state_changed(new_state: State)

## Behavior states and Priority levels remain unchanged as they don't produce output
enum State { INACTIVE, ACTIVE, COMPLETED, INTERRUPTED }
enum Priority { LOWEST = 0, LOW = 25, MEDIUM = 50, HIGH = 75, HIGHEST = 100 }

## Properties remain unchanged as they don't produce output
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

var conditions: Array[Condition] = []:
	set(value):
		conditions = value

var actions: Array[Action] = []:
	set(value):
		actions = value
		if is_instance_valid(ant):
			_update_action_references()

var _condition_cache: Dictionary = {}

func _init(p_priority: int = Priority.MEDIUM) -> void:
	priority = p_priority

## Add a condition to this behavior
func add_condition(condition: Condition) -> void:
	conditions.append(condition)
	DebugLogger.debug(DebugLogger.Category.BEHAVIOR, 
		"Added condition to behavior '%s'" % name
	)

## Add an action to this behavior
func add_action(action: Action) -> void:
	actions.append(action)
	if is_instance_valid(ant):
		action.ant = ant
	DebugLogger.debug(DebugLogger.Category.BEHAVIOR, 
		"Added action to behavior '%s': %s" % [name, action.get_script().resource_path.get_file()]
	)

## Get all conditions for this behavior
func get_conditions() -> Array[Condition]:
	return conditions

## Start the behavior
func start(p_ant: Ant) -> void:
	if not is_instance_valid(p_ant):
		DebugLogger.error(DebugLogger.Category.BEHAVIOR, 
			"Cannot start behavior '%s' with invalid ant reference" % name
		)
		return
		
	DebugLogger.debug(DebugLogger.Category.BEHAVIOR,
		"Starting behavior '%s' (Current state: %s)" % [name, State.keys()[state]]
	)
		
	ant = p_ant
	state = State.ACTIVE
	
	DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
		"Behavior '%s' state set to: %s" % [name, State.keys()[state]]
	)
	
	started.emit()
	
	# Start all actions
	for action in actions:
		action.start(ant)
		DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
			"Started action: %s" % action.get_script().resource_path.get_file()
		)

## Check if the behavior should activate
func should_activate(context: Dictionary) -> bool:
	var conditions_met = _check_conditions(context)
	var _should_activate = state != State.COMPLETED and conditions_met
	
	DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
		"Checking activation for '%s':\n" % name +
		"  Current state: %s\n" % State.keys()[state] +
		"  Conditions met: %s\n" % conditions_met +
		"  Should activate: %s" % _should_activate
	)
	
	return _should_activate

## Update the behavior
func update(delta: float, context: Dictionary) -> void:
	DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
		"Updating behavior '%s' (State: %s)" % [name, State.keys()[state]]
	)
		
	if state != State.ACTIVE:
		return
	
	# Check conditions
	if not _check_conditions(context):
		DebugLogger.info(DebugLogger.Category.BEHAVIOR,
			"Conditions no longer met for '%s', interrupting" % name
		)
		interrupt()
		return
	
	# Update actions
	_update_actions(delta)
	
	DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
		"After update - Behavior '%s' state: %s" % [name, State.keys()[state]]
	)

## Interrupt the behavior
func interrupt() -> void:
	if state == State.ACTIVE:
		state = State.INTERRUPTED
		
		DebugLogger.info(DebugLogger.Category.BEHAVIOR,
			"Interrupting behavior '%s'" % name
		)
		
		# Cancel all actions
		for action in actions:
			action.interrupt()
			DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
				"Interrupted action: %s" % action.get_script().resource_path.get_file()
			)
		
		interrupted.emit()

## Reset the behavior to its initial state
func reset() -> void:
	state = State.INACTIVE
	clear_condition_cache()
	
	DebugLogger.debug(DebugLogger.Category.BEHAVIOR,
		"Reset behavior '%s'" % name
	)
	
	# Reset all actions
	for action in actions:
		action.reset()
		DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
			"Reset action: %s" % action.get_script().resource_path.get_file()
		)

## Clear the condition evaluation cache
func clear_condition_cache() -> void:
	_condition_cache.clear()
	DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
		"Cleared condition cache for behavior '%s'" % name
	)

## Check if all conditions are met using the context
func _check_conditions(context: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		if not condition.is_met(_condition_cache, context):
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
		DebugLogger.info(DebugLogger.Category.BEHAVIOR,
			"Behavior '%s' completed (all actions finished)" % name
		)

## Update ant references in actions when ant changes
func _update_action_references() -> void:
	if not is_instance_valid(ant):
		return
		
	for action in actions:
		action.ant = ant
		DebugLogger.trace(DebugLogger.Category.BEHAVIOR,
			"Updated ant reference for action: %s" % action.get_script().resource_path.get_file()
		)

## Get debug information about the behavior
func get_debug_info() -> Dictionary:
	var info = {
		"name": name,
		"priority": priority,
		"state": State.keys()[state],
		"conditions": conditions.size(),
		"actions": actions.size()
	}
	
	DebugLogger.debug(DebugLogger.Category.BEHAVIOR,
		"\nBehavior Debug Info for '%s':" % name +
		"\n  Priority: %d" % priority +
		"\n  State: %s" % State.keys()[state] +
		"\n  Conditions: %d" % conditions.size() +
		"\n  Actions: %d" % actions.size()
	)
	
	return info
