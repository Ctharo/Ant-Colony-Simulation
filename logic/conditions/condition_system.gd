class_name ConditionSystem
extends RefCounted

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

## Required properties for evaluation
var _required_properties: Dictionary = {}

## Static condition configuration registry
static var _condition_configs: Dictionary

## Evaluation context stack for nested conditions
var _evaluation_stack: Array[String] = []

var logger: Logger
#endregion

#region Initialization
func _init(p_ant: Ant) -> void:
	logger = Logger.new("condition_system", DebugLogger.Category.CONDITION)
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

	if not json.data.has("conditions"):
		push_error("JSON file does not contain 'conditions' key")
		return ERR_INVALID_DATA

	_condition_configs = json.data.conditions
	return OK

static func load_condition_configs_from_dict(config: Dictionary) -> Error:
	if not config.has("conditions"):
		push_error("Config dictionary does not contain 'conditions' key")
		return ERR_INVALID_DATA

	_condition_configs = config.conditions
	return OK
#endregion

#region Public Methods
## Evaluates a condition based on its configuration
func evaluate_condition(condition: Condition, context: Dictionary) -> bool:
	if condition == null:
		logger.error("Attempted to evaluate null condition")
		return false

	var _result := _evaluate_condition_config(condition.config, context)
	var previous = condition.previous_result
	
	if _result != previous:
		condition.previous_result = _result
		evaluation_changed.emit(condition, _result)
		logger.info("Condition changed: %s -> %s | %s" % [
			previous,
			_result
		])

	return _result

## Gets a list of all required property paths
func get_required_properties() -> Array[String]:
	var a: Array[String] = []
	for key in _required_properties.keys():
		a.append(key as String)
	return a

## Gets context value for a property path
func get_property_value(path: Path) -> Variant:
	if not path.full in _required_properties:
		logger.warn("Accessing unrequired property '%s'" % path.full)
		return null

	var value = get_property_value(path)
	if value != null:
		logger.trace("Retrieved value for property '%s' = %s" % [path.full, str(value)])

	return value
	
## Creates a condition instance from configuration
static func create_condition(config: Dictionary) -> Condition:
	if typeof(config) != TYPE_DICTIONARY:
		DebugLogger.error(DebugLogger.Category.CONDITION, "Invalid condition config type: %s" % typeof(config), {"from": "condition_system"})
		return null

	var condition = Condition.new()

	# Handle named conditions from the registry
	if config.has("type") and config.type in _condition_configs:
		var base_config = _condition_configs[config.type]
		# Create a copy of the base config
		var merged_config = base_config.duplicate(true)
		# Override with any provided config values
		for key in config:
			if key != "type":
				merged_config[key] = config[key]
		condition.config = merged_config
		return condition

	# Handle operator conditions or direct property checks
	condition.config = config
	return condition
#endregion

#region Private Methods
## Format context chain for logging
func _format_context_chain() -> String:
	if _evaluation_stack.is_empty():
		return ""

	var formatted_parts = []
	var depth = 0

	for part in _evaluation_stack:
		var prefix = "    ".repeat(depth)  # Increased indent for better readability

		# Special formatting for different condition types
		if part.begins_with("NOT operator"):
			formatted_parts.append("%s↳ %s" % [prefix, part])
		elif part.begins_with("AND operator") or part.begins_with("OR operator"):
			formatted_parts.append("%s↳ %s" % [prefix, part])
		elif part.begins_with("Named condition"):
			formatted_parts.append("%s→ %s" % [prefix, part])
		elif part.begins_with("Property check"):
			formatted_parts.append("%s• %s" % [prefix, part])
		else:
			formatted_parts.append("%s  %s" % [prefix, part])

		depth += 1

	return "\nContext:\n%s" % "\n".join(formatted_parts)



## Push condition to evaluation stack
func _push_evaluation_context(description: String) -> void:
	_evaluation_stack.append(description)
	if _evaluation_stack.size() > 1:
		var indent = "  ".repeat(_evaluation_stack.size() - 1)
		logger.debug("%s→ Evaluating: %s" % [indent, description])

## Pop condition from evaluation stack
func _pop_evaluation_context() -> void:
	if not _evaluation_stack.is_empty():
		_evaluation_stack.pop_back()

## Get current evaluation context
func _get_current_context() -> String:
	if _evaluation_stack.is_empty():
		return ""
	return " (in context: %s)" % " → ".join(_evaluation_stack)

func _evaluate_condition_config(config: Dictionary, context: Dictionary) -> bool:
	var condition_name = config.get("type", "Anonymous")
	var evaluation = config.get("evaluation", {})
	var used_properties = []
	
	if evaluation.has("property"):
		used_properties.append(evaluation.property)
	if evaluation.has("value_from"):
		used_properties.append(evaluation.value_from)
		
	logger.info("Evaluating condition: %s" % condition_name)
	logger.debug("Context properties used: %s" % str(used_properties))
	
	if used_properties:
		for prop in used_properties:
			var value = context.get(prop, null)
			logger.debug("  %s = %s" % [prop, str(value)])
	
	var result = _evaluate_condition_config_internal(config, context)
	logger.info("Condition %s result: %s" % [condition_name, result])
	return result

func _evaluate_condition_config_internal(config: Dictionary, context: Dictionary) -> bool:
	if config.has("type") and config.type == "Operator":
		return _evaluate_operator_condition(config, context)
	elif config.has("type") and config.type in _condition_configs:
		_push_evaluation_context("Named condition: %s" % config.type) 
		var base_config = _condition_configs[config.type]
		var result = _evaluate_condition_config_internal(base_config, context)
		_pop_evaluation_context()
		return result
	elif config.has("evaluation"):
		return _evaluate_property_check(config.evaluation, context)
	elif config.has("property"):
		return _evaluate_property_check(config, context)
		
	logger.error("Invalid condition format")
	return false

## Evaluates property check conditions with consolidated logging
func _evaluate_property_check(evaluation: Dictionary, context: Dictionary) -> bool:
	if not evaluation.has("property"):
		logger.error("Property check missing 'property' field")
		return false

	var operator = evaluation.get("operator", "EQUALS")
	var op_symbol = OPERATOR_MAP.get(operator, "==")
	_push_evaluation_context("Property check: %s %s" % [evaluation.property, operator])

	# Get first value
	var value_a = context.get(evaluation.property)
	if value_a == null and not operator in ["IS_EMPTY", "NOT_EMPTY"]:
		logger.error("Failed to retrieve property: %s" % evaluation.property)
		_pop_evaluation_context()
		return false

	# Get comparison value
	var value_b = null
	if "value" in evaluation:
		value_b = evaluation.value
	elif "value_from" in evaluation:
		value_b = context.get(evaluation.value_from)
		if value_b == null:
			logger.error("Failed to retrieve comparison property: %s" % evaluation.value_from)
			_pop_evaluation_context()
			return false
	elif not operator in ["IS_EMPTY", "NOT_EMPTY"]:
		logger.error("Invalid property check: missing comparison value")
		_pop_evaluation_context()
		return false

	var result = _compare_values(value_a, value_b, operator)
	_log_evaluation_block("Property Check", value_a, op_symbol, value_b, result)
	_pop_evaluation_context()
	return result

## Evaluates operator conditions with consolidated logging
func _evaluate_operator_condition(config: Dictionary, context: Dictionary) -> bool:
	if not config.has("operator_type"):
		logger.error("Operator condition missing operator_type")
		return false

	var operator_type = config.operator_type.to_lower()
	var operands = config.get("operands", [])

	if operands.is_empty():
		logger.error("Operator condition has no operands")
		return false

	_push_evaluation_context("%s operator with %d operands" % [operator_type.to_upper(), operands.size()])

	var result := false
	match operator_type:
		"and":
			result = _evaluate_and_operator(operands, context)
		"or":
			result = _evaluate_or_operator(operands, context)
		"not":
			result = _evaluate_not_operator(operands, context)
		_:
			logger.error("Unknown operator type: %s" % operator_type)

	var message = "\n%s Operator Evaluation:" % operator_type.to_upper()
	message += "\n    Result: %s" % result
	message += _format_context_chain()
	logger.debug(message)

	_pop_evaluation_context()
	return result

## Helper function for AND operator evaluation
func _evaluate_and_operator(operands: Array, context: Dictionary) -> bool:
	for i in range(operands.size()):
		_push_evaluation_context("Operand %d of %d" % [i + 1, operands.size()])
		if not _evaluate_condition_config(operands[i], context):
			_pop_evaluation_context()
			return false
		_pop_evaluation_context()
	return true

## Helper function for OR operator evaluation
func _evaluate_or_operator(operands: Array, context: Dictionary) -> bool:
	for i in range(operands.size()):
		_push_evaluation_context("Operand %d of %d" % [i + 1, operands.size()])
		if _evaluate_condition_config(operands[i], context):
			_pop_evaluation_context()
			return true
		_pop_evaluation_context()
	return false

## Helper function for NOT operator evaluation
func _evaluate_not_operator(operands: Array, context: Dictionary) -> bool:
	if operands.size() != 1:
		logger.error("NOT operator requires exactly one operand")
		return false

	_push_evaluation_context("Evaluating condition to negate")
	var original = _evaluate_condition_config(operands[0], context)
	var result = not original

	var message = "\nNOT Operator Evaluation:"
	message += "\n    Original: %s" % original
	message += "\n    Result:   %s" % result
	message += _format_context_chain()
	logger.debug(message)

	_pop_evaluation_context()
	return result

## Compares two values using the specified operator
func _compare_values(value_a: Variant, value_b: Variant, operator: String) -> bool:
	var eval_operator = OPERATOR_MAP.get(operator)
	if not eval_operator:
		logger.error("Unknown operator: %s" % operator)
		return false

	var compare_func = COMPARISON_OPERATORS.get(eval_operator)
	if not compare_func:
		logger.error("Missing comparison function for operator: %s" % eval_operator)
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
		logger.warn("Cannot register root path as required property")
		return

	_required_properties[path.full] = path
	logger.trace("Registered required property: %s" % path.full)

## Generates cache key for condition evaluation
func _get_condition_cache_key(condition: Condition, context: Dictionary) -> String:
	var key_parts = []

	# Add condition description if available
	if condition.config.has("description"):
		key_parts.append(condition.config.description)

	# Add evaluation details
	if condition.config.has("evaluation"):
		var eval = condition.config.evaluation
		if eval.has("property"):
			var op_str = OPERATOR_MAP.get(eval.get("operator", "EQUALS"), "==")
			var value_str = ""
			if "value" in eval:
				value_str = str(eval.value)
			elif "value_from" in eval:
				value_str = "from:" + eval.value_from
			key_parts.append("%s %s %s" % [eval.property, op_str, value_str])

	# Add context values for properties
	var context_parts = []
	for property in condition.get_required_properties():
		var path := Path.parse(property)
		if context.has(path.full):
			context_parts.append("%s=%s" % [path.full, context[path.full]])

	var key = " | ".join(key_parts)
	if not context_parts.is_empty():
		key += " [Context: %s]" % ", ".join(context_parts)

	return key

## Log condition evaluation with consolidated messages
func _log_evaluation_block(operation: String, value_a: Variant, operator: String, value_b: Variant, result: bool) -> void:
	var context = _format_context_chain()
	var message = "\nCondition Evaluation:"
	message += "\n    Operation: %s" % operation
	message += "\n    Compare:   %s %s %s" % [str(value_a), operator, str(value_b)]
	message += "\n    Result:    %s" % result
	if not context.is_empty():
		message += context
	logger.debug(message)

## Log condition evaluation with formatted context
func _log_condition_evaluation(message: String, level: String = "debug") -> void:
	var context = _format_context_chain()
	var log_message = message

	if not context.is_empty():
		log_message += context

	match level:
		"debug":
			logger.debug(log_message)
		"trace":
			logger.trace(log_message)
		"info":
			logger.info(log_message)
		"error":
			logger.error(log_message)


## Logs registered required properties
func _log_required_properties() -> void:
	var properties = _required_properties.keys()
	if properties.is_empty():
		return

	var formatted_list = ""
	for prop in properties:
		formatted_list += "\n  - " + str(prop)
	logger.debug("Required properties:%s" % formatted_list)
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
