class_name Transition
extends Resource

## Name of this transition - also sets [member id]
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

## Priority level - higher numbers mean higher priority
@export_range(0, 100) var priority: int
@export_multiline var enter_expression_string: String
@export var enter_nested_expressions: Array[Logic]
@export_multiline var exit_expression_string: String
@export var exit_nested_expressions: Array[Logic]
## Action to transition to if exit conditions are met
@export var exit_to_action: Action

## Gets set by [member name]
var id: String
