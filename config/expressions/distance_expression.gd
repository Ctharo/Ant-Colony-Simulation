class_name DistanceExpression
extends LogicExpression

## Expression that provides the first position
@export var position1_expression: LogicExpression
## Expression that provides the second position
@export var position2_expression: LogicExpression

func _init() -> void:
	name = "Distance"
	description = "Calculates distance between two positions"
	return_type = TYPE_FLOAT

func _register_dependencies() -> void:
	if position1_expression:
		add_dependency(position1_expression)
	if position2_expression:
		add_dependency(position2_expression)

func _evaluate() -> float:
	var pos1 = position1_expression.evaluate()
	var pos2 = position2_expression.evaluate()
	if not pos1 or not pos2:
		return INF
	return pos1.distance_to(pos2)
