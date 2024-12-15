class_name EvaluationCache
extends Resource

#region Properties
## Cached values for formulas
var _values: Dictionary = {}
## Last evaluation timestamps
var _timestamps: Dictionary = {}
## Dependencies between formulas
var _dependencies: Dictionary = {}
#endregion

func get_value(id: String) -> Variant:
	return _values.get(id)

func set_value(id: String, value: Variant) -> void:
	_values[id] = value
	_timestamps[id] = Time.get_unix_time_from_system()

func needs_evaluation(id: String) -> bool:
	if id not in _values:
		return true

	var timestamp = _timestamps[id]
	for dep_id in _dependencies.get(id, []):
		if _timestamps.get(dep_id, 0) > timestamp:
			return true

	return false

func add_dependency(dependent: String, dependency: String) -> void:
	if dependent not in _dependencies:
		_dependencies[dependent] = []
	_dependencies[dependent].append(dependency)

func invalidate(id: String) -> void:
	var visited = {}
	_invalidate_recursive(id, visited)

func _invalidate_recursive(id: String, visited: Dictionary) -> void:
	if id in visited:
		return

	visited[id] = true
	_values.erase(id)
	_timestamps.erase(id)

	for dependent_id in _get_dependents(id):
		_invalidate_recursive(dependent_id, visited)

func _get_dependents(id: String) -> Array:
	var dependents = []
	for formula_id in _dependencies:
		if id in _dependencies[formula_id]:
			dependents.append(formula_id)
	return dependents
