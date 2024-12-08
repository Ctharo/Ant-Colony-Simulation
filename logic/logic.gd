class_name Logic
extends Evaluatable

#region Properties
## The expression string to evaluate
@export_multiline var expression_string: String

## Array of nested expressions
@export var nested_expressions: Array[Logic]

## Expression object for evaluation
var _expression: Expression = Expression.new()

## Flag indicating if expression is successfully parsed
var is_parsed: bool = false
#endregion

#region Public Methods
func initialize(p_evaluation_system: EvaluationSystem) -> void:
	super(p_evaluation_system)
	
	# Initialize nested expressions and register dependencies
	for expr in nested_expressions:
		expr.initialize(evaluation_system)
		add_dependency(expr.id)
	
	parse_expression()

func set_expression(expression: String) -> void:
	expression_string = expression
	parse_expression()
	invalidate()

func _calculate() -> Variant:
	if not is_parsed:
		push_error("Expression not parsed: %s" % expression_string)
		return null
	
	# Get values from nested expressions
	var bindings = []
	for expr in nested_expressions:
		var value = expr.evaluate()
		if value == null:
			push_error("Could not get value for nested expression: %s" % expr.name)
			return null
		bindings.append(value)
	
	# Execute expression with bindings
	var result = _expression.execute(bindings, evaluation_system.base_node)
	if _expression.has_execute_failed():
		push_error("Failed to execute expression: %s\nError: %s" % [
			expression_string, 
			_expression.get_error_text()
		])
		return null
	
	return result

## Parse the expression with current nested expressions
func parse_expression() -> void:
	if expression_string.is_empty():
		push_error("Empty expression string")
		return
	
	# Create array of variable names from nested expressions
	var variable_names = []
	for expr in nested_expressions:
		variable_names.append(expr.id)
	
	# Parse the expression
	var error = _expression.parse(expression_string, PackedStringArray(variable_names))
	if error != OK:
		push_error("Failed to parse expression: %s\nError: %s" % [
			expression_string,
			_expression.get_error_text()
		])
		return
	
	is_parsed = true
	logger.trace("Successfully parsed expression: %s" % expression_string)
#endregion
