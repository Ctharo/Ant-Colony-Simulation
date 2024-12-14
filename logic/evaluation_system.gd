class_name EvaluationSystem
extends Node

class ExpressionState:
	var expression: Expression
	var is_parsed: bool = false
	var logic_expression: Logic  # Store reference to Logic resource

	func _init(p_logic: Logic) -> void:
		expression = Expression.new()
		logic_expression = p_logic

#region Properties
# Map of expression resource ID to entity to state
var _states: Dictionary = {}
## Evaluation cache system
var _cache: EvaluationCache = EvaluationCache.new()
## Cache statistics tracker
var _stats: Dictionary = {}
## Entity for evaluations
var entity: Node
## Logger instance
var logger: Logger

#endregion

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

## Initialize the evaluation system with a base node
func initialize(p_entity: Node) -> void:
	entity = p_entity
#endregion

func get_or_create_state(expression: Logic) -> ExpressionState:
	if expression.id.is_empty():
		push_error("Expression has empty ID: %s" % expression)
		return null
		
	if not _states.has(expression.id):
		_states[expression.id] = ExpressionState.new(expression)
		_stats[expression.id] = ExpressionStats.new()
	return _states[expression.id]


#region Expression Management
## Register a Logic component with the system
func register_expression(expression: Logic) -> void:
	if not expression:
		return
	
	# Ensure expression has an ID
	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())
		
	logger.debug("Registering expression: %s with ID: %s" % [expression, expression.id])

	var state := get_or_create_state(expression)
	if not state:
		return
		
	if not state.is_parsed:
		_parse_expression(expression)

	# Register nested expressions
	for nested in expression.nested_expressions:
		if nested == null:
			push_error("Cannot register null nested expression")
			return
		register_expression(nested)
		_cache.add_dependency(expression.id, nested.id)

#endregion

#region Evaluation
## Get the current value of an expression
func get_value(id: String, force_update: bool = false) -> Variant:
	assert(not id.is_empty())
	if id not in _states:
		logger.error("Unknown expression: %s" % id)
		return null

	var stats = _stats[id]

	if _cache.needs_evaluation(id) or force_update:
		stats.misses += 1
		var result = _calculate(id)
		_cache.set_value(id, result)
		return result

	stats.hits += 1
	return _cache.get_value(id)

func _parse_expression(expression: Logic) -> void:
	var state := get_or_create_state(expression)

	if state.is_parsed or expression.expression_string.is_empty():
		return

	var variable_names = []
	for nested in expression.nested_expressions:
		variable_names.append(nested.id)

	var error = state.expression.parse(expression.expression_string,
									 PackedStringArray(variable_names))
	if error != OK:
		push_error("Failed to parse expression: %s" % expression.expression_string)
		return

	state.is_parsed = true

func _calculate(expression_id: String) -> Variant:
	assert(not expression_id.is_empty())
	var state: ExpressionState = _states.get(expression_id)
	if not state:
		logger.error("No state found for expression ID: %s" % expression_id)
		return null
		
	if not state.is_parsed:
		return null

	var expression: Logic = state.logic_expression
	var bindings = []

	for nested in expression.nested_expressions:
		bindings.append(get_value(nested.id))

	var result = state.expression.execute(bindings, entity)
	if state.expression.has_execute_failed():
		push_error("Failed to execute expression: %s" % expression.expression_string)
		return null

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
	_cache.invalidate(expression_id)
#endregion
