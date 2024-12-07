class_name OperatorConfig
extends ConditionConfig

@export var operator_type: String
@export var operands: Array[ConditionConfig]

func _init() -> void:
	assert(false) # depreciated conditions -> remove

	type = "Operator"
