class_name CustomConditionConfig
extends ConfigBase

@export var condition_name: String
@export var evaluation: PropertyCheckConfig

func _init() -> void:
	type = "Custom"
