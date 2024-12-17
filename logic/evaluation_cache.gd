class_name EvaluationCache
extends Resource

signal value_invalidated(expression_id: String)

## Cached values for expressions
var _values: Dictionary = {}
## Last evaluation timestamps
var _timestamps: Dictionary = {}
## Dependencies (dependent -> dependencies)
var _dependencies: Dictionary = {}
## Reverse dependencies (dependency -> dependents) for faster invalidation
var _reverse_dependencies: Dictionary = {}
var logger: Logger

func _init(entity_name: String) -> void:
	logger = Logger.new("evaluation_cache][" + entity_name, DebugLogger.Category.LOGIC)

func get_value(id: String) -> Variant:
	return _values.get(id)

func set_value(id: String, value: Variant) -> void:
	var old_value = _values.get(id)
	if old_value != value:  # Only update if value actually changed
		_values[id] = value
		_timestamps[id] = Time.get_unix_time_from_system()
		# Invalidate dependents since this value changed
		invalidate_dependents(id)

func needs_evaluation(id: String) -> bool:
	if id not in _values:
		return true
		
	var timestamp = _timestamps[id]
	for dep_id in _dependencies.get(id, []):
		if _timestamps.get(dep_id, 0) > timestamp:
			logger.debug("Expression %s needs update due to dependency %s" % [id, dep_id])
			return true
	return false

func add_dependency(dependent: String, dependency: String) -> void:
	# Add forward dependency
	if dependent not in _dependencies:
		_dependencies[dependent] = []
	if not dependency in _dependencies[dependent]:
		_dependencies[dependent].append(dependency)
	
	# Add reverse dependency for faster invalidation
	if dependency not in _reverse_dependencies:
		_reverse_dependencies[dependency] = []
	if not dependent in _reverse_dependencies[dependency]:
		_reverse_dependencies[dependency].append(dependent)
		
	logger.debug("Added dependency: %s depends on %s" % [dependent, dependency])

## Only invalidate the dependents of the changed value
func invalidate_dependents(id: String) -> void:
	var start_time := Time.get_ticks_msec()
	var visited := {}
	_invalidate_dependent_recursive(id, visited)
	
	var end_time := Time.get_ticks_msec()
	if visited.size() > 0:
		logger.trace("Invalidated %d dependent expressions in %d ms for %s" % [
			visited.size(),
			end_time - start_time,
			id
		])

func _invalidate_dependent_recursive(id: String, visited: Dictionary) -> void:
	# Don't invalidate the source value, only its dependents
	for dependent_id in _reverse_dependencies.get(id, []):
		if dependent_id in visited:
			continue
			
		visited[dependent_id] = true
		_values.erase(dependent_id)
		_timestamps.erase(dependent_id)
		value_invalidated.emit(dependent_id)
		
		# Continue up the dependency chain
		_invalidate_dependent_recursive(dependent_id, visited)

func remove_expression(id: String) -> void:
	_dependencies.erase(id)
	_values.erase(id)
	_timestamps.erase(id)
	
	# Clean up reverse dependencies
	for dep_id in _reverse_dependencies.get(id, []):
		var deps = _dependencies.get(dep_id, [])
		deps.erase(id)
		if deps.is_empty():
			_dependencies.erase(dep_id)
	
	_reverse_dependencies.erase(id)
	logger.trace("Removed expression %s from cache" % id)

func get_stats() -> Dictionary:
	return {
		"cached_values": _values.size(),
		"dependencies": _dependencies.size(),
		"reverse_dependencies": _reverse_dependencies.size()
	}
