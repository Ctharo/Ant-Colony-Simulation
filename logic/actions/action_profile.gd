class_name ActionProfile
extends Resource

@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()
@export var actions: Dictionary # Priority -> Action
var id: String
