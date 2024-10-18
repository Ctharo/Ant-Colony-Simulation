extends Control

var profile_dropdown: OptionButton
var colony_ant_list: ItemList
var available_ant_list: ItemList
var edit_colony_behavior_button: Button
var add_ant_profile_button: Button
var remove_ant_profile_button: Button
var new_colony_button: Button
var delete_colony_button: Button
var back_button: Button
var main_container: VBoxContainer
var info_label: RichTextLabel
var data_manager: DataManager

# Colony Behavior Editor components
var behavior_popup: Popup
var behavior_list: ItemList
var add_rule_button: Button
var edit_rule_button: Button
var delete_rule_button: Button
var save_behavior_button: Button

var profile_id_to_name: Dictionary = {}

func _ready():
	data_manager = DataManager
	create_ui()
	create_behavior_editor()
	populate_colony_profiles()

func create_ui():
	main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(main_container)

	var title = Label.new()
	title.text = "Colony Editor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	profile_dropdown = OptionButton.new()
	profile_dropdown.connect("item_selected", Callable(self, "_on_profile_selected"))
	main_container.add_child(profile_dropdown)

	var lists_and_info_container = HBoxContainer.new()
	main_container.add_child(lists_and_info_container)

	var lists_container = HBoxContainer.new()
	lists_and_info_container.add_child(lists_container)

	# Colony Ants List
	var colony_ant_container = VBoxContainer.new()
	lists_container.add_child(colony_ant_container)
	
	var colony_ant_label = Label.new()
	colony_ant_label.text = "Colony Ants"
	colony_ant_container.add_child(colony_ant_label)

	colony_ant_list = ItemList.new()
	colony_ant_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colony_ant_list.custom_minimum_size = Vector2(200, 200)
	colony_ant_list.connect("item_selected", Callable(self, "_on_colony_ant_selected"))
	colony_ant_container.add_child(colony_ant_list)

	# Arrow Buttons
	var button_container = VBoxContainer.new()
	button_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists_container.add_child(button_container)

	# Add some spacing at the top to center the buttons
	var spacer_top = Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 80)
	button_container.add_child(spacer_top)

	add_ant_profile_button = Button.new()
	add_ant_profile_button.text = "◀"
	add_ant_profile_button.disabled = true
	add_ant_profile_button.connect("pressed", Callable(self, "_on_add_ant_profile_pressed"))
	button_container.add_child(add_ant_profile_button)

	remove_ant_profile_button = Button.new()
	remove_ant_profile_button.text = "▶"
	remove_ant_profile_button.disabled = true
	remove_ant_profile_button.connect("pressed", Callable(self, "_on_remove_ant_profile_pressed"))
	button_container.add_child(remove_ant_profile_button)

	# Available Ants List
	var available_ant_container = VBoxContainer.new()
	lists_container.add_child(available_ant_container)
	
	var available_ant_label = Label.new()
	available_ant_label.text = "Available Ant Profiles"
	available_ant_container.add_child(available_ant_label)

	available_ant_list = ItemList.new()
	available_ant_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	available_ant_list.custom_minimum_size = Vector2(200, 200)
	available_ant_list.connect("item_selected", Callable(self, "_on_available_ant_selected"))
	available_ant_container.add_child(available_ant_list)

	# Info Panel
	var info_container = PanelContainer.new()
	info_container.custom_minimum_size = Vector2(250, 300)  # Set a fixed height
	lists_and_info_container.add_child(info_container)

	var info_vbox = VBoxContainer.new()
	info_container.add_child(info_vbox)

	var info_title = Label.new()
	info_title.text = "Ant Profile Info"
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(info_title)

	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(scroll_container)


	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(info_label)

	var bottom_button_container = HBoxContainer.new()
	main_container.add_child(bottom_button_container)

	edit_colony_behavior_button = Button.new()
	edit_colony_behavior_button.text = "Edit Colony Behavior"
	edit_colony_behavior_button.connect("pressed", Callable(self, "_on_edit_colony_behavior_pressed"))
	bottom_button_container.add_child(edit_colony_behavior_button)

	new_colony_button = Button.new()
	new_colony_button.text = "New Colony"
	new_colony_button.connect("pressed", Callable(self, "_on_new_colony_pressed"))
	bottom_button_container.add_child(new_colony_button)

	delete_colony_button = Button.new()
	delete_colony_button.text = "Delete Colony"
	delete_colony_button.connect("pressed", Callable(self, "_on_delete_colony_pressed"))
	bottom_button_container.add_child(delete_colony_button)

	back_button = Button.new()
	back_button.text = "Back to Main Menu"
	back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	main_container.add_child(back_button)

func create_behavior_editor():
	behavior_popup = Popup.new()
	behavior_popup.size = Vector2(800, 600)
	add_child(behavior_popup)

	var popup_container = VBoxContainer.new()
	popup_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	behavior_popup.add_child(popup_container)

	var popup_title = Label.new()
	popup_title.text = "Edit Colony Behavior"
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.add_theme_font_size_override("font_size", 24)
	popup_container.add_child(popup_title)

	behavior_list = ItemList.new()
	behavior_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_container.add_child(behavior_list)

	var button_container = HBoxContainer.new()
	popup_container.add_child(button_container)

	add_rule_button = Button.new()
	add_rule_button.text = "Add Rule"
	add_rule_button.connect("pressed", Callable(self, "_on_add_rule_pressed"))
	button_container.add_child(add_rule_button)

	edit_rule_button = Button.new()
	edit_rule_button.text = "Edit Rule"
	edit_rule_button.connect("pressed", Callable(self, "_on_edit_rule_pressed"))
	button_container.add_child(edit_rule_button)

	delete_rule_button = Button.new()
	delete_rule_button.text = "Delete Rule"
	delete_rule_button.connect("pressed", Callable(self, "_on_delete_rule_pressed"))
	button_container.add_child(delete_rule_button)

	save_behavior_button = Button.new()
	save_behavior_button.text = "Save Behavior"
	save_behavior_button.connect("pressed", Callable(self, "_on_save_behavior_pressed"))
	popup_container.add_child(save_behavior_button)

func populate_colony_profiles():
	profile_dropdown.clear()
	var colony_names = data_manager.get_colony_names()
	for colony_name in colony_names:
		profile_dropdown.add_item(colony_name)
	
	if colony_names.size() > 0:
		profile_dropdown.select(0)
		_on_profile_selected(0)
	else:
		push_warning("No colony profiles found")


func update_colony_ant_list(colony_name: String):
	colony_ant_list.clear()
	var ant_profile_ids = data_manager.get_ant_profiles_for_colony(colony_name)
	var all_profiles = data_manager.get_all_ant_profiles()
	for profile_id in ant_profile_ids:
		if profile_id in all_profiles:
			var profile_name = all_profiles[profile_id]["name"]
			colony_ant_list.add_item(profile_name)
			profile_id_to_name[profile_name] = profile_id

func update_available_ant_list(colony_name: String):
	available_ant_list.clear()
	var all_profiles = data_manager.get_all_ant_profiles()
	var colony_profile_ids = data_manager.get_ant_profiles_for_colony(colony_name)
	for profile_id in all_profiles:
		if profile_id not in colony_profile_ids:
			var profile_name = all_profiles[profile_id]["name"]
			available_ant_list.add_item(profile_name)
			profile_id_to_name[profile_name] = profile_id

func _on_add_ant_profile_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var selected_items = available_ant_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for addition")
		return
	var selected_ant_name = available_ant_list.get_item_text(selected_items[0])
	var selected_ant_id = profile_id_to_name[selected_ant_name]
	data_manager.add_ant_profile_to_colony(selected_colony, selected_ant_id)
	update_colony_ant_list(selected_colony)
	update_available_ant_list(selected_colony)
	add_ant_profile_button.disabled = true

func _on_remove_ant_profile_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var selected_items = colony_ant_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for removal")
		return
	var selected_ant_name = colony_ant_list.get_item_text(selected_items[0])
	var selected_ant_id = profile_id_to_name[selected_ant_name]
	data_manager.remove_ant_profile_from_colony(selected_colony, selected_ant_id)
	update_colony_ant_list(selected_colony)
	update_available_ant_list(selected_colony)
	remove_ant_profile_button.disabled = true

func _on_edit_colony_behavior_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	show_colony_behavior(selected_colony)

func show_colony_behavior(colony_name: String):
	behavior_list.clear()
	var colony_behavior = data_manager.get_colony_behavior(colony_name)
	for rule in colony_behavior:
		behavior_list.add_item(format_rule(rule))
	behavior_popup.popup_centered()

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


func _on_delete_rule_pressed():
	var selected_items = behavior_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No rule selected for deletion")
		return
	behavior_list.remove_item(selected_items[0])

func _on_save_behavior_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var updated_behavior = []
	for i in range(behavior_list.item_count):
		updated_behavior.append(parse_rule(behavior_list.get_item_text(i)))
	data_manager.save_colony_behavior(selected_colony, updated_behavior)
	behavior_popup.hide()


func _on_new_colony_pressed():
	var dialog = ConfirmationDialog.new()
	dialog.title = "New Colony"
	var line_edit = LineEdit.new()
	line_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(line_edit)
	add_child(dialog)
	
	dialog.connect("confirmed", Callable(self, "_on_new_colony_confirmed").bind(line_edit))
	dialog.popup_centered()

func _on_new_colony_confirmed(line_edit: LineEdit):
	var colony_name = line_edit.text.strip_edges()
	if colony_name.is_empty():
		push_warning("Colony name cannot be empty")
		return
	
	if data_manager.colony_exists(colony_name):
		# Show overwrite warning
		var overwrite_dialog = ConfirmationDialog.new()
		overwrite_dialog.dialog_text = "A colony with the name '%s' already exists. Do you want to overwrite it?" % colony_name
		overwrite_dialog.connect("confirmed", Callable(self, "_on_overwrite_colony_confirmed").bind(colony_name))
		add_child(overwrite_dialog)
		overwrite_dialog.popup_centered()
	else:
		_create_new_colony(colony_name)

func _on_overwrite_colony_confirmed(colony_name: String):
	_create_new_colony(colony_name)

func _create_new_colony(colony_name: String):
	data_manager.create_new_colony(colony_name)
	populate_colony_profiles()
	profile_dropdown.select(profile_dropdown.get_item_count() - 1)
	_on_profile_selected(profile_dropdown.get_item_count() - 1)
	info_label.text = "No profile selected"

func _on_delete_colony_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	
	# Show a confirmation dialog before deleting
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to delete the colony '%s'? This action cannot be undone." % selected_colony
	confirm_dialog.connect("confirmed", Callable(self, "_confirm_delete_colony").bind(selected_colony))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_delete_colony(colony_name: String):
	data_manager.delete_colony(colony_name)
	populate_colony_profiles()
	colony_ant_list.clear()
	available_ant_list.clear()
	edit_colony_behavior_button.disabled = true
	delete_colony_button.disabled = true
	add_ant_profile_button.disabled = true
	remove_ant_profile_button.disabled = true
	info_label.text = "No profile selected"

func _on_back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")

# Helper function to update button states
func update_button_states():
	var colony_selected = profile_dropdown.selected != -1
	edit_colony_behavior_button.disabled = !colony_selected
	delete_colony_button.disabled = !colony_selected
	
	var colony_ant_selected = !colony_ant_list.get_selected_items().is_empty()
	var available_ant_selected = !available_ant_list.get_selected_items().is_empty()
	
	add_ant_profile_button.disabled = !available_ant_selected
	remove_ant_profile_button.disabled = !colony_ant_selected

# Call this function whenever the selection state changes
func _on_selection_changed():
	update_button_states()

func _on_colony_ant_selected(index):
	remove_ant_profile_button.disabled = false
	add_ant_profile_button.disabled = true
	
	var selected_ant_name = colony_ant_list.get_item_text(index)
	var selected_ant_id = profile_id_to_name[selected_ant_name]
	update_info_panel(selected_ant_id)

func _on_available_ant_selected(index):
	add_ant_profile_button.disabled = false
	remove_ant_profile_button.disabled = true
	
	var selected_ant_name = available_ant_list.get_item_text(index)
	var selected_ant_id = profile_id_to_name[selected_ant_name]
	update_info_panel(selected_ant_id)

func update_info_panel(profile_id: String):
	var profile = data_manager.get_ant_profile(profile_id)
	if profile.is_empty():
		info_label.text = "No profile selected"
		return
	
	var info_text = "[b]Name:[/b] %s\n\n[b]Stats:[/b]\n" % profile["name"]
	
	for stat_name in profile["stats"]:
		info_text += "• %s: %s\n" % [stat_name.capitalize(), profile["stats"][stat_name]]
	
	info_text += "\n[b]Behavior Logic:[/b]\n"
	if profile["behavior_logic"].is_empty():
		info_text += "No behaviors defined"
	else:
		for behavior in profile["behavior_logic"]:
			info_text += "• If %s then %s (Priority: %d)\n" % [
				behavior["condition"],
				behavior["action"],
				behavior["priority"]
			]
	
	info_label.text = info_text

func _on_profile_selected(index):
	var selected_profile = profile_dropdown.get_item_text(index)
	update_colony_ant_list(selected_profile)
	update_available_ant_list(selected_profile)
	_on_selection_changed()

# Error handling and user feedback
func show_error(message: String):
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	add_child(error_dialog)
	error_dialog.popup_centered()

# Improve rule parsing and formatting
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

# Add functionality to edit existing rules
func _on_edit_rule_pressed():
	var selected_items = behavior_list.get_selected_items()
	if selected_items.is_empty():
		show_error("No rule selected for editing")
		return
	
	var selected_rule = behavior_list.get_item_text(selected_items[0])
	var rule_data = parse_rule(selected_rule)
	
	var edit_dialog = Window.new()
	edit_dialog.title = "Edit Rule"
	edit_dialog.size = Vector2(400, 300)
	
	var vbox = VBoxContainer.new()
	edit_dialog.add_child(vbox)
	
	var condition_hbox = HBoxContainer.new()
	vbox.add_child(condition_hbox)
	
	var left_input = LineEdit.new()
	left_input.text = rule_data["condition"]["left"]
	condition_hbox.add_child(left_input)
	
	var operator_input = OptionButton.new()
	for op in [">", "<", "==", "!=", ">=", "<="]:
		operator_input.add_item(op)
	operator_input.selected = operator_input.get_item_index(rule_data["condition"]["operator"])
	condition_hbox.add_child(operator_input)
	
	var right_input = LineEdit.new()
	right_input.text = rule_data["condition"]["right"]
	condition_hbox.add_child(right_input)
	
	var action_hbox = HBoxContainer.new()
	vbox.add_child(action_hbox)
	
	var action_type_input = OptionButton.new()
	action_type_input.add_item("spawn")
	action_type_input.add_item("set")
	action_type_input.selected = 0 if rule_data["action"]["type"] == "spawn" else 1
	action_hbox.add_child(action_type_input)
	
	var action_target_input = LineEdit.new()
	action_target_input.text = rule_data["action"]["profile"] if "profile" in rule_data["action"] else rule_data["action"]["property"]
	action_hbox.add_child(action_target_input)
	
	var action_value_input = LineEdit.new()
	action_value_input.text = rule_data["action"].get("value", "")
	action_value_input.visible = rule_data["action"]["type"] == "set"
	action_hbox.add_child(action_value_input)
	
	var save_button = Button.new()
	save_button.text = "Save Changes"
	save_button.connect("pressed", Callable(self, "_on_save_rule_changes").bind(selected_items[0], left_input, operator_input, right_input, action_type_input, action_target_input, action_value_input, edit_dialog))
	vbox.add_child(save_button)
	
	add_child(edit_dialog)
	edit_dialog.popup_centered()

func _on_save_rule_changes(rule_index: int, left_input: LineEdit, operator_input: OptionButton, right_input: LineEdit, action_type_input: OptionButton, action_target_input: LineEdit, action_value_input: LineEdit, edit_dialog: Window):
	var new_rule = {
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
	
	behavior_list.set_item_text(rule_index, format_rule(new_rule))
	edit_dialog.queue_free()

# Add this function to create a new rule
func _on_add_rule_pressed():
	var new_rule = {
		"condition": {
			"left": "property",
			"operator": ">",
			"right": "0"
		},
		"action": {
			"type": "spawn",
			"profile": "default_ant"
		}
	}
	behavior_list.add_item(format_rule(new_rule))
