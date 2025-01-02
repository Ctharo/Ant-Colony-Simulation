class_name EvaluationCache
extends Node2D

signal value_invalidated(expression_id: String)

## Cached values for expressions
var _values: Dictionary = {}
## Last evaluation timestamps
var _timestamps: Dictionary = {}
## Dependencies (dependent -> dependencies)
var _dependencies: Dictionary = {}
## Map of expression ID to last update time
var _last_update_time: Dictionary = {}
## Track which expressions have changed this frame
var _changed_this_frame: Dictionary = {}
## Reverse dependencies (dependency -> dependents) for faster invalidation
var _reverse_dependencies: Dictionary = {}
var logger: Logger

func _init() -> void:
	logger = Logger.new("evaluation_cache", DebugLogger.Category.LOGIC)

func set_value(expression_id: String, value: Variant, trigger_dependencies: bool = true) -> void:
	var old_value = _values.get(expression_id)
	var has_changed = old_value != value

	if has_changed:
		logger.trace("Cache updated for %s: %s -> %s" % [expression_id, old_value, value])
		_values[expression_id] = value
		_last_update_time[expression_id] = Time.get_ticks_msec() / 1000.0
		_changed_this_frame[expression_id] = true
		if trigger_dependencies:
			invalidate_dependents(expression_id)

func has_value(expression_id: String) -> bool:
	return _values.has(expression_id)

func has_valid_value(expression_id: String) -> bool:
	return has_value(expression_id) and not _changed_this_frame.get(expression_id, false)

func get_value(expression_id: String) -> Variant:
	return _values.get(expression_id)

func needs_evaluation(expression_id: String) -> bool:
	return not _values.has(expression_id) or _changed_this_frame.get(expression_id, false)

func add_dependency(dependent: String, dependency: String) -> void:
	# Add forward dependency
	if dependent not in _dependencies:
		_dependencies[dependent] = []
	if not dependency in _dependencies[dependent]:
		_dependencies[dependent].append(dependency)
		logger.trace("Added forward dependency: [b]%s[/b] depends on [b]%s[/b]" % [dependent, dependency])

	# Add reverse dependency for faster invalidation
	if dependency not in _reverse_dependencies:
		_reverse_dependencies[dependency] = []
	if not dependent in _reverse_dependencies[dependency]:
		_reverse_dependencies[dependency].append(dependent)
		logger.trace("Added reverse dependency: [b]%s[/b] affects [b]%s[/b]" % [dependency, dependent])

## Only invalidate the dependents of the changed value
func invalidate_dependents(expression_id: String) -> void:
	if not _dependencies.has(expression_id):
		return

	var all_dependents = _dependencies[expression_id]
	var current_time = Time.get_ticks_msec() / 1000.0

	# Only invalidate dependents that haven't been updated recently
	var to_invalidate = []
	for dependent_id in all_dependents:
		var last_update = _last_update_time.get(dependent_id, 0.0)
		if current_time - last_update >= 0.05:  # 50ms threshold
			to_invalidate.append(dependent_id)

	if not to_invalidate.is_empty():
		logger.debug("Invalidated dependents for %s: %s" % [expression_id, to_invalidate])
		for dependent_id in to_invalidate:
			_values.erase(dependent_id)
			# Track that this dependent needs evaluation this frame
			_changed_this_frame[dependent_id] = true

## Clear the changed_this_frame tracking at the end of each frame
func clear_frame_changes() -> void:
	_changed_this_frame.clear()

## Get the time since last update for an expression
func time_since_update(expression_id: String) -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_update = _last_update_time.get(expression_id, 0.0)
	return current_time - last_update

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

func get_debug_info(id: String) -> Dictionary:
	return {
		"value": _values.get(id, null),
		"timestamp": _timestamps.get(id, 0),
		"dependencies": _dependencies.get(id, []),
		"reverse_dependencies": _reverse_dependencies.get(id, [])
	}

func get_stats() -> Dictionary:
	return {
		"cached_values": _values.size(),
		"dependencies": _dependencies.size(),
		"reverse_dependencies": _reverse_dependencies.size()
	}
