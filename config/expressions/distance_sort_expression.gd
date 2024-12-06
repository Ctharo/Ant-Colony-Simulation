class_name DistanceSortExpression
extends BaseExpression

## Expression providing the list to sort
@export var list_expression: BaseExpression

## Property path for position to measure from
@export var position_property: String

func _init() -> void:
	return_type = Property.Type.ARRAY
	dependencies = [list_expression]
	property_dependencies = [position_property]

func _evaluate() -> Array:
	var list = list_expression.evaluate()
	if list == null:
		return []
		
	var pos = entity.get_property_value(position_property)
	if pos == null:
		return []
		
	var sorted = list.duplicate()
	sorted.sort_custom(func(a, b): 
		return a.global_position.distance_to(pos) < b.global_position.distance_to(pos)
	)
	return sorted
