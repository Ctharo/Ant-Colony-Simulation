extends Node

## Emitted when any setting changes
signal setting_changed(setting_name: String, new_value: Variant)

# Use different paths for editor and runtime
const EDITOR_SETTINGS_PATH = "res://.godot/editor_settings.json"
const RUNTIME_SETTINGS_PATH = "user://settings.json"

var logger: Logger

## Current settings values
var _settings: Dictionary = {}

func _init() -> void:
	load_settings()

func get_settings_path() -> String:
	# Check if we're running in the editor
	if Engine.is_editor_hint():
		return EDITOR_SETTINGS_PATH
	return RUNTIME_SETTINGS_PATH

#region Public Methods
## Get a setting value. Returns default_value if setting doesn't exist
func get_setting(setting_name: String, default_value: Variant = null) -> Variant:
	return _settings.get(setting_name, default_value)

## Set a setting value and save to disk
func set_setting(setting_name: String, value: Variant) -> void:
	if _settings.get(setting_name) != value:
		_settings[setting_name] = value
		save_settings()
		setting_changed.emit(setting_name, value)

## Apply default settings for any missing values
func ensure_defaults() -> void:
	_set_default_if_missing("difficulty", 1)  # Normal
	_set_default_if_missing("master_volume", 1.0)
	_set_default_if_missing("log_level", DebugLogger.LogLevel.INFO)
	_set_default_if_missing("show_context", true)

	# Set defaults for all logging categories
	for category in DebugLogger.Category.keys():
		_set_default_if_missing("category_" + category.to_lower(), true)
#endregion

#region Internal Methods
func _set_default_if_missing(setting_name: String, default_value: Variant) -> void:
	if not setting_name in _settings:
		set_setting(setting_name, default_value)

func load_settings() -> void:
	var settings_path = get_settings_path()

	if not FileAccess.file_exists(settings_path):
		ensure_defaults()
		return

	var file = FileAccess.open(settings_path, FileAccess.READ)
	if not file:
		push_error("Failed to open settings file: %s" % FileAccess.get_open_error())
		ensure_defaults()
		return

	var json_string = file.get_as_text()
	var parse_result = JSON.parse_string(json_string)
	if parse_result == null:
		push_error("Failed to parse settings JSON")
		ensure_defaults()
		return

	_settings = parse_result
	ensure_defaults()  # Fill in any missing settings

func save_settings() -> void:
	var settings_path = get_settings_path()
	var json_string = JSON.stringify(_settings)
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save settings: %s" % FileAccess.get_open_error())
		return
	file.store_string(json_string)
#endregion
