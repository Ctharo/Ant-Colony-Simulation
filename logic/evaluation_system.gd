class_name EvaluationSystem
extends Resource

#region Properties
## Registered formulas
var _formulas: Dictionary = {}
## Current variable values
var _variables: Dictionary = {}
## Cache system
var _cache: EvaluationCache = EvaluationCache.new()
## Logger instance
var logger: Logger
#endregion

func _init() -> void:
	logger = Logger.new("formula_system", DebugLogger.Category.LOGIC)

func add_formula(id: String, formula_string: String, variables: Array[String]) -> void:
	var evaluator = Evaluator.new()
	evaluator.formula = formula_string
	evaluator.variable_names = variables
	if not evaluator.parse():
		logger.error("Failed to parse formula: %s" % id)
		return
	_formulas[id] = evaluator

func set_variable(name: String, value: Variant) -> void:
	if _variables.get(name) != value:
		_variables[name] = value
		# Invalidate all formulas using this variable
		for id in _formulas:
			if name in _formulas[id].variable_names:
				_cache.invalidate(id)

func evaluate(id: String) -> Variant:
	if id not in _formulas:
		logger.error("Unknown formula: %s" % id)
		return null
		
	if _cache.needs_evaluation(id):
		var result = _formulas[id].evaluate(_variables)
		_cache.set_value(id, result)
		return result
		
	return _cache.get_value(id)
