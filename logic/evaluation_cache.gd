class_name EvaluationCache
extends Node2D

#region Properties
## Signal when a value is invalidated
signal value_invalidated(expression_id: String)

## Core cache data
var _values: Dictionary = {}
var _timestamps: Dictionary = {}

## Dependencies tracking
var _dependencies: Dictionary = {}
var _reverse_dependencies: Dictionary = {}

## Frame state tracking
var _changed_this_frame: Dictionary = {}

## Performance tracking
var _invalidation_count: Dictionary = {}
var _last_invalidation_time: Dictionary = {}

## Logging
var logger: Logger

## Minimum time between invalidations (seconds)
const MIN_INVALIDATION_INTERVAL := 0.05  # 50ms
#endregion

func _init() -> void:
	logger = Logger.new("evaluation_cache", DebugLogger.Category.LOGIC)

#region Cache Operations
## Set a cached value and handle dependency updates
func set_value(expression_id: String, value: Variant, trigger_dependencies: bool = true) -> void:
	var old_value = _values.get(expression_id)
	var has_changed = old_value != value

	_values[expression_id] = value  # Always update the value
	_timestamps[expression_id] = Time.get_ticks_msec() / 1000.0

	if has_changed and trigger_dependencies:
		_changed_this_frame[expression_id] = true
		invalidate_dependents(expression_id)

## Check if a value exists in cache
func has_value(expression_id: String) -> bool:
	return _values.has(expression_id)

## Get a cached value
func get_value(expression_id: String) -> Variant:
	return _values.get(expression_id)

## Check if an expression needs evaluation
func needs_evaluation(expression_id: String) -> bool:
	return not _values.has(expression_id) or _changed_this_frame.get(expression_id, false)

## Get time since last update
func time_since_update(expression_id: String) -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_update = _timestamps.get(expression_id, 0.0)
	return current_time - last_update
#endregion

#region Dependency Management
## Add a dependency relationship between expressions
func add_dependency(dependent: String, dependency: String) -> void:
	# Add forward dependency
	if not _dependencies.has(dependent):
		_dependencies[dependent] = []
	if not dependency in _dependencies[dependent]:
		_dependencies[dependent].append(dependency)
		logger.trace("Added forward dependency: %s depends on %s" % [dependent, dependency])

	# Add reverse dependency for faster invalidation
	if not _reverse_dependencies.has(dependency):
		_reverse_dependencies[dependency] = []
	if not dependent in _reverse_dependencies[dependency]:
		_reverse_dependencies[dependency].append(dependent)
		logger.trace("Added reverse dependency: %s affects %s" % [dependency, dependent])

## Remove an expression and its dependencies
func remove_expression(id: String) -> void:
	# Clean up dependencies
	_dependencies.erase(id)
	_values.erase(id)
	_timestamps.erase(id)
	_changed_this_frame.erase(id)

	# Clean up reverse dependencies
	if _reverse_dependencies.has(id):
		for dependent in _reverse_dependencies[id]:
			var deps = _dependencies.get(dependent, [])
			deps.erase(id)
			if deps.is_empty():
				_dependencies.erase(dependent)
		_reverse_dependencies.erase(id)

	logger.trace("Removed expression %s and its dependencies" % id)
#endregion

#region Invalidation
## Invalidate dependents of a changed value with rate limiting
func invalidate_dependents(expression_id: String) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Check if enough time has passed since last invalidation
	var last_time = _last_invalidation_time.get(expression_id, 0.0)
	if current_time - last_time < MIN_INVALIDATION_INTERVAL:
		return

	_invalidate_dependents(expression_id)
	_last_invalidation_time[expression_id] = current_time

## Internal invalidation implementation
func _invalidate_dependents(expression_id: String) -> void:
	if not _reverse_dependencies.has(expression_id):
		return

	var to_invalidate = []
	var current_time = Time.get_ticks_msec() / 1000.0
	var dependents = _reverse_dependencies[expression_id]

	# Only invalidate if enough time has passed and change is significant
	for dependent_id in dependents:
		# Don't clear the value, just mark it for re-evaluation
		_changed_this_frame[dependent_id] = true
		value_invalidated.emit(dependent_id)

## Clear frame change tracking
func clear_frame_changes() -> void:
	_changed_this_frame.clear()
#endregion

#region Debug and Statistics
## Get debug information for an expression
func get_debug_info(id: String) -> Dictionary:
	return {
		"value": _values.get(id, null),
		"last_update": _timestamps.get(id, 0.0),
		"dependencies": _dependencies.get(id, []),
		"reverse_dependencies": _reverse_dependencies.get(id, []),
		"invalidation_count": _invalidation_count.get(id, 0),
		"changed_this_frame": _changed_this_frame.get(id, false)
	}

## Get cache statistics
func get_stats() -> Dictionary:
	var total_invalidations = 0
	for count in _invalidation_count.values():
		total_invalidations += count

	return {
		"cached_values": _values.size(),
		"dependencies": _dependencies.size(),
		"reverse_dependencies": _reverse_dependencies.size(),
		"total_invalidations": total_invalidations,
		"changed_this_frame": _changed_this_frame.size()
	}
#endregion
