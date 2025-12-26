class_name AntProfileSelector
extends Window

signal profile_selected(profile: AntProfile)

#region Node References
@onready var profile_list: ItemList = %ProfileList
@onready var select_button: Button = %SelectButton
@onready var cancel_button: Button = %CancelButton
@onready var search_edit: LineEdit = %SearchEdit
#endregion

var profiles: Array[AntProfile] = []
var filtered_profiles: Array[AntProfile] = []

func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	profile_list.item_activated.connect(_on_item_activated)
	search_edit.text_changed.connect(_on_search_changed)
	close_requested.connect(_on_cancel_pressed)
	
	title = "Select Ant Profile"
	_load_profiles()
	popup_centered()

func _load_profiles() -> void:
	profiles.clear()
	filtered_profiles.clear()
	profile_list.clear()
	
	# Load all AntProfile resources
	var dir = DirAccess.open("res://resources/profiles/ant")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var profile = load("res://resources/profiles/ant/" + file_name) as AntProfile
				if profile:
					profiles.append(profile)
					filtered_profiles.append(profile)
					profile_list.add_item(profile.name)
			file_name = dir.get_next()
	
	_update_ui()

func _update_ui() -> void:
	select_button.disabled = profile_list.get_selected_items().size() == 0

func _filter_profiles(search_text: String) -> void:
	filtered_profiles.clear()
	profile_list.clear()
	
	var lower_search = search_text.to_lower()
	for profile in profiles:
		if profile.name.to_lower().contains(lower_search):
			filtered_profiles.append(profile)
			profile_list.add_item(profile.name)

func _on_select_pressed() -> void:
	var selected = profile_list.get_selected_items()
	if selected.size() > 0:
		var profile = filtered_profiles[selected[0]]
		profile_selected.emit(profile)
		queue_free()

func _on_cancel_pressed() -> void:
	profile_selected.emit(null)
	queue_free()

func _on_item_activated(index: int) -> void:
	if index >= 0 and index < filtered_profiles.size():
		profile_selected.emit(filtered_profiles[index])
		queue_free()

func _on_search_changed(new_text: String) -> void:
	_filter_profiles(new_text)
