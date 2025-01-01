extends Node

## Emitted when any setting changes
signal setting_changed(setting_name: String, new_value: Variant)

const SETTINGS_PATH = "user://settings.json"

var logger: Logger

## Current settings values
var _settings: Dictionary = {}

func _init() -> void:
	logger = Logger.new("settings_manager", DebugLogger.Category.PROGRAM)
	logger.info("Initializing Settings Manager")
	load_settings()

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
		logger.trace("Setting changed: %s = %s" % [setting_name, str(value)])

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
	logger.trace("Loading settings from file")

	if not FileAccess.file_exists(SETTINGS_PATH):
		logger.info("No settings file found, using defaults")
		ensure_defaults()
		return

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		logger.error("Failed to open settings file: %s" % FileAccess.get_open_error())
		ensure_defaults()
		return

	var json_string = file.get_as_text()
	var parse_result = JSON.parse_string(json_string)

	if parse_result == null:
		logger.error("Failed to parse settings JSON")
		ensure_defaults()
		return

	_settings = parse_result
	ensure_defaults()  # Fill in any missing settings
	logger.info("Settings loaded successfully")

func save_settings() -> void:
	logger.trace("Saving settings to file")

	var json_string = JSON.stringify(_settings)
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		logger.info("Settings saved successfully")
	else:
		logger.error("Failed to save settings: %s" % FileAccess.get_open_error())
#endregion
