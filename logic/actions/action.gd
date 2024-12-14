class_name Action
extends BaseComponent

#region Properties
## Priority level - higher numbers mean higher priority
@export_range(0, 100) var priority: int = 0
## Description of what this action does
@export var description: String
## Time before action can be used again
@export var cooldown: float = 0.0
## How long the action takes to complete
@export var duration: float = 0.0
## Parameters required for this action
@export var params: Dictionary = {}
## Expression string to evaluate conditions
@export_multiline var condition_expression: String
## Nested conditions used in the expression
@export var nested_conditions: Array[Logic]

#region Internal State
var is_executing: bool = false
var elapsed_time: float = 0.0
var current_cooldown: float = 0.0
var _condition: Logic
#endregion

#region Signals
signal started
signal completed
signal interrupted
#endregion

# Add entity-specific state storage
var _action_state: Dictionary = {}

func _get_action_state(entity_id: String) -> Dictionary:
	if not _action_state.has(entity_id):
		_action_state[entity_id] = {
			"is_executing": false,
			"elapsed_time": 0.0,
			"current_cooldown": 0.0
		}
	return _action_state[entity_id]



func _setup_dependencies(dependencies: Dictionary) -> void:
	# Create and initialize condition if we have an expression
	if condition_expression:
		_condition = Logic.new()
		_condition.name = id + "_condition"
		_condition.expression_string = condition_expression
		_condition.nested_expressions = nested_conditions.duplicate()
		
		# Get evaluation system from dependencies if provided
		if dependencies.has("evaluation_system"):
			_condition.initialize(entity, {
				"evaluation_system": dependencies.get("evaluation_system")
			})
		else:
			_condition.initialize(entity)

## Check if action is ready to execute (off cooldown)
func is_ready() -> bool:
	var state = _get_action_state(entity.name)
	return state.current_cooldown <= 0.0

## Get whether conditions are met for this action
func conditions_met() -> bool:
	if not _condition:
		return true
	return _condition.get_value()

## Start executing the action
func start() -> void:
	is_executing = true
	elapsed_time = 0.0
	started.emit()

## Stop executing and reset state
func stop() -> void:
	is_executing = false
	elapsed_time = 0.0
	current_cooldown = cooldown
	completed.emit()

## Interrupt execution
func interrupt() -> void:
	is_executing = false
	elapsed_time = 0.0
	interrupted.emit()

## Update action state
func update(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown = max(0, current_cooldown - delta)
		
	if is_executing:
		elapsed_time += delta
		if duration > 0 and elapsed_time >= duration:
			stop()
			
## Check if the action can be executed
func can_execute() -> bool:
	if not is_ready():
		return false
		
	return _condition.get_value()

## Execute one tick of the action
func execute(delta: float) -> void:
	var state = _get_action_state(entity.name)
	if not state.is_executing:
		_start_execution()
		return
		
	state.elapsed_time += delta
	_update_execution(delta)
	
	if state.elapsed_time >= duration and duration > 0:
		_complete_execution()

## Reset the action state
func reset() -> void:
	current_cooldown = 0.0
	is_executing = false 
	elapsed_time = 0.0

## Check if action has completed
func is_completed() -> bool:
	return not is_executing

#region Protected Methods
## Validate action parameters (override in subclasses)
func _validate_params() -> bool:
	return true

## Start executing the action
func _start_execution() -> void:
	var state = _get_action_state(entity.name)
	state.is_executing = true
	state.current_cooldown = cooldown
	state.elapsed_time = 0.0
	started.emit()

## Update the action execution (override in subclasses)
func _update_execution(delta: float) -> void:
	pass

## Complete the action execution
func _complete_execution() -> void:
	is_executing = false
	completed.emit()
#endregion
