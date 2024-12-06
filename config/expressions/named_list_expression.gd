class_name NamedListExpression
extends BaseExpression

## The source expression providing the list
@export var source_expression: BaseExpression

func _init() -> void:
	return_type = Property.Type.ARRAY
	dependencies = [source_expression]

func _evaluate() -> Array:
	return source_expression.evaluate()
