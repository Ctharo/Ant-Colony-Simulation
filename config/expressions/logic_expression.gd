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
var dependencies: Array[LogicExpression] = []
## Property paths this logic expression depends on
var required_properties: Array[Path] = []
## Reference to the entity (ant) for property access
var entity: Node
## Current evaluation context
var current_context: EvaluationContext
## Reference to cache manager
var cache_manager: ExpressionCache

var use_current_item: bool = false
#endregion

#region Signals
signal value_changed(new_value: Variant)
signal dependencies_changed
#endregion

#region Public Methods
func initialize(p_entity: Node, p_cache_manager: ExpressionCache = null) -> void:
	entity = p_entity
	cache_manager = p_cache_manager

	_register_dependencies()


	# Initialize all dependencies with the same entity and cache
	for dep in dependencies:
		dep.initialize(entity, cache_manager)

## Set the current evaluation context
func set_context(context: EvaluationContext) -> void:
	current_context = context
	# Propagate context to dependencies
	for dep in dependencies:
		dep.set_context(context)

## Add a dependency to this expression
func add_dependency(expression: LogicExpression) -> void:
	if expression and not dependencies.has(expression):
		dependencies.append(expression)
		if cache_manager:
			cache_manager.register_dependency(id, expression.id)

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
		if not dep.is_valid():
			return false

	# Check all required properties exist
	for prop_path in required_properties:
		if not entity.has_property(prop_path):
			return false

	return true

## Evaluate with optional context
func evaluate(context: EvaluationContext = null) -> Variant:
	if context:
		set_context(context)

	if not is_valid():
		push_error("Attempted to evaluate invalid expression: %s" % name)
		return null

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

## Register dependencies with cache manager
func register_with_cache_manager(p_cache_manager: ExpressionCache) -> void:
	cache_manager = p_cache_manager
	for dep in dependencies:
		dep.register_with_cache_manager(p_cache_manager)
		cache_manager.register_dependency(id, dep.id)

## Override in derived classes to register dependencies
func _register_dependencies() -> void:
	pass
#endregion

#region Private Methods
## Handle dependency value changes
func _on_dependency_changed(_value: Variant) -> void:
	if cache_manager:
		cache_manager.invalidate_cache(id)
	dependencies_changed.emit()
	value_changed.emit(evaluate())
#endregion
