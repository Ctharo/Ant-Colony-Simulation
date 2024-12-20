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

## How much energy does this action cost per second
@export var energy_coefficient: float

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
		assert(start_condition, "Should always have a start condition?")
		return true
	return start_condition.get_value(entity.action_manager.evaluation_system)

## Get whether the action should be stopped
func should_stop(entity: Node) -> bool:
	if not stop_condition:
		return false
	return stop_condition.get_value(entity.action_manager.evaluation_system)

## Check if the action can be executed
func can_execute(entity: Node) -> bool:
	return can_start(entity)

# Virtual method to be implemented by subclasses
func execute_tick(entity: Node, _state: ActionManager.ActionState, delta: float) -> void:
	energy_loss(entity, energy_coefficient * delta)

#region Protected Methods
## Validate action parameters (override in subclasses)
func _validate_params() -> bool:
	return true

## Update the action execution (override in subclasses)
func _update_execution(_entity: Node, _delta: float) -> void:
	pass
	
func energy_loss(entity: Node, amount: float) -> void:
	entity.energy_level -= amount

#endregion
