class_name SourceLogic
extends Logic
## Leaf logic reading from an external source through the senses facade.
##
## ASSUMPTION FLAG: the pre-refactor `if logic is SourceLogic:` branch body
## was not in project knowledge, so this implements the same direct-read
## semantics as PropertyLogic (expression_string names the sense). If your
## local branch did something different — parameterized sense calls,
## colony/world reads, a pushed blackboard value — replace this body with
## that branch verbatim; the engine contract (evaluate(state, bindings))
## stays the same either way.


func evaluate(state: LogicState, _bindings: Array) -> Variant:
	var sense: String = expression_string.strip_edges()
	if sense.is_empty() or state.context == null:
		return null
	if state.context.has_method(sense):
		return state.context.call(sense)
	return state.context.get(sense)
