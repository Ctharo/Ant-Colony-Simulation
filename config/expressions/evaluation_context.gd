## Context object passed to expressions during list processing
class_name EvaluationContext
extends Resource

## The current item being processed from a list
var current_item: Node
## The original entity (ant)
var root_entity: Node
## Any additional context data needed for evaluation
var data: Dictionary

## Create a new context
static func create(item: Node, entity: Node) -> EvaluationContext:
	var context = EvaluationContext.new()
	context.current_item = item
	context.root_entity = entity
	return context
