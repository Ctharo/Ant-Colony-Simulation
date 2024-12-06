class_name PropertyListExpression
extends BaseExpression

## Path to the property containing the list
@export var source_property: String

func _init() -> void:
	return_type = Property.Type.ARRAY
	property_dependencies = [source_property]

func _evaluate() -> Array:
	return entity.get_property_value(source_property)
