class_name LogicDirector
extends Node

## Set of all registered expressions
var expressions: Dictionary = {}

## Cache of expression results
var results_cache: Dictionary = {}

## Set of active conditions to evaluate
var active_conditions: Array[String] = []

## Dictionary of actions mapped to their trigger conditions
var action_triggers: Dictionary = {}

## Register an expression with the director
func register_expression(expression: BaseExpression) -> void:
	expression.initialize(get_parent())
	expressions[expression.id] = expression
	
	# Invalidate dependent expression caches when dependencies change
	for dep_id in expression.dependencies:
		if expressions.has(dep_id):
			var dep = expressions[dep_id]
			dep.connect("dependency_changed", expression.invalidate_cache)

## Add a condition to actively evaluate
func add_active_condition(condition_id: String) -> void:
	if not active_conditions.has(condition_id):
		active_conditions.append(condition_id)

## Register an action to trigger when conditions are met
func register_action(action: Callable, required_conditions: Dictionary) -> void:
	action_triggers[action] = required_conditions

## Get cached result of an expression
func get_result(expression_id: String) -> Variant:
	if not expressions.has(expression_id):
		push_error("Unknown expression: %s" % expression_id)
		return null
		
	var expression = expressions[expression_id]
	return expression.evaluate()

## Evaluate active conditions and trigger actions
func evaluate_logic() -> void:
	# Evaluate all active conditions
	var condition_results = {}
	for condition_id in active_conditions:
		condition_results[condition_id] = get_result(condition_id)
	
	# Check action triggers
	for action in action_triggers:
		var should_trigger = true
		var conditions = action_triggers[action]
		
		for condition_id in conditions:
			var expected_value = conditions[condition_id]
			if condition_results.get(condition_id) != expected_value:
				should_trigger = false
				break
				
		if should_trigger:
			action.call()
