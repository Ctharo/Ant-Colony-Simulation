class_name EvaluationSystem
extends Node

#region Properties
## Map of expression resource ID to entity to state
var _states: Dictionary = {}
## Evaluation cache system
var _cache: EvaluationCache
## Cache statistics tracker
var _stats: Dictionary = {}
## Entity for evaluations
var entity: Node
## Logger instance
var logger: Logger

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
	logger = Logger.new("evaluation_system", DebugLogger.Category.LOGIC)

func initialize(p_entity: Node) -> void:
	entity = p_entity
	logger = Logger.new("evaluation_system][" + entity.name, DebugLogger.Category.LOGIC)
	_cache = EvaluationCache.new(entity.name)

func get_or_create_state(expression: Logic) -> ExpressionState:
	if expression.id.is_empty():
		push_error("Expression has empty ID: %s" % expression)
		return null

	if not _states.has(expression.id):
		_states[expression.id] = ExpressionState.new(expression)

	return _states[expression.id]

func register_expression(expression: Logic) -> void:
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	logger.debug("=== Registering expression [b]%s[/b] ===" % expression.id)
	logger.trace("- Expression string: %s" % expression.expression_string)
	logger.trace("- Always evaluate: %s" % expression.always_evaluate)
	logger.trace("- Nested expressions: %s" % str(expression.nested_expressions))

	# Create and parse state
	var state := get_or_create_state(expression)
	if not state:
		return

	if not state.is_parsed:
		_parse_expression(expression)

	# Register nested expressions and dependencies
	for nested in expression.nested_expressions:
		if nested == null:
			push_error("Cannot register null nested expression")
			return

		logger.trace("- Registering nested expression [b]%s[/b] for [b]%s[/b]" % [
			nested.id,
			expression.id
		])
		register_expression(nested)
		_cache.add_dependency(expression.id, nested.id)

	logger.debug("=== Completed registration of [b]%s[/b] ===" % expression.id)

func get_value(expression: Logic, force_update: bool = false) -> Variant:
	assert(expression != null and not expression.id.is_empty())

	logger.trace("Getting value for [b]%s[/b]" % expression.id)

	# For always_evaluate expressions (no nested dependencies)
	if expression.always_evaluate:
		logger.trace("- Direct always_evaluate expression")
		var result = _calculate(expression.id)
		var old_value = _cache.get_value(expression.id)

		if old_value != result:
			logger.trace("- Value changed: %s -> %s" % [old_value, result])
			_cache.set_value(expression.id, result)
		return result

	# Check if this expression has any always_evaluate dependencies
	var has_always_eval_dep = _has_always_evaluate_dependency(expression)
	if has_always_eval_dep:
		logger.trace("- Has always_evaluate dependency, forcing calculation")
		var result = _calculate(expression.id)
		_cache.set_value(expression.id, result)
		return result

	# Regular cached evaluation
	if force_update or _cache.needs_evaluation(expression.id):
		var result = _calculate(expression.id)
		_cache.set_value(expression.id, result)
		return result

	return _cache.get_value(expression.id)

func _has_always_evaluate_dependency(expression: Logic) -> bool:
	logger.trace("Checking for always_evaluate dependencies in [b]%s[/b]" % expression.id)
	for nested in expression.nested_expressions:
		if nested.always_evaluate:
			logger.trace("- Found always_evaluate dependency: [b]%s[/b]" % nested.id)
			return true
		if _has_always_evaluate_dependency(nested):
			logger.trace("- Found nested always_evaluate dependency in [b]%s[/b]" % nested.id)
			return true
	return false

func _parse_expression(expression: Logic) -> void:
	var state := get_or_create_state(expression)
	if state.is_parsed or expression.expression_string.is_empty():
		return

	var variable_names = []
	for nested in expression.nested_expressions:
		if nested.name.is_empty():
			push_error("Nested expression missing name: %s" % nested)
			return
		if nested.id.is_empty():
			push_error("Nested expression missing ID (should be generated from name): %s" % nested)
			return
		variable_names.append(nested.id)

	if expression.id not in DebugLogger.parsed_expression_strings:
		DebugLogger.debug(
			DebugLogger.Category.LOGIC,
			"Parsing expression [b]%s[/b]%s" % [
				expression.id,
				" with variables: %s" % str(variable_names) if variable_names else ""
			]
		)
		DebugLogger.parsed_expression_strings.append(expression.id)

	var error = state.parse(PackedStringArray(variable_names))
	if error != OK:
		push_error('Failed to parse expression "%s": %s' % [expression.name, expression.expression_string])
		return

func _calculate(expression_id: String) -> Variant:
	var state: ExpressionState = _states[expression_id]
	if not state.is_parsed:
		return null

	logger.trace("Calculating [b]%s[/b]" % expression_id)

	# Get values from nested expressions
	var bindings = []
	for nested in state.logic.nested_expressions:
		logger.trace("- Getting nested value for [b]%s[/b]" % nested.id)
		# Pass force_update=true if this is an always_evaluate expression
		var force = nested.always_evaluate
		var value = get_value(nested, force)
		bindings.append(value)
		logger.trace("- Nested [b]%s[/b] = %s" % [nested.id, value])

	var result = state.execute(bindings, entity)
	if state.has_error():
		push_error('Failed to execute expression: "%s"' % state.compiled_expression)
		return null

	logger.debug("- Final result for [b]%s[/b] = %s" % [expression_id, result])
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
