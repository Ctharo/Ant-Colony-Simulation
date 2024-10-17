extends Control

var profile_dropdown: OptionButton
var ant_profile_list: ItemList
var edit_button: Button
var delete_button: Button
var new_profile_button: Button
var back_button: Button
var main_container: VBoxContainer
var details_container: VBoxContainer

var data_manager: DataManager = DataManager


func _ready():
	create_ui()
	populate_colony_profiles()

func create_ui():
	main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
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

func _on_back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")

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

func _on_ant_profile_selected(index):
	edit_button.disabled = false
	delete_button.disabled = false
	show_ant_details(ant_profile_list.get_item_text(index))

func _on_edit_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var selected_items = ant_profile_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for editing")
		return
	var selected_ant = ant_profile_list.get_item_text(selected_items[0])
	edit_ant_profile(selected_colony, selected_ant)

func _on_delete_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var selected_items = ant_profile_list.get_selected_items()
	if selected_items.is_empty():
		push_warning("No ant profile selected for deletion")
		return
	var selected_ant = ant_profile_list.get_item_text(selected_items[0])
	data_manager.delete_ant_profile(selected_colony, selected_ant)
	_on_profile_selected(profile_dropdown.selected)

func _on_new_profile_pressed():
	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var new_profile = data_manager.create_new_ant_profile("New Ant")
	data_manager.save_ant_profile(selected_colony, new_profile)
	_on_profile_selected(profile_dropdown.selected)
	
func show_ant_details(ant_name: String):
	# Clear previous details
	for child in details_container.get_children():
		child.queue_free()

	var selected_colony = profile_dropdown.get_item_text(profile_dropdown.selected)
	var ant_profiles = data_manager.get_ant_profiles(selected_colony)
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
		var stat_label = Label.new()
		stat_label.text = "  " + stat_name.capitalize() + ": " + str(ant_profile["stats"][stat_name])
		details_container.add_child(stat_label)

	# Display behavior logic
	var behavior_label = Label.new()
	behavior_label.text = "Behavior Logic:"
	details_container.add_child(behavior_label)
	for behavior in ant_profile["behavior_logic"]:
		var behavior_item = Label.new()
		behavior_item.text = "  Priority " + str(behavior["priority"]) + ": " + behavior["condition"] + " then " + behavior["action"]
		details_container.add_child(behavior_item)

	# Animate main container to the left
	var tween = create_tween()
	tween.tween_property(main_container, "position:x", -main_container.size.x / 2, 0.5)

	# Animate details container into view
	tween.parallel().tween_property(details_container, "position:x", get_viewport_rect().size.x - details_container.size.x, 0.5)

func edit_ant_profile(colony_name: String, ant_name: String):
	# This is a placeholder for the edit functionality
	push_warning("Edit functionality not yet implemented for " + ant_name + " from " + colony_name)
	# TODO: Implement edit functionality
