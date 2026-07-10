class_name ConditionLogic
extends Logic
## Boolean logic: an expression whose result gates rules, pheromone
## emission, or influence profiles. Coerces the executed result to bool so
## downstream code never has to truthiness-test a float.
##
## Null (execution failure or empty expression) stays null — the engine
## detects state.has_error() after evaluate() and refuses to cache, so
## swallowing errors into `false` here would hide them.


func evaluate(state: LogicState, bindings: Array) -> Variant:
	var result: Variant = state.execute(bindings)
	if result == null:
		return null
	return bool(result)
