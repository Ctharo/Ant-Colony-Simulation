class_name LogicExpression
extends Resource

#region Properties
## Unique identifier for this expression
var id: String

## Human readable name
@export var name: String :
	set(value):
		name = value
		id = name.to_camel_case()

## The expression string to evaluate
@export_multiline var expression_string: String

## Description of what this expression does
@export var description: String

## Type of value this expression returns
@export_enum("BOOL", "INT", "FLOAT", "STRING", "VECTOR2", "VECTOR3", "ARRAY", "DICTIONARY", 
			 "FOOD", "ANT", "COLONY", "PHEROMONE", "ITERATOR", "FOODS", "PHEROMONES", 
			 "COLONIES", "ANTS", "OBJECT", "UNKNOWN") var type: int = 19  # UNKNOWN


## Array of LogicExpression resources to use as nested expressions
@export var nested_expressions: Array[LogicExpression]

## The base node for evaluating expressions
var base_node: Node

## Cached expression result
var _cache: Variant

## Flag for cache invalidation
var _dirty: bool = true

## Expression object for evaluation
var _expression: Expression = Expression.new()

## Flag indicating if expression is successfully parsed
var is_parsed: bool = false
#endregion

#region Signals
## Emitted when the expression value changes
signal value_changed(new_value: Variant)

## Emitted when properties or nested expressions are modified
signal dependencies_changed
#endregion

#region Public Methods
## Initialize the expression with a base node for property resolution
func initialize(p_base_node: Node) -> void:
	base_node = p_base_node
	_dirty = true
	
	if name.is_empty():
		push_error("Expression name cannot be empty")
		return
		
	id = name.to_snake_case()
	
	# Initialize all nested expressions
	for expr in nested_expressions:
		expr.initialize(base_node)
		if not expr.value_changed.is_connected(_on_nested_expression_changed):
			expr.value_changed.connect(_on_nested_expression_changed)
	
	parse_expression()

## Get the current value of the expression
func get_value() -> Variant:
	if _dirty or _cache == null:
		_cache = _calculate()
		_dirty = false
	return _cache

## Force recalculation on next get_value() call
func invalidate() -> void:
	_dirty = true
	value_changed.emit(get_value())

## Get a formatted string representation of the value
func get_display_value() -> String:
	var value = get_value()
	match type:
		8, 9, 10, 11:  # FOOD, ANT, COLONY, PHEROMONE
			return str(value.name) if value else "null"
		_:
			return str(value)
#endregion

#region Protected Methods
## Calculate the expression value
func _calculate() -> Variant:
	if not is_parsed or not base_node:
		push_error("Expression not ready: %s" % expression_string)
		return null
	
	# Create variable bindings array
	var bindings = []
	
	# Add nested expression values
	for expr in nested_expressions:
		var value = expr.get_value()
		if value == null:
			push_error("Could not get value for nested expression: %s" % expr.name)
			return null
		bindings.append(value)
	
	# Execute expression with bindings
	var result = _expression.execute(bindings, base_node)
	if _expression.has_execute_failed():
		push_error("Failed to execute expression: %s\nError: %s" % [
			expression_string, 
			_expression.get_error_text()
		])
		return null
	
	return result

## Parse the expression string
func parse_expression() -> void:
	if expression_string.is_empty():
		push_error("Empty expression string")
		return
	
	# Create array of variable names
	var variable_names = []
		
	# Add nested expression names
	for expr in nested_expressions:
		variable_names.append(expr.id)
	
	# Parse the expression
	var error = _expression.parse(expression_string, PackedStringArray(variable_names))
	if error != OK:
		push_error("Failed to parse expression: %s\nError: %s" % [
			expression_string,
			_expression.get_error_text()
		])
		return
	
	is_parsed = true

## Handle property value changes
func _on_property_changed(_value: Variant) -> void:
	invalidate()

## Handle nested expression value changes
func _on_nested_expression_changed(_value: Variant) -> void:
	invalidate()
#endregion
