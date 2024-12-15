class_name ActionManager
extends Node

class ActionState:
	var condition: Logic
	var evaluation_system: EvaluationSystem
	var current_cooldown: float = 0.0
	var elapsed_time: float = 0.0

	func _init(p_eval_system: EvaluationSystem) -> void:
		evaluation_system = p_eval_system

#region Properties
var _states: Dictionary = {}
## Evaluation system for caching expressions
var evaluation_system: EvaluationSystem
var influence_manager: InfluenceManager
## Dictionary of registered actions
var _actions: Dictionary = {}

## Currently executing action
var _current_action: String  # Stores action ID instead of reference

## Entity being managed
var entity: Node

## Logger instance
var logger: Logger

var _current_action_id: String
#endregion

func _init() -> void:
	evaluation_system = EvaluationSystem.new()
	influence_manager = InfluenceManager.new()

func initialize(p_entity: Node) -> void:
	entity = p_entity
	logger = Logger.new("action_manager][" + entity.name, DebugLogger.Category.LOGIC)
	entity.tree_exiting.connect(_on_entity_tree_exiting)
	evaluation_system.initialize(entity)
	influence_manager.initialize(entity, evaluation_system)

func get_or_create_state(action_id: String) -> ActionState:
	assert(not action_id.is_empty())
	if not _states.has(action_id):
		_states[action_id] = ActionState.new(evaluation_system)
	return _states[action_id]

#region Action Management
## Register an action by creating a unique instance for this entity

func register_action(action: Action) -> void:
	_actions[action.id] = action
	var state := get_or_create_state(action.id)

	# Create condition Logic resource if needed
	if action.condition_expression and not state.condition:
		state.condition = Logic.new()
		state.condition.id = action.id
		state.condition.expression_string = action.condition_expression
		state.condition.nested_expressions = action.nested_conditions.duplicate()
		evaluation_system.register_expression(state.condition)

	if action is Move:
		influence_manager.register_influences(action, evaluation_system)

## Update the action system
func update(delta: float) -> void:
	if _current_action_id:
		var action: Action = _actions[_current_action_id]
		var state := get_or_create_state(_current_action_id)

		state.elapsed_time += delta
		action.execute_tick(entity, state, delta)

		if action.duration > 0 and state.elapsed_time >= action.duration:
			_complete_current_action()
	else:
		_select_next_action()

func _complete_current_action() -> void:
	if _current_action_id:
		var state := get_or_create_state(_current_action_id)
		var action: Action = _actions[_current_action_id]
		state.current_cooldown = action.cooldown
		state.elapsed_time = 0.0
		_current_action_id = ""

## Get the next valid action based on priority
func get_next_action() -> Action:
	var sorted_actions = _actions.values()
	sorted_actions.sort_custom(func(a: Action, b: Action): return a.priority > b.priority)

	for action in sorted_actions:
		if conditions_met(action):
			return action

	return null

func conditions_met(action: Action) -> bool:
	assert(not action.id.is_empty())
	var state := get_or_create_state(action.id)
	if not state.condition:
		return true
	assert(not state.condition.id.is_empty())
	if state.current_cooldown > 0:
		return false
	return evaluation_system.get_value(state.condition.id)

## Validate the expression chain
func validate_expression_chain(expression: Logic, visited: Array = []) -> bool:
	if expression.id in visited:
		logger.error("Cyclic dependency detected for expression: %s" % expression.id)
		return false

	visited.append(expression.id)

	if expression.evaluation_system == null:
		logger.error("Expression missing evaluation system: %s" % expression.id)
		return false

	for nested in expression.nested_expressions:
		if not validate_expression_chain(nested, visited):
			return false

	return true

## Helper method to change action priorities at runtime
func set_action_priority(action_id: String, new_priority: int) -> void:
	if action_id in _actions:
		_actions[action_id].priority = new_priority
#endregion

#region Private Methods
## Select the next action to execute
func _select_next_action() -> void:
	var next_action = get_next_action()
	if next_action:
		_current_action_id = next_action.id

## Handle action completion
func _on_action_completed() -> void:
	_current_action = ""

## Handle action interruption
func _on_action_interrupted() -> void:
	_current_action = ""

## Clean up when entity is removed
func _on_entity_tree_exiting() -> void:
	# Cleanup actions
	for action in _actions.values():
		if action._condition:
			evaluation_system.unregister_expression(action._condition.id)
	_actions.clear()

	# Cleanup evaluation system
	evaluation_system = null
	_current_action = ""
#endregion
