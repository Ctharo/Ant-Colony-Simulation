class_name OperatorConfig
extends ConfigBase

@export var operator_type: String
@export var operands: Array[ConfigBase]

func _init() -> void:
	type = "Operator"
