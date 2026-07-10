class_name ExpressionLogic
extends Logic
## Interior logic: a compiled Expression over nested ids, atomic senses, and
## pure built-ins. state.expression holds the parsed program; the engine has
## already resolved the nested values into `bindings` (in
## nested_expressions order) before calling this.


func evaluate(state: LogicState, bindings: Array) -> Variant:
	return state.execute(bindings)
