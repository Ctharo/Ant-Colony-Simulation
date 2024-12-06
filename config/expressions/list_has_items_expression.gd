## Expression for checking if a list has any items
class_name ListHasItemsExpression
extends LogicExpression

## Expression that provides the list to check
@export var list_expression: LogicExpression

func _init() -> void:
	name = "List Has Items"
	description = "Checks if a list contains any items"
	return_type = TYPE_BOOL

func _register_dependencies() -> void:
	if list_expression:
		add_dependency(list_expression)

func _evaluate() -> bool:
	var list = list_expression.evaluate()
	return list != null and list.size() > 0
