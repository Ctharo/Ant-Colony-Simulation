class_name CustomConditionConfig
extends ConditionConfig

@export var condition_name: String
@export var evaluation: PropertyCheckConfig

func _init() -> void:
	assert(false) # depreciated conditions -> remove

	type = "Custom"
