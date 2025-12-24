extends Node

#region Properties
## Evaluation controller for batching and rate limiting
@onready var _controller: EvaluationController

## Dictionary mapping entity instance IDs to their expression states
## Structure: { entity_id: { expression_id: ExpressionState } }
var _entity_states: Dictionary = {}
var _evaluation_cache: Dictionary = {}
const CACHE_TTL = 0.5

## Logger instance
var logger: iLogger

## Performance monitoring enabled state
var _perf_monitor_enabled := false

## Threshold for logging slow evaluations (ms)
var _slow_threshold_ms := 1.0
#endregion

#region Expression State
class ExpressionState:
	var expression: Expression
	var compiled_expression: String
	var logic: Logic  # Store reference to the Logic object
	var is_parsed: bool = false
	var entity_context: Node  # Store reference to the entity context

	func _init(p_logic: Logic, p_entity: Node) -> void:
		expression = Expression.new()
		compiled_expression = p_logic.expression_string
		logic = p_logic
		entity_context = p_entity

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

	func execute(bindings: Array) -> Variant:
		if not is_parsed:
			return null
		return expression.execute(bindings, entity_context)

	func has_error() -> bool:
		return expression.has_execute_failed()
#endregion

#region Initialization
func _init() -> void:
	logger = iLogger.new("expr_mgr", DebugLogger.Category.LOGIC)
	_controller = EvaluationController.new()

## Gets or creates the state dictionary for an entity
func _get_entity_states(entity: Node) -> Dictionary:
	var entity_id := str(entity.get_instance_id())
	if not _entity_states.has(entity_id):
		_entity_states[entity_id] = {}
	return _entity_states[entity_id]

## Gets or creates an expression state for a specific entity
func _get_or_create_state(expression: Logic, entity: Node) -> ExpressionState:
	if expression.id.is_empty():
		logger.error("Expression has empty ID: %s" % expression)
		return null

	var states := _get_entity_states(entity)
	if not states.has(expression.id):
		states[expression.id] = ExpressionState.new(expression, entity)

	return states[expression.id]

## Registers an expression for a specific entity context
func register_expression(expression: Logic, entity: Node) -> void:
	# Generate ID if needed
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	# Create state (parsing will be done lazily when needed)
	var state := _get_or_create_state(expression, entity)
	if not state:
		logger.error("Failed to create state for expression %s" % expression.id)
		return

	# Register nested expressions and their dependencies
	for nested in expression.nested_expressions:
		register_expression(nested, entity)

	logger.trace("Completed registration of %s for entity %s" % [
		expression.id,
		entity.name
	])
#endregion

#region Expression Evaluation
## Gets the value of an expression in the context of a specific entity
func get_value(expression: Logic, entity: Node) -> Variant:
	# Lazy registration and parsing if needed
	var states := _get_entity_states(entity)
	if not states.has(expression.id):
		logger.trace("Auto-registering expression %s for entity %s" % [
			expression.id,
			entity.name
		])
		register_expression(expression, entity)

	# Get expression state if available
	var state: ExpressionState = states[expression.id]
	if not state:
		logger.error("Failed to get/create state for expression %s" % expression.id)
		return null

	# Lazy parsing if needed
	if not state.is_parsed:
		_parse_expression(expression, entity)

	# Calculate new value
	var result = _calculate(expression.id, entity)
	return result

func _parse_expression(expression: Logic, entity: Node) -> void:
	var state := _get_or_create_state(expression, entity)
	if state.is_parsed or expression.expression_string.is_empty():
		return

	var variable_names = []
	for nested in expression.nested_expressions:
		if nested.name.is_empty():
			logger.error("Nested expression missing name: %s" % nested)
			return
		if nested.id.is_empty():
			logger.error("Nested expression missing ID: %s" % nested)
			return
		variable_names.append(nested.id)

	if expression.id not in DebugLogger.parsed_expression_strings:
		if logger.is_debug_enabled():
			logger.debug("Parsing expression %s%s for entity %s" % [
				expression.id,
				" with variables: %s" % str(variable_names) if variable_names else "",
				entity.name
			])
		DebugLogger.parsed_expression_strings.append(expression.id)

	var error = state.parse(PackedStringArray(variable_names))
	if error != OK:
		logger.error('Failed to parse expression "%s": %s' % [
			expression.name,
			expression.expression_string
		])
		return

func _calculate(expression_id: String, entity: Node) -> Variant:
	var cache_key = "%s_%s" % [expression_id, entity.get_instance_id()]

	# Check cache
	if _evaluation_cache.has(cache_key):
		var cache_entry = _evaluation_cache[cache_key]
		if Time.get_ticks_msec() - cache_entry.timestamp < CACHE_TTL:
			return cache_entry.value

	var start_time := 0.0
	if _perf_monitor_enabled and logger.is_debug_enabled():
		start_time = Time.get_ticks_usec()

	var states := _get_entity_states(entity)
	var state: ExpressionState = states[expression_id]
	if not state.is_parsed:
		return null

	logger.trace("Calculating %s for entity %s" % [expression_id, entity.name])

	# Get values from nested expressions
	var bindings = []
	for nested in state.logic.nested_expressions:
		logger.trace("Getting nested value for %s" % nested.id)
		var value = get_value(nested, entity)
		bindings.append(value)
		logger.trace("Nested %s = %s" % [nested.id, value])

	var result = state.execute(bindings)

	if state.has_error():
		logger.error('Expression execution failed: id=%s expr="%s" entity=%s' % [
			expression_id,
			state.compiled_expression,
			entity.name
		])
		return null

	if _perf_monitor_enabled and logger.is_debug_enabled():
		var duration = (Time.get_ticks_usec() - start_time) / 1000.0
		if duration > _slow_threshold_ms:
			logger.warn("Slow expression calculation: id=%s entity=%s duration=%.2fms" % [
				expression_id,
				entity.name,
				duration
			])

	if logger.is_debug_enabled():
		logger.debug("Final result for %s (entity %s) = %s" % [
			expression_id,
			entity.name,
			result
		])

	# Store in cache
	_evaluation_cache[cache_key] = {
		"value": result,
		"timestamp": Time.get_ticks_msec()
	}

	return result
#endregion

#region Cleanup
## Cleans up expression states for an entity when it's no longer needed
func cleanup_entity(entity: Node) -> void:
	var entity_id := str(entity.get_instance_id())
	if _entity_states.has(entity_id):
		_entity_states.erase(entity_id)
		logger.debug("Cleaned up expression states for entity %s" % entity.name)
#endregion
