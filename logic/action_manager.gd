class_name ActionManager
extends Node

class ActionState:
	var condition: Logic
	var current_cooldown: float = 0.0
	var elapsed_time: float = 0.0
	var influence_manager: InfluenceManager  # Add this for Move actions
	var was_stopped: bool = false  # Track if action was stopped by stop condition

	func _init(p_influence_manager: InfluenceManager) -> void:
		influence_manager = p_influence_manager

#region Properties
var _states: Dictionary = {}
var _actions: Dictionary = {}
var _current_action_id: String

var evaluation_system: EvaluationSystem
var influence_manager: InfluenceManager
var entity: Node
var logger: Logger
#endregion

func _init() -> void:
	evaluation_system = EvaluationSystem.new()
	influence_manager = InfluenceManager.new()

func initialize(p_entity: Node) -> void:
	entity = p_entity
	logger = Logger.new("action_manager][" + entity.name, DebugLogger.Category.LOGIC)
	evaluation_system.initialize(entity)
	influence_manager.initialize(entity, evaluation_system)

func get_or_create_state(action_id: String) -> ActionState:
	assert(not action_id.is_empty())
	if not _states.has(action_id):
		_states[action_id] = ActionState.new(influence_manager)
	return _states[action_id]

func register_action(action: Action) -> void:
	assert(not action.name.is_empty(), "Action must have a name")
	_actions[action.id] = action  # action.id is already snake_case from name
	var state := get_or_create_state(action.id)

	# Generate and register both conditions
	if (action.start_condition_expression or action.stop_condition_expression):
		action.generate_conditions()

		if action.start_condition:
			evaluation_system.register_expression(action.start_condition)

		if action.stop_condition:
			evaluation_system.register_expression(action.stop_condition)

	if action is Move:
		influence_manager.register_influences(action)

func update(delta: float) -> void:
	if _current_action_id:
		var action: Action = _actions[_current_action_id]
		var state := get_or_create_state(_current_action_id)

		# Check stop condition
		if action.should_stop(entity):
			logger.debug("Stop condition met for action %s" % [_current_action_id])
			action.emit_signal("interrupted")
			state.was_stopped = true  # Mark that this action was stopped
			_complete_current_action()
			_select_next_action()
			return

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

func get_next_action() -> Action:
	var sorted_actions = _actions.values()
	sorted_actions.sort_custom(func(a: Action, b: Action): return a.priority > b.priority)

	for action in sorted_actions:
		if conditions_met(action):
			# Check if this action was recently stopped
			var state := get_or_create_state(action.id)
			if state.was_stopped:
				logger.trace("Skipping recently stopped action %s" % [action.id])
				continue
			return action
	return null

func conditions_met(action: Action) -> bool:
	assert(not action.name.is_empty(), "Action must have a name")
	var state := get_or_create_state(action.id)

	if state.current_cooldown > 0:
		return false

	# Reset the was_stopped flag when cooldown expires
	if state.was_stopped and state.current_cooldown <= 0:
		state.was_stopped = false

	return action.can_start(entity)

func set_action_priority(action_id: String, new_priority: int) -> void:
	if action_id in _actions:
		_actions[action_id].priority = new_priority

func _select_next_action() -> void:
	logger.trace("Selecting next action")
	var next_action: Action = get_next_action()
	if next_action:
		logger.debug("Selected action %s" % [next_action.id])
		_current_action_id = next_action.id
