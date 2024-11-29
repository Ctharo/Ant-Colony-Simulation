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
static var _condition_configs: Dictionary
var _evaluation_stack: Array[String] = []
var logger: Logger
#endregion

#region Initialization
func _init(p_ant: Ant) -> void:
	logger = Logger.new("condition_system", DebugLogger.Category.CONDITION)
	if not _condition_configs.is_empty():
		register_required_properties()

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


func get_required_properties() -> Array[String]:
	var a: Array[String] = []
	for key in _required_properties.keys():
		a.append(key as String)
	return a

func get_property_value(path: Path) -> Variant:
	if not path.full in _required_properties:
		logger.warn("Accessing unrequired property '%s'" % path.full)
		return null

	var value = get_property_value(path)
	if value != null:
		logger.trace("Property '%s' = %s" % [path.full, str(value)])
	return value

static func create_condition(config: Dictionary) -> Condition:
	if typeof(config) != TYPE_DICTIONARY:
		push_error("Invalid condition config type: %s" % typeof(config))
		return null

	var condition = Condition.new()
	
	if config.has("type") and config.type in _condition_configs:
		var merged_config = _condition_configs[config.type].duplicate(true)
		for key in config:
			if key != "type":
				merged_config[key] = config[key]
		condition.config = merged_config
	else:
		condition.config = config
	
	return condition
	
func evaluate_condition(condition: Condition, context: Dictionary) -> bool:
	if condition == null:
		logger.error("Attempted to evaluate null condition")
		return false

	var result := _evaluate_condition_config(condition.config, context)
	var previous = condition.previous_result
	
	if result != previous:
		condition.previous_result = result
		evaluation_changed.emit(condition, result)
		_log_evaluation_change(previous, result, condition.config)

	return result
#endregion

#region Evaluation Methods
func _evaluate_condition_config(config: Dictionary, context: Dictionary) -> bool:
	_push_evaluation_context("condition")
	_log_evaluation_chain(config, context)
	
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
	_log_result(result)
	_pop_evaluation_context()
	return result

func _evaluate_named_condition(config: Dictionary, context: Dictionary) -> bool:
	var condition_name = config.get("name", "Anonymous")
	_push_evaluation_context("Named condition: %s" % condition_name)
	
	_log_evaluation_chain(config, context)
	var result = _evaluate_property_check({"evaluation": config.evaluation}, context)
	_log_result(result)
	
	_pop_evaluation_context()
	return result

func _evaluate_operator(config: Dictionary, context: Dictionary) -> bool:
	var operator_type = config.operator_type.to_upper()
	var operands = config.get("operands", [])
	
	_push_evaluation_context("%s operator" % operator_type)
	_log_evaluation_chain(config, context)
	
	var result 
	match operator_type:
		"AND":
			result = _evaluate_and_operator(operands, context)
		"OR": 
			result = _evaluate_or_operator(operands, context)
		"NOT": 
			result = _evaluate_not_operator(operands, context)
		_:
			logger.error("Unknown operator: %s" % operator_type)
			return false
	
	_log_result(result, operator_type)
	_pop_evaluation_context()
	return result

func _evaluate_property_check(config: Dictionary, context: Dictionary) -> bool:
	var evaluation = config.get("evaluation", {})
	if evaluation.is_empty() or not evaluation.has("property"):
		logger.error("Invalid property check configuration")
		return false
		
	_push_evaluation_context("Property check: %s" % evaluation.property)
	_log_evaluation_chain(config, context)
	
	var operator = evaluation.get("operator", "EQUALS")
	var value_a = context.get(evaluation.property)
	var value_b = evaluation.get("value", context.get(evaluation.get("value_from", "")))
	
	var result = _compare_values(value_a, value_b, operator)
	_log_result(result)
	
	_pop_evaluation_context()
	return result

func _evaluate_and_operator(operands: Array, context: Dictionary) -> bool:
	for i in range(operands.size()):
		_push_evaluation_context("AND operand %d/%d" % [i + 1, operands.size()])
		if not _evaluate_condition_config(operands[i], context):
			_pop_evaluation_context()
			return false
		_pop_evaluation_context()
	return true

func _evaluate_or_operator(operands: Array, context: Dictionary) -> bool:
	for i in range(operands.size()):
		_push_evaluation_context("OR operand %d/%d" % [i + 1, operands.size()])
		if _evaluate_condition_config(operands[i], context):
			_pop_evaluation_context()
			return true
		_pop_evaluation_context()
	return false

func _evaluate_not_operator(operands: Array, context: Dictionary) -> bool:
	if operands.size() != 1:
		logger.error("NOT operator requires exactly one operand")
		return false

	_push_evaluation_context("NOT operand")
	var result = not _evaluate_condition_config(operands[0], context)
	_pop_evaluation_context()
	return result
#endregion

#region Logging Methods
func _log_evaluation_chain(config: Dictionary, context: Dictionary) -> void:
	var depth = _evaluation_stack.size()
	var indent = "  ".repeat(depth)
	var eval_info = _get_evaluation_info(config, context)
	
	logger.debug("%s%s %s%s" % [
		indent,
		_get_stack_symbol(eval_info.type),
		eval_info.name,
		"\n%s   Compare: %s" % [indent, eval_info.comparison] if eval_info.has("comparison") else ""
	])
	
func _get_evaluation_info(config: Dictionary, context: Dictionary) -> Dictionary:
	var info = {"type": "generic"}
	
	if config.has("type"):
		match config.type:
			"Operator":
				info.type = "operator"
				info.name = config.operator_type.to_upper()
			_:
				info.type = "named"
				info.name = config.get("description", "Unnamed Condition")
	
	var eval = config.get("evaluation", {})
	if eval.has("property"):
		info.type = "property"
		info.name = "Check %s" % eval.property
		var value_a = context.get(eval.property)
		var value_b = eval.get("value", context.get(eval.get("value_from", "")))
		var op = OPERATOR_MAP.get(eval.get("operator", "EQUALS"), "==")
		info.comparison = "%s %s %s" % [str(value_a), op, str(value_b)]
	
	return info
	
func _get_evaluation_type(config: Dictionary) -> String:
	if config.has("type"):
		match config.type:
			"Operator": return "%s" % config.get("operator_type", "").to_upper()
			_: return config.get("description", "Unnamed Condition")
	return "Check %s" % config.get("evaluation", {}).get("property", "unknown")

func _get_stack_symbol(type: String) -> String:
	return {
		"operator": {"NOT": "!", "AND": "&", "OR": "|"}.get(type, "|"),
		"named": "►",
		"property": "•"
	}.get(type, "○")

func _log_result(result: bool, extra_info: String = "") -> void:
	var indent = "  ".repeat(_evaluation_stack.size())
	logger.debug("%s└─ Result: %s%s" % [
		indent, 
		result,
		" (%s)" % extra_info if extra_info else ""
	])


func _log_evaluation_change(previous: bool, current: bool, config: Dictionary) -> void:
	var desc = config.get("description", "unnamed")
	logger.info("Condition '%s' changed: %s -> %s" % [desc, previous, current])

#endregion

#region Helper Methods
static func _is_empty(value: Variant) -> bool:
	if value == null: return true
	match typeof(value):
		TYPE_ARRAY: return (value as Array).is_empty()
		TYPE_DICTIONARY: return (value as Dictionary).is_empty()
		TYPE_STRING: return (value as String).is_empty()
		_: return false

static func _are_comparable(a: Variant, b: Variant) -> bool:
	var type_a = typeof(a)
	var type_b = typeof(b)
	return type_a == type_b or (type_a in [TYPE_INT, TYPE_FLOAT] and type_b in [TYPE_INT, TYPE_FLOAT])

static func _contains_value(container: Variant, value: Variant) -> bool:
	match typeof(container):
		TYPE_STRING: return (container as String).contains(str(value))
		TYPE_ARRAY: return (container as Array).has(value)
		TYPE_DICTIONARY: return (container as Dictionary).has(value)
		_: return false

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
	for condition_name in _condition_configs:
		var config = _condition_configs[condition_name]
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

#region Stack Management
func _push_evaluation_context(description: String) -> void:
	_evaluation_stack.append(description)
	
func _pop_evaluation_context() -> void:
	_evaluation_stack.pop_back()

func _get_current_context() -> String:
	return "" if _evaluation_stack.is_empty() else " (in: %s)" % " → ".join(_evaluation_stack)

func _get_condition_cache_key(condition: Condition, context: Dictionary) -> String:
	var parts = []
	
	if condition.config.has("description"):
		parts.append(condition.config.description)
		
	if condition.config.has("evaluation"):
		var eval = condition.config.evaluation
		if eval.has("property"):
			var op_str = OPERATOR_MAP.get(eval.get("operator", "EQUALS"), "==")
			var value_str = eval.get("value", "from:" + eval.get("value_from", ""))
			parts.append("%s %s %s" % [eval.property, op_str, value_str])
			
	var context_values = []
	for property in condition.get_required_properties():
		var path := Path.parse(property)
		if context.has(path.full):
			context_values.append("%s=%s" % [path.full, context[path.full]])
			
	var key = " | ".join(parts)
	if not context_values.is_empty():
		key += " [Context: %s]" % ", ".join(context_values)
		
	return key
#endregion
