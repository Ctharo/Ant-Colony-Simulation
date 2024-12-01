class_name TaskConfigList
extends Resource

@export var _paths: Dictionary = {} :
	get:
		return _paths
	set(value):
		_paths = value
		# Validate dictionary entries are strings
		for key in value:
			assert(key is String and value[key] is String,
				"TaskConfigList paths must be Dictionary<String, String>")

## Dictionary mapping condition names to their resource paths
var task_paths: Dictionary = {} :
	get: return _paths
	set(value):
		for key in value:
			assert(key is String and value[key] is String,
				"TaskConfigList paths must be Dictionary<String, String>")
		_paths = value

## Cache of loaded condition instances
var tasks: Dictionary = {} :
	set(value):
		tasks = value
	get:
		return tasks


## Loads all tasks from their saved paths
func load_tasks() -> void:
	tasks.clear()
	for task_name in _paths:
		var task = load(_paths[task_name]) as TaskConfig
		if task:
			tasks[task_name] = task

## Required for proper serialization of dictionary property
func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "task_paths",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Dictionary<String, String>"
	}]

## Override _init to ensure dictionary is initialized
func _init():
	if task_paths == null:
		task_paths = {}
