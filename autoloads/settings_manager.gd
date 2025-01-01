extends Node
## Emitted when any setting changes
signal setting_changed(setting_name: String, new_value: Variant)

## Signal emitted when settings are fully initialized
signal settings_initialized

## Paths for different runtime contexts
const EDITOR_SETTINGS_PATH: String = "res://.godot/editor_settings.json"
const RUNTIME_SETTINGS_PATH: String = "user://settings.json"

## Default values for all settings
const DEFAULT_SETTINGS = {
	# Game Settings
	"difficulty": 1,  # 0: Easy, 1: Normal, 2: Hard
	"master_volume": 1.0,
	
	# Simulation Settings
	"ant_spawn_count": 5,
	"food_spawn_count": 500,
	"map_size_x": 6800,
	"map_size_y": 3600,
	"obstacle_density": 0.03,
	"obstacle_size_min": 15,
	"obstacle_size_max": 70,
	"terrain_seed": 0,
	
	# Debug Settings
	"log_level": DebugLogger.LogLevel.TRACE,
	"show_context": false
}

## Logger instance for debugging
var logger: Logger

## Current settings values
var _settings: Dictionary = {}

## Tracks if settings have been initialized
var _is_initialized: bool = false

func _init() -> void:
	logger = Logger.new("settings_manager", DebugLogger.Category.PROGRAM)
	_is_initialized = false

func _ready() -> void:
	load_settings()
	apply_debug_settings()
	_is_initialized = true
	settings_initialized.emit()

#region Public Methods

## Returns whether settings have been fully initialized
func is_initialized() -> bool:
	return _is_initialized

## Get a setting value. Returns default_value if setting doesn't exist
func get_setting(setting_name: String, default_value: Variant = null) -> Variant:
	if not _is_initialized:
		push_warning("Attempting to access setting '%s' before initialization" % setting_name)
	
	# If no default provided, use the one from DEFAULT_SETTINGS if it exists
	if default_value == null and DEFAULT_SETTINGS.has(setting_name):
		default_value = DEFAULT_SETTINGS[setting_name]
		
	return _settings.get(setting_name, default_value)

## Set a setting value and save to disk
func set_setting(setting_name: String, value: Variant) -> void:
	if not _is_initialized:
		push_warning("Attempting to set setting '%s' before initialization" % setting_name)
		
	if _settings.get(setting_name) != value:
		_settings[setting_name] = value
		save_settings()
		
		# Apply special handling for certain settings
		match setting_name:
			"log_level":
				DebugLogger.set_log_level(value)
			"show_context":
				DebugLogger.set_show_context(value)
		
		setting_changed.emit(setting_name, value)

## Apply default settings for any missing values
func ensure_defaults() -> void:
	# Apply all default settings
	for setting_name in DEFAULT_SETTINGS:
		set_default_if_missing(setting_name, DEFAULT_SETTINGS[setting_name])
	
	# Set defaults for all logging categories
	for category in DebugLogger.Category.keys():
		set_default_if_missing("category_" + category.to_lower(), true)

## Reset all settings to their default values
func reset_to_defaults() -> void:
	_settings.clear()
	ensure_defaults()
	save_settings()

## Get the dimensions of the map
func get_map_size() -> Vector2:
	return Vector2(
		get_setting("map_size_x"),
		get_setting("map_size_y")
	)

## Get the obstacle size range
func get_obstacle_size_range() -> Vector2:
	return Vector2(
		get_setting("obstacle_size_min"),
		get_setting("obstacle_size_max")
	)

#endregion

#region Internal Methods

## Gets the appropriate settings path based on runtime context
func get_settings_path() -> String:
	return EDITOR_SETTINGS_PATH if Engine.is_editor_hint() else RUNTIME_SETTINGS_PATH

## Sets a default value for a setting if it doesn't exist
func set_default_if_missing(setting_name: String, default_value: Variant) -> void:
	if not setting_name in _settings:
		set_setting(setting_name, default_value)

## Apply debug-related settings
func apply_debug_settings() -> void:
	# Apply logger settings
	DebugLogger.set_log_level(get_setting("log_level"))
	DebugLogger.set_show_context(get_setting("show_context"))
	
	# Apply category settings
	for category in DebugLogger.Category.keys():
		var setting_key: String = "category_" + category.to_lower()
		DebugLogger.set_category_enabled(
			DebugLogger.Category[category],
			get_setting(setting_key, true)
		)

## Loads settings from disk
func load_settings() -> void:
	var settings_path: String = get_settings_path()
	
	if not FileAccess.file_exists(settings_path):
		logger.info("No settings file found, creating with defaults")
		ensure_defaults()
		return
		
	var file: FileAccess = FileAccess.open(settings_path, FileAccess.READ)
	if not file:
		push_error("Failed to open settings file: %s" % FileAccess.get_open_error())
		ensure_defaults()
		return
		
	var json_string: String = file.get_as_text()
	var parse_result: Variant = JSON.parse_string(json_string)
	
	if parse_result == null:
		push_error("Failed to parse settings JSON")
		ensure_defaults()
		return
		
	_settings = parse_result
	ensure_defaults()  # Fill in any missing settings

## Saves current settings to disk
func save_settings() -> void:
	var settings_path: String = get_settings_path()
	var json_string: String = JSON.stringify(_settings)
	
	var file: FileAccess = FileAccess.open(settings_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save settings: %s" % FileAccess.get_open_error())
		return
		
	file.store_string(json_string)

#endregion
