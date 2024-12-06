## Core logic evaluator class that all other logic components inherit from
class_name LogicExpression
extends Resource

#region Properties
## Unique identifier for this logic expression
@export var id: String
## Human readable name
@export var name: String
## Description of what this logic expression does
@export var description: String
## Type of value this logic expression returns
@export var return_type: int  # Using Property.Type enum
## Dependencies on other logic expressions
@export var dependencies: Array[LogicExpression] = []
## Property paths this logic expression depends on
@export var required_properties: Array[Path] = []
## Reference to the entity (ant) for property access
var entity: Node
## Reference to cache manager
var cache_manager: ExpressionCache
#endregion

#region Signals
signal value_changed(new_value: Variant)
signal dependencies_changed
#endregion

#region Public Methods
## Initialize logic expression with entity reference
func initialize(p_entity: Node, p_cache_manager: ExpressionCache = null) -> void:
	entity = p_entity
	cache_manager = p_cache_manager
	_register_dependencies()
	_setup_dependency_signals()

## Add a dependency to this expression
func add_dependency(expression: LogicExpression) -> void:
	if expression and not dependencies.has(expression):
		dependencies.append(expression)
		if cache_manager:
			cache_manager.register_dependency(id, expression.id)

		# Ensure the dependency is initialized
		if entity and cache_manager:
			expression.initialize(entity, cache_manager)

## Add a required property
func add_required_property(property_path: Path) -> void:
	if property_path and not required_properties.has(property_path):
		required_properties.append(property_path)

## Validate if logic expression can be evaluated
func is_valid() -> bool:
	if entity == null:
		return false

	# Check all dependencies are valid
	for dep in dependencies:
		if dep and not dep.is_valid():
			return false

	return true

## Evaluate the logic expression
func evaluate() -> Variant:
	#if not is_valid():
		#push_error("Attempted to evaluate invalid logic expression: %s" % name)
		#return null

	# Check cache first
	if cache_manager:
		var cached_result = cache_manager.get_cached_result(id)
		if cached_result != null:
			return cached_result

	# Evaluate and cache result
	var result = _evaluate()
	if cache_manager:
		cache_manager.cache_result(id, result)

	return result
#endregion

#region Protected Methods
## Internal evaluation logic (override in derived classes)
func _evaluate() -> Variant:
	return null

## Register dependencies (override in derived classes)
func _register_dependencies() -> void:
	pass

## Setup dependency signals
func _setup_dependency_signals() -> void:
	for dep in dependencies:
		if not dep.is_connected("value_changed", _on_dependency_changed):
			dep.connect("value_changed", _on_dependency_changed)
#endregion

#region Private Methods
## Handle dependency value changes
func _on_dependency_changed(_value: Variant) -> void:
	if cache_manager:
		cache_manager.invalidate_cache(id)
	dependencies_changed.emit()
	value_changed.emit(evaluate())
#endregion
