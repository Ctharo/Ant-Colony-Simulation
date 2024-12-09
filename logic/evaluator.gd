# Core formula evaluation class
class_name Evaluator
extends Resource

#region Properties
## The formula string to evaluate
var formula: String
## Variable names used in formula
var variable_names: Array[String] = []
## The parsed GDScript expression
var _expression: Expression

## Logger instance
var logger: Logger
#endregion

func _init() -> void:
	logger = Logger.new("formula_evaluator", DebugLogger.Category.LOGIC)
	_expression = Expression.new()

func parse() -> bool:
	if formula.is_empty():
		logger.error("Empty formula")
		return false
		
	var error = _expression.parse(formula, PackedStringArray(variable_names))
	if error != OK:
		logger.error("Parse error: %s" % _expression.get_error_text())
		return false
	
	return true

func evaluate(variables: Dictionary) -> Variant:
	var values = []
	for name in variable_names:
		if name not in variables:
			logger.error("Missing variable: %s" % name)
			return null
		values.append(variables[name])
		
	var result = _expression.execute(values)
	if _expression.has_execute_failed():
		logger.error("Execution error: %s" % _expression.get_error_text())
		return null
		
	return result
