class_name EvaluationSystem
extends Node2D

#region Properties
## Evaluation controller for batching and rate limiting
@onready var _controller: EvaluationController = $EvaluationController
@onready var _cache: EvaluationCache = $EvaluationCache
var _registered_logic: Array[Logic] = []

## Map of expression resource ID to entity to state
var _states: Dictionary = {}
## Evaluation cache system
## Track last evaluation time for expressions
var _last_eval_time: Dictionary = {}
## Track last significant change time for expressions
var _last_change_time: Dictionary = {}


## Cache statistics tracker
var _stats: Dictionary = {}
## Entity for evaluations
var entity: Node
## Logger instance
var logger: Logger
## Performance monitoring enabled state
var _perf_monitor_enabled := false
## Threshold for logging slow evaluations (ms)
var _slow_threshold_ms := 1.0

#endregion

class ExpressionState:
	var expression: Expression
	var compiled_expression: String
	var logic: Logic  # Store reference to the Logic object
	var is_parsed: bool = false

	func _init(p_logic: Logic) -> void:
		expression = Expression.new()
		compiled_expression = p_logic.expression_string
		logic = p_logic

	func parse(variables: PackedStringArray) -> Error:
		if is_parsed:
			return OK

		# Check for unsafe access patterns
		var unsafe_patterns := [
			" _",  # Space followed by underscore
			"._",  # Dot followed by underscore
			"@",   # Direct property access
			"$/",  # Node path traversal
			"get_node",  # Node access
			" load",      # Resource loading
			" preload"    # Resource preloading
		]

		for pattern in unsafe_patterns:
			if compiled_expression.contains(pattern):
				push_error("Unsafe expression pattern detected: %s" % pattern)
				return ERR_UNAUTHORIZED

		# Validate variables don't contain unsafe patterns
		for var_name in variables:
			for pattern in unsafe_patterns:
				if var_name.contains(pattern):
					push_error("Unsafe variable name detected: %s" % var_name)
					return ERR_UNAUTHORIZED

		var error = expression.parse(compiled_expression, variables)
		is_parsed = error == OK
		return error

	func execute(bindings: Array, context: Object) -> Variant:
		if not is_parsed:
			return null
		return expression.execute(bindings, context)

	func has_error() -> bool:
		return expression.has_execute_failed()

#region Cache Statistics Structure
class ExpressionStats:
	var hits: int = 0
	var misses: int = 0

	func get_hit_rate() -> float:
		var total = hits + misses
		return 100.0 * hits / total if total > 0 else 0.0

	func to_dictionary() -> Dictionary:
		return {
			"hits": hits,
			"misses": misses,
			"hit_rate": get_hit_rate()
		}
#endregion

#region Initialization
func _init() -> void:
	logger = Logger.new("eval", DebugLogger.Category.LOGIC)

func _process(_delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Check all registered logic for evaluation needs
	for logic in _registered_logic:
		if not logic.should_evaluate(current_time):
			continue

		if logic.needs_immediate_eval():
			_controller.queue_high_priority(logic.id)
		elif logic.can_eval_when_idle():
			_controller.queue_idle_priority(logic.id)
		else:
			_controller.queue_normal_priority(logic.id)

	# Let controller handle actual evaluations
	_controller.process_evaluations()

func initialize(p_entity: Node) -> void:
	entity = p_entity

func get_or_create_state(expression: Logic) -> ExpressionState:
	if expression.id.is_empty():
		logger.error("Expression has empty ID: %s" % expression)
		return null

	if not _states.has(expression.id):
		_states[expression.id] = ExpressionState.new(expression)
		_registered_logic.append(expression)


	return _states[expression.id]

func register_expression(expression: Logic) -> void:
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	logger.trace("Expression details: string=%s, always_eval=%s, nested=%s" % [
		expression.expression_string,
		expression.always_evaluate,
		expression.nested_expressions
	])

	# Create and parse state
	var state := get_or_create_state(expression)
	if not state:
		return

	if not state.is_parsed:
		_parse_expression(expression)

	# Register nested expressions and dependencies
	for nested in expression.nested_expressions:
		if nested == null:
			logger.error("Cannot register null nested expression")
			return

		logger.trace("Registering nested expression %s for %s" % [
			nested.id,
			expression.id
		])
		register_expression(nested)
		_cache.add_dependency(expression.id, nested.id)

	logger.trace("Completed registration of %s" % expression.id)

func get_value(expression: Logic, force_update: bool = false) -> Variant:

	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = _last_eval_time.get(expression.id, 0.0)
	var last_change = _last_change_time.get(expression.id, 0.0)
	var time_since_eval = current_time - last_time

	# Check if we can use cached value
	if _cache.has_value(expression.id) and not force_update:
		# Handle immediate evaluation needs
		if expression.needs_immediate_eval():
			if time_since_eval < expression.max_eval_interval:
				return _cache.get_value(expression.id)
		# Handle lazy evaluation
		elif expression.is_lazy_evaluated():
			if not _have_dependencies_changed(expression, last_change):
				return _cache.get_value(expression.id)
		# Handle normal evaluation
		elif time_since_eval < expression.min_eval_interval:
			return _cache.get_value(expression.id)

	# Calculate new value
	_last_eval_time[expression.id] = current_time
	var result = _calculate(expression.id)

	# Update cache if value changed significantly
	var old_value = _cache.get_value(expression.id)
	if expression._is_significant_change(old_value, result):
		_last_change_time[expression.id] = current_time
		_cache.set_value(expression.id, result)
		logger.trace("Value changed significantly")
	else:
		_cache.set_value(expression.id, result, false)  # Update without triggering dependencies
		logger.trace("Value updated (not significant)")

	expression.mark_evaluated()
	return result

func _have_dependencies_changed(expression: Logic, since_time: float) -> bool:
	for nested in expression.nested_expressions:
		var dep_last_change = _last_change_time.get(nested.id, 0.0)
		if dep_last_change > since_time:
			logger.trace("Dependency %s changed since last eval" % nested.id)
			return true
	return false

func _has_always_evaluate_dependency(expression: Logic) -> bool:
	logger.trace("Checking for always_evaluate dependencies in %s" % expression.id)

	# Cache the result for this frame
	var cache_key = "_always_eval_deps_" + expression.id
	if _cache.has_value(cache_key):
		return _cache.get_value(cache_key)

	var has_always_eval = false
	for nested in expression.nested_expressions:
		if nested.always_evaluate:
			logger.trace("Found always_evaluate dependency: %s" % nested.id)
			has_always_eval = true
			break
		if _has_always_evaluate_dependency(nested):
			logger.trace("Found nested always_evaluate dependency in %s" % nested.id)
			has_always_eval = true
			break

	if not has_always_eval:
		logger.trace("No nested always_evaluate dependency found in %s" % expression.id)

	# Cache the result
	_cache.set_value(cache_key, has_always_eval)
	return has_always_eval

func _parse_expression(expression: Logic) -> void:
	var state := get_or_create_state(expression)
	if state.is_parsed or expression.expression_string.is_empty():
		return

	var variable_names = []
	for nested in expression.nested_expressions:
		if nested.name.is_empty():
			logger.error("Nested expression missing name: %s" % nested)
			return
		if nested.id.is_empty():
			logger.error("Nested expression missing ID (should be generated from name): %s" % nested)
			return
		variable_names.append(nested.id)

	if expression.id not in DebugLogger.parsed_expression_strings:
		if logger.is_debug_enabled():
			logger.debug("Parsing expression %s%s" % [
				expression.id,
				" with variables: %s" % str(variable_names) if variable_names else ""
			])
		DebugLogger.parsed_expression_strings.append(expression.id)

	var error = state.parse(PackedStringArray(variable_names))
	if error != OK:
		logger.error('Failed to parse expression "%s": %s' % [expression.name, expression.expression_string])
		return

func _calculate(expression_id: String) -> Variant:
	var start_time := 0.0
	if _perf_monitor_enabled and logger.is_debug_enabled():
		start_time = Time.get_ticks_usec()

	var state: ExpressionState = _states[expression_id]
	if not state.is_parsed:
		return null

	logger.trace("Calculating %s" % expression_id)

	# Get values from nested expressions
	var bindings = []
	for nested in state.logic.nested_expressions:
		logger.trace("Getting nested value for %s" % nested.id)
		var force = nested.always_evaluate
		var value = get_value(nested, force)
		bindings.append(value)
		logger.trace("Nested %s = %s" % [nested.id, value])

	var result = state.execute(bindings, entity)

	if state.has_error():
		logger.error('Expression execution failed: id=%s expr="%s"' % [
			expression_id,
			state.compiled_expression
		])
		return null

	if _perf_monitor_enabled and logger.is_debug_enabled():
		var duration = (Time.get_ticks_usec() - start_time) / 1000.0
		if duration > _slow_threshold_ms:
			logger.warn("Slow expression calculation: id=%s duration=%.2fms" % [
				expression_id,
				duration
			])

	if logger.is_debug_enabled():
		logger.debug("Final result for %s = %s" % [expression_id, result])

	return result

## Get cache statistics for a specific expression
func get_expression_stats(id: String) -> Dictionary:
	if id in _stats:
		return _stats[id].to_dictionary()
	return {}

## Get cache statistics for all expressions
func get_cache_stats() -> Dictionary:
	var total_hits := 0
	var total_misses := 0
	var expression_stats := {}

	for id in _stats:
		var stats = _stats[id]
		total_hits += stats.hits
		total_misses += stats.misses
		expression_stats[id] = stats.to_dictionary()

	var total = total_hits + total_misses
	var overall_hit_rate = 100.0 * total_hits / total if total > 0 else 0.0

	return {
		"overall": {
			"hits": total_hits,
			"misses": total_misses,
			"hit_rate": overall_hit_rate
		},
		"expressions": expression_stats
	}
#endregion

#region Signal Handlers
## Handle value changes in expressions
func _on_expression_value_changed(_value: Variant, expression_id: String) -> void:
	_cache.invalidate_dependents(expression_id)

func _on_expression_dependencies_changed(expression_id: String) -> void:
	_cache.invalidate_dependents(expression_id)
#endregion
