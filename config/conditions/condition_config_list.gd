class_name ConditionConfigList
extends Resource

@export var _paths: Dictionary = {} :
	get:
		return _paths
	set(value):
		_paths = value
		# Validate dictionary entries are strings
		for key in value:
			assert(key is String and value[key] is String,
				"ConditionConfigList paths must be Dictionary<String, String>")

## Dictionary mapping condition names to their resource paths
var condition_paths: Dictionary = {} :
	get: return _paths
	set(value):
		for key in value:
			assert(key is String and value[key] is String,
				"ConditionConfigList paths must be Dictionary<String, String>")
		_paths = value

## Cache of loaded condition instances
var conditions: Dictionary = {}

## Loads all conditions from their saved paths
func load_conditions() -> void:
	assert(false) # depreciated conditions -> remove

	conditions.clear()
	for condition_name in _paths:
		var condition = load(_paths[condition_name]) as ConditionConfig
		if condition:
			conditions[condition_name] = condition

## Required for proper serialization of dictionary property
func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "condition_paths",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Dictionary<String, String>"
	}]

## Override _init to ensure dictionary is initialized
func _init():
	if condition_paths == null:
		condition_paths = {}
