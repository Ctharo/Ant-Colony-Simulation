class_name ConditionSystem
extends RefCounted

#region Signals
signal evaluation_changed(condition: Condition, is_met: bool)
#endregion

#region Constants
const OPERATOR_MAP = {
	"EQUALS": "==", "NOT_EQUALS": "!=", "GREATER_THAN": ">",
	"LESS_THAN": "<", "GREATER_THAN_EQUAL": ">=", "LESS_THAN_EQUAL": "<=",
	"CONTAINS": "contains", "STARTS_WITH": "starts_with", "ENDS_WITH": "ends_with",
	"IS_EMPTY": "is_empty", "NOT_EMPTY": "not_empty"
}

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
var _required_properties: Dictionary = {}
var _evaluation_stack: Array[String] = []
var logger: Logger
#endregion

#region Initialization
func _init(p_ant: Ant) -> void:
	logger = Logger.new("condition_system", DebugLogger.Category.CONDITION)
	register_required_properties()
#endregion

#region Public Methods
func get_required_properties() -> Array[String]:
	var a: Array[String] = []
	for key in _required_properties.keys():
		a.append(key as String)
	return a
	
func evaluate_condition(condition: Condition, context: Dictionary) -> bool:
	if condition == null:
		logger.error("Attempted to evaluate null condition")
		return false
	var result := _evaluate_condition_config(condition.config, context)
	var previous = condition.previous_result
	if result != previous:
		condition.previous_result = result
		evaluation_changed.emit(condition, result)
	return result
#endregion

#region Evaluation Methods
func _evaluate_condition_config(config: Dictionary, context: Dictionary) -> bool:	
	var result = false
	match config.get("type"):
		"Custom": # Named condition
			result = _evaluate_named_condition(config, context)
		"Operator": # Operator
			result = _evaluate_operator(config, context)
		"PropertyCheck":
			result = _evaluate_property_check(config, context)
		_: # Property check
			logger.error("Unhandled config: %s" % config)
	return result

func _evaluate_named_condition(config: Dictionary, context: Dictionary) -> bool:
	var condition_name = config.get("name", "N/A")
	var condition_config: Dictionary = AntConfigs.get_condition_config(condition_name)
	var result = _evaluate_property_check(condition_config, context)
	return result

func _evaluate_operator(config: Dictionary, context: Dictionary) -> bool:
	var operator_type = config.operator_type.to_upper()
	var operands = config.get("operands", [])
	var result = false
	match operator_type:
		"AND":
			result = _evaluate_and_operator(operands, context)
		"OR": 
			result = _evaluate_or_operator(operands, context)
		"NOT": 
			result = _evaluate_not_operator(operands, context)
		_:
			logger.error("Unknown operator: %s" % operator_type)
	return result

func _evaluate_property_check(config: Dictionary, context: Dictionary) -> bool:
	var evaluation = config.get("evaluation", {})
	if evaluation.is_empty() or not evaluation.has("property"):
		logger.error("Invalid property check configuration")
		return false
	
	var operator = evaluation.get("operator", "EQUALS")
	var value_a = context.get(evaluation.property)
	var value_b = evaluation.get("value", context.get(evaluation.get("value_from", "")))
	
	var result = _compare_values(value_a, value_b, operator)
	return result

func _evaluate_and_operator(operands: Array, context: Dictionary) -> bool:
	for i in range(operands.size()):
		if not _evaluate_condition_config(operands[i], context):
			return false
	return true

func _evaluate_or_operator(operands: Array, context: Dictionary) -> bool:
	for i in range(operands.size()):
		if _evaluate_condition_config(operands[i], context):
			return true
	return false

func _evaluate_not_operator(operands: Array, context: Dictionary) -> bool:
	if operands.size() != 1:
		logger.error("NOT operator requires exactly one operand")
		return false
	var result = not _evaluate_condition_config(operands[0], context)
	return result
#endregion

#region Helper Methods
func _is_empty(value: Variant) -> bool:
	if value == null: return true
	match typeof(value):
		TYPE_ARRAY: return (value as Array).is_empty()
		TYPE_DICTIONARY: return (value as Dictionary).is_empty()
		TYPE_STRING: return (value as String).is_empty()
		_: return false

func _contains_value(container: Variant, value: Variant) -> bool:
	match typeof(container):
		TYPE_STRING: return (container as String).contains(str(value))
		TYPE_ARRAY: return (container as Array).has(value)
		TYPE_DICTIONARY: return (container as Dictionary).has(value)
		_: return false

func _are_comparable(a: Variant, b: Variant) -> bool:
	var type_a = typeof(a)
	var type_b = typeof(b)
	return type_a == type_b or (type_a in [TYPE_INT, TYPE_FLOAT] and type_b in [TYPE_INT, TYPE_FLOAT])

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
#endregion

#region Property Management
func register_required_properties() -> void:
	for condition_name in AntConfigs._condition_configs:
		var config = AntConfigs._condition_configs[condition_name]
		_register_config_properties(config)
	_log_required_properties()

func _register_config_properties(config: Dictionary) -> void:
	if config.get("type") == "Operator":
		for operand in config.get("operands", []):
			_register_config_properties(operand)
	else:
		if "evaluation" in config:
			_register_properties_from_evaluation(config.evaluation)
		elif config.has("property"):
			_register_properties_from_evaluation(config)

func _register_properties_from_evaluation(evaluation: Dictionary) -> void:
	if evaluation.has("property"):
		_register_property(evaluation.property)
	if evaluation.has("value_from"):
		_register_property(evaluation.value_from)

func _register_property(property_path_str: String) -> void:
	if property_path_str.is_empty():
		return

	var path := Path.parse(property_path_str)
	if path.is_root():
		logger.warn("Cannot register root path as required property")
		return

	_required_properties[path.full] = path
	logger.trace("Registered property: %s" % path.full)

func _log_required_properties() -> void:
	var properties = _required_properties.keys()
	if properties.is_empty():
		return

	logger.debug("Required properties:\n  - %s" % "\n  - ".join(properties))
#endregion

#region Stack Management
func _push_evaluation_context(description: String) -> void:
	_evaluation_stack.append(description)
	
func _pop_evaluation_context() -> void:
	_evaluation_stack.pop_back()

func _get_current_context() -> String:
	return "" if _evaluation_stack.is_empty() else " (in: %s)" % " → ".join(_evaluation_stack)

#endregion
