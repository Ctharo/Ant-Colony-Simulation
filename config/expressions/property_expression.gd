class_name PropertyExpression
extends LogicExpression

## Path to the property to access
@export var property_path: String

func _init() -> void:
	name = "Property Value"
	description = "Returns the value of a property"

func _evaluate() -> Variant:
	return entity.get_property_value(property_path)
