class_name PropertyCheckConfig
extends ConfigBase

@export var property: Path
@export var operator: String = "EQUALS"
var value: Variant


func _init() -> void:
	type = "PropertyCheck"
