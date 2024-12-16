class_name EvaluationCache
extends Resource

signal value_invalidated(expression_id: String)

#region Properties
## Cached values for expressions
var _values: Dictionary = {}
## Last evaluation timestamps
var _timestamps: Dictionary = {}
## Dependencies between expressions (dependent -> dependencies)
var _dependencies: Dictionary = {}
## Reverse dependencies lookup (dependency -> dependents)
var _reverse_dependencies: Dictionary = {}

var logger: Logger
#endregion

func _init(entity_name: String) -> void:
	logger = Logger.new("evaluation_cache][" + entity_name, DebugLogger.Category.LOGIC)

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

func invalidate(id: String) -> void:
	var start_time := Time.get_ticks_msec()
	var visited := {}
	_invalidate_recursive(id, visited)
	
	var end_time := Time.get_ticks_msec()
	if visited.size() > 1:  # Only log if we invalidated more than just the target
		logger.trace("Invalidated %d expressions in %d ms starting from %s" % [
			visited.size(),
			end_time - start_time,
			id
		])
	elif visited.size() == 1:
		logger.trace("Invalidated expression %s" % 	id)
	else:
		pass
func _invalidate_recursive(id: String, visited: Dictionary) -> void:
	if id in visited:
		return
		
	visited[id] = true
	_values.erase(id)
	_timestamps.erase(id)
	
	# Use reverse dependencies for faster lookup
	for dependent_id in _reverse_dependencies.get(id, []):
		_invalidate_recursive(dependent_id, visited)
	
	value_invalidated.emit(id)

## Get all expressions that depend on the given expression
func get_dependents(id: String) -> Array:
	return _reverse_dependencies.get(id, []).duplicate()

## Remove an expression and all its dependencies from the cache
func remove_expression(id: String) -> void:
	# Clean up forward dependencies
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

## Get current cache statistics
func get_stats() -> Dictionary:
	return {
		"cached_values": _values.size(),
		"dependencies": _dependencies.size(),
		"reverse_dependencies": _reverse_dependencies.size()
	}
