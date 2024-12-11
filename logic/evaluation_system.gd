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
## Cache statistics tracker
var _stats: Dictionary = {}
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
func initialize(p_base_node: Node) -> void:
	base_node = p_base_node
#endregion

#region Expression Management
## Register a Logic component with the system
func register_expression(expression: Logic) -> void:
	if not expression:
		return
		
	if expression.id in _expressions and expression.evaluation_system == self:
		return
		
	expression.initialize(base_node, {
		"evaluation_system": self
	})
	
	_stats[expression.id] = ExpressionStats.new()
	
	for nested in expression.nested_expressions:
		if nested == null:
			assert(nested, "Cannot register null nested expression for expression: %s" % expression.name)
			logger.error("Cannot register null nested expression for expression: %s" % expression.name)
			return
		register_expression(nested)
		_cache.add_dependency(expression.id, nested.id)
		
	_expressions[expression.id] = expression
	
## Unregister a LogicExpression from the system
func unregister_expression(id: String) -> void:
	if id in _expressions:
		var expression = _expressions[id]
		expression.value_changed.disconnect(_on_expression_value_changed)
		_expressions.erase(id)
		_stats.erase(id)
		logger.trace("Unregistered expression: %s" % id)
#endregion

#region Evaluation
## Get the current value of an expression
func get_value(id: String) -> Variant:
	if id not in _expressions:
		logger.error("Unknown expression: %s" % id)
		return null
		
	var expression: Logic = _expressions[id]
	#if not expression.evaluation_system:
		#expression.initialize(base_node, self)
		#logger.warn("evaluation system was missing from expression: %s" % expression.name)
		#
	var stats = _stats[id]
	
	if _cache.needs_evaluation(id):
		stats.misses += 1
		logger.trace("Cache MISS for expression: %s (Hits: %d, Misses: %d, Hit Rate: %.1f%%)" % [
			id, 
			stats.hits, 
			stats.misses, 
			stats.get_hit_rate()
		])
		
		# First get cached values for all nested expressions
		var nested_values = {}
		for nested in expression.nested_expressions:
			nested_values[nested.id] = get_value(nested.id)  # This will use cache or calculate
		
		# Now calculate this expression's value using cached nested values
		var result = expression._calculate()
		_cache.set_value(id, result)
		return result
		
	stats.hits += 1
	logger.trace("Cache HIT for expression: %s (Hits: %d, Misses: %d, Hit Rate: %.1f%%)" % [
			id, 
			stats.hits, 
			stats.misses, 
			stats.get_hit_rate()
		])
	return _cache.get_value(id)

## Force reevaluation of an expression
func invalidate(id: String) -> void:
	if id in _expressions:
		_cache.invalidate(id)
		logger.trace("Invalidated expression: %s" % id)

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
