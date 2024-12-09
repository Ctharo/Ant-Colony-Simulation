class_name Logic
extends Resource

#region Properties
var _evaluation_system: EvaluationSystem = EvaluationSystem.new()
var _actions: Dictionary = {}
var _active_action: Action
var ant: Ant
var logger: Logger
#endregion

func _init(p_ant: Ant) -> void:
	ant = p_ant
	logger = Logger.new("logic_system", DebugLogger.Category.LOGIC)

func add_action(action: Action) -> void:
	_actions[action.id] = action
	action.initialize(ant)

func update(delta: float) -> void:
	var highest_priority_action := _get_highest_priority_valid_action()
	
	if highest_priority_action != _active_action:
		_switch_action(highest_priority_action)
	
	if _active_action:
		_active_action.update(delta)

func _get_highest_priority_valid_action() -> Action:
	var highest_priority_action: Action = null
	var highest_priority := -1
	
	for action in _actions.values():
		if action.priority > highest_priority and _check_conditions(action.conditions):
			highest_priority = action.priority
			highest_priority_action = action
	
	return highest_priority_action

func _check_conditions(conditions: Array) -> bool:
	for condition in conditions:
		if not _evaluation_system.evaluate(condition):
			return false
	return true

func _switch_action(new_action: Action) -> void:
	if _active_action:
		_active_action.exit()
	_active_action = new_action
	if _active_action:
		_active_action.enter()

func add_formula(id: String, formula: String, variables: Array[String]) -> void:
	_evaluation_system.add_formula(id, formula, variables)

func set_variable(name: String, value: Variant) -> void:
	_evaluation_system.set_variable(name, value)

func add_dependency(dependent: String, dependency: String) -> void:
	_evaluation_system.add_dependency(dependent, dependency)
