class_name ActionManager
extends Resource

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
	evaluation_system.initialize(entity)

#region Action Management
func register_action(action: Action) -> void:
	if not _entity:
		push_error("Initialize action manager before registering actions")
		return
		
	_actions[action.id] = action
	
	# Register action's main condition with evaluation system
	action.initialize(_entity)
	evaluation_system.register_expression(action._condition)
	
	# Connect signals
	action.completed.connect(_on_action_completed.bind(action.id))
	action.interrupted.connect(_on_action_interrupted.bind(action.id))

func unregister_action(action_id: String) -> void:
	if action_id in _actions:
		var action = _actions[action_id]
		evaluation_system.unregister_expression(action._condition.id)
		action.completed.disconnect(_on_action_completed)
		action.interrupted.disconnect(_on_action_interrupted)
		_actions.erase(action_id)

func update(delta: float = 0.0) -> void:
	if _current_action:
		_current_action.execute(delta)
	else:
		_select_next_action()
	
	# Update cooldowns
	for action in _actions.values():
		if not action.is_ready():
			action._current_cooldown = max(0.0, action._current_cooldown - delta)

func get_next_action() -> Action:
	var valid_actions = _actions.values().filter(func(action: Action): 
		return action.is_ready() and evaluation_system.get_value(action._condition.id)
	)
	return valid_actions[0] if not valid_actions.is_empty() else null

func interrupt_current_action() -> void:
	if _current_action:
		_current_action.stop()
		_current_action = null
#endregion

#region Private Methods
func _select_next_action() -> void:
	var next_action = get_next_action()
	if next_action:
		_current_action = next_action

func _on_action_completed(action_id: String) -> void:
	if _current_action and _current_action.id == action_id:
		_current_action = null

func _on_action_interrupted(action_id: String) -> void:
	if _current_action and _current_action.id == action_id:
		_current_action = null
#endregion
