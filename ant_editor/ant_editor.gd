extends Control

var data_manager: DataManager
var profile_list: ItemList
var edit_button: Button
var new_profile_button: Button
var delete_button: Button
var back_button: Button

var stats_editor: Popup
var behavior_editor: Popup

var profile_id_to_name: Dictionary = {}

func _ready():
	data_manager = DataManager
	create_ui()
	populate_profile_list()

func create_ui():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(main_container)

	var title = Label.new()
	title.text = "Ant Profile Editor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	profile_list = ItemList.new()
	profile_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_list.custom_minimum_size = Vector2(0, 200)
	profile_list.connect("item_selected", Callable(self, "_on_profile_selected"))
	main_container.add_child(profile_list)

	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)

	edit_button = Button.new()
	edit_button.text = "Edit Profile"
	edit_button.connect("pressed", Callable(self, "_on_edit_pressed"))
	button_container.add_child(edit_button)

	new_profile_button = Button.new()
	new_profile_button.text = "New Profile"
	new_profile_button.connect("pressed", Callable(self, "_on_new_profile_pressed"))
	button_container.add_child(new_profile_button)

	delete_button = Button.new()
	delete_button.text = "Delete Profile"
	delete_button.connect("pressed", Callable(self, "_on_delete_pressed"))
	button_container.add_child(delete_button)

	back_button = Button.new()
	back_button.text = "Back to Main Menu"
	back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	main_container.add_child(back_button)

	create_stats_editor()
	create_behavior_editor()

func create_stats_editor():
	stats_editor = Popup.new()
	stats_editor.size = Vector2(400, 300)
	add_child(stats_editor)

	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	stats_editor.add_child(container)

	var stats = ["sight_range", "pheromone_sense_range", "speed", "strength", "intelligence"]
	for stat in stats:
		var stat_container = HBoxContainer.new()
		var stat_label = Label.new()
		stat_label.text = stat.capitalize()
		var stat_input = SpinBox.new()
		stat_input.min_value = 1
		stat_input.max_value = 100
		stat_container.add_child(stat_label)
		stat_container.add_child(stat_input)
		container.add_child(stat_container)

	var save_button = Button.new()
	save_button.text = "Save Changes"
	save_button.connect("pressed", Callable(self, "_on_save_stats"))
	container.add_child(save_button)

func create_behavior_editor():
	behavior_editor = Popup.new()
	behavior_editor.size = Vector2(600, 400)
	add_child(behavior_editor)

	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	behavior_editor.add_child(container)

	var behavior_list = ItemList.new()
	behavior_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(behavior_list)

	var add_behavior_button = Button.new()
	add_behavior_button.text = "Add Behavior"
	add_behavior_button.connect("pressed", Callable(self, "_on_add_behavior_pressed"))
	container.add_child(add_behavior_button)

	var save_button = Button.new()
	save_button.text = "Save Changes"
	save_button.connect("pressed", Callable(self, "_on_save_behavior"))
	container.add_child(save_button)

func populate_profile_list():
	profile_list.clear()
	profile_id_to_name.clear()
	var ant_profiles = data_manager.get_all_ant_profiles()
	for profile_id in ant_profiles:
		var profile_name = ant_profiles[profile_id]["name"]
		profile_list.add_item(profile_name)
		profile_id_to_name[profile_name] = profile_id

func _on_edit_pressed():
	var selected_items = profile_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for editing")
		return
	var selected_profile_name = profile_list.get_item_text(selected_items[0])
	var selected_profile_id = profile_id_to_name[selected_profile_name]
	show_profile_editor(selected_profile_id)

func _create_new_ant_profile(profile_name: String):
	var profile_id = data_manager.create_new_ant_profile(profile_name)
	populate_profile_list()
	
	# Select the new profile in the list
	for i in range(profile_list.get_item_count()):
		if profile_list.get_item_text(i) == profile_name:
			profile_list.select(i)
			_on_profile_selected(i)
			break

func _confirm_delete_profile(profile_name: String):
	var profile_id = profile_id_to_name[profile_name]
	data_manager.delete_ant_profile(profile_id)
	populate_profile_list()
	edit_button.disabled = true
	delete_button.disabled = true

func _on_profile_selected(index):
	edit_button.disabled = false
	delete_button.disabled = false


func show_profile_editor(profile_name: String):
	var profile_data = data_manager.get_ant_profile(profile_name)
	show_stats_editor(profile_data)
	show_behavior_editor(profile_data)

func show_stats_editor(profile_data: Dictionary):
	var stat_containers = stats_editor.get_node("VBoxContainer").get_children()
	for stat_container in stat_containers:
		if stat_container is HBoxContainer:
			var stat_name = stat_container.get_child(0).text.to_lower()
			var stat_input = stat_container.get_child(1)
			stat_input.value = profile_data["stats"].get(stat_name, 1)
	stats_editor.popup_centered()

func show_behavior_editor(profile_data: Dictionary):
	var behavior_list = behavior_editor.get_node("VBoxContainer/ItemList")
	behavior_list.clear()
	for behavior in profile_data["behavior_logic"]:
		behavior_list.add_item(format_behavior(behavior))
	behavior_editor.popup_centered()

func format_behavior(behavior: Dictionary) -> String:
	return "If %s then %s (Priority: %d)" % [behavior["condition"], behavior["action"], behavior["priority"]]
	
func _on_new_profile_pressed():
	var dialog = ConfirmationDialog.new()
	dialog.title = "New Ant Profile"
	var line_edit = LineEdit.new()
	line_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(line_edit)
	add_child(dialog)
	
	dialog.connect("confirmed", Callable(self, "_on_new_profile_confirmed").bind(line_edit))
	dialog.popup_centered()

func _on_new_profile_confirmed(line_edit: LineEdit):
	var profile_name = line_edit.text.strip_edges()
	if profile_name.is_empty():
		push_warning("Profile name cannot be empty")
		return
	
	if data_manager.ant_profile_exists(profile_name):
		# Show overwrite warning
		var overwrite_dialog = ConfirmationDialog.new()
		overwrite_dialog.dialog_text = "An ant profile with the name '%s' already exists. Do you want to overwrite it?" % profile_name
		overwrite_dialog.connect("confirmed", Callable(self, "_on_overwrite_profile_confirmed").bind(profile_name))
		add_child(overwrite_dialog)
		overwrite_dialog.popup_centered()
	else:
		_create_new_ant_profile(profile_name)

func _on_overwrite_profile_confirmed(profile_name: String):
	_create_new_ant_profile(profile_name)


func _on_delete_pressed():
	var selected_items = profile_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for deletion")
		return
	var selected_profile = profile_list.get_item_text(selected_items[0])
	
	# Show a confirmation dialog before deleting
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to delete the ant profile '%s'? This action cannot be undone." % selected_profile
	confirm_dialog.connect("confirmed", Callable(self, "_confirm_delete_profile").bind(selected_profile))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _on_save_stats():
	var selected_items = profile_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for saving stats")
		return
	var selected_profile = profile_list.get_item_text(selected_items[0])
	
	var updated_stats = {}
	var stat_containers = stats_editor.get_node("VBoxContainer").get_children()
	for stat_container in stat_containers:
		if stat_container is HBoxContainer:
			var stat_name = stat_container.get_child(0).text.to_lower()
			var stat_value = stat_container.get_child(1).value
			updated_stats[stat_name] = stat_value
	
	data_manager.update_ant_profile_stats(selected_profile, updated_stats)
	stats_editor.hide()

func _on_save_behavior():
	var selected_items = profile_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for saving behavior")
		return
	var selected_profile = profile_list.get_item_text(selected_items[0])
	
	var updated_behavior = []
	var behavior_list = behavior_editor.get_node("VBoxContainer/ItemList")
	for i in range(behavior_list.get_item_count()):
		updated_behavior.append(parse_behavior(behavior_list.get_item_text(i)))
	
	data_manager.update_ant_profile_behavior(selected_profile, updated_behavior)
	behavior_editor.hide()

func _on_add_behavior_pressed():
	var behavior_list = behavior_editor.get_node("VBoxContainer/ItemList")
	behavior_list.add_item("If [condition] then [action] (Priority: 1)")

func parse_behavior(behavior_text: String) -> Dictionary:
	# This is a placeholder implementation and should be expanded based on your specific behavior format
	var parts = behavior_text.split(" then ")
	var condition = parts[0].trim_prefix("If ")
	var action_priority = parts[1].split(" (Priority: ")
	var action = action_priority[0]
	var priority = int(action_priority[1].trim_suffix(")"))
	
	return {
		"condition": condition,
		"action": action,
		"priority": priority
	}

func _on_back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")
