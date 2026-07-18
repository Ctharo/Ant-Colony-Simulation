class_name BBGraphValidator
extends RefCounted
## Closed-whitelist validation for serialized behavior graphs — the graph
## runtime's analogue of LogicValidator. A graph is a plain Dictionary in
## BBEval's format ({nodes, connections, output_id}); this validator
## rejects anything outside the whitelists below, so UI- or hand-authored
## graph data can never reach an unknown node type, world key, list
## source, item property, or operator at runtime.
##
## GATES (same doctrine as LogicValidator's three):
##   1. editor live       — graph editor validates on every change  (Batch C)
##   2. persistence       — ResourceLibrary.save_resource(GraphLogic) (Batch B)
##   3. first evaluation  — GraphLogic validates once per parse      (Batch B)
## The class ships in Batch A so both wirings land against a stable API.
##
## Deliberately NOT errors here:
## - Cycles: BBEval detects them at evaluation time and yields unknown
##   (null) — documented graph semantics, not invalid data.
## - Unwired inputs: null-as-unknown is the feature, not a fault.
## - Unreachable nodes: legal scratch space, same as the editor allows.
##
## Errors are data failures, never invariants (a hand-edited .tres or a
## renamed pheromone can produce every one of them in release). Callers
## follow the log-once doctrine: this validator DETECTS and returns; the
## gate that called it decides recovery (status label, refuse save, refuse
## parse) without re-logging.

## Every node type BBEval.compute() understands. Anything else is rejected.
const NODE_TYPES: PackedStringArray = [
	"world_value", "constant", "compare", "math", "timer",
	"and", "or", "not", "condition", "behavior",
	"sense_list", "filter", "sort", "pick", "item_value", "list_count",
]

const COMPARE_OPS: PackedStringArray = [">", "<", ">=", "<=", "==", "!="]
const MATH_OPS: PackedStringArray = ["+", "-", "*", "/", "min", "max"]
const FILTER_OPS: PackedStringArray = ["<", ">", "<=", ">=", "=="]
const FILTER_MODES: PackedStringArray = ["float", "bool"]
const PICK_MODES: PackedStringArray = ["first", "nearest", "farthest"]

## SORT keys may reference a saved library value: "lib:<name>".
const LIB_KEY_PREFIX: String = "lib:"


## Validates a serialized graph. `library` is duck-typed (anything with
## has_condition(name) -> bool); pass it to also check condition/sort
## references, or null to skip reference checks (e.g. validating a graph
## detached from any library). Empty result = valid.
static func validate(data: Dictionary, library: Variant = null) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()

	var nodes_raw: Variant = data.get("nodes", [])
	if not (nodes_raw is Array):
		errors.append("graph: 'nodes' must be an Array")
		return errors
	var conns_raw: Variant = data.get("connections", [])
	if not (conns_raw is Array):
		errors.append("graph: 'connections' must be an Array")
		return errors

	# node_id -> in_count, for connection port-range checks.
	var in_counts: Dictionary = {}

	for node_raw: Variant in (nodes_raw as Array):
		if not (node_raw is Dictionary):
			errors.append("graph: non-Dictionary entry in 'nodes'")
			continue
		var node: Dictionary = node_raw
		var node_id: String = str(node.get("id", ""))
		if node_id.is_empty():
			errors.append("graph: node without an id")
			continue
		if in_counts.has(node_id):
			errors.append("graph: duplicate node id '%s'" % node_id)
		in_counts[node_id] = int(node.get("in_count", 0))
		_validate_node(node_id, node, library, errors)

	for conn_raw: Variant in (conns_raw as Array):
		if not (conn_raw is Dictionary):
			errors.append("graph: non-Dictionary entry in 'connections'")
			continue
		var conn: Dictionary = conn_raw
		var from_id: String = str(conn.get("from", ""))
		var to_id: String = str(conn.get("to", ""))
		var to_port: int = int(conn.get("to_port", -1))
		if not in_counts.has(from_id):
			errors.append("connection: 'from' references unknown node '%s'" % from_id)
		if not in_counts.has(to_id):
			errors.append("connection: 'to' references unknown node '%s'" % to_id)
		elif to_port < 0 or to_port >= int(in_counts[to_id]):
			errors.append("connection: port %d out of range on node '%s' (in_count %d)" % [
				to_port, to_id, int(in_counts[to_id])])

	var output_id: String = str(data.get("output_id", ""))
	if not output_id.is_empty() and not in_counts.has(output_id):
		errors.append("graph: output_id '%s' is not a node" % output_id)

	return errors


static func is_valid(data: Dictionary, library: Variant = null) -> bool:
	return validate(data, library).is_empty()


static func _validate_node(node_id: String, node: Dictionary,
		library: Variant, errors: PackedStringArray) -> void:
	var node_type: String = str(node.get("type", ""))
	if not node_type in NODE_TYPES:
		errors.append("node '%s': unknown type '%s'" % [node_id, node_type])
		return

	var params_raw: Variant = node.get("params", {})
	if not (params_raw is Dictionary):
		errors.append("node '%s' (%s): 'params' must be a Dictionary" % [node_id, node_type])
		return
	var params: Dictionary = params_raw

	match node_type:
		"world_value":
			var key: String = str(params.get("key", ""))
			if not BBVocabulary.has_field(key):
				errors.append("node '%s' (world_value): unknown world key '%s' — the vocabulary may have changed (renamed pheromone?)" % [node_id, key])
		"compare":
			var compare_op: String = str(params.get("op", "<"))
			if not compare_op in COMPARE_OPS:
				errors.append("node '%s' (compare): unknown op '%s'" % [node_id, compare_op])
		"math":
			var math_op: String = str(params.get("op", "+"))
			if not math_op in MATH_OPS:
				errors.append("node '%s' (math): unknown op '%s'" % [node_id, math_op])
		"timer":
			var seconds: float = float(params.get("seconds", 3.0))
			if seconds <= 0.0:
				errors.append("node '%s' (timer): hold duration must be > 0 (got %s)" % [node_id, str(seconds)])
		"condition":
			var cond_name: String = str(params.get("name", ""))
			if cond_name.is_empty():
				errors.append("node '%s' (condition): missing referenced condition name" % node_id)
			elif library != null and library.has_method("has_condition") \
					and not library.has_condition(cond_name):
				errors.append("node '%s' (condition): '%s' is not in the library" % [node_id, cond_name])
		"sense_list":
			var source: String = str(params.get("source", ""))
			if not BBVocabulary.has_list_source(source):
				errors.append("node '%s' (sense_list): unknown source '%s'" % [node_id, source])
		"filter":
			var filter_prop: String = str(params.get("prop", ""))
			if not BBVocabulary.has_item_prop(filter_prop):
				errors.append("node '%s' (filter): unknown item property '%s'" % [node_id, filter_prop])
			var filter_mode: String = str(params.get("mode", "float"))
			if not filter_mode in FILTER_MODES:
				errors.append("node '%s' (filter): unknown mode '%s'" % [node_id, filter_mode])
			elif filter_mode == "float":
				var filter_op: String = str(params.get("op", "<"))
				if not filter_op in FILTER_OPS:
					errors.append("node '%s' (filter): unknown op '%s'" % [node_id, filter_op])
		"sort":
			var sort_key: String = str(params.get("key", ""))
			if sort_key.begins_with(LIB_KEY_PREFIX):
				var lib_name: String = sort_key.trim_prefix(LIB_KEY_PREFIX)
				if lib_name.is_empty():
					errors.append("node '%s' (sort): empty library key reference" % node_id)
				elif library != null and library.has_method("has_condition") \
						and not library.has_condition(lib_name):
					errors.append("node '%s' (sort): library value '%s' does not exist" % [node_id, lib_name])
			elif not BBVocabulary.has_item_prop(sort_key):
				errors.append("node '%s' (sort): unknown sort key '%s'" % [node_id, sort_key])
		"pick":
			var pick_mode: String = str(params.get("mode", "nearest"))
			if not pick_mode in PICK_MODES:
				errors.append("node '%s' (pick): unknown mode '%s'" % [node_id, pick_mode])
		"item_value":
			var item_prop: String = str(params.get("prop", ""))
			if not BBVocabulary.has_item_prop(item_prop):
				errors.append("node '%s' (item_value): unknown item property '%s'" % [node_id, item_prop])
		_:
			# constant / and / or / not / behavior / list_count carry no
			# validatable params beyond their type membership.
			pass
