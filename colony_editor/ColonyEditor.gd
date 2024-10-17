extends Control

var profile_dropdown: OptionButton
var ant_profile_list: ItemList
var edit_button: Button
var delete_button: Button
var new_profile_button: Button
var back_button: Button
var main_container: VBoxContainer
var details_container: VBoxContainer
var edit_popup: Popup

var data_manager: DataManager

func _ready():
	data_manager = DataManager
	create_ui()
	populate_colony_profiles()
	print("UI created and populated")

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		if edit_popup and edit_popup.visible:
			edit_popup.hide()
		else:
			_on_back_pressed()

func create_ui():
	# Main layout
	main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(main_container)

	var title = Label.new()
	title.text = "Colony Profile Editor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	profile_dropdown = OptionButton.new()
	profile_dropdown.connect("item_selected", Callable(self, "_on_profile_selected"))
	main_container.add_child(profile_dropdown)

	ant_profile_list = ItemList.new()
	ant_profile_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ant_profile_list.custom_minimum_size = Vector2(0, 200)  # Set a minimum height
	ant_profile_list.connect("item_selected", Callable(self, "_on_ant_profile_selected"))
	main_container.add_child(ant_profile_list)

	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)

	edit_button = Button.new()
	edit_button.text = "Edit"
	edit_button.connect("pressed", Callable(self, "_on_edit_pressed"))
	button_container.add_child(edit_button)

	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.connect("pressed", Callable(self, "_on_delete_pressed"))
	button_container.add_child(delete_button)

	new_profile_button = Button.new()
	new_profile_button.text = "New Ant Profile"
	new_profile_button.connect("pressed", Callable(self, "_on_new_profile_pressed"))
	button_container.add_child(new_profile_button)

	back_button = Button.new()
	back_button.text = "Back to Main Menu"
	back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	main_container.add_child(back_button)

	# Create edit popup
	create_edit_popup()

func create_edit_popup():
	edit_popup = Popup.new()
	edit_popup.size = Vector2(400, 300)
	add_child(edit_popup)

	var popup_panel = Panel.new()
	popup_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edit_popup.add_child(popup_panel)

	details_container = VBoxContainer.new()
	details_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	edit_popup.add_child(details_container)

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
	ant_profile_list.clear()
	var ant_profiles = data_manager.get_ant_profiles(selected_profile)
	for ant_profile in ant_profiles:
		ant_profile_list.add_item(ant_profile["name"])
	
	print("Selected colony: ", selected_profile)
	print("Ant profiles: ", ant_profiles)
	print("Ant profile list item count: ", ant_profile_list.get_item_count())

func _on_ant_profile_selected(index):
	print("Ant profile selected: ", ant_profile_list.get_item_text(index))
	edit_button.disabled = false
	delete_button.disabled = false
	
func _on_edit_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var selected_items = ant_profile_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for editing")
		return
	var selected_ant = ant_profile_list.get_item_text(selected_items[0])
	show_ant_details(selected_colony, selected_ant)

func _on_delete_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var selected_items = ant_profile_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for deletion")
		return
	var selected_ant = ant_profile_list.get_item_text(selected_items[0])
	var selected_index = selected_items[0]
	data_manager.delete_ant_profile(selected_colony, selected_ant, selected_index)
	_on_profile_selected(profile_dropdown.selected)

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
	
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var new_profile = data_manager.create_new_ant_profile(profile_name)
	data_manager.save_ant_profile(selected_colony, new_profile)
	_on_profile_selected(profile_dropdown.selected)

func show_ant_details(colony_name: String, ant_name: String):
	for child in details_container.get_children():
		child.queue_free()

	var ant_profiles = data_manager.get_ant_profiles(colony_name)
	var ant_profile = ant_profiles.filter(func(profile): return profile["name"] == ant_name)
	
	if ant_profile.is_empty():
		push_error("Ant profile not found: " + ant_name)
		return
	
	ant_profile = ant_profile[0]

	var title = Label.new()
	title.text = ant_name + " Details"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_container.add_child(title)

	# Display stats
	var stats_label = Label.new()
	stats_label.text = "Stats:"
	details_container.add_child(stats_label)
	for stat_name in ant_profile["stats"]:
		var stat_container = HBoxContainer.new()
		var stat_name_label = Label.new()
		stat_name_label.text = stat_name.capitalize() + ":"
		stat_container.add_child(stat_name_label)
		var stat_value = SpinBox.new()
		stat_value.min_value = 1
		stat_value.max_value = 10
		stat_value.value = ant_profile["stats"][stat_name]
		stat_container.add_child(stat_value)
		details_container.add_child(stat_container)

	# Display behavior logic
	var behavior_label = Label.new()
	behavior_label.text = "Behavior Logic:"
	details_container.add_child(behavior_label)
	for behavior in ant_profile["behavior_logic"]:
		var behavior_item = Label.new()
		behavior_item.text = "Priority " + str(behavior["priority"]) + ": " + behavior["condition"] + " then " + behavior["action"]
		details_container.add_child(behavior_item)

	var save_button = Button.new()
	save_button.text = "Save Changes"
	save_button.connect("pressed", Callable(self, "_on_save_changes").bind(colony_name, ant_name))
	details_container.add_child(save_button)

	edit_popup.popup_centered()

func _on_save_changes(colony_name: String, ant_name: String):
	var updated_profile = {
		"name": ant_name,
		"stats": {},
		"behavior_logic": []  # You might want to implement a way to edit behavior logic as well
	}
	
	for child in details_container.get_children():
		if child is HBoxContainer:
			var stat_name = child.get_child(0).text.to_lower().trim_suffix(":")
			var stat_value = child.get_child(1).value
			updated_profile["stats"][stat_name] = stat_value
	
	# Preserve the original behavior logic
	var original_profile = data_manager.get_ant_profiles(colony_name).filter(func(profile): return profile["name"] == ant_name)[0]
	updated_profile["behavior_logic"] = original_profile["behavior_logic"]
	
	data_manager.update_ant_profile(colony_name, updated_profile)
	edit_popup.hide()
	_on_profile_selected(profile_dropdown.selected)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")
