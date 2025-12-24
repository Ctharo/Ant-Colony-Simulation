extends Node
## Emitted when any setting changes
signal setting_changed(setting_name: String, new_value: Variant)

## Signal emitted when settings are fully initialized
signal settings_initialized

## Signal emitted when colony profile is updated
signal colony_profile_changed(profile: ColonyProfile)

## Paths for different runtime contexts
const EDITOR_SETTINGS_PATH: String = "res://.godot/editor_settings.json"
const RUNTIME_SETTINGS_PATH: String = "user://settings.json"

## Default colony profile path
const DEFAULT_COLONY_PROFILE_PATH: String = "res://entities/colony/resources/standard_colony_profile.tres"

## Default values for all settings
## Note: ant_spawn_count removed - now defined in ColonyProfile.initial_ants
const DEFAULT_SETTINGS = {
	# Game Settings
	"difficulty": 1,  # 0: Easy, 1: Normal, 2: Hard
	"master_volume": 1.0,

	# Simulation Settings
	"colony_profile_path": DEFAULT_COLONY_PROFILE_PATH,
	"food_spawn_count": 500,
	"map_size_x": 6800,
	"map_size_y": 3600,
	"obstacle_density": 0.00001,
	"obstacle_size_min": 15,
	"obstacle_size_max": 70,
	"terrain_seed": 0,

	# Debug Settings
	"log_level": DebugLogger.LogLevel.TRACE,
	"show_context": false
}

## Logger instance for debugging
var logger: iLogger

## Current settings values
var _settings: Dictionary = {}

## Tracks if settings have been initialized
var _is_initialized: bool = false

## Cached colony profile reference
var _colony_profile: ColonyProfile

func _init() -> void:
	logger = iLogger.new("settings_manager", DebugLogger.Category.PROGRAM)
	_is_initialized = false

func _ready() -> void:
	load_settings()
	apply_debug_settings()
	_load_colony_profile()
	_is_initialized = true
	settings_initialized.emit()

#region Public Methods

## Returns whether settings have been fully initialized
func is_initialized() -> bool:
	return _is_initialized

## Get a setting value. Returns default_value if setting doesn't exist
func get_setting(setting_name: String, default_value: Variant = null) -> Variant:
	# If no default provided, use the one from DEFAULT_SETTINGS if it exists
	if default_value == null and DEFAULT_SETTINGS.has(setting_name):
		default_value = DEFAULT_SETTINGS[setting_name]

	return _settings.get(setting_name, default_value)

## Set a setting value and save to disk
func set_setting(setting_name: String, value: Variant) -> void:

	if _settings.get(setting_name) != value:
		_settings[setting_name] = value
		save_settings()

		# Apply special handling for certain settings
		match setting_name:
			"log_level":
				DebugLogger.set_log_level(value)
			"show_context":
				DebugLogger.set_show_context(value)
			"colony_profile_path":
				_load_colony_profile()
			_:
				# Handle category settings (category_task, category_entity, etc.)
				if setting_name.begins_with("category_"):
					var category_name = setting_name.trim_prefix("category_").to_upper()
					if DebugLogger.Category.has(category_name):
						DebugLogger.set_category_enabled(
							DebugLogger.Category[category_name],
							value
						)

		setting_changed.emit(setting_name, value)
		logger.trace("Setting changed: %s = %s" % [setting_name, str(value)])

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

#region Colony Profile Methods

## Load the colony profile from the configured path
func _load_colony_profile() -> void:
	var profile_path = get_setting("colony_profile_path", DEFAULT_COLONY_PROFILE_PATH)
	
	if ResourceLoader.exists(profile_path):
		_colony_profile = load(profile_path) as ColonyProfile
		if _colony_profile:
			logger.info("Loaded colony profile: %s" % _colony_profile.name)
			colony_profile_changed.emit(_colony_profile)
		else:
			logger.error("Failed to load colony profile from: %s" % profile_path)
			_colony_profile = ColonyProfile.create_standard()
	else:
		logger.warn("Colony profile not found at: %s, using default" % profile_path)
		_colony_profile = ColonyProfile.create_standard()

## Get the current colony profile
func get_colony_profile() -> ColonyProfile:
	if not _colony_profile:
		_load_colony_profile()
	return _colony_profile

## Update a colony profile property and save to disk
func update_colony_profile_property(property: String, value: Variant) -> Result:
	if not _colony_profile:
		return Result.new(Result.ErrorType.INVALID_RESOURCE, "No colony profile loaded")
	
	if not property in _colony_profile:
		return Result.new(Result.ErrorType.NOT_FOUND, "Property not found: %s" % property)
	
	_colony_profile.set(property, value)
	
	# Save the resource
	var save_result = save_colony_profile()
	if save_result.is_error():
		return save_result
	
	colony_profile_changed.emit(_colony_profile)
	logger.debug("Updated colony profile property: %s = %s" % [property, str(value)])
	return Result.new()

## Update initial ant counts in the colony profile
func update_colony_initial_ants(profile_id: String, count: int) -> Result:
	if not _colony_profile:
		return Result.new(Result.ErrorType.INVALID_RESOURCE, "No colony profile loaded")
	
	_colony_profile.initial_ants[profile_id] = count
	
	var save_result = save_colony_profile()
	if save_result.is_error():
		return save_result
	
	colony_profile_changed.emit(_colony_profile)
	logger.debug("Updated initial ants for %s: %d" % [profile_id, count])
	return Result.new()

## Save the current colony profile to its resource file
func save_colony_profile() -> Result:
	if not _colony_profile:
		return Result.new(Result.ErrorType.INVALID_RESOURCE, "No colony profile to save")
	
	var profile_path = get_setting("colony_profile_path", DEFAULT_COLONY_PROFILE_PATH)
	
	# Only save to user:// paths or if in editor
	if Engine.is_editor_hint() or profile_path.begins_with("user://"):
		var error = ResourceSaver.save(_colony_profile, profile_path)
		if error != OK:
			logger.error("Failed to save colony profile: %s" % error)
			return Result.new(Result.ErrorType.ACCESS_ERROR, "Failed to save: %s" % error)
		logger.info("Saved colony profile to: %s" % profile_path)
	else:
		# At runtime, save to user directory instead
		var user_path = "user://colony_profile.tres"
		var error = ResourceSaver.save(_colony_profile, user_path)
		if error != OK:
			logger.error("Failed to save colony profile: %s" % error)
			return Result.new(Result.ErrorType.ACCESS_ERROR, "Failed to save: %s" % error)
		
		# Update setting to point to user path
		set_setting("colony_profile_path", user_path)
		logger.info("Saved colony profile to user directory: %s" % user_path)
	
	return Result.new()

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
	logger.info("Settings loaded successfully")

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
