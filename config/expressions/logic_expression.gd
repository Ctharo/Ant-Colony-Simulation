class_name LogicExpression
extends Resource

#region Properties
## Unique identifier for this expression
var id: String

## Human readable name
@export var name: String :
	set(value):
		name = value
		id = name.to_camel_case()

## Type of value this expression returns
@export_enum("BOOL", "INT", "FLOAT", "STRING", "VECTOR2", "VECTOR3", "ARRAY", "DICTIONARY", 
			 "FOOD", "ANT", "COLONY", "PHEROMONE", "ITERATOR", "FOODS", "PHEROMONES", 
			 "COLONIES", "ANTS", "OBJECT", "UNKNOWN") var type: int = 19  # UNKNOWN

## The expression string to evaluate
@export_multiline var expression_string: String

## Array of LogicExpression resources to use as nested expressions
@export var nested_expressions: Array[LogicExpression]


## Description of what this expression does
@export var description: String

## The base node for evaluating expressions
var base_node: Node

## Reference to evaluation system
var evaluation_system: EvaluationSystem

var logger: Logger

## Cached expression result
var _cache: Variant

## Flag for cache invalidation
var _dirty: bool = true

## Expression object for evaluation
var _expression: Expression = Expression.new()

## Flag indicating if expression is successfully parsed
var is_parsed: bool = false
#endregion

#region Signals
## Emitted when the expression value changes
signal value_changed(new_value: Variant)

## Emitted when properties or nested expressions are modified
signal dependencies_changed
#endregion

#region Public Methods
## Initialize the expression with a base node and evaluation system
func initialize(p_base_node: Node, p_evaluation_system: EvaluationSystem = null) -> void:
	base_node = p_base_node
	evaluation_system = p_evaluation_system
	
	if name.is_empty():
		push_error("Expression name cannot be empty")
		return
		
	id = name.to_snake_case()
	logger = Logger.new("expression_%s" % id, DebugLogger.Category.LOGIC)
	
	# Initialize all nested expressions
	for expr in nested_expressions:
		expr.initialize(base_node, evaluation_system)
	
	parse_expression()

## Get the current value of the expression
func get_value() -> Variant:
	# If we have an evaluation system, always use it
	if evaluation_system:
		return evaluation_system.get_value(id)
		
	# Fallback to local calculation if no evaluation system
	if _dirty or _cache == null:
		_cache = _calculate()
		_dirty = false
	return _cache


## Force recalculation on next get_value() call
func invalidate() -> void:
	_dirty = true
	value_changed.emit(get_value())

## Get a formatted string representation of the value
func get_display_value() -> String:
	var value = get_value()
	match type:
		8, 9, 10, 11:  # FOOD, ANT, COLONY, PHEROMONE
			return str(value.name) if value else "null"
		_:
			return str(value)
#endregion

#region Protected Methods
func _calculate() -> Variant:
	if not is_parsed or not base_node:
		push_error("Expression not ready: %s" % expression_string)
		return null
	
	logger.debug("Calculating expression: %s" % expression_string)
	
	var bindings = []
	
	# Add nested expression values to array in same order as we parsed them
	for expr in nested_expressions:
		# Always use evaluation system's get_value if available
		var value = evaluation_system.get_value(expr.id) if evaluation_system else expr.get_value()
		
		if value == null:
			push_error("Could not get value for nested expression: %s" % expr.name)
			return null
			
		bindings.append(value)
		logger.debug("Added binding for %s: %s" % [expr.id, str(value)])
	
	logger.debug("Final bindings array: %s" % str(bindings))
	
	var result = _expression.execute(bindings, base_node)
	if _expression.has_execute_failed():
		var error_msg = "Failed to execute expression: %s\nError: %s" % [
			expression_string, 
			_expression.get_error_text()
		]
		logger.error(error_msg)
		push_error(error_msg)
		return null
	
	logger.debug("Expression result: %s" % str(result))
	return result

func parse_expression() -> void:
	if expression_string.is_empty():
		push_error("Empty expression string")
		return
	
	logger.debug("Parsing expression: %s" % expression_string)
	
	# Create array of names - these will be used as variable names in expression
	var variable_names = []
	
	# Add each nested expression name - order must match execute bindings array
	for expr in nested_expressions:
		variable_names.append(expr.id)
		logger.debug("Added variable name: %s" % expr.id)
	
	logger.debug("Variable names array: %s" % str(variable_names))
	
	# Parse with ordered variable names array
	var error = _expression.parse(expression_string, PackedStringArray(variable_names))
	if error != OK:
		var error_msg = "Failed to parse expression: %s\nError: %s" % [
			expression_string,
			_expression.get_error_text()
		]
		print(error_msg)
		push_error(error_msg)
		return
	
	logger.debug("Successfully parsed expression")
	is_parsed = true
## Handle property value changes
func _on_property_changed(_value: Variant) -> void:
	invalidate()

## Handle nested expression value changes
func _on_nested_expression_changed(_value: Variant) -> void:
	invalidate()
#endregion
