extends Node

var data_manager: DataManager
var logger: Logger
## Enum for comparison operators
enum ComparisonOperator {
	EQUAL,
	NOT_EQUAL,
	GREATER_THAN,
	LESS_THAN,
	GREATER_EQUAL,
	LESS_EQUAL
}

## Dictionary mapping operator strings to enum values
const OPERATOR_MAP = {
	"==": ComparisonOperator.EQUAL,
	"!=": ComparisonOperator.NOT_EQUAL,
	">": ComparisonOperator.GREATER_THAN,
	"<": ComparisonOperator.LESS_THAN,
	">=": ComparisonOperator.GREATER_EQUAL,
	"<=": ComparisonOperator.LESS_EQUAL
}


func _init() -> void:
	logger = Logger.new("rule_manager", DebugLogger.Category.PROGRAM)


func _ready() -> void:
	data_manager = DataManager

## Format a rule into a human-readable string
func format_rule(rule: Dictionary) -> String:
	return "If %s then %s" % [
		format_condition(rule["condition"]),
		format_action(rule["action"])
	]

## Format a condition into a human-readable string
func format_condition(condition: Dictionary) -> String:
	var left = format_value(condition["left"])
	var right = format_value(condition["right"])
	var op = get_operator_string(condition["operator"])
	return "%s %s %s" % [left, op, right]

## Format a value (property, callable, or literal) into a string
func format_value(value) -> String:
	if value is String:
		if value.begins_with("@"):
			return "call " + value.substr(1)
		elif value.begins_with("$"):
			return "property " + value.substr(1)
		else:
			return '"' + value + '"'
	elif value is float or value is int:
		return str(value)
	elif value is Dictionary and "expression" in value:
		return "(%s)" % value["expression"]
	else:
		return str(value)

## Format an action into a human-readable string
func format_action(action: Dictionary) -> String:
	var method_name = action["method"]
	var args = action.get("args", [])
	var args_str = ", ".join(args.map(func(arg): return str(arg)))
	return "call %s(%s)" % [method_name, args_str]

## Parse a rule from a string representation
func parse_rule(rule_text: String) -> Dictionary:
	var parts = rule_text.split(" then ")
	var condition_text = parts[0].substr(3)  # Remove "If " prefix
	var action_text = parts[1]
	
	return {
		"condition": parse_condition(condition_text),
		"action": parse_action(action_text)
	}

## Parse a condition from a string representation
func parse_condition(condition_text: String) -> Dictionary:
	var parts = condition_text.split(" ", false, 3)  # Split into 3 parts: left, operator, right
	return {
		"left": parse_value(parts[0]),
		"operator": get_operator_from_string(parts[1]),
		"right": parse_value(parts[2])
	}

## Parse a value from a string representation
func parse_value(value_text: String):
	if value_text.begins_with("@"):
		return value_text  # Callable
	elif value_text.begins_with("$"):
		return value_text  # Property
	elif value_text.is_valid_float():
		return float(value_text)
	elif value_text.is_valid_int():
		return int(value_text)
	elif value_text.begins_with("(") and value_text.ends_with(")"):
		return {"expression": value_text.substr(1, value_text.length() - 2)}
	else:
		return value_text  # Treat as string literal

## Parse an action from a string representation
func parse_action(action_text: String) -> Dictionary:
	if action_text.begins_with("call "):
		var method_and_args = action_text.substr(5).split("(")
		var method_name = method_and_args[0]
		var args_str = method_and_args[1].trim_suffix(")")
		var args = []
		if args_str:
			args = args_str.split(",")
			args = args.map(func(arg): return parse_value(arg.strip_edges()))
		
		return {
			"method": method_name,
			"args": args
		}
	return {"method": "unknown_action"}

## Get the string representation of an operator
func get_operator_string(op: ComparisonOperator) -> String:
	for key in OPERATOR_MAP:
		if OPERATOR_MAP[key] == op:
			return key
	return "=="  # Default to equality if not found

## Get the operator enum value from a string representation
func get_operator_from_string(op_string: String) -> ComparisonOperator:
	return OPERATOR_MAP.get(op_string, ComparisonOperator.EQUAL)

## Create a dialog for editing a rule
func create_edit_rule_dialog(existing_rule: Dictionary = {}) -> Window:
	var edit_dialog = Window.new()
	edit_dialog.title = "Edit Rule"
	edit_dialog.size = Vector2(400, 300)
	
	var vbox = VBoxContainer.new()
	edit_dialog.add_child(vbox)
	
	# Add inputs for condition
	var condition = existing_rule.get("condition", {})
	var left_input = LineEdit.new()
	left_input.text = str(condition.get("left", ""))
	vbox.add_child(left_input)
	
	var operator_input = OptionButton.new()
	for op in ComparisonOperator.keys():
		operator_input.add_item(op)
	operator_input.selected = ComparisonOperator.values().find(condition.get("operator", ComparisonOperator.EQUAL))
	vbox.add_child(operator_input)
	
	var right_input = LineEdit.new()
	right_input.text = str(condition.get("right", ""))
	vbox.add_child(right_input)
	
	# Add inputs for action
	var action = existing_rule.get("action", {})
	var method_input = LineEdit.new()
	method_input.text = action.get("method", "")
	vbox.add_child(method_input)
	
	var args_input = LineEdit.new()
	args_input.text = ", ".join(action.get("args", []))
	vbox.add_child(args_input)
	
	return edit_dialog

## Get the rule from the edit dialog
func get_rule_from_dialog(dialog: Window) -> Dictionary:
	var vbox = dialog.get_child(0)
	var left_input = vbox.get_child(0)
	var operator_input = vbox.get_child(1)
	var right_input = vbox.get_child(2)
	var method_input = vbox.get_child(3)
	var args_input = vbox.get_child(4)
	
	var args = args_input.text.split(",")
	args = args.map(func(arg): return parse_value(arg.strip_edges()))
	
	return {
		"condition": {
			"left": parse_value(left_input.text),
			"operator": ComparisonOperator.values()[operator_input.selected],
			"right": parse_value(right_input.text)
		},
		"action": {
			"method": method_input.text,
			"args": args
		}
	}

## Save rules for a given entity
func save_rules(entity_name: String, rules: Array, is_colony: bool = true) -> void:
	if is_colony:
		data_manager.save_colony_behavior(entity_name, rules)
	else:
		data_manager.update_ant_profile_behavior(entity_name, rules)

## Load rules for a given entity
func load_rules(entity_name: String, is_colony: bool = true) -> Array:
	if is_colony:
		return data_manager.get_colony_behavior(entity_name)
	else:
		var ant_profile = data_manager.get_ant_profile(entity_name)
		return ant_profile.get("behavior_logic", [])

## Evaluate a condition based on the current simulation state
func evaluate_condition(condition: Dictionary, simulation_state: Node) -> bool:
	var left_value = evaluate_value(condition["left"], simulation_state)
	var right_value = evaluate_value(condition["right"], simulation_state)
	
	match condition["operator"]:
		ComparisonOperator.EQUAL:
			return left_value == right_value
		ComparisonOperator.NOT_EQUAL:
			return left_value != right_value
		ComparisonOperator.GREATER_THAN:
			return left_value > right_value
		ComparisonOperator.LESS_THAN:
			return left_value < right_value
		ComparisonOperator.GREATER_EQUAL:
			return left_value >= right_value
		ComparisonOperator.LESS_EQUAL:
			return left_value <= right_value
	
	return false

## Evaluate a value (property, callable, or literal) based on the current simulation state
func evaluate_value(value, simulation_state: Node):
	if value is String:
		if value.begins_with("@"):
			# Call a method on the simulation state
			var method_name = value.substr(1)
			return simulation_state.call(method_name)
		elif value.begins_with("$"):
			# Get a property from the simulation state
			var property_name = value.substr(1)
			return simulation_state.get(property_name)
		else:
			return value
	elif value is float or value is int:
		return value
	elif value is Dictionary and "expression" in value:
		# Evaluate the expression (this is a simplified version, you might want to use an expression parser here)
		var expression = Expression.new()
		var error = expression.parse(value["expression"])
		if error != OK:
			push_error("Failed to parse expression: " + value["expression"])
			return null
		return expression.execute([], simulation_state)
	else:
		return value

## Execute an action based on the current simulation state
func execute_action(action: Dictionary, simulation_state: Node) -> void:
	var method_name = action["method"]
	var args = action.get("args", [])
	
	if simulation_state.has_method(method_name):
		simulation_state.callv(method_name, args)
	else:
		push_warning("Unknown action method: " + method_name)
