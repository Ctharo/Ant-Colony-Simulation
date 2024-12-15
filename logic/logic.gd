class_name Logic
extends Resource

@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()

@export_enum("BOOL", "INT", "FLOAT", "STRING", "VECTOR2", "VECTOR3", "ARRAY", "DICTIONARY",
			 "FOOD", "ANT", "COLONY", "PHEROMONE", "ITERATOR", "FOODS", "PHEROMONES",
			 "COLONIES", "ANTS", "OBJECT", "UNKNOWN") var type: int = 19
@export_multiline var expression_string: String
@export var nested_expressions: Array[Logic]
@export var description: String

var id: String

signal value_changed(new_value: Variant)
signal dependencies_changed

## Get the current value of the expression
func get_value(eval_system: EvaluationSystem, force_update: bool = false) -> Variant:
	return eval_system.get_value(self, force_update)

func _get_property_list() -> Array:
	var props = []
	props.append({
		"name": "_runtime_state",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE
	})
	return props
