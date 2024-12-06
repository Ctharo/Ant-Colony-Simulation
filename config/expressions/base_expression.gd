class_name BaseExpression
extends Resource

## Unique identifier for this expression
@export var id: String

## Human readable name for this expression
@export var name: String

## Description of what this expression does
@export var description: String

## Type of value this expression returns
@export var return_type: Property.Type

## List of expressions this one depends on
@export var dependencies: Array[BaseExpression]

## Property paths this expression directly depends on
@export var property_dependencies: Array[String]

## Reference to entity for property access
var entity: Node

## Initialize with entity reference
func initialize(p_entity: Node) -> void:
	entity = p_entity

## Validate if expression can be evaluated
func is_valid() -> bool:
	return entity != null

## Evaluate the expression
func evaluate() -> Variant:
	if not is_valid():
		push_error("Attempted to evaluate invalid expression: %s" % name)
		return null
	return _evaluate()

## Internal evaluation logic (override in derived classes)
func _evaluate() -> Variant:
	return null
