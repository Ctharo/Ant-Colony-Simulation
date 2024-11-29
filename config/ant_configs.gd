class_name AntConfigs
extends RefCounted

## Dictionary mapping action names to their GDScript classes
static var _action_classes: Dictionary = {
	"Move": Action.Move,
	"Harvest":  Action.Harvest,
	"Store":  Action.Store,
	"Rest":  Action.Rest,
	"FollowPheromone":  Action.FollowPheromone,
	"RandomMove":  Action.RandomMove,
}

## Dictionary of task configurations loaded from JSON
static var _task_configs: Dictionary

## Dictionary of behavior configurations loaded from JSON
static var _behavior_configs: Dictionary = {}

func _init() -> void:
	load_task_configs()
	load_behavior_configs()

## Load task configurations from JSON file
static func load_task_configs() -> Error:
	var file := FileAccess.open("res://config/ant_tasks.json", FileAccess.READ)
	if not file:
		return ERR_FILE_NOT_FOUND

	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	if result != OK:
		return result

	_task_configs = json.data.tasks
	return OK


func load_behavior_configs() -> void:
	var file = FileAccess.open("res://config/ant_behaviors.json", FileAccess.READ)
	if not file:
		push_error("Failed to open behaviors config")
		return
		
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_error("Failed to parse behaviors JSON: %s" % json.get_error_message())
		return
		
	_behavior_configs = json.data.behaviors


static func get_action_config(behavior_name: String) -> Dictionary:
	if not behavior_name in _behavior_configs:
		push_error("Unknown behavior: %s" % behavior_name)
		return {}
	return _behavior_configs[behavior_name].action

static func create_action_from_config(config: Dictionary, ant: Ant) -> Action:
	var action_name = config.get("base_action")
	if not action_name in _action_classes:
		push_error("Unknown action type: %s" % action_name)
		return null
		
	var action_class = _action_classes[action_name]
	var builder = action_class.create()
	
	# Apply configuration
	builder.with_ant(ant)
	
	# Add params if they exist
	if "params" in config:
		for key in config.params:
			builder.with_param(key, config.params[key])
			
	return builder.build()


## Create a task's behaviors from task configuration
static func create_task_behaviors(task_type: String, ant: Ant, condition_system: ConditionSystem) -> Array[Behavior]:
	if not task_type in _task_configs:
		push_error("Unknown task type: %s" % task_type)
		return []
		
	var task_config = _task_configs[task_type]
	var behaviors: Array[Behavior] = []
	
	# Add task behaviors
	if "behaviors" in task_config:
		for behavior_data in task_config.behaviors:
			var behavior = AntConfigs.create_behavior_from_config(behavior_data, ant, condition_system)
			if behavior:
				behaviors.append(behavior)
				
	return behaviors

## Create a behavior from behavior configuration
static func create_behavior_from_config(config: Dictionary, ant: Ant, condition_system: ConditionSystem) -> Behavior:
	var behavior_name = config.name
	
	# Start building the behavior
	var builder = (Behavior.builder(Task.Priority[config.get("priority", "MEDIUM")])
		.with_name(behavior_name)
		.with_ant(ant)
		.with_condition_system(condition_system))
	
	# Add behavior conditions
	if "conditions" in config:
		for condition_data in config.conditions:
			builder.with_condition(ConditionSystem.create_condition(condition_data))
	
	# Get action config and create action
	var action_config = AntConfigs.get_action_config(behavior_name)
	if action_config.is_empty():
		push_error("No action configuration found for behavior %s" % behavior_name)
		return null
		
	var action = AntConfigs.create_action_from_config(action_config, ant)
	if not action:
		push_error("Failed to create action for behavior %s" % behavior_name)
		return null
		
	builder.with_action(action)
	
	return builder.build()
	
