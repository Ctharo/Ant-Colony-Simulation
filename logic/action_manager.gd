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
	evaluation_system = EvaluationSystem.new()

func initialize(entity: Node) -> void:
	_entity = entity
	logger = Logger.new("action_manager" + "][" + entity.name, DebugLogger.Category.LOGIC)
	entity.tree_exiting.connect(_on_entity_tree_exiting)
	evaluation_system.initialize(entity)

#region Action Management
## Register an action by creating a unique instance for this entity
func register_action(action_template: Action) -> void:
	logger.debug("Registering action %s" % [action_template.name])
	if not _entity:
		logger.error("Initialize action manager before registering actions")
		return
		
	# Create a new instance of the action for this entity
	var action = action_template.duplicate()
	_actions[action.id] = action
	
	# Initialize the action with this entity
	action.initialize(_entity)
	
	# Set up the condition with our evaluation system
	if action._condition:
		evaluation_system.register_expression(action._condition)

	
	# Connect signals
	if not action.completed.is_connected(_on_action_completed):
		action.completed.connect(_on_action_completed)
	if not action.interrupted.is_connected(_on_action_interrupted):
		action.interrupted.connect(_on_action_interrupted)

## Unregister an action and clean up
func unregister_action(action_id: String) -> void:
	if action_id in _actions:
		var action = _actions[action_id]
		if action._condition:
			evaluation_system.unregister_expression(action._condition.id)
		
		action.completed.disconnect(_on_action_completed)
		action.interrupted.disconnect(_on_action_interrupted)
		_actions.erase(action_id)

## Update the action system
func update(delta: float = 0.0) -> void:
	if _current_action:
		_current_action.execute(delta)
	else:
		_select_next_action()
	
	# Update cooldowns
	for action in _actions.values():
		if not action.is_ready():
			action._current_cooldown = max(0.0, action._current_cooldown - delta)

## Get the next valid action based on priority
func get_next_action() -> Action:
	# Sort actions by priority (highest first)
	var sorted_actions = _actions.values()
	sorted_actions.sort_custom(func(a: Action, b: Action): return a.priority > b.priority)
	
	# Check conditions in priority order, return first valid action
	for action: Action in sorted_actions:
		if action.is_ready() and action.conditions_met():
			return action
	
	return null

## Interrupt the current action
func interrupt_current_action() -> void:
	if _current_action:
		_current_action.stop()
		_current_action = null

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
		_current_action = next_action

## Handle action completion
func _on_action_completed() -> void:
	_current_action = null

## Handle action interruption
func _on_action_interrupted() -> void:
	_current_action = null

## Clean up when entity is removed
func _on_entity_tree_exiting() -> void:
	# Cleanup actions
	for action in _actions.values():
		if action._condition:
			evaluation_system.unregister_expression(action._condition.id)
	_actions.clear()
	
	# Cleanup evaluation system
	evaluation_system = null
	_current_action = null
#endregion
