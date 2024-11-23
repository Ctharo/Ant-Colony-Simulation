class_name ConditionSystem
extends BaseRefCounted

#region Signals
## Emitted when any condition evaluation changes
signal evaluation_changed(condition: Condition, is_met: bool)
#endregion

#region Constants
## Mapping of operator names to comparison symbols
const OPERATOR_MAP = {
	"EQUALS": "==",
	"NOT_EQUALS": "!=",
	"GREATER_THAN": ">",
	"LESS_THAN": "<",
	"GREATER_THAN_EQUAL": ">=",
	"LESS_THAN_EQUAL": "<=",
	"CONTAINS": "contains",
	"STARTS_WITH": "starts_with",
	"ENDS_WITH": "ends_with",
	"IS_EMPTY": "is_empty",
	"NOT_EMPTY": "not_empty"
}

## Comparison functions for different operators
var COMPARISON_OPERATORS = {
	"==": func(a, b): return a == b,
	"!=": func(a, b): return a != b,
	">": func(a, b): return a > b if _are_comparable(a, b) else false,
	"<": func(a, b): return a < b if _are_comparable(a, b) else false,
	">=": func(a, b): return a >= b if _are_comparable(a, b) else false,
	"<=": func(a, b): return a <= b if _are_comparable(a, b) else false,
	"contains": func(a, b): return _contains_value(a, b),
	"starts_with": func(a, b): return str(a).begins_with(str(b)) if a != null and b != null else false,
	"ends_with": func(a, b): return str(a).ends_with(str(b)) if a != null and b != null else false,
	"is_empty": func(a, _b): return _is_empty(a),
	"not_empty": func(a, _b): return not _is_empty(a)
}
#endregion

#region Properties
## Property access manager
var _property_access: PropertyAccess

## Cache for condition results
var _condition_cache: Dictionary = {}

## Required properties for evaluation
var _required_properties: Dictionary = {}

## Static condition configuration registry
static var _condition_configs: Dictionary
#endregion

#region Initialization
func _init(p_ant: Ant) -> void:
	log_category = DebugLogger.Category.CONDITION
	log_from = "condition_system"
	_property_access = p_ant._property_access
	if not _condition_configs.is_empty():
		register_required_properties()

## Load condition configurations from JSON file
static func load_condition_configs(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open conditions config: %s" % path)
		return ERR_FILE_NOT_FOUND
		
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	if result != OK:
		push_error("Failed to parse conditions JSON: %s" % json.get_error_message())
		return result
		
	_condition_configs = json.data.conditions
	return OK
#endregion

#region Public Methods
## Evaluates a condition based on its configuration
func evaluate_condition(condition: Condition, context: Dictionary) -> bool:
	if condition == null:
		_error("Attempted to evaluate null condition")
		return false
		
	var cache_key = _get_condition_cache_key(condition, context)

	if _condition_cache.has(cache_key):
		return _condition_cache[cache_key]

	var result := _evaluate_condition_config(condition.config, context)
	_condition_cache[cache_key] = result

	if result != condition.previous_result:
		condition.previous_result = result
		evaluation_changed.emit(condition, result)

	return result
	
## Clears the condition evaluation cache
func clear_cache() -> void:
	_condition_cache.clear()

## Gets a list of all required property paths
func get_required_properties() -> Array[String]:
	var a: Array[String] = []
	for key in _required_properties.keys():
		a.append(key as String)
	return a

## Gets context value for a property path
func get_property_value(path: Path) -> Variant:
	if not path.full in _required_properties:
		_warn("Accessing unrequired property '%s'" % path.full)
		return null

	var node: PropertyNode = _property_access.find_property_node(path)
	if not node:
		_error("Path may be incorrect, no node found at path %s" % path.full)
		return null

	var value = _property_access.get_property_value(path)
	if value != null:
		_trace("Evaluated property '%s' = %s" % [path.full, str(value)])

	return value

## Creates a condition instance from configuration
static func create_condition(config: Dictionary) -> Condition:
	if typeof(config) == TYPE_DICTIONARY and config.has("type"):
		var condition_type = config.type
		
		# Handle operator conditions directly
		if condition_type == "Operator":
			var condition = Condition.new()
			condition.config = config
			return condition
			
		# Handle named conditions from the registry
		if condition_type in _condition_configs:
			var base_config = _condition_configs[condition_type]
			# Create a copy of the base config
			var merged_config = base_config.duplicate(true)
			# Override with any provided config values
			for key in config:
				if key != "type":
					merged_config[key] = config[key]
					
			var condition = Condition.new()
			condition.config = merged_config
			return condition
			
		push_error("Unknown condition type: %s" % condition_type)
		return null
		
	# Handle direct property checks or other condition formats
	var condition = Condition.new()
	condition.config = config
	return condition
#endregion

#region Private Methods
## Evaluates condition configuration recursively
func _evaluate_condition_config(config: Dictionary, context: Dictionary) -> bool:
	# Handle operator conditions (AND, OR, NOT)
	if config.get("type") == "Operator":
		return _evaluate_operator_condition(config, context)

	# Handle property checks
	if config.has("evaluation"):
		return _evaluate_property_check(config.evaluation, context)
	elif config.has("property"):
		return _evaluate_property_check(config, context)

	_error("Invalid condition format: %s" % config)
	return false

## Evaluates operator conditions (AND, OR, NOT)
func _evaluate_operator_condition(config: Dictionary, context: Dictionary) -> bool:
	var operator_type = config.operator_type.to_lower()
	var operands = config.get("operands", [])

	_debug("\nEvaluating %s operator" % operator_type.to_upper())

	match operator_type:
		"and":
			for operand in operands:
				if not _evaluate_condition_config(operand, context):
					return false
			return true

		"or":
			for operand in operands:
				if _evaluate_condition_config(operand, context):
					return true
			return false

		"not":
			if operands.size() != 1:
				_error("NOT operator requires exactly one operand")
				return false
			return not _evaluate_condition_config(operands[0], context)

		_:
			_error("Unknown operator type: %s" % operator_type)
			return false

## Evaluates property check conditions
func _evaluate_property_check(evaluation: Dictionary, _context: Dictionary) -> bool:
	if not evaluation.has("property"):
		_error("Property check missing 'property' field: %s" % evaluation)
		return false

	var path = Path.parse(evaluation.property)
	var operator = evaluation.get("operator", "EQUALS")

	# Get first value
	var value_a = _property_access.get_property_value(path)
	if value_a == null:
		_error("Problem retrieving property: %s" % path.full)
		return false

	# Get comparison value if needed
	var value_b: Variant
	if "value" in evaluation:
		value_b = evaluation.value
	elif "value_from" in evaluation:
		var compare_path = Path.parse(evaluation.value_from)
		value_b = _property_access.get_property_value(compare_path)
		if value_b == null:
			_error("Problem retrieving comparison property: %s" % compare_path.full)
			return false
	else:
		# Special operators that don't need a second value
		if operator in ["IS_EMPTY", "NOT_EMPTY"]:
			value_b = null
		else:
			_error("Invalid property check configuration: %s" % evaluation)
			return false

	return _compare_values(value_a, value_b, operator)

## Compares two values using the specified operator
func _compare_values(value_a: Variant, value_b: Variant, operator: String) -> bool:
	var eval_operator = OPERATOR_MAP.get(operator)
	if not eval_operator:
		_error("Unknown operator: %s" % operator)
		return false

	var compare_func = COMPARISON_OPERATORS.get(eval_operator)
	if not compare_func:
		_error("Missing comparison function for operator: %s" % eval_operator)
		return false

	return compare_func.call(value_a, value_b)

## Register properties from condition configuration
func register_required_properties() -> void:
	for condition_name in _condition_configs:
		var config = _condition_configs[condition_name]
		_register_config_properties(config)
	_log_required_properties()

## Register properties from a config recursively
func _register_config_properties(config: Dictionary) -> void:
	if config.get("type") == "Operator":
		if config.has("operands"):
			for operand in config.operands:
				_register_config_properties(operand)
	else:
		if "evaluation" in config:
			_register_properties_from_evaluation(config.evaluation)
		elif config.has("property"):
			_register_properties_from_evaluation(config)

## Registers properties from evaluation configuration
func _register_properties_from_evaluation(evaluation: Dictionary) -> void:
	if "property" in evaluation:
		_register_property(evaluation.property)
	if "value_from" in evaluation:
		_register_property(evaluation.value_from)

## Registers a single property path
func _register_property(property_path_str: String) -> void:
	if property_path_str.is_empty():
		return

	var path := Path.parse(property_path_str)
	if path.is_root():
		_warn("Cannot register root path as required property")
		return

	_required_properties[path.full] = path
	_trace("Registered required property: %s" % path.full)

## Generates cache key for condition evaluation
func _get_condition_cache_key(condition: Condition, context: Dictionary) -> String:
	var condition_str = JSON.stringify(condition.config)
	var context_values = []

	for property in condition.get_required_properties():
		var path := Path.parse(property)
		if context.has(path.full):
			context_values.append("%s=%s" % [path.full, context[path.full]])

	return "%s|%s" % [condition_str, "|".join(context_values)]

## Logs registered required properties
func _log_required_properties() -> void:
	var properties = _required_properties.keys()
	if properties.is_empty():
		return

	var formatted_list = ""
	for prop in properties:
		formatted_list += "\n  - " + str(prop)
	_debug("Required properties:%s" % formatted_list)
#endregion

#region Static Helper Methods
## Checks if value is empty
static func _is_empty(value: Variant) -> bool:
	if value == null:
		return true

	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).is_empty()
		TYPE_DICTIONARY:
			return (value as Dictionary).is_empty()
		TYPE_STRING:
			return (value as String).is_empty()
		_:
			return false

## Checks if values are comparable
static func _are_comparable(a: Variant, b: Variant) -> bool:
	var type_a = typeof(a)
	var type_b = typeof(b)

	if type_a == type_b:
		return true

	if type_a in [TYPE_INT, TYPE_FLOAT] and type_b in [TYPE_INT, TYPE_FLOAT]:
		return true

	return false

## Checks if a value contains another value
static func _contains_value(container: Variant, value: Variant) -> bool:
	match typeof(container):
		TYPE_STRING:
			return (container as String).contains(str(value))
		TYPE_ARRAY:
			return (container as Array).has(value)
		TYPE_DICTIONARY:
			return (container as Dictionary).has(value)
	return false
#endregion

## Simplified Condition class
class Condition:
	extends RefCounted

	## Signals
	signal evaluation_changed(is_met: bool)

	## Properties
	var config: Dictionary = {}
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
