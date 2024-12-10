class_name Action
extends Resource

#region Properties
## Unique identifier for this action
var id: String

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

## Expression string to evaluate conditions
@export_multiline var condition_expression: String

## Nested conditions used in the expression
@export var nested_conditions: Array[Logic]

var logger: Logger

## Dictionary to store instance-specific runtime states
var _instance_states: Dictionary = {}
#endregion

#region Signals
signal started(entity: Node)
signal completed(entity: Node)
signal interrupted(entity: Node)
#endregion

func _init() -> void:
	logger = Logger.new(name, DebugLogger.Category.ACTION)

#region Public Methods
## Initialize the action for a specific entity instance
func initialize(entity: Node) -> void:
	if not entity:
		logger.error("Cannot initialize action with null entity")
		return
		
	var instance_id = entity.get_instance_id()
	if instance_id not in _instance_states:
		_instance_states[instance_id] = ActionInstanceState.new()
		
	id = name.to_snake_case()
	var state = _instance_states[instance_id]
	state.entity = entity
	state.condition = _create_condition_for_entity(entity)

## Check if the action can be executed for a specific entity
func can_execute(entity: Node) -> bool:
	var state = _get_instance_state(entity)
	if not state or not is_ready(entity):
		return false
		
	return state.condition.get_value()

## Execute one tick of the action for an entity
func execute(entity: Node, delta: float) -> void:
	var state = _get_instance_state(entity)
	if not state:
		return
		
	if not state.is_executing:
		_start_execution(entity)
		return
		
	state.elapsed_time += delta
	_update_execution(entity, delta)
	
	if state.elapsed_time >= duration and duration > 0:
		_complete_execution(entity)

## Stop the action for an entity
func stop(entity: Node) -> void:
	var state = _get_instance_state(entity)
	if state and state.is_executing:
		state.is_executing = false
		interrupted.emit(entity)

## Reset the action state for an entity
func reset(entity: Node) -> void:
	var state = _get_instance_state(entity)
	if state:
		state.current_cooldown = 0.0
		state.is_executing = false 
		state.elapsed_time = 0.0

## Check if action is ready to use for an entity
func is_ready(entity: Node) -> bool:
	var state = _get_instance_state(entity)
	return state and state.current_cooldown <= 0.0

## Check if action has completed for an entity
func is_completed(entity: Node) -> bool:
	var state = _get_instance_state(entity)
	return not state or not state.is_executing

## Clean up instance state when entity is freed
func cleanup_instance(entity: Node) -> void:
	var instance_id = entity.get_instance_id()
	if instance_id in _instance_states:
		_instance_states.erase(instance_id)
#endregion

#region Protected Methods
## Validate action parameters for an entity
func _validate_params(entity: Node) -> bool:
	return true

## Create a condition instance for a specific entity
func _create_condition_for_entity(entity: Node) -> Logic:
	var condition = Logic.new()
	condition.name = id + "_condition"
	condition.expression_string = condition_expression
	
	# Deep copy nested conditions
	condition.nested_expressions = [] as Array[Logic]
	for nested in nested_conditions:
		condition.nested_expressions.append(nested)
	
	return condition

## Start executing the action for an entity
func _start_execution(entity: Node) -> void:
	var state = _get_instance_state(entity)
	if state:
		state.is_executing = true
		state.current_cooldown = cooldown
		state.elapsed_time = 0.0
		started.emit(entity)

## Update the action execution for an entity
func _update_execution(entity: Node, delta: float) -> void:
	pass

## Complete the action execution for an entity
func _complete_execution(entity: Node) -> void:
	var state = _get_instance_state(entity)
	if state:
		state.is_executing = false
		completed.emit(entity)

## Get the instance state for an entity
func _get_instance_state(entity: Node) -> ActionInstanceState:
	if not entity:
		return null
	return _instance_states.get(entity.get_instance_id())
#endregion

## Class to store instance-specific state
class ActionInstanceState:
	var entity: Node
	var condition: Logic
	var is_executing: bool = false
	var elapsed_time: float = 0.0
	var current_cooldown: float = 0.0
