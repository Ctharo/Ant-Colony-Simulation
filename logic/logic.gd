class_name Logic
extends Resource

@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

@export_multiline var expression_string: String
@export var nested_expressions: Array[Logic]
@export var description: String

@export_enum("BOOL", "INT", "FLOAT", "STRING", "VECTOR2", "VECTOR3", "ARRAY", "DICTIONARY",
			 "FOOD", "ANT", "COLONY", "PHEROMONE", "ITERATOR", "FOODS", "PHEROMONES",
			 "COLONIES", "ANTS", "OBJECT", "UNKNOWN")
var type: int = 19

var id: String
var _last_value: Variant

signal value_changed(new_value: Variant, expression_id: String)

## If there are no nested expressions and no caching is desired,
## this indicates the expression should be evaluated every time
var always_evaluate: bool:
	get:
		return nested_expressions.is_empty()

func set_value(new_value: Variant) -> void:
	if _last_value != new_value:
		_last_value = new_value
		value_changed.emit(new_value, id)

func get_value(eval_system: EvaluationSystem, force_update: bool = false) -> Variant:
	var result = eval_system.get_value(self, force_update)
	if result != _last_value:
		set_value(result)
	return result

func _get_property_list() -> Array:
	return [{
		"name": "_runtime_state",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE
	}]
