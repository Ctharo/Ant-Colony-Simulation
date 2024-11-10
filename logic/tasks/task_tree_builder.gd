class_name TaskTreeBuilder
extends RefCounted

## Builder class for constructing the task tree

## The ant for this task tree
var ant: Ant

## Configuration file paths
const DEFAULT_CONDITIONS_PATH = "res://conditions.json"
const DEFAULT_BEHAVIORS_PATH = "res://behaviors.json"
const DEFAULT_TASKS_PATH = "res://tasks.json"

var conditions_path: String = DEFAULT_CONDITIONS_PATH
var behaviors_path: String = DEFAULT_BEHAVIORS_PATH
var tasks_path: String = DEFAULT_TASKS_PATH

## Root task type to create
var root_task_type: String = "Root"

## Priority for root task
var root_priority: int = Task.Priority.MEDIUM

## Additional task types to force-load (optional)
var required_tasks: Array[String] = []

func _init(_ant: Ant) -> void:
	ant = _ant

## Set the root task type
func with_root_task(type: String, priority: int = Task.Priority.MEDIUM) -> TaskTreeBuilder:
	root_task_type = type
	root_priority = priority
	return self

## Add required task types to ensure they're loaded
func with_required_tasks(task_types: Array[String]) -> TaskTreeBuilder:
	required_tasks = task_types
	return self

## Set custom config file paths
func with_config_paths(tasks: String, behaviors: String, conditions: String) -> TaskTreeBuilder:
	tasks_path = tasks
	behaviors_path = behaviors
	conditions_path = conditions
	return self

## Build and return the configured task tree
func build() -> TaskTree:
	# Create tree instance
	var tree := TaskTree.new()
	tree.ant = ant

	# Initialize task configuration
	tree.task_config = TaskConfig.new()
	var load_result = tree.task_config.load_configs(tasks_path, behaviors_path, conditions_path)
	if load_result != OK:
		DebugLogger.error(DebugLogger.Category.TASK, "Failed to load configs from: %s, %s, and/or %s" %
				  [tasks_path, behaviors_path, conditions_path])
		return tree

	# Validate configurations
	if not _validate_configs(tree.task_config):
		DebugLogger.error(DebugLogger.Category.TASK, "Configuration validation failed")
		return tree

	# Create root task
	var root = tree.task_config.create_task(root_task_type, root_priority, ant)
	if not root:
		DebugLogger.error(DebugLogger.Category.TASK, "Failed to create root task of type: %s" % root_task_type)
		return tree

	root.name = root_task_type  # Ensure root is named
	tree.root_task = root

	# Verify the created hierarchy
	if not _verify_task_hierarchy(root):
		DebugLogger.error(DebugLogger.Category.TASK, "Task hierarchy verification failed")
		return tree

	DebugLogger.info(DebugLogger.Category.TASK, "Successfully built task tree")
	return tree

## Validate that all required tasks and their behaviors are configured
func _validate_configs(config: TaskConfig) -> bool:
	# Check root task exists
	if not root_task_type in config.task_configs:
		DebugLogger.error(DebugLogger.Category.TASK, "Root task type '%s' not found in configuration" % root_task_type)
		return false

	# Check required tasks exist
	for task_type in required_tasks:
		if not task_type in config.task_configs:
			DebugLogger.error(DebugLogger.Category.TASK, "Required task type '%s' not found in configuration" % task_type)
			return false

	# Check that all behaviors referenced by tasks exist
	for task_type in config.task_configs:
		var task_config = config.task_configs[task_type]
		if "behaviors" in task_config:
			for behavior_data in task_config.behaviors:
				var behavior_type = behavior_data.type
				if not behavior_type in config.behavior_configs:
					DebugLogger.error(DebugLogger.Category.TASK, "Task '%s' references undefined behavior: %s" %
							 [task_type, behavior_type])
					return false

	return true

## Verify the created task hierarchy
func _verify_task_hierarchy(task: Task) -> bool:
	if not task:
		return false

	# Check that task has proper references
	if not task.ant:
		DebugLogger.error(DebugLogger.Category.TASK, "Task '%s' missing ant reference" % task.name)
		return false

	# Verify behaviors
	for behavior in task.behaviors:
		if not behavior.ant:
			DebugLogger.error(DebugLogger.Category.BEHAVIOR, "Behavior '%s' in task '%s' missing ant reference" %
					  [behavior.name, task.name])
			return false

		# Verify behavior actions
		for action in behavior.actions:
			if not action.ant:
				DebugLogger.error(DebugLogger.Category.ACTION, "Action in behavior '%s' of task '%s' missing ant reference" %
						  [behavior.name, task.name])
				return false

	return true

## Get the list of all task types that will be loaded
func get_task_types() -> Array[String]:
	var types: Array[String] = []
	types.append(root_task_type)
	types.append_array(required_tasks)
	return types
