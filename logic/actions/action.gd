class_name Action
extends Resource

#region Properties
var id: String
@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()

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

## Expression string to evaluate start conditions
@export_multiline var start_condition_expression: String

## Expression string to evaluate stop conditions
@export_multiline var stop_condition_expression: String

## Nested conditions used in start expression
@export var start_nested_conditions: Array[Logic]

## Nested conditions used in stop expression
@export var stop_nested_conditions: Array[Logic]

#region Protected
var start_condition: Logic
var stop_condition: Logic
#endregion

#region Signals
signal started
signal completed
signal interrupted
#endregion

func generate_conditions() -> void:
	if start_condition_expression:
		start_condition = Logic.new()
		start_condition.name = name + "_start_condition"
		start_condition.expression_string = start_condition_expression
		start_condition.nested_expressions = start_nested_conditions.duplicate()

	if stop_condition_expression:
		stop_condition = Logic.new()
		stop_condition.name = name + "_stop_condition"
		stop_condition.expression_string = stop_condition_expression
		stop_condition.nested_expressions = stop_nested_conditions.duplicate()

## Get whether conditions are met to start this action
func can_start(entity: Node) -> bool:
	if not start_condition:
		return true
	return start_condition.get_value(entity.action_manager.evaluation_system, true)

## Get whether the action should be stopped
func should_stop(entity: Node) -> bool:
	if not stop_condition:
		return false
	return stop_condition.get_value(entity.action_manager.evaluation_system, true)

## Check if the action can be executed
func can_execute(entity: Node) -> bool:
	return can_start(entity)

# Virtual method to be implemented by subclasses
func execute_tick(entity: Node, state: ActionManager.ActionState, delta: float) -> void:
	pass

#region Protected Methods
## Validate action parameters (override in subclasses)
func _validate_params() -> bool:
	return true

## Update the action execution (override in subclasses)
func _update_execution(entity: Node, delta: float) -> void:
	pass
#endregion
