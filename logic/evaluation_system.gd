class_name EvaluationSystem
extends Node

class ExpressionState:
	var expression: Expression
	var logic_expression: Logic  # Store reference to Logic resource
	var is_parsed: bool = false

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

func initialize(p_entity: Node) -> void:
	entity = p_entity
	logger = Logger.new("evaluation_system][" + entity.name, DebugLogger.Category.LOGIC)

func get_or_create_state(expression: Logic) -> ExpressionState:
	if expression.id.is_empty():
		push_error("Expression has empty ID: %s" % expression)
		return null

	if not _states.has(expression.id):
		_states[expression.id] = ExpressionState.new(expression)
		_stats[expression.id] = ExpressionStats.new()
	return _states[expression.id]

func register_expression(expression: Logic) -> void:
	if not expression:
		return

	if expression.id.is_empty():
		expression.id = str(expression.get_instance_id())

	if expression.id not in DebugLogger.registered_logic:
		DebugLogger.debug(DebugLogger.Category.LOGIC, "Registering expression: [b]%s[/b] with ID: %s" % [expression.expression_string, expression.id])
		DebugLogger.registered_logic.append(expression.id)
		
	var state := get_or_create_state(expression)
	if not state:
		return

	if not state.is_parsed:
		_parse_expression(expression)

	for nested in expression.nested_expressions:
		if nested == null:
			push_error("Cannot register null nested expression")
			return
		register_expression(nested)
		_cache.add_dependency(expression.id, nested.id)

func get_value(expression: Logic, force_update: bool = false) -> Variant:
	assert(expression != null and not expression.id.is_empty())

	if expression.id == "full_health":
		pass

	var state := get_or_create_state(expression)
	if not state:
		push_error("No state found for expression: %s" % expression)
		return null

	var stats = _stats[expression.id]

	if _cache.needs_evaluation(expression.id) or force_update:
		stats.misses += 1
		var result = _calculate(state)
		_cache.set_value(expression.id, result)
		return result

	stats.hits += 1
	return _cache.get_value(expression.id)

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
		variable_names.append(nested.id)  # Using snake_case ID consistently

	if expression.id not in DebugLogger.parsed_expression_strings:
		DebugLogger.debug(DebugLogger.Category.LOGIC, "Parsing expression [b]%s[/b] with variables: %s" % [expression.name, variable_names])
		DebugLogger.parsed_expression_strings.append(expression.id)
		
	var error = state.expression.parse(expression.expression_string,
									 PackedStringArray(variable_names))
	if error != OK:
		push_error("Failed to parse expression '%s': %s" % [expression.name, expression.expression_string])
		return

	state.is_parsed = true

func _calculate(state: ExpressionState) -> Variant:
	if not state.is_parsed:
		return null

	var bindings = []
	for nested in state.logic_expression.nested_expressions:
		bindings.append(get_value(nested))

	var result = state.expression.execute(bindings, entity)
	if state.expression.has_execute_failed():
		assert(false, "Failed to execute expression '%s': %s" % [state.logic_expression.id, state.logic_expression.expression_string])
		push_error("Failed to execute expression '%s': %s" % [state.logic_expression.name, state.logic_expression.expression_string])
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
