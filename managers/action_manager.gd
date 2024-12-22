class_name ActionManager
extends Node



#region Properties
var _states: Dictionary = {}
var _actions: Dictionary = {}
var _action_priorities: Dictionary = {}
var _current_action_id: String

var evaluation_system: EvaluationSystem
var influence_manager: InfluenceManager
var entity: Node
var logger: Logger
var current_profile: ActionProfile : set = set_profile

#endregion

func _init() -> void:
	evaluation_system = EvaluationSystem.new()
	influence_manager = InfluenceManager.new()

func initialize(p_entity: Node) -> void:
	entity = p_entity
	logger = Logger.new("action_manager][" + entity.name, DebugLogger.Category.LOGIC)
	evaluation_system.initialize(entity)
	influence_manager.initialize(entity, evaluation_system)

func set_profile(profile: ActionProfile) -> void:
	if not profile:
		logger.error("Attempted to load null action profile")
		return

	logger.trace("Loading action profile: %s" % profile.name)

	# Store current profile
	current_profile = profile

	# Set role title in entity
	entity.role = current_profile.name.capitalize() if current_profile else "None"

	# Clear existing state
	_actions.clear()
	_action_priorities.clear()
	_states.clear()
	_current_action_id = ""

	# Track registration stats for logging
	var registered_count := 0
	var start_time := Time.get_ticks_msec()

	# Register all actions with their priorities
	for priority in profile.actions:
		var action: Action = profile.actions[priority]
		if not action:
			logger.warn("Null action found in profile %s at priority %d" % [profile.name, priority])
			continue

		register_action(action, priority)
		registered_count += 1

	var end_time := Time.get_ticks_msec()
	logger.debug("Loaded profile %s: %d actions in %d ms" % [
		profile.name,
		registered_count,
		end_time - start_time
	])
	update(0.0)

func get_or_create_state(action_id: String) -> ActionState:
	if action_id.is_empty():
		logger.error("Attempted to get/create state with empty action ID")
		return null

	if not _states.has(action_id):
		_states[action_id] = ActionState.new(influence_manager)
	return _states[action_id]

func register_action(action: Action, priority: int = 0) -> void:
	if not action:
		logger.error("Attempted to register null action")
		return

	if action.name.is_empty():
		logger.error("Attempted to register action with empty name")
		return

	_actions[action.id] = action
	_action_priorities[action.id] = priority
	action.priority = priority # Set internal priority to match list

	var state := get_or_create_state(action.id)
	if not state:
		return

	if action.start_condition:
		evaluation_system.register_expression(action.start_condition)

	if action.stop_condition:
		evaluation_system.register_expression(action.stop_condition)

	if action.interrupt_condition:
		evaluation_system.register_expression(action.interrupt_condition)

	if action is Move:
		influence_manager.register_influences(action)

	logger.trace("Registered action %s with priority %d" % [action.name, priority])

func get_next_action() -> Action:
	# Use priorities from profile instead of action's internal priority
	var candidates = _actions.values()
	candidates.sort_custom(func(a: Action, b: Action):
		return _action_priorities[a.id] > _action_priorities[b.id]
	)

	for action in candidates:
		if conditions_met(action):
			var state := get_or_create_state(action.id)
			if state.was_stopped:
				logger.trace("Skipping recently stopped action %s" % [action.id])
				continue
			return action
	return null

func set_action_priority(action_id: String, new_priority: int) -> void:
	if action_id in _actions:
		_action_priorities[action_id] = new_priority
		logger.trace("Updated priority for action %s to %d" % [action_id, new_priority])

func update(delta: float) -> void:
	if _current_action_id:
		var action: Action = _actions[_current_action_id]
		var state := get_or_create_state(_current_action_id)

		# Check stop condition
		if action.should_stop(entity):
			logger.debug("Stop condition met for action %s" % [_current_action_id])
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
	var action: Action = _actions[_current_action_id]
	var state := get_or_create_state(_current_action_id)
	if _current_action_id:
		state.current_cooldown = action.cooldown
		state.elapsed_time = 0.0
		_current_action_id = ""

func get_current_action() -> Action:
	if not _current_action_id:
		return null
	var state := get_or_create_state(_current_action_id)
	return _actions[_current_action_id]

func conditions_met(action: Action) -> bool:
	assert(not action.name.is_empty(), "Action must have a name")
	var state := get_or_create_state(action.id)

	if state.current_cooldown > 0:
		logger.trace("[b]%s[/b] on cooldown: %.2f" % [action.id, state.current_cooldown])
		return false

	# Reset the was_stopped flag when cooldown expires
	if state.was_stopped and state.current_cooldown <= 0:
		state.was_stopped = false

	logger.debug("Checking conditions for action [b]%s[/b]" % action.id)
	var can_start = action.can_start(entity)
	logger.debug("Action [b]%s[/b] can_start = %s" % [action.id, can_start])
	return can_start

func _select_next_action() -> void:
	logger.debug("=== Selecting next action ===")
	var next_action: Action = get_next_action()
	if next_action:
		logger.debug("Selected action [b]%s[/b]" % [next_action.id])
		_current_action_id = next_action.id
	else:
		logger.debug("No action selected")
