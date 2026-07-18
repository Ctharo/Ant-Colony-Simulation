class_name BBEval
extends RefCounted
## Pure, UI-independent evaluation of behavior graphs.
## Both the live editor nodes AND serialized (saved) conditions run through here,
## which means the ant sim itself can later evaluate library JSON directly.
##
## Value semantics: null means "unknown / not wired". AND & OR ignore unknown
## inputs; a node with no usable inputs evaluates to null.
## New value kinds: Array = a sensed LIST (never null when wired, may be
## empty), Dictionary = one ITEM picked from a list (null when the list was
## empty). Both contain value types only — the AntSenses safety rule.
##
## Stateful nodes ("timer"): each node instance needs somewhere to remember
## its hold-until timestamp. Live editor nodes pass their own eval_state dict;
## serialized graphs get one from [member _states], keyed by condition path +
## node id (note: all instances of the same saved condition therefore share
## one timer — unpack the condition if you need independent timers).


## Persistent state for stateful nodes inside serialized/saved graphs.
static var _states: Dictionary = {}


## Drops every stateful-node memory whose key contains `tag`. Two callers:
## entity despawn ("@<iid>" — an ant's timer holds die with it) and
## GraphLogic re-save ("glogic:<id>@" — an edited graph restarts its
## holds). Substring matching is deliberate: keys are
## "<name_stack>#<node_id>" strings, and GraphLogic.entity_tag constructs
## tags (colon/at characters) that cannot collide with condition names or
## node ids.
static func clear_states_tagged(tag: String) -> void:
	if tag.is_empty():
		return
	var doomed: Array[String] = []
	for key: String in _states:
		if key.contains(tag):
			doomed.append(key)
	for key: String in doomed:
		var _erased: bool = _states.erase(key)


## Evaluates one item's sort key against a saved ◈ VALUE from the library:
## world_value reads hit the item's own properties first (distance, health,
## …) and fall back to the surrounding world. This is what makes "sort by a
## function" work — any saved float expression becomes a per-item key.
class ItemContext extends RefCounted:
	var _item: Dictionary
	var _world: Variant

	func _init(p_item: Dictionary, p_world: Variant) -> void:
		_item = p_item
		_world = p_world

	func get_value(key: String) -> float:
		var raw: Variant = _item.get(key)
		if raw is bool:
			return 1.0 if bool(raw) else 0.0
		if raw != null:
			return float(raw)
		return float(_world.get_value(key))

	func get_list(source: String) -> Array:
		if _world != null and _world.has_method("get_list"):
			return _world.get_list(source)
		var empty: Array = []
		return empty

	func snapshot() -> Dictionary:
		if _world != null and _world.has_method("snapshot"):
			return _world.snapshot()
		return {}


static func compute(type: String, params: Dictionary, inputs: Array, world: Variant, library: Variant, name_stack: Array = [], state: Dictionary = {}) -> Variant:
	match type:
		"world_value":
			return world.get_value(str(params.get("key", "health")))
		"constant":
			return float(params.get("value", 0.0))
		"compare":
			var a: Variant = inputs[0] if inputs.size() > 0 else null
			if a == null:
				return null
			var b: Variant = inputs[1] if inputs.size() > 1 and inputs[1] != null else params.get("b", 0.0)
			match str(params.get("op", "<")):
				">":
					return float(a) > float(b)
				"<":
					return float(a) < float(b)
				">=":
					return float(a) >= float(b)
				"<=":
					return float(a) <= float(b)
				"==":
					return absf(float(a) - float(b)) < 0.0001
				"!=":
					return absf(float(a) - float(b)) >= 0.0001
			return null
		"math":
			var a: Variant = inputs[0] if inputs.size() > 0 else null
			if a == null:
				return null
			var b: Variant = inputs[1] if inputs.size() > 1 and inputs[1] != null else params.get("b", 0.0)
			match str(params.get("op", "+")):
				"+":
					return float(a) + float(b)
				"-":
					return float(a) - float(b)
				"*":
					return float(a) * float(b)
				"/":
					return null if is_zero_approx(float(b)) else float(a) / float(b)
				"min":
					return minf(float(a), float(b))
				"max":
					return maxf(float(a), float(b))
			return null
		"timer":
			# HOLD TRUE: once the input goes true, output stays true for
			# `seconds`; only after the hold expires is the input re-considered.
			var v: Variant = inputs[0] if inputs.size() > 0 else null
			var now: int = Time.get_ticks_msec()
			if now < int(state.get("hold_until", 0)):
				return true
			if v is bool and bool(v):
				state["hold_until"] = now + int(float(params.get("seconds", 3.0)) * 1000.0)
				return true
			return null if v == null else false
		"and":
			var vals: Array = inputs.filter(func(v: Variant) -> bool: return v != null)
			if vals.is_empty():
				return null
			for v: Variant in vals:
				if not v:
					return false
			return true
		"or":
			var vals: Array = inputs.filter(func(v: Variant) -> bool: return v != null)
			if vals.is_empty():
				return null
			for v: Variant in vals:
				if v:
					return true
			return false
		"not":
			var v: Variant = inputs[0] if inputs.size() > 0 else null
			return null if v == null else not v
		"condition":
			return eval_condition(str(params.get("name", "")), world, library, name_stack)
		"behavior":
			return inputs[0] if inputs.size() > 0 else null

		# ---------------------------------------------------- list pipeline
		"sense_list":
			return world.get_list(str(params.get("source", "ants_in_view")))
		"filter":
			return _compute_filter(params, inputs)
		"sort":
			return _compute_sort(params, inputs, world, library, name_stack)
		"pick":
			return _compute_pick(params, inputs)
		"item_value":
			var item: Variant = inputs[0] if inputs.size() > 0 else null
			if not (item is Dictionary):
				return null
			var raw: Variant = (item as Dictionary).get(str(params.get("prop", "distance")))
			if raw == null:
				return null
			if raw is bool:
				return raw
			return float(raw)
		"list_count":
			var lst: Variant = inputs[0] if inputs.size() > 0 else null
			if not (lst is Array):
				return null
			return float((lst as Array).size())
	return null


## FILTER: keep items where <prop> passes the test. Bool mode keeps items
## whose flag equals want_true; float mode compares against an inline or
## wired threshold. Items missing the property are always dropped.
static func _compute_filter(params: Dictionary, inputs: Array) -> Variant:
	var src: Variant = inputs[0] if inputs.size() > 0 else null
	if not (src is Array):
		return null
	var items: Array = src
	var prop: String = str(params.get("prop", "distance"))
	var out: Array = []

	if str(params.get("mode", "float")) == "bool":
		var want: bool = bool(params.get("want_true", true))
		for item: Variant in items:
			if not (item is Dictionary):
				continue
			var raw: Variant = (item as Dictionary).get(prop)
			if raw is bool and bool(raw) == want:
				out.append(item)
		return out

	var threshold: float = float(inputs[1]) if inputs.size() > 1 and inputs[1] != null \
			else float(params.get("value", 0.0))
	var op: String = str(params.get("op", "<"))
	for item: Variant in items:
		if not (item is Dictionary):
			continue
		var raw: Variant = (item as Dictionary).get(prop)
		if raw == null or raw is bool:
			continue
		var a: float = float(raw)
		var keep: bool = false
		match op:
			"<":
				keep = a < threshold
			">":
				keep = a > threshold
			"<=":
				keep = a <= threshold
			">=":
				keep = a >= threshold
			"==":
				keep = absf(a - threshold) < 0.0001
		if keep:
			out.append(item)
	return out


## SORT: orders a list by a key. The key is either a built-in item property
## ("distance", "health", …) or "lib:<name>" — a saved ◈ VALUE evaluated per
## item via ItemContext. Keys are computed once per item, not per comparison.
static func _compute_sort(params: Dictionary, inputs: Array, world: Variant, library: Variant, name_stack: Array) -> Variant:
	var src: Variant = inputs[0] if inputs.size() > 0 else null
	if not (src is Array):
		return null
	var key: String = str(params.get("key", "distance"))
	var descending: bool = bool(params.get("descending", false))

	var keyed: Array = []
	for item: Variant in (src as Array):
		keyed.append([_item_key_value(item, key, world, library, name_stack), item])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) > float(b[0]) if descending else float(a[0]) < float(b[0]))

	var out: Array = []
	for pair: Array in keyed:
		out.append(pair[1])
	return out


## PICK: one item out of a list, or null when the list is empty — the same
## degrade-safely contract as Vector2.INF in AntSenses (downstream compares
## on a null item evaluate as unknown, never crash).
static func _compute_pick(params: Dictionary, inputs: Array) -> Variant:
	var src: Variant = inputs[0] if inputs.size() > 0 else null
	if not (src is Array):
		return null
	var items: Array = src
	if items.is_empty():
		return null
	match str(params.get("mode", "nearest")):
		"first":
			return items[0]
		"nearest":
			return _extreme_by_distance(items, true)
		"farthest":
			return _extreme_by_distance(items, false)
	return items[0]


static func _extreme_by_distance(items: Array, want_min: bool) -> Variant:
	var best: Variant = null
	var best_d: float = INF if want_min else -INF
	for item: Variant in items:
		if not (item is Dictionary):
			continue
		var d: float = float((item as Dictionary).get("distance", INF))
		if (want_min and d < best_d) or (not want_min and d > best_d):
			best_d = d
			best = item
	return best


## Numeric sort key for one item. Missing keys sort last ascending (INF);
## bools coerce to 1/0 so "sort by is_ally, highest first" puts allies first.
static func _item_key_value(item: Variant, key: String, world: Variant, library: Variant, name_stack: Array) -> float:
	if not (item is Dictionary):
		return INF
	var dict: Dictionary = item
	if key.begins_with("lib:"):
		var ctx: ItemContext = ItemContext.new(dict, world)
		var v: Variant = eval_condition(key.trim_prefix("lib:"), ctx, library, name_stack)
		if v is bool:
			return 1.0 if bool(v) else 0.0
		return float(v) if v != null else INF
	var raw: Variant = dict.get(key)
	if raw is bool:
		return 1.0 if bool(raw) else 0.0
	return float(raw) if raw != null else INF


## Evaluate a saved condition by name. name_stack guards against
## self-referential / cyclic condition definitions.
static func eval_condition(cname: String, world: Variant, library: Variant, name_stack: Array = []) -> Variant:
	if cname in name_stack:
		return null
	if library == null or not library.has_condition(cname):
		return null
	var data: Dictionary = library.get_condition(cname)
	var memo: Dictionary = eval_graph(data, world, library, name_stack + [cname])
	return memo.get(str(data.get("output_id", "")), null)


## Evaluate every node in a serialized graph. Returns { node_id: value }.
static func eval_graph(data: Dictionary, world: Variant, library: Variant, name_stack: Array = []) -> Dictionary:
	var nodes: Dictionary = {}
	for n: Dictionary in data.get("nodes", []):
		nodes[str(n.id)] = n
	var incoming: Dictionary = {}
	for c: Dictionary in data.get("connections", []):
		var to_id: String = str(c.to)
		if not incoming.has(to_id):
			incoming[to_id] = {}
		incoming[to_id][int(c.to_port)] = str(c.from)
	var memo: Dictionary = {}
	for id: String in nodes:
		var _v: Variant = _eval_id(id, nodes, incoming, memo, {}, world, library, name_stack)
	return memo


static func _eval_id(id: String, nodes: Dictionary, incoming: Dictionary, memo: Dictionary, visiting: Dictionary, world: Variant, library: Variant, name_stack: Array) -> Variant:
	if memo.has(id):
		return memo[id]
	if visiting.has(id) or not nodes.has(id):
		return null
	visiting[id] = true
	var n: Dictionary = nodes[id]
	var cnt: int = int(n.get("in_count", 0))
	var inputs: Array = []
	var inc: Dictionary = incoming.get(id, {})
	for p: int in cnt:
		if inc.has(p):
			inputs.append(_eval_id(str(inc[p]), nodes, incoming, memo, visiting, world, library, name_stack))
		else:
			inputs.append(null)
	var v: Variant = compute(str(n.type), n.get("params", {}), inputs, world, library, name_stack, _state_for(name_stack, id))
	visiting.erase(id)
	memo[id] = v
	return v


## Persistent per-node state dict for serialized graphs.
static func _state_for(name_stack: Array, id: String) -> Dictionary:
	var key: String = "%s#%s" % [str(name_stack), id]
	if not _states.has(key):
		_states[key] = {}
	return _states[key]
