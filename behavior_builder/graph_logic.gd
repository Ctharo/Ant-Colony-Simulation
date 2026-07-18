class_name GraphLogic
extends Logic
## Node-graph Logic (Path B of the graph-editor integration): WHAT to
## compute is a serialized behavior graph in BBEval's format, evaluated
## against an AntWorldAdapter. Slots into the engine unchanged —
## EvaluationSystem still decides WHEN (policies, caching, dependency
## versions, stats) because this class only overrides Logic.evaluate(),
## exactly the contract the base class documents.
##
## RUNTIME TRUTH: graph_data. expression_string stays EMPTY by design:
## LogicState then compiles nothing (parse() early-returns OK) and
## pure_composite stays false — the correct conservative default, since a
## graph reads the world directly (leaf semantics) and may contain
## stateful timer nodes. Dependency-version short-circuiting therefore
## never gates a graph; only the eval policy does. Do NOT put text in
## expression_string to "document" a graph — use description; a non-empty
## expression_string would be parsed as a real expression.
##
## EVAL POLICY GUIDANCE: FRAME (default), ALWAYS, and TIMER behave
## correctly. STICKY and EVENT will freeze timer-node holds (the cached
## value never expires, so hold expiry is never observed) — avoid them on
## graphs containing timer nodes. The editor-side warning lands in Batch C.
##
## VALIDATION: LogicValidator.validate_logic() branches GraphLogic to
## BBGraphValidator (Batch B patch). That one seam covers gate 2
## (ResourceLibrary.save_resource and its embedded-Logic walk) and gate 3
## (EvaluationSystem._ensure_ready) — hand-edited .tres graph data cannot
## reach BBEval unvalidated.
##
## TIMER STATE: BBEval keys stateful-node memory by name_stack, so
## evaluate() seeds the stack with a per-(graph, entity) tag: no two ants
## share a hold, and no two graphs on one ant collide on reused node ids.
## Cleanup helpers live in the BBEval patch (clear_states_tagged).
##
## PERF NOTE: one AntWorldAdapter is allocated per RECOMPUTE (cache hits
## never reach evaluate()). Deliberate — a RefCounted holding one
## reference is cheaper than a per-entity adapter map that would need
## eviction bookkeeping.

## Serialized graph (BBEval format: { nodes, connections, output_id }).
## The graph editor (Batch C) writes it; hand edits are caught by the
## validator gates like any other .tres tampering.
@export var graph_data: Dictionary = {}


func _init() -> void:
	# Graphs are authored as behavior conditions; a bool default gives
	# EvaluationSystem._default_for_type() the right neutral (false) when
	# validation rejects one. A float-outputting graph still evaluates
	# fine — rule gating applies ordinary truthiness.
	type = TYPE_BOOL


## Per-(graph, entity) namespace for BBEval's stateful-node memory. The
## format is load-bearing: BBEval.clear_states_tagged("@<iid>") clears an
## entity's holds on despawn, and ("glogic:<id>@") clears one graph's
## holds everywhere after a library re-save. The colon/at characters keep
## tags disjoint from condition names, so BBEval's cycle guard
## ("cname in name_stack") is unaffected.
static func entity_tag(p_logic_id: String, p_entity: Node) -> String:
	return "glogic:%s@%d" % [p_logic_id, p_entity.get_instance_id()]


func evaluate(state: LogicState, _bindings: Array) -> Variant:
	if graph_data.is_empty():
		return null  # empty graph = unknown; a rule gated on it never fires

	var ant: Ant = state.entity as Ant
	if ant == null:
		return null  # graphs read an ant's world; other entities have none

	var world: AntWorldAdapter = AntWorldAdapter.new(ant)
	var name_stack: Array = [GraphLogic.entity_tag(id, state.entity)]
	var memo: Dictionary = BBEval.eval_graph(
		graph_data, world, BBGraphLibrary.shared(), name_stack)
	return memo.get(str(graph_data.get("output_id", "")), null)
