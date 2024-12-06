## Expression for filtering a list based on a predicate
class_name ListFilterExpression
extends LogicExpression

## Expression that provides the source list
@export var array_expression: LogicExpression
## Expression to evaluate for each item
@export var predicate_expression: LogicExpression
## Comparison operator
@export var operator: int
## Value to compare against
@export var compare_value: LogicExpression

func _init() -> void:
	name = "List Filter"
	description = "Filters a list based on a condition"
	return_type = TYPE_ARRAY

func _register_dependencies() -> void:
	if array_expression:
		add_dependency(array_expression)
	if predicate_expression:
		add_dependency(predicate_expression)
	if compare_value:
		add_dependency(compare_value)

func _evaluate() -> Array:
	var source_array = array_expression.evaluate()
	if not source_array:
		return []

	var filtered = []
	for item in source_array:
		predicate_expression.position2_expression = PropertyExpression.new()
		predicate_expression.position2_expression.entity = item
		predicate_expression.position2_expression.property_path = "global_position"
		var value = predicate_expression.evaluate()
		var compare_value = compare_value.evaluate()
		if _compare(value, compare_value, operator):
			filtered.append(item)
	return filtered

func _compare(a: Variant, b: Variant, op: int) -> bool:
	match op:
		0: return a < b  # LESS
		1: return a <= b # LESS_EQUAL
		2: return a == b # EQUAL
		3: return a >= b # GREATER_EQUAL
		4: return a > b  # GREATER
		_: return false
