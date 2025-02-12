class_name ColonyProfileEditor
extends Window

signal closed(result: Variant)

#region Node References
@onready var name_edit: LineEdit = %NameEdit
@onready var ant_profiles_list: ItemList = %AntProfilesList
@onready var add_ant_profile_button: Button = %AddAntProfileButton
@onready var remove_ant_profile_button: Button = %RemoveAntProfileButton
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton
#endregion

var editing_profile: ColonyProfile
var selected_ant_profiles: Array[AntProfile] = []

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	add_ant_profile_button.pressed.connect(_on_add_ant_profile_pressed)
	remove_ant_profile_button.pressed.connect(_on_remove_ant_profile_pressed)
	ant_profiles_list.item_selected.connect(_on_ant_profile_selected)
	
	close_requested.connect(_on_cancel_pressed)

func edit_profile(profile: ColonyProfile) -> void:
	editing_profile = profile
	_load_profile_data()
	title = "Edit Colony Profile"
	popup_centered()

func create_new_profile() -> void:
	editing_profile = ColonyProfile.new()
	title = "New Colony Profile"
	popup_centered()

func _load_profile_data() -> void:
	if editing_profile:
		name_edit.text = editing_profile.name
		_update_ant_profiles_list()

func _update_ant_profiles_list() -> void:
	ant_profiles_list.clear()
	selected_ant_profiles.clear()
	
	if editing_profile:
		for profile in editing_profile.ant_profiles:
			selected_ant_profiles.append(profile)
			ant_profiles_list.add_item(profile.name)

func _on_save_pressed() -> void:
	if name_edit.text.strip_edges().is_empty():
		# TODO: Show error
		return
		
	if editing_profile:
		editing_profile.name = name_edit.text
		editing_profile.ant_profiles = selected_ant_profiles
		
		# Save to file
		if editing_profile.resource_path.is_empty():
			var file_name = "res://resources/profiles/colony/" + name_edit.text.to_snake_case() + ".tres"
			ResourceSaver.save(editing_profile, file_name)
		else:
			ResourceSaver.save(editing_profile, editing_profile.resource_path)
		
		closed.emit(editing_profile)
		queue_free()

func _on_cancel_pressed() -> void:
	closed.emit(null)
	queue_free()

func _on_add_ant_profile_pressed() -> void:
	var selector = AntProfileSelector.new()
	add_child(selector)
	var selected = await selector.profile_selected
	if selected:
		selected_ant_profiles.append(selected)
		_update_ant_profiles_list()

func _on_remove_ant_profile_pressed() -> void:
	var selected = ant_profiles_list.get_selected_items()
	if selected.size() > 0:
		var idx = selected[0]
		selected_ant_profiles.remove_at(idx)
		_update_ant_profiles_list()

func _on_ant_profile_selected(_index: int) -> void:
	remove_ant_profile_button.disabled = ant_profiles_list.get_selected_items().size() == 0
