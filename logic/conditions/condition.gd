class_name Condition
extends RefCounted

## Signal emitted when condition evaluation changes
signal evaluation_changed(is_met: bool)

## Previous evaluation result for change detection
var _previous_result: bool = false

## Configuration for this condition
var config: Dictionary = {}
var _required_properties: Array[Path] = []

func get_required_properties() -> Array[String]:
	var props: Array[String] = []
	for path in _required_properties:
		props.append(path.full)
	return props

func _register_required_property(property_path: String) -> void:
	var path := Path.parse(property_path)
	if not _required_properties.has(path):
		_required_properties.append(path)

## Evaluate if the condition is met
## @param ant The ant to evaluate for
## @param cache Dictionary to cache results
## @param context Dictionary containing context parameters
## @return Whether the condition is met
func is_met(_cache: Dictionary, context: Dictionary) -> bool:
	var result := ConditionEvaluator.new(context).evaluate(config, context)

	if result != _previous_result:
		_previous_result = result
		evaluation_changed.emit(result)

	return result

## Create a condition from configuration
## @param condition_config The configuration dictionary
## @return The configured condition
static func create_from_config(condition_config: Dictionary) -> Condition:
	var condition = new()
	condition.config = condition_config
	return condition
