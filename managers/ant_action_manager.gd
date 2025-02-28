class_name AntActionManager
extends Node

## Signal emitted when an action starts
signal action_started(action: AntAction)
## Signal emitted when an action completes
signal action_completed(action: AntAction)
## Signal emitted when an action fails
signal action_failed(action: AntAction, reason: String)
## Signal emitted when an action is interrupted
signal action_interrupted(action: AntAction)
## Signal emitted when the active action changes
signal active_action_changed(old_action: AntAction, new_action: AntAction)

## The ant this manager belongs to
var ant: Ant

## All available actions
var available_actions: Array[AntAction] = []

## The currently active action
var active_action: AntAction

## Action that's been forcibly set (overrides priority)
var forced_action: AntAction

## Whether action processing is enabled
var is_processing_enabled: bool = true

## Logger instance
var logger: Logger

func _init() -> void:
	logger = Logger.new("action_manager", DebugLogger.Category.ENTITY)

## Initialize with an ant reference
func initialize(p_ant: Ant) -> void:
	if not is_instance_valid(p_ant):
		logger.error("Cannot initialize with invalid ant")
		return

	ant = p_ant
	logger.debug("Initialized action manager for " + ant.name)

func _physics_process(delta: float) -> void:
	if not is_processing_enabled or not is_instance_valid(ant) or ant.is_dead:
		return

	# Update cooldowns for all actions
	for action in available_actions:
		action.update_cooldown(delta)

	# Process forced action if one is set
	if forced_action:
		_process_forced_action(delta)
		return

	# Check if current action is running
	if active_action and active_action.status == AntAction.ActionStatus.RUNNING:
		active_action.update(delta)
		return

	# Find the highest priority action that can start
	var next_action = _find_next_action()
	if next_action:
		_change_active_action(next_action)
		if not next_action.start():
			logger.warning("Failed to start action: " + next_action.name)

## Process a forced action
func _process_forced_action(delta: float) -> void:
	match forced_action.status:
		AntAction.ActionStatus.INACTIVE:
			if forced_action.start():
				logger.debug("Started forced action: " + forced_action.name)
			else:
				logger.warning("Failed to start forced action: " + forced_action.name)
				forced_action = null
		AntAction.ActionStatus.RUNNING:
			forced_action.update(delta)
		AntAction.ActionStatus.COMPLETED, AntAction.ActionStatus.FAILED:
			logger.debug("Forced action completed or failed")
			forced_action = null

## Find the next highest priority action that can start
func _find_next_action() -> AntAction:
	var candidate: AntAction
	var highest_priority: int = -99999

	for action in available_actions:
		if action.can_start() and action.priority > highest_priority:
			candidate = action
			highest_priority = action.priority

	return candidate

## Add an action to the available actions
func add_action(action: AntAction) -> void:
	if not is_instance_valid(action):
		logger.error("Cannot add null action")
		return

	if action in available_actions:
		return

	action.initialize(ant)
	available_actions.append(action)
	_connect_action_signals(action)

	logger.debug("Added action: " + action.name)

## Remove an action from available actions
func remove_action(action: AntAction) -> void:
	if not action in available_actions:
		return

	if action == active_action:
		action.interrupt()
		active_action = null

	available_actions.erase(action)
	_disconnect_action_signals(action)

	logger.debug("Removed action: " + action.name)

func clear_actions() -> void:
	# Cancel any running actions
	if active_action and active_action.status == AntAction.ActionStatus.RUNNING:
		active_action.interrupt()
	
	# Clear all actions
	for action in available_actions.duplicate():
		remove_action(action)
	
	available_actions.clear()
	active_action = null
	forced_action = null

## Force a specific action to run
func force_action(action: AntAction) -> bool:
	if not action in available_actions:
		logger.error("Cannot force action " + action.name + ": not in available actions")
		return false

	if active_action and active_action != action and active_action.status == AntAction.ActionStatus.RUNNING:
		active_action.interrupt()

	forced_action = action
	_change_active_action(action)

	logger.debug("Forced action: " + action.name)
	return true

## Cancel the currently active action
func cancel_active_action() -> void:
	if active_action and active_action.status == AntAction.ActionStatus.RUNNING:
		active_action.interrupt()

	forced_action = null

	logger.debug("Cancelled active action")

## Change the active action
func _change_active_action(new_action: AntAction) -> void:
	var old_action = active_action
	active_action = new_action

	if old_action != new_action:
		active_action_changed.emit(old_action, new_action)

## Connect to an action's signals
func _connect_action_signals(action: AntAction) -> void:
	if not action.action_started.is_connected(_on_action_started):
		action.action_started.connect(_on_action_started.bind(action))
	if not action.action_completed.is_connected(_on_action_completed):
		action.action_completed.connect(_on_action_completed.bind(action))
	if not action.action_failed.is_connected(_on_action_failed):
		action.action_failed.connect(_on_action_failed.bind(action))
	if not action.action_interrupted.is_connected(_on_action_interrupted):
		action.action_interrupted.connect(_on_action_interrupted.bind(action))

## Disconnect from an action's signals
func _disconnect_action_signals(action: AntAction) -> void:
	if action.action_started.is_connected(_on_action_started):
		action.action_started.disconnect(_on_action_started)
	if action.action_completed.is_connected(_on_action_completed):
		action.action_completed.disconnect(_on_action_completed)
	if action.action_failed.is_connected(_on_action_failed):
		action.action_failed.disconnect(_on_action_failed)
	if action.action_interrupted.is_connected(_on_action_interrupted):
		action.action_interrupted.disconnect(_on_action_interrupted)

## Get an action by name
func get_action_by_name(action_name: String) -> AntAction:
	for action in available_actions:
		if action.name == action_name or action.id == action_name:
			return action
	return null

## Enable or disable action processing
func set_processing_enabled(enabled: bool) -> void:
	is_processing_enabled = enabled

	if not enabled and active_action and active_action.status == AntAction.ActionStatus.RUNNING:
		active_action.interrupt()
		active_action = null
		forced_action = null

## Signal handlers
func _on_action_started(_ant: Ant, action: AntAction) -> void:
	logger.debug("Action started: " + action.name)
	action_started.emit(action)

func _on_action_completed(_ant: Ant, action: AntAction) -> void:
	logger.debug("Action completed: " + action.name)
	action_completed.emit(action)

	if action == forced_action:
		forced_action = null
	if action == active_action:
		active_action = null

func _on_action_failed(_ant: Ant, reason: String, action: AntAction) -> void:
	logger.debug("Action failed: " + action.name + " - " + reason)
	action_failed.emit(action, reason)

	if action == forced_action:
		forced_action = null
	if action == active_action:
		active_action = null

func _on_action_interrupted(_ant: Ant, action: AntAction) -> void:
	logger.debug("Action interrupted: " + action.name)
	action_interrupted.emit(action)

	if action == forced_action:
		forced_action = null
	if action == active_action:
		active_action = null
