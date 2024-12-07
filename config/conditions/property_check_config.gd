class_name PropertyCheckConfig
extends ConditionConfig

@export var property: Path
@export var operator: String = "EQUALS"
var value: Variant


func _init() -> void:
	assert(false) # depreciated conditions -> remove

	type = "PropertyCheck"
