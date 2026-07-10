class_name PropertyLogic
extends Logic
## Leaf logic: a direct read of ONE atomic sense — expression_string holds
## the AntSenses symbol name (e.g. "energy_level"). Skips the Expression VM
## entirely: no parse, no bindings, just a property read or zero-arg call on
## the senses facade.
##
## These leaves are what make dependency-version gating sound: when every
## world read is wrapped in a Property/Source leaf with its own eval policy,
## interior expressions become pure functions of their children and can skip
## recomputation whenever no child version changed.


func evaluate(state: LogicState, _bindings: Array) -> Variant:
	var sense := expression_string.strip_edges()
	if sense.is_empty() or state.context == null:
		return null
	# AntSenses exposes both properties (energy_level) and zero-arg methods;
	# handle either. Whitelist enforcement already happened at the three
	# validator gates, so `sense` is guaranteed to be a vocabulary name.
	if state.context.has_method(sense):
		return state.context.call(sense)
	return state.context.get(sense)
