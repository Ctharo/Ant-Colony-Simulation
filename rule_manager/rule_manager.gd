extends Node

var data_manager: DataManager

func _ready() -> void:
	data_manager = DataManager

func format_rule(rule: Dictionary) -> String:
	var condition = rule["condition"]
	var action = rule["action"]
	return "If %s %s %s then %s" % [condition["left"], condition["operator"], condition["right"], format_action(action)]

func format_action(action: Dictionary) -> String:
	if action["type"] == "spawn_ant":
		return "spawn ant of type '%s'" % action["profile"]
	elif action["type"] == "set_property":
		return "set %s to %s" % [action["property"], action["value"]]
	return "Unknown action"

func parse_rule(rule_text: String) -> Dictionary:
	var parts = rule_text.split(" then ")
	var condition_parts = parts[0].trim_prefix("If ").split(" ")
	var action_parts = parts[1].split(" ")
	
	return {
		"condition": {
			"left": condition_parts[0],
			"operator": condition_parts[1],
			"right": condition_parts[2]
		},
		"action": {
			"type": action_parts[0],
			"profile" if action_parts[0] == "spawn" else "property": action_parts[3],
			"value": action_parts[5] if action_parts[0] == "set" else ""
		}
	}

func create_edit_rule_dialog(existing_rule: Dictionary = {}) -> Window:
	var edit_dialog = Window.new()
	edit_dialog.title = "Edit Rule"
	edit_dialog.size = Vector2(400, 300)
	
	var vbox = VBoxContainer.new()
	edit_dialog.add_child(vbox)
	
	var condition_hbox = HBoxContainer.new()
	vbox.add_child(condition_hbox)
	
	var left_input = LineEdit.new()
	left_input.text = existing_rule.get("condition", {}).get("left", "")
	condition_hbox.add_child(left_input)
	
	var operator_input = OptionButton.new()
	for op in [">", "<", "==", "!=", ">=", "<="]:
		operator_input.add_item(op)
	operator_input.selected = operator_input.get_item_index(existing_rule.get("condition", {}).get("operator", ">"))
	condition_hbox.add_child(operator_input)
	
	var right_input = LineEdit.new()
	right_input.text = existing_rule.get("condition", {}).get("right", "")
	condition_hbox.add_child(right_input)
	
	var action_hbox = HBoxContainer.new()
	vbox.add_child(action_hbox)
	
	var action_type_input = OptionButton.new()
	action_type_input.add_item("spawn")
	action_type_input.add_item("set")
	action_type_input.selected = 0 if existing_rule.get("action", {}).get("type", "") == "spawn" else 1
	action_hbox.add_child(action_type_input)
	
	var action_target_input = LineEdit.new()
	action_target_input.text = existing_rule.get("action", {}).get("profile", existing_rule.get("action", {}).get("property", ""))
	action_hbox.add_child(action_target_input)
	
	var action_value_input = LineEdit.new()
	action_value_input.text = existing_rule.get("action", {}).get("value", "")
	action_value_input.visible = existing_rule.get("action", {}).get("type", "") == "set"
	action_hbox.add_child(action_value_input)
	
	return edit_dialog

func get_rule_from_dialog(dialog: Window) -> Dictionary:
	var vbox = dialog.get_child(0)
	var condition_hbox = vbox.get_child(0)
	var action_hbox = vbox.get_child(1)
	
	var left_input = condition_hbox.get_child(0)
	var operator_input = condition_hbox.get_child(1)
	var right_input = condition_hbox.get_child(2)
	var action_type_input = action_hbox.get_child(0)
	var action_target_input = action_hbox.get_child(1)
	var action_value_input = action_hbox.get_child(2)
	
	return {
		"condition": {
			"left": left_input.text,
			"operator": operator_input.get_item_text(operator_input.selected),
			"right": right_input.text
		},
		"action": {
			"type": action_type_input.get_item_text(action_type_input.selected),
			"profile" if action_type_input.selected == 0 else "property": action_target_input.text,
			"value": action_value_input.text if action_type_input.selected == 1 else ""
		}
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
