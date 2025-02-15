class_name AntAction
extends Resource
## Base level action resource

@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()
## keywords should either be methods of ant or match name of a nested action
@export_multiline var action_string: String
@export var nested_actions: Array[AntAction]
@export var duration: float = 1.0
@export var refractory_period: float = 0.0
@export var is_active: bool = false
@export var is_interruptable: bool = true
## Unique identifier for this action
var id: String
