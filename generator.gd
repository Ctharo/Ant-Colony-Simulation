@tool
extends EditorScript

const TASKS_DIR := "res://resources/tasks"
const TASKS_LIST_PATH := "res://resources/ant_tasks.tres"

const TASKS := {
	"CollectFood": {
		"priority": "MEDIUM",
		"conditions": [
			{
				"type": "Operator",
				"operator_type": "not",
				"operands": [
					{
						"type": "Operator",
						"operator_type": "or",
						"operands": [
							{
								"type": "Custom",
								"name": "LowEnergy"
							},
							{
								"type": "Custom",
								"name": "LowHealth"
							}
						]
					}
				]
			}
		],
		"behaviors": [
			{
				"name": "WanderForFood",
				"priority": "LOWEST"
			},
			{
				"name": "FollowFoodPheromones",
				"priority": "LOW"
			},
			{
				"name": "MoveToFood",
				"priority": "HIGH"
			},
			{
				"name": "HarvestFood",
				"priority": "HIGHEST"
			},
			{
				"name": "MoveToHome",
				"priority": "HIGHEST"
			},
			{
				"name": "StoreFood",
				"priority": "HIGHEST"
			}
		]
	}
}

func _run() -> void:
	if not _setup_directory():
		return

	if not create_task_configs():
		push_error("Failed to create task configurations")
		return

	print("Successfully created and saved all task configurations")

func _setup_directory() -> bool:
	var dir := DirAccess.open("res://")
	if not dir:
		push_error("Failed to access res:// directory")
		return false

	if not dir.dir_exists(TASKS_DIR):
		var err := dir.make_dir_recursive(TASKS_DIR)
		if err != OK:
			push_error("Failed to create tasks directory")
			return false

	return true

func create_task_configs() -> bool:
	var task_list := TaskConfigList.new()

	for task_name in TASKS:
		var task_config := _create_single_task(task_name)
		if not task_config:
			push_error("Failed to create task config for: %s" % task_name)
			continue

		var path := _save_task_config(task_config, task_name)
		if path.is_empty():
			continue

		task_list._paths[task_name] = path
		print("Added task path: %s -> %s" % [task_name, path])

	return _save_task_list(task_list)

func _create_single_task(task_name: String) -> TaskConfig:
	if not TASKS.has(task_name):
		push_error("Task %s not found in definitions" % task_name)
		return null

	var task_data: Dictionary = TASKS[task_name]
	var task := TaskConfig.new()
	task.priority = task_data.priority
	task.conditions = task_data.conditions
	task.behaviors = task_data.behaviors

	return task

func _save_task_config(task: TaskConfig, task_name: String) -> String:
	var path := "%s/%s.tres" % [TASKS_DIR, task_name.to_snake_case()]

	var err := ResourceSaver.save(task, path)
	if err != OK:
		push_error("Failed to save task: %s (Error: %d)" % [task_name, err])
		return ""

	print("Saved task: %s" % path)
	return path

func _save_task_list(task_list: TaskConfigList) -> bool:
	if task_list._paths.is_empty():
		push_error("No task paths to save!")
		return false

	print("Saving task list with paths: ", task_list._paths)

	var err := ResourceSaver.save(task_list, TASKS_LIST_PATH)
	if err != OK:
		push_error("Failed to save task list (Error: %d)" % err)
		return false

	# Verify the save
	var loaded_list = load(TASKS_LIST_PATH) as TaskConfigList
	if not loaded_list:
		push_error("Failed to verify saved task list!")
		return false

	if loaded_list._paths.is_empty():
		push_error("Verified task list has empty paths!")
		return false

	print("Successfully saved and verified task list at: %s" % TASKS_LIST_PATH)
	return true
