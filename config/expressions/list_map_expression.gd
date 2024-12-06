## Expression for applying an expression to each element of a list
class_name ListMapExpression
extends LogicExpression

## Expression that provides the source list
@export var array_expression: LogicExpression
## Expression to evaluate for each item
@export var map_expression: LogicExpression

func _init() -> void:
	name = "List Map"
	description = "Applies an expression to each element of a list"
	return_type = TYPE_ARRAY

func _register_dependencies() -> void:
	if array_expression:
		add_dependency(array_expression)
	if map_expression:
		add_dependency(map_expression)

func _evaluate() -> Array:
	var source_array = array_expression.evaluate()
	if not source_array:
		return []

	var mapped = []
	for item in source_array:
		# Create context for this item
		var item_context = EvaluationContext.create(item, entity)

		# Evaluate map expression with item context
		var result = map_expression.evaluate(item_context)
		if result != null:  # Skip null results
			mapped.append(result)

	return mapped
