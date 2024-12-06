## Context object passed to expressions during list processing
class_name EvaluationContext
extends Resource

## The current item being processed from a list
var current_item: Variant
## The original entity (ant)
var root_entity: Node
## Whether the current item is a Node
var is_node_context: bool
## Any additional context data needed for evaluation
var data: Dictionary

## Create a new context
static func create(item: Variant, entity: Node) -> EvaluationContext:
	var context = EvaluationContext.new()
	context.current_item = item
	context.root_entity = entity
	context.is_node_context = item is Node
	return context
