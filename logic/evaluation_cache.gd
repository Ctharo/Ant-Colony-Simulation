class_name EvaluationCache
extends Node2D

<<<<<<< HEAD
#region Properties
signal value_invalidated(expression_id: String)

=======
signal value_invalidated(expression_id: String)

## Cached values for expressions
>>>>>>> parent of 1272e56 (Many updates - removed influence)
var _values: Dictionary = {}
## Last evaluation timestamps
var _timestamps: Dictionary = {}
<<<<<<< HEAD
var _dependencies: Dictionary = {}
var _reverse_dependencies: Dictionary = {}
var _changed_this_frame: Dictionary = {}
var _invalidation_count: Dictionary = {}
var _last_invalidation_time: Dictionary = {}
var _valid_flags: Dictionary = {}  # New: Track validity of cached values

var logger: Logger

const MIN_INVALIDATION_INTERVAL := 0.05
#endregion

func _init() -> void:
	logger = Logger.new("evaluation_cache", DebugLogger.Category.LOGIC)

#region Cache Operations
=======
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

>>>>>>> parent of 1272e56 (Many updates - removed influence)
func set_value(expression_id: String, value: Variant, trigger_dependencies: bool = true) -> void:
	var old_value = _values.get(expression_id)
	var has_changed = old_value != value

<<<<<<< HEAD
	_values[expression_id] = value
	_timestamps[expression_id] = Time.get_ticks_msec() / 1000.0
	_valid_flags[expression_id] = true  # Mark as valid when set

	if has_changed and trigger_dependencies:
		_changed_this_frame[expression_id] = true
		logger.trace("Value changed for %s, triggering dependencies" % expression_id)
		invalidate_dependents(expression_id)
=======
	if has_changed:
		logger.trace("Cache updated for %s: %s -> %s" % [expression_id, old_value, value])
		_values[expression_id] = value
		_last_update_time[expression_id] = Time.get_ticks_msec() / 1000.0
		_changed_this_frame[expression_id] = true
		if trigger_dependencies:
			invalidate_dependents(expression_id)
>>>>>>> parent of 1272e56 (Many updates - removed influence)

func has_value(expression_id: String) -> bool:
	return _values.has(expression_id) and _valid_flags.get(expression_id, false)

func has_valid_value(expression_id: String) -> bool:
	return has_value(expression_id) and not _changed_this_frame.get(expression_id, false)

func get_value(expression_id: String) -> Variant:
	return _values.get(expression_id)

<<<<<<< HEAD
func needs_update(expression_id: String) -> bool:
	return not has_valid_value(expression_id)

func invalidate_value(expression_id: String) -> void:
	_valid_flags[expression_id] = false
	_changed_this_frame[expression_id] = true
	value_invalidated.emit(expression_id)
	logger.trace("Invalidated value for %s" % expression_id)
#endregion

#region Dependency Management
func add_dependency(dependent: String, dependency: String) -> void:
	if not _dependencies.has(dependent):
=======
func needs_evaluation(expression_id: String) -> bool:
	return not _values.has(expression_id) or _changed_this_frame.get(expression_id, false)

func add_dependency(dependent: String, dependency: String) -> void:
	# Add forward dependency
	if dependent not in _dependencies:
>>>>>>> parent of 1272e56 (Many updates - removed influence)
		_dependencies[dependent] = []
	if not dependency in _dependencies[dependent]:
		_dependencies[dependent].append(dependency)
		logger.trace("Added forward dependency: [b]%s[/b] depends on [b]%s[/b]" % [dependent, dependency])

<<<<<<< HEAD
	if not _reverse_dependencies.has(dependency):
=======
	# Add reverse dependency for faster invalidation
	if dependency not in _reverse_dependencies:
>>>>>>> parent of 1272e56 (Many updates - removed influence)
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

<<<<<<< HEAD
func get_dependents(expression_id: String) -> Array:
	return _reverse_dependencies.get(expression_id, []).duplicate()

func get_dependencies(expression_id: String) -> Array:
	return _dependencies.get(expression_id, []).duplicate()

=======
>>>>>>> parent of 1272e56 (Many updates - removed influence)
func remove_expression(id: String) -> void:
	_dependencies.erase(id)
	_values.erase(id)
	_timestamps.erase(id)
<<<<<<< HEAD
	_changed_this_frame.erase(id)
	_valid_flags.erase(id)

	if _reverse_dependencies.has(id):
		for dependent in _reverse_dependencies[id]:
			var deps = _dependencies.get(dependent, [])
			deps.erase(id)
			if deps.is_empty():
				_dependencies.erase(dependent)
		_reverse_dependencies.erase(id)
=======

	# Clean up reverse dependencies
	for dep_id in _reverse_dependencies.get(id, []):
		var deps = _dependencies.get(dep_id, [])
		deps.erase(id)
		if deps.is_empty():
			_dependencies.erase(dep_id)
>>>>>>> parent of 1272e56 (Many updates - removed influence)

	_reverse_dependencies.erase(id)
	logger.trace("Removed expression %s from cache" % id)

<<<<<<< HEAD
#region Invalidation
func invalidate_dependents(expression_id: String) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = _last_invalidation_time.get(expression_id, 0.0)

	if current_time - last_time < MIN_INVALIDATION_INTERVAL:
		logger.trace("Skipping invalidation for %s due to rate limiting" % expression_id)
		return

	_invalidate_dependents(expression_id)
	_last_invalidation_time[expression_id] = current_time

func _invalidate_dependents(expression_id: String) -> void:
	if not _reverse_dependencies.has(expression_id):
		return

	var dependents = _reverse_dependencies[expression_id]
	for dependent_id in dependents:
		_valid_flags[dependent_id] = false
		_changed_this_frame[dependent_id] = true
		value_invalidated.emit(dependent_id)
		logger.trace("Invalidated dependent %s due to change in %s" % [dependent_id, expression_id])

		# Cascade invalidation to higher-level dependents
		_invalidate_dependents(dependent_id)

func clear_frame_changes() -> void:
	_changed_this_frame.clear()
#endregion
=======
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
>>>>>>> parent of 1272e56 (Many updates - removed influence)
