class_name Condition
extends Resource

#region Properties
## Unique identifier
@export var id: String
## Human readable name
@export var name: String
## Description of what this condition represents
@export var description: String
## The logic expression that determines if condition is met
@export var logic_expression: LogicExpression
## Previous evaluation result for change detection
var previous_result: bool = false
#endregion

#region Signals
signal evaluation_changed(is_met: bool)
#endregion

func _init() -> void:
	assert(false) # depreciated conditions -> remove


#region Public Methods
## Initialize the condition
func initialize(entity: Node) -> void:
	if logic_expression:
		logic_expression.initialize(entity)
		if not logic_expression.is_connected("value_changed", _on_logic_changed):
			logic_expression.connect("value_changed", _on_logic_changed)

## Check if condition is currently met
func is_met() -> bool:
	if not logic_expression or not logic_expression.is_valid():
		return false

	var result = logic_expression.evaluate()
	if typeof(result) != TYPE_BOOL:
		push_error("Condition logic must return boolean: %s" % name)
		return false

	if result != previous_result:
		previous_result = result
		evaluation_changed.emit(result)

	return result

## Get list of required property paths
func get_required_properties() -> Array[String]:
	if not logic_expression:
		return []

	var props: Array[String] = []
	for path in logic_expression.required_properties:
		props.append(path.full)
	return props
#endregion

#region Private Methods
## Handle logic expression value changes
func _on_logic_changed(value: Variant) -> void:
	if typeof(value) == TYPE_BOOL and value != previous_result:
		previous_result = value
		evaluation_changed.emit(value)
#endregion
