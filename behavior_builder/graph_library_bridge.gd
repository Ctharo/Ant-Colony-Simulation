class_name BBGraphLibrary
extends RefCounted
## ResourceLibrary-backed implementation of the duck-typed library contract
## BBEval and the graph editor expect — the clean-break replacement for the
## prototype's BBConditionLibrary and its user://behavior_conditions.json.
## Named subgraphs (◈ condition nodes, "lib:" sort keys, Ctrl+G saves)
## resolve to GraphLogic resources cataloged under ResourceLibrary
## KIND_LOGIC, so reusable graph conditions live in the SAME unified
## catalog as every other behavior resource: never-clobber seeding,
## manifest-tracked deletions, and user://behavior persistence apply free.
##
## BATCH C additions over the read-only Batch B version: names(),
## save_condition(), remove_condition(), all_condition_data(),
## export_json(), and a `changed` signal relayed from
## ResourceLibrary.library_changed(KIND_LOGIC) — everything BBGraphPanel's
## library UI needs. This file SUPERSEDES batch_b's
## graph_library_bridge.gd.
##
## RESOLUTION: by resource NAME first (what the save dialog and node titles
## display), falling back to id. Renaming a GraphLogic orphans references
## saved under the old name — the same known tradeoff as renaming a
## pheromone; BBGraphValidator reports the dangling reference at every gate.
##
## MOSTLY STATELESS: no condition caching — ResourceLibrary's catalog IS
## the cache, so library edits are visible to the next evaluation with no
## invalidation protocol. Lookups are linear over KIND_LOGIC; authoring-
## scale noise.
##
## SAFETY: get_condition returns the graph's plain-Dictionary data, never
## the GraphLogic resource — worlds and graphs deal exclusively in value
## types, and this bridge preserves that.

signal changed

static var _shared: BBGraphLibrary = null


func _init() -> void:
	var _err: Error = ResourceLibrary.library_changed.connect(_on_library_changed)


## Process-wide instance for evaluate()/validator/panel callers. A plain
## static, not an autoload: no lifecycle beyond the signal relay above.
static func shared() -> BBGraphLibrary:
	if _shared == null:
		_shared = BBGraphLibrary.new()
	return _shared


func _on_library_changed(kind: String) -> void:
	if kind == ResourceLibrary.KIND_LOGIC:
		changed.emit()


#region Read contract (BBEval, condition nodes, validator)
func has_condition(cname: String) -> bool:
	return _find(cname) != null


## Serialized graph data for the named condition, or null when it does not
## exist (BBEval degrades a missing reference to unknown).
func get_condition(cname: String) -> Variant:
	var found: GraphLogic = _find(cname)
	return found.graph_data if found != null else null


## Display names of every cataloged graph condition/value, catalog order
## (ResourceLibrary pre-sorts entries by display name).
func names() -> Array[String]:
	var out: Array[String] = []
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		var graph: GraphLogic = entry.resource as GraphLogic
		if graph != null and not graph.name.is_empty():
			out.append(graph.name)
	return out


## name -> graph_data for every cataloged graph (debug-JSON export shape,
## matching the prototype's `library.conditions`).
func all_condition_data() -> Dictionary:
	var out: Dictionary = {}
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		var graph: GraphLogic = entry.resource as GraphLogic
		if graph != null:
			out[graph.name] = graph.graph_data
	return out


func export_json() -> String:
	return JSON.stringify(all_condition_data(), "  ")
#endregion


#region Write contract (Ctrl+G, library delete)
## Creates or overwrites the GraphLogic named `cname` with `data`.
## Overwrite-by-reference is automatic: ◈ nodes and GraphLogic.evaluate()
## resolve by name at read time, so every reference sees the new definition
## immediately. Goes through ResourceLibrary.save_resource — gate 2
## (validate_logic → BBGraphValidator) rejects invalid data before it can
## persist. On success, cached values and timer holds are dropped so live
## ants (and any behavior referencing this condition) pick up the edit now.
func save_condition(cname: String, data: Dictionary) -> Error:
	var existing: GraphLogic = _find(cname)
	var graph: GraphLogic
	var previous_path: String = ""
	if existing != null:
		previous_path = existing.resource_path \
			if existing.resource_path.begins_with("user://") else ""
		graph = ResourceLibrary.duplicate_for_edit(existing) as GraphLogic
	else:
		graph = GraphLogic.new()
		graph.name = cname
		graph.description = "Saved from the graph editor (Ctrl+G)."
	graph.graph_data = data
	graph.type = TYPE_FLOAT if str(data.get("output_type", "bool")) == "float" else TYPE_BOOL

	var err: Error = ResourceLibrary.save_resource(
		graph, ResourceLibrary.KIND_LOGIC, previous_path)
	if err == OK:
		EvaluationSystem.invalidate_expression(graph.id)
		BBEval.clear_states_tagged("glogic:%s@" % graph.id)
	return err


## Deletes the named graph from the catalog. References degrade to unknown
## (BBEval's missing-condition contract); behaviors whose owned condition
## is deleted show up in the designer as broken data, same as deleting any
## other referenced Logic.
func remove_condition(cname: String) -> void:
	var entry: ResourceLibrary.Entry = _find_entry(cname)
	if entry == null:
		return
	var doomed_id: String = str(entry.resource.get("id"))
	ResourceLibrary.delete_resource(entry)
	EvaluationSystem.invalidate_expression(doomed_id)
	BBEval.clear_states_tagged("glogic:%s@" % doomed_id)
#endregion


func _find(cname: String) -> GraphLogic:
	var entry: ResourceLibrary.Entry = _find_entry(cname)
	return entry.resource as GraphLogic if entry != null else null


func _find_entry(cname: String) -> ResourceLibrary.Entry:
	if cname.is_empty():
		return null
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		var graph: GraphLogic = entry.resource as GraphLogic
		if graph == null:
			continue
		if graph.name == cname or graph.id == cname:
			return entry
	return null
