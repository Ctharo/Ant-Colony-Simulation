extends Node

var data_manager: DataManager

func _ready() -> void:
	data_manager = DataManager

func format_rule(rule: Dictionary) -> String:
	return "If %s %s %s then %s" % [
		rule["property"],
		BehaviorConfig.get_operator_string(rule["operator"]),
		rule["value"],
		rule["action"]
	]

func parse_rule(rule_text: String) -> Dictionary:
	var parts = rule_text.split(" ")
	return {
		"property": parts[1],
		"operator": BehaviorConfig.get_operator_from_string(parts[2]),
		"value": parts[3],
		"action": parts[5]
	}
	
func format_action(action: Dictionary) -> String:
	if action["type"] == "spawn_ant":
		return "spawn ant of type '%s'" % action["profile"]
	elif action["type"] == "set_property":
		return "set %s to %s" % [action["property"], action["value"]]
	return "Unknown action"

func create_edit_rule_dialog(existing_rule: Dictionary = {}) -> Window:
	var edit_dialog = Window.new()
	edit_dialog.title = "Edit Rule"
	edit_dialog.size = Vector2(400, 300)
	
	var vbox = VBoxContainer.new()
	edit_dialog.add_child(vbox)
	
	var property_input = OptionButton.new()
	for option in BehaviorConfig.property_options:
		property_input.add_item(option)
	property_input.selected = BehaviorConfig.property_options.find(existing_rule.get("property", BehaviorConfig.property_options[0]))
	vbox.add_child(property_input)
	
	var operator_input = OptionButton.new()
	for op in BehaviorConfig.ComparisonOperator.keys():
		operator_input.add_item(op)
	operator_input.selected = BehaviorConfig.ComparisonOperator.values().find(existing_rule.get("operator", BehaviorConfig.ComparisonOperator.EQUAL))
	vbox.add_child(operator_input)
	
	var value_input = LineEdit.new()
	value_input.text = str(existing_rule.get("value", ""))
	vbox.add_child(value_input)
	
	var action_input = OptionButton.new()
	for action in BehaviorConfig.action_options:
		action_input.add_item(action)
	action_input.selected = BehaviorConfig.action_options.find(existing_rule.get("action", BehaviorConfig.action_options[0]))
	vbox.add_child(action_input)
	
	return edit_dialog

func get_rule_from_dialog(dialog: Window) -> Dictionary:
	var vbox = dialog.get_child(0)
	var property_input = vbox.get_child(0)
	var operator_input = vbox.get_child(1)
	var value_input = vbox.get_child(2)
	var action_input = vbox.get_child(3)
	
	return {
		"property": BehaviorConfig.property_options[property_input.selected],
		"operator": BehaviorConfig.ComparisonOperator.values()[operator_input.selected],
		"value": value_input.text,
		"action": BehaviorConfig.action_options[action_input.selected]
	}
	
func save_rules(entity_name: String, rules: Array, is_colony: bool = true) -> void:
	if is_colony:
		data_manager.save_colony_behavior(entity_name, rules)
	else:
		data_manager.update_ant_profile_behavior(entity_name, rules)

func load_rules(entity_name: String, is_colony: bool = true) -> Array:
	if is_colony:
		return data_manager.get_colony_behavior(entity_name)
	else:
		var ant_profile = data_manager.get_ant_profile(entity_name)
		return ant_profile.get("behavior_logic", [])
