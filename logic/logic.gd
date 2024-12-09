class_name Logic
extends Resource

#region Properties
## Formula system instance
var evaluation_system: EvaluationSystem
## Component identifier
var id: String
## Logger instance
var logger: Logger
#endregion

func _init(p_id: String) -> void:
	id = p_id
	evaluation_system = EvaluationSystem.new()
	logger = Logger.new("logic_component", DebugLogger.Category.LOGIC)

func add_formula(formula_id: String, formula: String, variables: Array[String]) -> void:
	evaluation_system.add_formula(formula_id, formula, variables)

func set_variable(name: String, value: Variant) -> void:
	evaluation_system.set_variable(name, value)

func evaluate_formula(formula_id: String) -> Variant:
	return evaluation_system.evaluate(formula_id)
