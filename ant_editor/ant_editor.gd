extends Control

var data_manager: DataManager
var profile_list: ItemList
var edit_button: Button
var new_profile_button: Button
var delete_button: Button

var stats_editor: Popup
var behavior_editor: Popup

func _ready():
	data_manager = DataManager
	create_ui()

func create_ui():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(main_container)

	var title = Label.new()
	title.text = "Ant Editor"
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

	create_stats_editor()
	create_behavior_editor()

func create_stats_editor():
	stats_editor = Popup.new()
	stats_editor.size = Vector2(400, 300)
	add_child(stats_editor)

	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	stats_editor.add_child(container)

	# Add stat editors here (similar to the previous implementation)

	var save_button = Button.new()
	save_button.text = "Save Changes"
	save_button.connect("pressed", Callable(self, "_on_save_stats"))
	container.add_child(save_button)
