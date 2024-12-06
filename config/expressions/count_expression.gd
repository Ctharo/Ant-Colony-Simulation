class_name ArrayCountExpression
extends BaseExpression

## Expression that provides the array to count
@export var array_expression: BaseExpression

func _init() -> void:
	return_type = Property.Type.INT

func is_valid() -> bool:
	return (super.is_valid() 
		and array_expression != null 
		and array_expression.is_valid())

func initialize(p_entity: Node) -> void:
	super.initialize(entity)
	array_expression.initialize(entity)

func _evaluate() -> int:
	var array = array_expression.evaluate()
	return array.size() if array != null else 0
