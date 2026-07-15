class_name BBConditionLibrary
extends RefCounted
## Named, reusable conditions. Each entry is a serialized subgraph:
## { nodes: [{id, type, params, in_count, pos}], connections: [...], output_id, name }
## Conditions can reference other conditions by name (nesting). Persisted to user://.

signal changed

const SAVE_PATH := "user://behavior_conditions.json"

var conditions := {}


func save_condition(cname: String, data: Dictionary) -> void:
	conditions[cname] = data
	_persist()
	changed.emit()


func remove_condition(cname: String) -> void:
	if conditions.erase(cname):
		_persist()
		changed.emit()


func has_condition(cname: String) -> bool:
	return conditions.has(cname)


func get_condition(cname: String) -> Variant:
	return conditions.get(cname)


func names() -> Array:
	var k := conditions.keys()
	k.sort()
	return k


func export_json() -> String:
	return JSON.stringify(conditions, "  ")


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		conditions = parsed


func _persist() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(conditions, "  "))
