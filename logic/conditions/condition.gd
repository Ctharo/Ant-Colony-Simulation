class_name Condition

## Signals
signal evaluation_changed(is_met: bool)

## Properties
@export var name: String
@export var config: ConditionConfig
var previous_result: bool = false
var _required_properties: Array[Path] = []

## Get list of required property paths
func get_required_properties() -> Array[String]:
	var props: Array[String] = []
	for path in _required_properties:
		props.append(path.full)
	return props

## Register a required property path
func register_required_property(property_path: String) -> void:
	var path := Path.parse(property_path)
	if not _required_properties.has(path):
		_required_properties.append(path)
