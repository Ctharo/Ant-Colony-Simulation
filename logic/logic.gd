class_name Logic
extends Resource

#region Properties
var id: String
@export var name: String
## Type of value this expression returns
@export_enum("BOOL", "INT", "FLOAT", "STRING", "VECTOR2", "VECTOR3", "ARRAY", "DICTIONARY",
			 "FOOD", "ANT", "COLONY", "PHEROMONE", "ITERATOR", "FOODS", "PHEROMONES",
			 "COLONIES", "ANTS", "OBJECT", "UNKNOWN") var type: int = 19  # UNKNOWN
## The expression string to evaluate
@export_multiline var expression_string: String
## Array of LogicExpression resources to use as nested expressions
@export var nested_expressions: Array[Logic]
## Description of what this expression does
@export var description: String
var _expression: Expression = Expression.new()
## Flag indicating if expression is successfully parsed
var is_parsed: bool = false

#region Signals
signal value_changed(new_value: Variant)
signal dependencies_changed
#endregion

func _init() -> void:
	id = str(get_instance_id())

func _ready() -> void:
	if id.is_empty():
		assert(false)
		id = str(get_instance_id())

func setup() -> void:
	if not is_parsed:
		parse_expression()

func _post_initialize() -> void:
	if expression_string and not is_parsed:
		parse_expression()

## Get the current value of the expression
func get_value(eval_system: EvaluationSystem, force_update: bool = false) -> Variant:
	return eval_system.get_value(id, force_update)

#endregion

#region Protected Methods
func _calculate(eval_system: EvaluationSystem) -> Variant:
	if not is_parsed:
		push_error("Expression not ready: %s" % expression_string)
		return null


	var bindings = []

	# Get values for each nested expression name in our parse list
	for expr in nested_expressions:
		var value = expr.get_value(eval_system)
		if value == null:
			push_error("Could not get value for nested expression: %s" % expr.name)
			return null

		bindings.append(value)

	# Execute expression with the cached values
	var result = _expression.execute(bindings, self)
	if _expression.has_execute_failed():
		var error_msg = "Failed to execute expression: %s\nError: %s" % [
			expression_string,
			_expression.get_error_text()
		]
		push_error(error_msg)
		return null

	return result

func parse_expression() -> void:
	if is_parsed:
		return

	if expression_string.is_empty():
		assert(expression_string, "Empty expression string")
		push_error("Empty expression string")
		return


	# Create array of names - these will be used as variable names in expression
	var variable_names = []

	# Add each nested expression name - order must match execute bindings array
	for expr in nested_expressions:
		variable_names.append(expr.id)


	# Parse with ordered variable names array
	var error = _expression.parse(expression_string, PackedStringArray(variable_names))
	if error != OK:
		var error_msg = "Failed to parse expression: %s\nError: %s" % [
			expression_string,
			_expression.get_error_text()
		]
		push_error(error_msg)
		assert(error == OK)
		return

	is_parsed = true

func _get_property_list() -> Array:
	var props = []
	props.append({
		"name": "_runtime_state",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE
	})
	return props
#endregion
