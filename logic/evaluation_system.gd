class_name EvaluationSystem
extends Resource

var _formulas: Dictionary = {}
var _variables: Dictionary = {}
var _cache: EvaluationCache = EvaluationCache.new()
var logger: Logger

func _init() -> void:
	logger = Logger.new("evaluation_system", DebugLogger.Category.LOGIC)

func add_formula(id: String, formula_string: String, variables: Array[String]) -> void:
	var evaluator = Evaluator.new()
	evaluator.formula = formula_string
	evaluator.variable_names = variables
	if evaluator.parse():
		_formulas[id] = evaluator
	else:
		logger.error("Failed to parse formula: %s" % id)

func set_variable(name: String, value: Variant) -> void:
	if _variables.get(name) != value:
		_variables[name] = value
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

func add_dependency(dependent: String, dependency: String) -> void:
	_cache.add_dependency(dependent, dependency)
