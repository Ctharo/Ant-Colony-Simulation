class_name Factory
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
## Resource containing expression configurations
static var expression_configs: ExpressionConfigList

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

	if not expression_configs:
		expression_configs = load("res://resources/ant_expressions.tres") as ExpressionConfigList
		assert(expression_configs)
		if expression_configs:
			expression_configs.load_expressions()
		else:
			push_error("Failed to load expression configs")

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

static func get_expression_config(expression_name: String) -> ExpressionConfig:
	if not expression_name in expression_configs.expressions:
		push_error("Unknown expression: %s" % expression_name)
		return null
	return expression_configs.expressions[expression_name]

static func get_task_config(task_name: String) -> TaskConfig:
	if not task_name in task_configs.tasks:
		push_error("Unknown task: %s" % task_name)
		return null
	return task_configs.tasks[task_name]

static func create_task_from_config(config: TaskConfig) -> Task:
	# Create the task with proper priority
	var task = Task.new(Task.Priority[config.priority])
	task.name = config.name

	# Add task conditions
	for expression_config in config.expressions:
		var expression = create_expression_from_config(expression_config)
		if expression:
			task.add_condition(expression)
		else:
			push_error("Failed to create expression for task: %s" % expression_config.name)

	# Create and add behaviors
	var behaviors = create_task_behaviors(config.name)
	for behavior in behaviors:
		task.add_behavior(behavior)

	return task

static func create_action_from_config(config: ActionConfig) -> Action:
	if not config.base_action in _action_classes:
		push_error("Unknown action type: %s" % config.base_action)
		return null

	var action_class = _action_classes[config.base_action]
	var builder = action_class.create()

	# Apply basic configuration
	builder.with_name(config.base_action)\
		.with_description(config.description)\
		.with_duration(2.0)

	# Add params if they exist
	if not config.params.is_empty():
		builder.with_params(config.params)

	return builder.build()

## Create a task's behaviors from task configuration
static func create_task_behaviors(task_type: String) -> Array[Behavior]:
	var task_config = get_task_config(task_type)

	if not task_config:
		push_error("Unknown task type: %s" % task_type)
		return []

	var behaviors: Array[Behavior] = []

	# Add task behaviors
	for behavior_data in task_config.behaviors:
		var behavior_config: BehaviorConfig = get_behavior_config(behavior_data)
		var behavior = create_behavior_from_config(behavior_config)
		if behavior:
			behaviors.append(behavior)

	return behaviors

## Create a behavior from behavior configuration
static func create_behavior_from_config(config: BehaviorConfig) -> Behavior:
	# Start building the behavior
	var builder = Behavior.builder(Task.Priority[config.priority])\
		.with_name(config.name)

	var action = create_action_from_config(config.action)
	if not action:
		push_error("Failed to create action for behavior %s" % config.name)
		return null

	builder.with_action(action)

	# Add behavior conditions
	for expression_config in config.expressions:
		var expression = create_expression_from_config(expression_config)
		if expression:
			builder = builder.with_condition(expression)
		else:
			push_error("Failed to create expression for behavior: %s" % config.name)

	return builder.build()

static func create_expression_from_config(config: ExpressionConfig) -> LogicExpression:
	match config.type:
		"property":
			return _create_property_expression(config)
		"list":
			return _create_list_expression(config)
		"distance":
			return _create_distance_expression(config)
		"operator":
			return _create_operator_expression(config)
		_:
			push_error("Unknown expression type: %s" % config.type)
			return null

static func _create_property_expression(config: PropertyExpressionConfig) -> PropertyExpression:
	var expression = PropertyExpression.new()
	expression.id = config.id
	expression.name = config.name
	expression.property_path = config.property_path
	expression.use_current_item = config.use_current_item
	return expression

static func _create_list_expression(config: ListExpressionConfig) -> LogicExpression:
	match config.list_type:
		"filter":
			return _create_list_filter_expression(config)
		"map":
			return _create_list_map_expression(config)
		"any":
			return _create_list_any_expression(config)
		"has_items":
			return _create_list_has_items_expression(config)
		_:
			push_error("Unknown list expression type: %s" % config.list_type)
			return null

static func _create_list_filter_expression(config: ListFilterExpressionConfig) -> ListFilterExpression:
	var expression = ListFilterExpression.new()
	expression.id = config.id
	expression.name = config.name
	expression.array_expression = create_expression_from_config(config.array_expression)
	expression.predicate_expression = create_expression_from_config(config.predicate_expression)
	expression.operator = config.operator
	expression.compare_value = create_expression_from_config(config.compare_value)
	return expression

static func _create_list_map_expression(config: ListMapExpressionConfig) -> ListMapExpression:
	var expression = ListMapExpression.new()
	expression.id = config.id
	expression.name = config.name
	expression.array_expression = create_expression_from_config(config.array_expression)
	expression.map_expression = create_expression_from_config(config.map_expression)
	return expression

static func _create_list_any_expression(config: ListAnyExpressionConfig) -> ListAnyExpression:
	var expression = ListAnyExpression.new()
	expression.id = config.id
	expression.name = config.name
	expression.array_expression = create_expression_from_config(config.array_expression)
	expression.condition_expression = create_expression_from_config(config.condition_expression)
	return expression

static func _create_list_has_items_expression(config: ListHasItemsExpressionConfig) -> ListHasItemsExpression:
	var expression = ListHasItemsExpression.new()
	expression.id = config.id
	expression.name = config.name
	expression.list_expression = create_expression_from_config(config.list_expression)
	return expression

static func _create_distance_expression(config: DistanceExpressionConfig) -> DistanceExpression:
	var expression = DistanceExpression.new()
	expression.id = config.id
	expression.name = config.name
	expression.position1_expression = create_expression_from_config(config.position1_expression)
	expression.position2_expression = create_expression_from_config(config.position2_expression)
	return expression

static func _create_operator_expression(config: OperatorExpressionConfig) -> LogicExpression:
	# Implement operator expression creation
	pass
