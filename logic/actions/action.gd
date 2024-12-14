class_name Action
extends Resource

#region Properties
@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()
var id: String
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

#region Protected
var _condition: Logic
#endregion

#region Signals
signal started
signal completed
signal interrupted
#endregion


func _setup_dependencies(dependencies: Dictionary) -> void:
	# Create and initialize condition if we have an expression
	if condition_expression:
		_condition = Logic.new()
		_condition.name = id + "_condition"
		_condition.expression_string = condition_expression
		_condition.nested_expressions = nested_conditions.duplicate()
		_condition.initialize()

## Get whether conditions are met for this action
func conditions_met(entity: Node) -> bool:
	if not _condition:
		return true
	return _condition.get_value(entity)

## Check if the action can be executed
func can_execute(entity: Node) -> bool:
	return _condition.get_value(entity)

## Execute one tick of the action
func execute(entity: Node, delta: float) -> void:
	_update_execution(entity, delta)

#region Protected Methods
## Validate action parameters (override in subclasses)
func _validate_params() -> bool:
	return true

## Update the action execution (override in subclasses)
func _update_execution(entity: Node, delta: float) -> void:
	pass
#endregion
