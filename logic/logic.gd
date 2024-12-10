class_name Logic
extends Resource
## Base class for logic expressions. Instance safety is handled by EvaluationSystem -
## each ant will get its own EvaluationSystem which creates unique Logic instances,
## so no additional instance state management is needed in this class.

#region Properties
## Unique identifier for this expression
var id: String

## Human readable name
@export var name: String :
	set(value):
		name = value
		id = name.to_snake_case()

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

## The base node for evaluating expressions
var base_node: Node

## Evaluation system reference
var evaluation_system: EvaluationSystem:
	set(value):
		evaluation_system = value

var logger: Logger

## Cached expression result
var _cache: Variant

## Flag for cache invalidation
var _dirty: bool = true

## Expression object for evaluation
var _expression: Expression = Expression.new()

## Flag indicating if expression is successfully parsed
var is_parsed: bool = false

## Dictionary to store runtime state for serialization
@export var _runtime_state: Dictionary = {}
#endregion

#region Signals
## Emitted when the expression value changes
signal value_changed(new_value: Variant)

## Emitted when properties or nested expressions are modified
signal dependencies_changed
#endregion

#region Public Methods
## Initialize the expression with a base node and evaluation system
func initialize(p_base_node: Node, p_evaluation_system: EvaluationSystem) -> void:
	# Only initialize if needed
	if base_node == p_base_node and evaluation_system == p_evaluation_system and is_parsed:
		return
		
	base_node = p_base_node
	evaluation_system = p_evaluation_system
	
	if name.is_empty():
		assert(name, "Expression name cannot be empty")
		logger.error("Expression name cannot be empty")
		return
		
	id = name.to_snake_case()
	if not logger:  # Only create logger once
		logger = Logger.new("expression_%s" % id, DebugLogger.Category.LOGIC)
	

	# Only parse if not already parsed
	if not is_parsed:
		parse_expression()
	
	_save_runtime_state()

## Get the current value of the expression
func get_value() -> Variant:
	# Always use evaluation system if available
	if evaluation_system:
		return evaluation_system.get_value(id)
		
	# Otherwise fall back to local calculation
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
func _calculate() -> Variant:
	if not is_parsed or not base_node:
		logger.error("Expression not ready: %s" % expression_string)
		return null
	
	logger.debug("Calculating expression: %s" % expression_string)
	
	var bindings = []
	
	# Get values for each nested expression name in our parse list
	for expr in nested_expressions:
		var value = expr.get_value()
		if value == null:
			logger.error("Could not get value for nested expression: %s" % expr.name)
			return null
			
		bindings.append(value)
		logger.trace("Added binding for %s: %s" % [expr.id, str(value)])
	
	logger.trace("Final bindings array: %s" % str(bindings))
	
	# Execute expression with the cached values
	var result = _expression.execute(bindings, base_node)
	if _expression.has_execute_failed():
		var error_msg = "Failed to execute expression: %s\nError: %s" % [
			expression_string, 
			_expression.get_error_text()
		]
		logger.error(error_msg)
		push_error(error_msg)
		return null
	
	logger.debug("Expression result: %s" % str(result.size()) + " values in array" if result is Array else str(result))
	return result

func parse_expression() -> void:
	if is_parsed:
		logger.debug("Expression already parsed, skipping: %s" % expression_string)
		return
		
	if expression_string.is_empty():
		assert(expression_string, "Empty expression string")
		logger.error("Empty expression string")
		return
	
	logger.debug("Parsing expression: %s" % expression_string)
	
	# Create array of names - these will be used as variable names in expression
	var variable_names = []
	
	# Add each nested expression name - order must match execute bindings array
	for expr in nested_expressions:
		variable_names.append(expr.id)
		logger.trace("Added variable name: %s" % expr.id)
	
	logger.trace("Variable names array: %s" % str(variable_names))
	
	# Parse with ordered variable names array
	var error = _expression.parse(expression_string, PackedStringArray(variable_names))
	if error != OK:
		var error_msg = "Failed to parse expression: %s\nError: %s" % [
			expression_string,
			_expression.get_error_text()
		]
		logger.error(error_msg)
		return
	
	logger.trace("Successfully parsed expression")
	is_parsed = true

## Handle property value changes
func _on_property_changed(_value: Variant) -> void:
	invalidate()

## Handle nested expression value changes
func _on_nested_expression_changed(_value: Variant) -> void:
	invalidate()

func _save_runtime_state() -> void:
	_runtime_state = {
		"evaluation_system_connected": evaluation_system != null,
		"is_parsed": is_parsed,
		"has_base_node": base_node != null,
		"name": name,
		"id": id
	}

func _restore_runtime_state() -> void:
	if not _runtime_state.is_empty():
		is_parsed = _runtime_state.get("is_parsed", false)
		# Don't restore null references, they'll be set during initialization
		if _runtime_state.get("name"):
			name = _runtime_state.get("name")
		if _runtime_state.get("id"):
			id = _runtime_state.get("id")

func _post_load() -> void:
	# Clear runtime references
	evaluation_system = null
	base_node = null
	_dirty = true
	is_parsed = false
	_cache = null
	
	# Reset nested expressions
	for nested in nested_expressions:
		nested._post_load()
	
	# Restore saved state
	_restore_runtime_state()

func _get_property_list() -> Array:
	var props = []
	props.append({
		"name": "_runtime_state",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE
	})
	return props
#endregion
