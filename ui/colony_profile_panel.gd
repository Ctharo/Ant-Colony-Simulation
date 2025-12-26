class_name ColonyProfilePanel
extends Control

signal profile_selected(profile: ColonyProfile)
signal profile_created(profile: ColonyProfile)
signal profile_edited(profile: ColonyProfile)

#region Node References
@onready var profile_list: ItemList = %ProfileList
@onready var edit_button: Button = %EditButton
@onready var new_button: Button = %NewButton
@onready var delete_button: Button = %DeleteButton
#endregion

var current_profile: ColonyProfile
var profiles: Array[ColonyProfile] = []

func _ready() -> void:
	edit_button.pressed.connect(_on_edit_pressed)
	new_button.pressed.connect(_on_new_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	profile_list.item_selected.connect(_on_profile_selected)
	
	_load_profiles()
	_update_ui()

func _load_profiles() -> void:
	# TODO: Load profiles from resources
	profiles.clear()
	profile_list.clear()
	
	# Load all ColonyProfile resources
	var dir = DirAccess.open("res://resources/profiles/colony")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var profile = load("res://resources/profiles/colony/" + file_name) as ColonyProfile
				if profile:
					profiles.append(profile)
					profile_list.add_item(profile.name)
			file_name = dir.get_next()

func _update_ui() -> void:
	var has_selection = profile_list.get_selected_items().size() > 0
	edit_button.disabled = !has_selection
	delete_button.disabled = !has_selection

func _on_profile_selected(index: int) -> void:
	if index >= 0 and index < profiles.size():
		current_profile = profiles[index]
		profile_selected.emit(current_profile)
	_update_ui()

func _on_edit_pressed() -> void:
	if current_profile:
		var editor = ColonyProfileEditor.new()
		add_child(editor)
		editor.edit_profile(current_profile)
		var result = await editor.closed
		if result is ColonyProfile:
			profile_edited.emit(result)
			_load_profiles() # Refresh list

func _on_new_pressed() -> void:
	var editor = ColonyProfileEditor.new()
	add_child(editor)
	editor.create_new_profile()
	var result = await editor.closed
	if result is ColonyProfile:
		profile_created.emit(result)
		_load_profiles() # Refresh list

func _on_delete_pressed() -> void:
	if current_profile:
		# TODO: Add confirmation dialog
		var dir = DirAccess.open("res://resources/profiles/colony")
		if dir:
			# Delete the resource file
			var file_name = current_profile.resource_path.get_file()
			dir.remove(file_name)
			_load_profiles() # Refresh list
