class_name Action
extends Resource

#region Properties
## Unique identifier for this action
@export var id: String
## Human readable name
@export var name: String
## Description of what this action does
@export var description: String
## Time before action can be used again
@export var cooldown: float = 0.0
## How long the action takes to complete
@export var duration: float = 0.0
## Parameters required for this action
@export var params: Dictionary = {}
## Conditions that must be met for action to be valid
@export var conditions: Array[LogicExpression]
## Properties this action depends on
@export var properties: Array[LogicExpression] # TODO REMOVE
#endregion

#region Internal State
var _is_executing: bool = false
var _elapsed_time: float = 0.0
var _current_cooldown: float = 0.0
var _entity: Node
#endregion

#region Signals
signal started
signal completed
signal interrupted
#endregion

#region Public Methods
## Initialize the action with an entity
func initialize(entity: Node) -> void:
	_entity = entity
	
	# Initialize conditions
	for condition in conditions:
		condition.initialize(entity)
		


## Check if the action can be executed
func can_execute() -> bool:
	if not is_ready():
		return false
		
	# Check all conditions are met
	for condition in conditions:
		if not condition.get_value():
			return false
			
	return _validate_params()

## Execute one tick of the action
func execute(delta: float) -> void:
	if not _is_executing:
		_start_execution()
		return
		
	_elapsed_time += delta
	_update_execution(delta)
	
	if _elapsed_time >= duration and duration > 0:
		_complete_execution()

## Stop the action early
func stop() -> void:
	if _is_executing:
		_is_executing = false
		interrupted.emit()

## Reset the action state
func reset() -> void:
	_current_cooldown = 0.0
	_is_executing = false 
	_elapsed_time = 0.0

## Check if action is ready to use
func is_ready() -> bool:
	return _current_cooldown <= 0.0

## Check if action has completed
func is_completed() -> bool:
	return not _is_executing
#endregion

#region Protected Methods
## Validate action parameters (override in subclasses)
func _validate_params() -> bool:
	return true

## Start executing the action
func _start_execution() -> void:
	_is_executing = true
	_current_cooldown = cooldown
	_elapsed_time = 0.0
	started.emit()

## Update the action execution (override in subclasses)
func _update_execution(delta: float) -> void:
	pass

## Complete the action execution
func _complete_execution() -> void:
	_is_executing = false
	completed.emit()
#endregion
