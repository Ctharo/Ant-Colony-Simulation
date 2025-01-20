class_name EvaluationSystem
extends Node2D

#region Properties
## Evaluation controller for batching and rate limiting
@onready var _controller: EvaluationController = $EvaluationController


## Map of expression resource ID to evaluation state
var _states: Dictionary = {}

## Entity for evaluations
var entity: Node

## Logger instance
var logger: Logger

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
#endregion

#region Initialization
func _init() -> void:
	logger = Logger.new("eval", DebugLogger.Category.LOGIC)

func initialize(p_entity: Node) -> void:
	entity = p_entity
	if not _controller:
		_controller = EvaluationController.new()


func get_or_create_state(expression: Logic) -> ExpressionState:
	if expression.id.is_empty():
		logger.error("Expression has empty ID: %s" % expression)
		return null

	if not _states.has(expression.id):
		_states[expression.id] = ExpressionState.new(expression)
		
	return _states[expression.id]

func register_expression(expression: Logic) -> void:
	# Generate ID if needed
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	# Create state (parsing will be done lazily when needed)
	var state := get_or_create_state(expression)
	if not state:
		logger.error("Failed to create state for expression %s" % expression.id)
		return

	# Register nested expressions and their dependencies
	for nested in expression.nested_expressions:
		register_expression(nested)

	logger.trace("Completed registration of %s" % expression.id)
#endregion

#region Expression Evaluation
func get_value(expression: Logic) -> Variant:
	# Lazy registration and parsing if needed
	if not _states.has(expression.id):
		logger.trace("Auto-registering expression %s" % expression.id)
		register_expression(expression)
	
	# Get expression state if available
	var state: ExpressionState = _states[expression.id]
	if not state:
		logger.error("Failed to get/create state for expression %s" % expression.id)
		return null
		
	# Lazy parsing if needed
	if not state.is_parsed:
		_parse_expression(expression)
	
	# Calculate new value
	var result = _calculate(expression.id)
	
	
	return result


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
		var value = get_value(nested)
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
#endregion
