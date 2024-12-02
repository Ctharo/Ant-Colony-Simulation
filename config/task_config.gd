class_name TaskConfig
extends Resource

@export var name: String
@export var priority: String = "MEDIUM"
@export var conditions: Array[ConfigBase]
@export var behaviors: Array[BehaviorConfig]

func _get_property_list() -> Array:
	return [
		{
			"name": "conditions",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "behaviors",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE
		}
	]
