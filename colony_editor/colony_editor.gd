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

var data_manager: DataManager

# Colony Behavior Editor components
var behavior_popup: Popup
var behavior_list: ItemList
var add_rule_button: Button
var edit_rule_button: Button
var delete_rule_button: Button
var save_behavior_button: Button

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

	var lists_container = HBoxContainer.new()
	main_container.add_child(lists_container)

	var colony_ant_container = VBoxContainer.new()
	lists_container.add_child(colony_ant_container)
	
	var colony_ant_label = Label.new()
	colony_ant_label.text = "Colony Ants"
	colony_ant_container.add_child(colony_ant_label)

	colony_ant_list = ItemList.new()
	colony_ant_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colony_ant_list.custom_minimum_size = Vector2(200, 200)
	colony_ant_container.add_child(colony_ant_list)

	var available_ant_container = VBoxContainer.new()
	lists_container.add_child(available_ant_container)
	
	var available_ant_label = Label.new()
	available_ant_label.text = "Available Ant Profiles"
	available_ant_container.add_child(available_ant_label)

	available_ant_list = ItemList.new()
	available_ant_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	available_ant_list.custom_minimum_size = Vector2(200, 200)
	available_ant_container.add_child(available_ant_list)

	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)

	edit_colony_behavior_button = Button.new()
	edit_colony_behavior_button.text = "Edit Colony Behavior"
	edit_colony_behavior_button.connect("pressed", Callable(self, "_on_edit_colony_behavior_pressed"))
	button_container.add_child(edit_colony_behavior_button)

	add_ant_profile_button = Button.new()
	add_ant_profile_button.text = "Add Ant Profile"
	add_ant_profile_button.connect("pressed", Callable(self, "_on_add_ant_profile_pressed"))
	button_container.add_child(add_ant_profile_button)

	remove_ant_profile_button = Button.new()
	remove_ant_profile_button.text = "Remove Ant Profile"
	remove_ant_profile_button.connect("pressed", Callable(self, "_on_remove_ant_profile_pressed"))
	button_container.add_child(remove_ant_profile_button)

	new_colony_button = Button.new()
	new_colony_button.text = "New Colony"
	new_colony_button.connect("pressed", Callable(self, "_on_new_colony_pressed"))
	main_container.add_child(new_colony_button)

	delete_colony_button = Button.new()
	delete_colony_button.text = "Delete Colony"
	delete_colony_button.connect("pressed", Callable(self, "_on_delete_colony_pressed"))
	main_container.add_child(delete_colony_button)

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

func _on_profile_selected(index):
	var selected_profile = profile_dropdown.get_item_text(index)
	update_colony_ant_list(selected_profile)
	update_available_ant_list(selected_profile)
	edit_colony_behavior_button.disabled = false
	delete_colony_button.disabled = false

func update_colony_ant_list(colony_name: String):
	colony_ant_list.clear()
	var ant_profiles = data_manager.get_ant_profiles_for_colony(colony_name)
	for ant_profile in ant_profiles:
		colony_ant_list.add_item(ant_profile)
		
func update_available_ant_list(colony_name: String):
	available_ant_list.clear()
	var all_profiles = data_manager.get_all_ant_profiles()
	var colony_profiles = data_manager.get_ant_profiles_for_colony(colony_name)
	for profile in all_profiles:
		if profile not in colony_profiles:
			available_ant_list.add_item(profile)
			
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

func _on_add_rule_pressed():
	# Implement rule addition logic
	pass

func _on_edit_rule_pressed():
	# Implement rule editing logic
	pass

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

func parse_rule(rule_text: String) -> Dictionary:
	# Implement parsing logic to convert rule text back to a dictionary
	# This is a placeholder and needs to be implemented based on your rule format
	return {}

func _on_add_ant_profile_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var selected_items = available_ant_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for addition")
		return
	var selected_ant = available_ant_list.get_item_text(selected_items[0])
	data_manager.add_ant_profile_to_colony(selected_colony, selected_ant)
	update_colony_ant_list(selected_colony)
	update_available_ant_list(selected_colony)

func _on_remove_ant_profile_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var selected_items = colony_ant_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for removal")
		return
	var selected_ant = colony_ant_list.get_item_text(selected_items[0])
	data_manager.remove_ant_profile_from_colony(selected_colony, selected_ant)
	update_colony_ant_list(selected_colony)
	update_available_ant_list(selected_colony)

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
	
	data_manager.create_new_colony(colony_name)
	populate_colony_profiles()
	profile_dropdown.select(profile_dropdown.get_item_count() - 1)
	_on_profile_selected(profile_dropdown.get_item_count() - 1)

func _on_delete_colony_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	data_manager.delete_colony(selected_colony)
	populate_colony_profiles()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")
