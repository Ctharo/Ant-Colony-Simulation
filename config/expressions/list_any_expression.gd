## Expression for checking if any items in a list meet a condition
class_name ListAnyExpression
extends LogicExpression

## Expression that provides the list to check
@export var array_expression: LogicExpression
## Expression to evaluate for each item
@export var condition_expression: LogicExpression

func _init() -> void:
	name = "List Any"
	description = "Checks if any item in the list meets the condition"
	return_type = TYPE_BOOL

func _register_dependencies() -> void:
	if array_expression:
		add_dependency(array_expression)
	if condition_expression:
		add_dependency(condition_expression)

func _evaluate() -> bool:
	var array = array_expression.evaluate()
	if not array:
		return false

	for item in array:
		if condition_expression.evaluate():
			return true
	return false
