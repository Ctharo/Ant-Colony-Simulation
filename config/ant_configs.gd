extends Node

## Dictionary mapping action names to their GDScript classes
static var _action_classes: Dictionary = {
	"Move": Action.Move,
	"Harvest": Action.Harvest,
	"Store": Action.Store,
	"Rest": Action.Rest,
	"FollowPheromone": Action.FollowPheromone,
	"RandomMove": Action.RandomMove,
}

## Resource containing task configurations
static var task_configs: TaskConfigList

## Resource containing behavior configurations
static var behavior_configs: BehaviorConfigList
## Resource containing condition configurations
static var condition_configs: ConditionConfigList

func _ready() -> void:
	load_configs()

static func load_configs() -> void:
	if not task_configs:
		task_configs = load("res://resources/ant_tasks.tres") as TaskConfigList
		task_configs.load_tasks()

	if not behavior_configs:
		behavior_configs = load("res://resources/ant_behaviors.tres") as BehaviorConfigList
		behavior_configs.load_behaviors()

	if not condition_configs:
		condition_configs = load("res://resources/ant_conditions.tres") as ConditionConfigList
		condition_configs.load_conditions()

static func get_action_config(behavior_name: String) -> ActionConfig:
	if not behavior_name in behavior_configs.behaviors:
		push_error("Unknown behavior: %s" % behavior_name)
		return null
	return behavior_configs.behaviors[behavior_name].action

static func get_condition_config(condition_name: String) -> Dictionary:
	if not condition_name in condition_configs.conditions:
		push_error("Unknown condition: %s" % condition_name)
		return {}
	return condition_configs.conditions[condition_name].evaluation

static func create_action_from_config(config: ActionConfig, ant: Ant) -> Action:
	if not config.base_action in _action_classes:
		push_error("Unknown action type: %s" % config.base_action)
		return null

	var action_class = _action_classes[config.base_action]
	var builder = action_class.create()

	# Apply basic configuration
	builder.with_ant(ant)\
		.with_name(config.base_action)\
		.with_description(config.description)\
		.with_duration(2.0)

	# Add params if they exist
	if not config.params.is_empty():
		builder.with_params(config.params)

	return builder.build()

## Create a task's behaviors from task configuration
static func create_task_behaviors(task_type: String, ant: Ant, condition_system: ConditionSystem) -> Array[Behavior]:
	if not AntConfigs.task_configs.tasks.get(task_type):
		push_error("Unknown task type: %s" % task_type)
		return []

	var task_config = AntConfigs.task_configs.tasks[task_type]
	var behaviors: Array[Behavior] = []

	# Add task behaviors
	for behavior_data in task_config.behaviors:
		var behavior = create_behavior_from_config(behavior_data, ant, condition_system)
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
			builder.with_condition(create_condition(condition_data))

	# Get action config and create action
	var action_config = get_action_config(behavior_name)
	if not action_config:
		push_error("No action configuration found for behavior %s" % behavior_name)
		return null

	var action = create_action_from_config(action_config, ant)
	if not action:
		push_error("Failed to create action for behavior %s" % behavior_name)
		return null

	builder.with_action(action)

	return builder.build()

static func create_condition(config: Dictionary) -> Condition:
	if typeof(config) != TYPE_DICTIONARY:
		push_error("Invalid condition config type: %s" % typeof(config))
		return null

	var condition = Condition.new()

	if config.type == "Custom" and config.name in condition_configs.conditions:
		condition.name = config.name
		# Get base evaluation from condition config
		var merged_config = condition_configs.conditions[config.name].evaluation.duplicate()
		# Merge with any overrides from the config
		for key in config:
			merged_config[key] = config[key]
		condition.config = merged_config
	elif config.type == "Operator":
		condition.name = "Operator: %s" % config.operator_type
		condition.config = config
	else:
		push_error("Unknown condition type")
		return null

	return condition
