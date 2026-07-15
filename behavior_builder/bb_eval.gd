class_name BBEval
extends RefCounted
## Pure, UI-independent evaluation of behavior graphs.
## Both the live editor nodes AND serialized (saved) conditions run through here,
## which means the ant sim itself can later evaluate library JSON directly.
##
## Value semantics: null means "unknown / not wired". AND & OR ignore unknown
## inputs; a node with no usable inputs evaluates to null.


static func compute(type: String, params: Dictionary, inputs: Array, world, library, name_stack: Array = []) -> Variant:
	match type:
		"world_value":
			return world.get_value(str(params.get("key", "health")))
		"constant":
			return float(params.get("value", 0.0))
		"compare":
			var a = inputs[0] if inputs.size() > 0 else null
			if a == null:
				return null
			var b = inputs[1] if inputs.size() > 1 and inputs[1] != null else params.get("b", 0.0)
			match str(params.get("op", "<")):
				">":  return float(a) > float(b)
				"<":  return float(a) < float(b)
				">=": return float(a) >= float(b)
				"<=": return float(a) <= float(b)
				"==": return absf(float(a) - float(b)) < 0.0001
				"!=": return absf(float(a) - float(b)) >= 0.0001
			return null
		"and":
			var vals := inputs.filter(func(v): return v != null)
			if vals.is_empty():
				return null
			for v in vals:
				if not v:
					return false
			return true
		"or":
			var vals := inputs.filter(func(v): return v != null)
			if vals.is_empty():
				return null
			for v in vals:
				if v:
					return true
			return false
		"not":
			var v = inputs[0] if inputs.size() > 0 else null
			return null if v == null else not v
		"condition":
			return eval_condition(str(params.get("name", "")), world, library, name_stack)
		"behavior":
			return inputs[0] if inputs.size() > 0 else null
	return null


## Evaluate a saved condition by name. name_stack guards against
## self-referential / cyclic condition definitions.
static func eval_condition(cname: String, world, library, name_stack: Array = []) -> Variant:
	if cname in name_stack:
		return null
	if library == null or not library.has_condition(cname):
		return null
	var data: Dictionary = library.get_condition(cname)
	var memo := eval_graph(data, world, library, name_stack + [cname])
	return memo.get(str(data.get("output_id", "")), null)


## Evaluate every node in a serialized graph. Returns { node_id: value }.
static func eval_graph(data: Dictionary, world, library, name_stack: Array = []) -> Dictionary:
	var nodes := {}
	for n in data.get("nodes", []):
		nodes[str(n.id)] = n
	var incoming := {}
	for c in data.get("connections", []):
		var to := str(c.to)
		if not incoming.has(to):
			incoming[to] = {}
		incoming[to][int(c.to_port)] = str(c.from)
	var memo := {}
	for id in nodes:
		_eval_id(id, nodes, incoming, memo, {}, world, library, name_stack)
	return memo


static func _eval_id(id: String, nodes: Dictionary, incoming: Dictionary, memo: Dictionary, visiting: Dictionary, world, library, name_stack: Array) -> Variant:
	if memo.has(id):
		return memo[id]
	if visiting.has(id) or not nodes.has(id):
		return null
	visiting[id] = true
	var n: Dictionary = nodes[id]
	var cnt := int(n.get("in_count", 0))
	var inputs := []
	var inc: Dictionary = incoming.get(id, {})
	for p in cnt:
		if inc.has(p):
			inputs.append(_eval_id(inc[p], nodes, incoming, memo, visiting, world, library, name_stack))
		else:
			inputs.append(null)
	var v = compute(str(n.type), n.get("params", {}), inputs, world, library, name_stack)
	visiting.erase(id)
	memo[id] = v
	return v
