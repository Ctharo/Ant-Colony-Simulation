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
		assert(task_configs)
		if task_configs:
			task_configs.load_tasks()
		else:
			push_error("Failed to load task configs")

	if not behavior_configs:
		behavior_configs = load("res://resources/ant_behaviors.tres") as BehaviorConfigList
		assert(behavior_configs)
		if behavior_configs:
			behavior_configs.load_behaviors()
		else:
			push_error("Failed to load behavior configs")

	if not condition_configs:
		condition_configs = load("res://resources/ant_conditions.tres") as ConditionConfigList
		assert(condition_configs)
		if condition_configs:
			condition_configs.load_conditions()
		else:
			push_error("Failed to load condition configs")

static func get_action_config(behavior_name: String) -> ActionConfig:
	if not behavior_name in behavior_configs.behaviors:
		push_error("Unknown behavior: %s" % behavior_name)
		return null
	return behavior_configs.behaviors[behavior_name].action

static func get_behavior_config(behavior_name: String) -> BehaviorConfig:
	if not behavior_name in behavior_configs.behaviors:
		push_error("Unknown behavior: %s" % behavior_name)
		return null
	return behavior_configs.behaviors[behavior_name]

static func get_condition_config(condition_name: String) -> ConditionConfig:
	if not condition_name in condition_configs.conditions:
		push_error("Unknown condition: %s" % condition_name)
		return null
	return condition_configs.conditions[condition_name]

static func get_task_config(task_name: String) -> TaskConfig:
	if not task_name in task_configs.tasks:
		push_error("Unknown task: %s" % task_name)
		return null
	return task_configs.tasks[task_name]

static func create_task_from_config(config: TaskConfig, ant: Ant, condition_system: ConditionSystem) -> Task:
	# Create the task with proper priority
	var task = Task.new(Task.Priority[config.priority], condition_system)
	task.name = config.name
	task.ant = ant

	# Add task conditions
	for condition_config in config.conditions:
		var condition_name: String = condition_config.name
		var condition = create_condition_from_config(condition_config)
		if condition:
			task.add_condition(condition)
		else:
			push_error("Failed to create condition for task: %s with config: %s" % [condition_config.name, condition_name])


	# Create and add behaviors
	var behaviors = create_task_behaviors(config.name, ant, condition_system)
	for behavior in behaviors:
		task.add_behavior(behavior)

	return task

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
	var task_config = get_task_config(task_type)

	if not task_config:
		push_error("Unknown task type: %s" % task_type)
		return []

	var behaviors: Array[Behavior] = []

	# Add task behaviors
	for behavior_data in task_config.behaviors:
		var behavior_config: BehaviorConfig = get_behavior_config(behavior_data)
		var behavior = create_behavior_from_config(behavior_config, ant, condition_system)
		if behavior:
			behaviors.append(behavior)

	return behaviors

## Create a behavior from behavior configuration
static func create_behavior_from_config(config: BehaviorConfig, ant: Ant, condition_system: ConditionSystem) -> Behavior:
	# Start building the behavior
	var builder = (Behavior.builder(Task.Priority[config.priority])
		.with_name(config.name)
		.with_ant(ant)
		.with_condition_system(condition_system))

	var action = create_action_from_config(config.action, ant)
	if not action:
		push_error("Failed to create action for behavior %s" % config.name)
		return null

	builder.with_action(action)

	return builder.build()

static func create_condition_from_config(config: ConditionConfig) -> Condition:
	var condition = Condition.new()
	condition.name = config.name

	var custom_config := CustomConditionConfig.new()
	custom_config.condition_name = config.name

	var property_config := PropertyCheckConfig.new()
	property_config.property = config.evaluation.property
	property_config.operator = config.evaluation.operator
	property_config.value = config.evaluation.value
	property_config.value_from = config.evaluation.value_from

	custom_config.evaluation = property_config
	condition.config = custom_config
	return condition

static func create_operator_condition(operator_type: String, operands: Array) -> Condition:
	var condition = Condition.new()
	condition.name = "Operator: %s" % operator_type

	var config := OperatorConfig.new()
	config.operator_type = operator_type
	config.operands = operands
	condition.config = config
	return condition
