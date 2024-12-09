class_name EvaluationSystem
extends Resource

#region Properties
## Dictionary of registered LogicExpressions
var _expressions: Dictionary = {}

## Evaluation cache system
var _cache: EvaluationCache = EvaluationCache.new()

## Base node for evaluations
var base_node: Node

## Logger instance 
var logger: Logger

## Cache statistics
var _cache_hits: int = 0
var _cache_misses: int = 0
#endregion

#region Initialization
func _init() -> void:
	logger = Logger.new("evaluation_system", DebugLogger.Category.LOGIC)

## Initialize the evaluation system with a base node
func initialize(p_base_node: Node) -> void:
	base_node = p_base_node
#endregion

#region Expression Management
## Register a LogicExpression with the system
func register_expression(expression: LogicExpression) -> void:
	if not expression.is_parsed:
		expression.initialize(base_node)
	
	_expressions[expression.id] = expression
	
	# First register all nested expressions
	for nested in expression.nested_expressions:
		if nested.id not in _expressions:
			register_expression(nested)
		_cache.add_dependency(expression.id, nested.id)
		
	# Connect to expression signals
	if not expression.value_changed.is_connected(_on_expression_value_changed):
		expression.value_changed.connect(_on_expression_value_changed.bind(expression.id))
		
	logger.trace("Registered expression: %s" % expression.id)

## Unregister a LogicExpression from the system
func unregister_expression(id: String) -> void:
	if id in _expressions:
		var expression = _expressions[id]
		expression.value_changed.disconnect(_on_expression_value_changed)
		_expressions.erase(id)
		logger.trace("Unregistered expression: %s" % id)
#endregion

#region Evaluation
## Get the current value of an expression
## Get the current value of an expression
func get_value(id: String) -> Variant:
	if id not in _expressions:
		logger.error("Unknown expression: %s" % id)
		return null
		
	var expression = _expressions[id]
	
	if _cache.needs_evaluation(id):
		_cache_misses += 1
		logger.trace("Cache MISS for expression: %s (Hits: %d, Misses: %d, Hit Rate: %.1f%%)" % [
			id, 
			_cache_hits, 
			_cache_misses, 
			_get_hit_rate()
		])
		
		# First get cached values for all nested expressions
		var nested_values = {}
		for nested in expression.nested_expressions:
			nested_values[nested.id] = get_value(nested.id)  # This will use cache or calculate
		
		# Now calculate this expression's value using cached nested values
		var result = expression._calculate()
		_cache.set_value(id, result)
		return result
		
	_cache_hits += 1
	logger.trace("Cache HIT for expression: %s (Hits: %d, Misses: %d, Hit Rate: %.1f%%)" % [
			id, 
			_cache_hits, 
			_cache_misses, 
			_get_hit_rate()
		])
	return _cache.get_value(id)

## Force reevaluation of an expression
func invalidate(id: String) -> void:
	if id in _expressions:
		_cache.invalidate(id)
		logger.trace("Invalidated expression: %s" % id)

## Get current cache hit rate percentage
func _get_hit_rate() -> float:
	var total = _cache_hits + _cache_misses
	return 100.0 * _cache_hits / total if total > 0 else 0.0

## Get cache statistics
func get_cache_stats() -> Dictionary:
	return {
		"hits": _cache_hits,
		"misses": _cache_misses,
		"hit_rate": _get_hit_rate()
	}
#endregion

#region Signal Handlers
## Handle value changes in expressions
func _on_expression_value_changed(_value: Variant, expression_id: String) -> void:
	_cache.invalidate(expression_id)
#endregion
