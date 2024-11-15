class_name TaskConfig
extends BaseRefCounted

## Signal emitted when tasks are loaded
signal tasks_loaded

## Dictionary of loaded configurations
var task_configs: Dictionary = {}
var behavior_configs: Dictionary = {}
var condition_configs: Dictionary = {}

## Dictionary mapping action types to their classes
const ACTION_TYPES = {
	"Move": Action.Move,
	"MoveToFood": Action.Move,
	"MoveToHome": Action.Move,
	"RandomMove": Action.RandomMove,
	"FollowPheromone": Action.FollowPheromone,
	"FollowFoodPheromone": Action.FollowPheromone,
	"FollowHomePheromone": Action.FollowPheromone,
	"Harvest": Action.Harvest,
	"Store": Action.Store,
	"Attack": Action.Attack,
	"EmitPheromone": Action.EmitPheromone,
	"Rest": Action.Rest
}

func _init() -> void:
	log_from = "task_config"
	log_category = DebugLogger.Category.TASK

## Load configurations from JSON files
func load_configs(tasks_path: String, behaviors_path: String, conditions_path: String) -> Error:
	# Load conditions first
	var conditions_file := FileAccess.open(conditions_path, FileAccess.READ)
	if not conditions_file:
		_error("Failed to open conditions config file: %s" % conditions_path)
		return ERR_FILE_NOT_FOUND
	
	var json := JSON.new()
	var result := json.parse(conditions_file.get_as_text())
	if result != OK:
		_error("Failed to parse conditions JSON: %s" % json.get_error_message())
		return result
	
	condition_configs = json.data.conditions
	
	# Load behaviors
	var behaviors_file := FileAccess.open(behaviors_path, FileAccess.READ)
	if not behaviors_file:
		_error("Failed to open behaviors config file: %s" % behaviors_path)
		return ERR_FILE_NOT_FOUND
	
	result = json.parse(behaviors_file.get_as_text())
	if result != OK:
		_error("Failed to parse behaviors JSON: %s" % json.get_error_message())
		return result
	
	behavior_configs = json.data.behaviors
	
	# Load tasks
	var tasks_file := FileAccess.open(tasks_path, FileAccess.READ)
	if not tasks_file:
		_error("Failed to open tasks config file: %s" % tasks_path)
		return ERR_FILE_NOT_FOUND
	
	result = json.parse(tasks_file.get_as_text())
	if result != OK:
		_error("Failed to parse tasks JSON: %s" % json.get_error_message())
		return result
	
	task_configs = json.data.tasks
	tasks_loaded.emit()
	return OK

## Create a complete task instance with its behaviors
func create_task(task_type: String, priority: int, ant: Ant = null) -> Task:
	_info("Creating task: %s" % task_type)
	
	if not task_type in task_configs:
		_error("No configuration found for task type: %s" % task_type)
		return null
	
	var config = task_configs[task_type]
	var task = Task.new(priority)
	
	# Set basic properties
	task.name = task_type
	task.ant = ant
	
	# Add conditions from configuration
	if "conditions" in config:
		_add_conditions_from_config(task, config.conditions)
	
	# Add behaviors from configuration
	if "behaviors" in config:
		_add_behaviors_from_config(task, config.behaviors, ant)
	
	return task

## Add conditions to a target (Task or Behavior) from configuration
func _add_conditions_from_config(target: RefCounted, conditions_config: Array) -> void:
	if not (target is Task or target is Behavior):
		_error("Target must be either Task or Behavior")
		return
		
	for condition_data in conditions_config:
		var condition = _create_condition(condition_data)
		if condition:
			target.add_condition(condition)


## Create a condition instance from configuration data
func _create_condition(condition_data: Variant) -> Condition:
	var config = _resolve_condition_config(condition_data)
	if config.is_empty():
		return null
	return Condition.create_from_config(config)

## Resolve condition configuration from various formats
func _resolve_condition_config(condition_data: Variant) -> Dictionary:
	# Handle string condition names (reference to predefined conditions)
	if condition_data is String:
		if not condition_data in condition_configs:
			_error("Unknown condition: %s" % condition_data)
			return {}
		return condition_configs[condition_data]
	
	# Handle direct condition objects
	if condition_data is Dictionary:
		if condition_data.get("type") == "Operator":
			match condition_data.operator_type.to_upper():
				"AND":
					var subconds = []
					for subcond in condition_data.operands:
						subconds.append(_resolve_condition_config(subcond))
					return Operator.and_condition(subconds)
				"OR":
					var subconds = []
					for subcond in condition_data.operands:
						subconds.append(_resolve_condition_config(subcond))
					return Operator.or_condition(subconds)
				"NOT":
					var subcond = _resolve_condition_config(condition_data.operands[0])
					return Operator.not_condition(subcond)
		return condition_data
	
	_error("Invalid condition data: %s" % condition_data)
	return {}

## Add behaviors to the task from configuration
func _add_behaviors_from_config(task: Task, behaviors_config: Array, ant: Ant) -> void:
	for behavior_data in behaviors_config:
		var behavior = _create_behavior_for_task(behavior_data, ant)
		if behavior:
			task.add_behavior(behavior)

## Create a behavior instance for a task
func _create_behavior_for_task(behavior_data: Dictionary, ant: Ant) -> Behavior:
	var behavior_type = behavior_data.type
	if not behavior_type in behavior_configs:
		_error("Unknown behavior type: %s" % behavior_type)
		return null
	
	var config = behavior_configs[behavior_type]
	var priority = Task.Priority[behavior_data.get("priority", "MEDIUM")]
	var behavior = Behavior.new(priority)
	
	# Set basic properties
	behavior.name = behavior_type
	behavior.ant = ant
	
	# Add behavior-specific conditions if specified
	if "conditions" in behavior_data:
		_add_conditions_from_config(behavior, behavior_data.conditions)
	
	# Create and add action
	if "action" in config:
		var action_data = config.action
		# Override default params with task-specific params if provided
		if "params" in behavior_data:
			action_data = action_data.duplicate()
			action_data.params = action_data.get("params", {}).duplicate()
			action_data.params.merge(behavior_data.params)
		
		var action = create_action(action_data, ant)
		if action:
			behavior.actions.append(action)
	
	return behavior

## Create an action from configuration data
func create_action(action_data: Dictionary, ant: Ant) -> Action:
	var action_type = action_data.type
	if not action_type in ACTION_TYPES:
		_error("Unknown action type: %s" % action_type)
		return null
	
	var action_class: GDScript = ACTION_TYPES[action_type]
	var builder: Action.Builder = action_class.create(action_class)
	
	# Add parameters if specified
	if "params" in action_data:
		for param_key in action_data.params:
			builder.with_param(param_key, action_data.params[param_key])
	
	# Set cooldown if specified
	if "cooldown" in action_data:
		builder.with_cooldown(action_data.cooldown)
	
	var action = builder.build()
	action.ant = ant
	return action

## Get available task types
func get_task_types() -> Array:
	return task_configs.keys()

## Validate task configuration
func validate_config() -> bool:
	# Check tasks reference valid behaviors
	for task_type in task_configs:
		var config = task_configs[task_type]
		if "behaviors" in config:
			for behavior_data in config.behaviors:
				if not behavior_data.type in behavior_configs:
					_error("Task '%s' references undefined behavior: %s" % 
							 [task_type, behavior_data.type])
					return false
	
	# Check behaviors reference valid actions
	for behavior_type in behavior_configs:
		var config = behavior_configs[behavior_type]
		if "action" in config:
			if not config.action.type in ACTION_TYPES:
				_error("Behavior '%s' references undefined action: %s" % 
						  [behavior_type, config.action.type])
				return false
	
	return true
