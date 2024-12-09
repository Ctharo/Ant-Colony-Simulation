## Base class for all evaluatable components
class_name Evaluatable
extends Resource

#region Properties
## Unique identifier for this component
var id: String

## Name of this component
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

## Reference to the shared evaluation system
var evaluation_system: EvaluationSystem

## Logger instance
var logger: Logger
#endregion

#region Public Methods
## Initialize the component
func initialize(p_evaluation_system: EvaluationSystem) -> void:
	evaluation_system = p_evaluation_system
	evaluation_system.register_component(self, id)
	logger = Logger.new(get_class().to_lower(), DebugLogger.Category.LOGIC)

## Evaluate this component
func evaluate() -> Variant:
	if evaluation_system.needs_evaluation(id):
		var result = _calculate()
		evaluation_system.set_cached_value(id, result)
		return result
	return evaluation_system.get_cached_value(id)

## Add a dependency to this component
func add_dependency(dependency_id: String) -> void:
	evaluation_system.add_dependency(id, dependency_id)

## Force cache invalidation
func invalidate() -> void:
	evaluation_system.invalidate(id)
#endregion

#region Protected Methods
## Calculate the actual value (override in derived classes)
func _calculate() -> Variant:
	return null
#endregion
