class_name CompositeAction
extends AntAction

## Types of composite behavior
enum CompositeType {
	SEQUENCE,    # Execute actions in order, stop on first failure
	SELECTOR,    # Try actions in order, stop on first success
	PARALLEL     # Execute all actions simultaneously
}

## The type of composite behavior
@export var composite_type: CompositeType = CompositeType.SEQUENCE
## Child actions to execute
@export var child_actions: Array[AntAction] = []
## For parallel composites, how many actions need to succeed
@export var required_success_count: int = 1

# Internal state
var _current_child_index: int = 0
var _running_children: Array[AntAction] = []
var _completed_children: Array[AntAction] = []
var _failed_children: Array[AntAction] = []

## Override initialize to also initialize children
func initialize(p_ant: Ant) -> void:
	super.initialize(p_ant)
	
	# Initialize all child actions
	for child in child_actions:
		child.initialize(p_ant)
		
	_reset_state()

## Reset internal state
func _reset_state() -> void:
	_current_child_index = 0
	_running_children.clear()
	_completed_children.clear()
	_failed_children.clear()

## Can this composite action start?
func _can_start_internal() -> bool:
	# Can't start with no children
	if child_actions.is_empty():
		return false
		
	# For sequences, first action must be able to start
	if composite_type == CompositeType.SEQUENCE:
		return child_actions[0].can_start()
		
	# For selectors and parallels, at least one child must be able to start
	for child in child_actions:
		if child.can_start():
			return true
			
	return false

## Start the composite action
func _start_internal() -> bool:
	_reset_state()
	
	match composite_type:
		CompositeType.SEQUENCE:
			return _start_sequence()
		CompositeType.SELECTOR:
			return _start_selector()
		CompositeType.PARALLEL:
			return _start_parallel()
			
	return false

## Start sequence behavior
func _start_sequence() -> bool:
	if _current_child_index >= child_actions.size():
		return false
		
	var child = child_actions[_current_child_index]
	if child.start():
		_running_children.append(child)
		return true
	else:
		fail("Failed to start first action in sequence")
		return false

## Start selector behavior
func _start_selector() -> bool:
	for i in range(child_actions.size()):
		var child = child_actions[i]
		if child.can_start() and child.start():
			_current_child_index = i
			_running_children.append(child)
			return true
			
	fail("No actions in selector could start")
	return false

## Start parallel behavior
func _start_parallel() -> bool:
	var any_started = false
	
	for child in child_actions:
		if child.can_start() and child.start():
			_running_children.append(child)
			any_started = true
			
	if not any_started:
		fail("No actions in parallel could start")
		
	return any_started

## Update the composite action
func _update_internal(delta: float) -> void:
	match composite_type:
		CompositeType.SEQUENCE:
			_update_sequence(delta)
		CompositeType.SELECTOR:
			_update_selector(delta)
		CompositeType.PARALLEL:
			_update_parallel(delta)

## Update sequence behavior
func _update_sequence(delta: float) -> void:
	if _running_children.is_empty():
		# Try to start the next action in sequence
		_current_child_index += 1
		
		if _current_child_index >= child_actions.size():
			# We've completed all actions, success!
			complete()
			return
			
		var next_child = child_actions[_current_child_index]
		if next_child.start():
			_running_children.append(next_child)
		else:
			fail("Failed to start next action in sequence")
			return
	
	# Update running child
	var child = _running_children[0]
	child.update(delta)
	
	# Check child status
	match child.status:
		AntAction.ActionStatus.COMPLETED:
			_running_children.erase(child)
			_completed_children.append(child)
			# Next action will be started on next update
		AntAction.ActionStatus.FAILED:
			_running_children.erase(child)
			_failed_children.append(child)
			fail("Child action failed: " + child.name)

## Update selector behavior
func _update_selector(delta: float) -> void:
	if _running_children.is_empty():
		# Try to find another action that can start
		_current_child_index += 1
		
		while _current_child_index < child_actions.size():
			var next_child = child_actions[_current_child_index]
			if next_child.start():
				_running_children.append(next_child)
				break
			_current_child_index += 1
			
		if _running_children.is_empty():
			fail("No more actions in selector could start")
			return
	
	# Update running child
	var child = _running_children[0]
	child.update(delta)
	
	# Check child status
	match child.status:
		AntAction.ActionStatus.COMPLETED:
			_running_children.erase(child)
			_completed_children.append(child)
			complete()  # Selector succeeds if any child succeeds
		AntAction.ActionStatus.FAILED:
			_running_children.erase(child)
			_failed_children.append(child)
			# Will try next action on next update

## Update parallel behavior
func _update_parallel(delta: float) -> void:
	if _running_children.is_empty():
		# Check if we've met success criteria
		if _completed_children.size() >= required_success_count:
			complete()
		else:
			fail("Not enough children succeeded in parallel")
		return
	
	# Update all running children
	var children_to_remove = []
	
	for child in _running_children:
		child.update(delta)
		
		match child.status:
			AntAction.ActionStatus.COMPLETED:
				children_to_remove.append(child)
				_completed_children.append(child)
			AntAction.ActionStatus.FAILED:
				children_to_remove.append(child)
				_failed_children.append(child)
	
	# Remove completed/failed children
	for child in children_to_remove:
		_running_children.erase(child)
	
	# Check success criteria
	if _completed_children.size() >= required_success_count:
		# Interrupt any remaining running children
		for child in _running_children:
			child.interrupt()
		_running_children.clear()
		complete()
	
	# Check if any more children can succeed
	if _running_children.size() + _completed_children.size() < required_success_count:
		# Not enough children remaining to meet criteria
		for child in _running_children:
			child.interrupt()
		_running_children.clear()
		fail("Not enough children remaining to meet success criteria")

## Clean up on interruption
func _interrupt_internal() -> void:
	# Interrupt all running children
	for child in _running_children:
		child.interrupt()
	_running_children.clear()
	_reset_state()

## Clean up on completion
func _complete_internal() -> void:
	# Make sure no children are still running
	for child in _running_children:
		child.interrupt()
	_running_children.clear()

## Clean up on failure
func _fail_internal() -> void:
	# Make sure no children are still running
	for child in _running_children:
		child.interrupt()
	_running_children.clear()
