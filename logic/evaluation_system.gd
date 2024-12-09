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
	
	# Register dependencies for nested expressions
	for nested in expression.nested_expressions:
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
func get_value(id: String) -> Variant:
	if id not in _expressions:
		logger.error("Unknown expression: %s" % id)
		return null
		
	if _cache.needs_evaluation(id):
		var result = _expressions[id].get_value()
		_cache.set_value(id, result)
		return result
		
	return _cache.get_value(id)

## Force reevaluation of an expression
func invalidate(id: String) -> void:
	if id in _expressions:
		_cache.invalidate(id)
		logger.trace("Invalidated expression: %s" % id)
#endregion

#region Signal Handlers
## Handle value changes in expressions
func _on_expression_value_changed(_value: Variant, expression_id: String) -> void:
	_cache.invalidate(expression_id)
#endregion
