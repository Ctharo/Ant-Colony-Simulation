class_name ActionManager
extends Node

#region Properties
## Evaluation system for caching expressions
var evaluation_system: EvaluationSystem

## Dictionary of registered actions
var _actions: Dictionary = {}

## Currently executing action
var _current_action: Action

## Entity being managed
var _entity: Node

## Logger instance
var logger: Logger
#endregion

func _init() -> void:
	logger = Logger.new("action_manager", DebugLogger.Category.LOGIC)
	evaluation_system = EvaluationSystem.new()

func initialize(entity: Node) -> void:
	_entity = entity
	entity.tree_exiting.connect(_on_entity_tree_exiting)
	evaluation_system.initialize(entity)

#region Action Management
## Register an action with instance-specific signal handling
func register_action(action: Action) -> void:
	if not _entity:
		push_error("Initialize action manager before registering actions")
		return
		
	_actions[action.id] = action
	
	# Initialize the action first
	action.initialize(_entity)
	
	# Now properly set up the condition
	var state = action._get_instance_state(_entity)
	if state and state.condition:
		# Explicitly set evaluation system
		state.condition.evaluation_system = evaluation_system
		
		# Register the condition to handle nested expressions
		evaluation_system.register_expression(state.condition)
	
	# Connect signals with entity-specific handling
	if not action.completed.is_connected(_on_action_completed):
		action.completed.connect(_on_action_completed)
	if not action.interrupted.is_connected(_on_action_interrupted):
		action.interrupted.connect(_on_action_interrupted)

## Unregister an action and clean up its instance-specific state
func unregister_action(action_id: String) -> void:
	if action_id in _actions:
		var action = _actions[action_id]
		var state = action._get_instance_state(_entity)
		if state and state.condition:
			evaluation_system.unregister_expression(state.condition.id)
		
		action.completed.disconnect(_on_action_completed)
		action.interrupted.disconnect(_on_action_interrupted)
		action.cleanup_instance(_entity)
		_actions.erase(action_id)

## Update the action system
func update(delta: float = 0.0) -> void:
	if _current_action:
		_current_action.execute(_entity, delta)
	else:
		_select_next_action()
	
	# Update cooldowns
	for action in _actions.values():
		if not action.is_ready(_entity):
			var state = action._get_instance_state(_entity)
			if state:
				state.current_cooldown = max(0.0, state.current_cooldown - delta)

## Get the next valid action
func get_next_action() -> Action:
	var valid_actions = _actions.values().filter(func(action: Action): 
		var state = action._get_instance_state(_entity)
		return action.is_ready(_entity) and state and evaluation_system.get_value(state.condition.id)
	)
	return valid_actions[0] if not valid_actions.is_empty() else null

## Interrupt the current action
func interrupt_current_action() -> void:
	if _current_action:
		_current_action.stop(_entity)
		_current_action = null

## Validate the expression chain
func validate_expression_chain(expression: Logic, visited: Array = []) -> bool:
	if expression.id in visited:
		push_error("Cyclic dependency detected for expression: %s" % expression.id)
		return false
		
	visited.append(expression.id)
	
	if expression.evaluation_system == null:
		push_error("Expression missing evaluation system: %s" % expression.id)
		return false
		
	for nested in expression.nested_expressions:
		if not validate_expression_chain(nested, visited):
			return false
			
	return true
#endregion

#region Private Methods
## Select the next action to execute
func _select_next_action() -> void:
	var next_action = get_next_action()
	if next_action:
		_current_action = next_action

## Handle action completion
func _on_action_completed(entity: Node) -> void:
	if entity == _entity and _current_action:
		_current_action = null

## Handle action interruption
func _on_action_interrupted(entity: Node) -> void:
	if entity == _entity and _current_action:
		_current_action = null

## Clean up when entity is removed
func _on_entity_tree_exiting() -> void:
	for action in _actions.values():
		action.cleanup_instance(_entity)
		
	# Cleanup evaluation system
	evaluation_system = null
	_current_action = null
#endregion
