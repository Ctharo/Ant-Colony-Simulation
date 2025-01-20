class_name Logic
extends Resource

#region Properties
## Name of the logic expression, used to generate ID
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

## The actual expression to evaluate
@export_multiline var expression_string: String

## Nested logic expressions used within this expression
@export var nested_expressions: Array[Logic]

## Description of what this logic does
@export var description: String

## Expected return type of the expression
@export var type: Variant.Type = TYPE_FLOAT

## Unique identifier for this logic expression
var id: String

@warning_ignore("unused_signal")
signal action_triggered(value: Variant, expression_id: String)
#endregion

## Get value with evaluation system
func get_value(eval_system: EvaluationSystem) -> Variant:
	return eval_system.get_value(self)
