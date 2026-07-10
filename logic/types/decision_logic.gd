class_name DecisionLogic
extends Logic
## Decision logic: evaluates like an expression, and additionally fires the
## action_triggered signal when the result is truthy — the hook that lets a
## Logic resource drive behavior directly rather than being polled.
##
## ASSUMPTION FLAG: the base class carries the (previously unused)
## action_triggered signal; wiring it here is the natural home, but if your
## local `if logic is DecisionLogic:` branch did something else, replace
## this body with that branch.


func evaluate(state: LogicState, bindings: Array) -> Variant:
	var result: Variant = state.execute(bindings)
	if state.has_error():
		return null
	if result:
		action_triggered.emit(result, id)
	return result
