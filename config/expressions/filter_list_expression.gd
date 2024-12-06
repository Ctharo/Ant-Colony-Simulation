class_name FilterExpression
extends BaseExpression

## Expression providing the source list
@export var list_expression: BaseExpression

## Property to compare against
@export var filter_property: String

## Comparison operator
enum Operator { EQUALS, NOT_EQUALS, GREATER, LESS, CONTAINS }
@export var operator: Operator

## Value to compare with
var compare_value: Variant

func _init() -> void:
	return_type = Property.Type.ARRAY
	dependencies = [list_expression]

func _evaluate() -> Array:
	var list = list_expression.evaluate()
	if list == null:
		return []
		
	var filtered = []
	for item in list:
		var prop_value = item.get(filter_property)
		if compare_values(prop_value, compare_value, operator):
			filtered.append(item)
	return filtered
