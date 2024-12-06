class_name PropertyExpression
extends LogicExpression

## Path to the property to access
@export var property_path: String

func _init() -> void:
	name = "Property Value"
	description = "Returns the value of a property"

func _evaluate() -> Variant:
	var target = current_context.current_item if use_current_item else entity
	return target.get_property_value(property_path)
