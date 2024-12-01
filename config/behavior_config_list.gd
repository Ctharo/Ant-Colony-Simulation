class_name BehaviorConfigList
extends Resource

## Dictionary mapping behavior names to their resource paths
@export var _paths: Dictionary = {} :
	get:
		return _paths
	set(value):
		_paths = value
		# Validate dictionary entries are strings
		for key in value:
			assert(key is String and value[key] is String,
				"BehaviorConfigList paths must be Dictionary<String, String>")

## Public interface to access paths
var behavior_paths: Dictionary:
	get: return _paths
	set(value):
		for key in value:
			assert(key is String and value[key] is String,
				"BehaviorConfigList paths must be Dictionary<String, String>")
		_paths = value

## Dictionary of loaded behavior instances
var behaviors: Dictionary = {}

## Loads all behaviors from their saved paths
func load_behaviors() -> void:
	behaviors.clear()
	for behavior_name in _paths:
		var behavior = load(_paths[behavior_name]) as BehaviorConfig
		if behavior:
			behaviors[behavior_name] = behavior

## Required for proper serialization of dictionary property
func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "_paths",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Dictionary<String, String>"
	}]

## Override _init to ensure dictionary is initialized
func _init():
	if _paths == null:
		_paths = {}
