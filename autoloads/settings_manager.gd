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

## Default values for all settings - SINGLE SOURCE OF TRUTH
const DEFAULT_SETTINGS := {
	# Game Settings
	"difficulty": 1,  # 0: Easy, 1: Normal, 2: Hard
	"master_volume": 1.0,

	# Simulation Settings
	# Empty = resolve the colony profile from the ResourceLibrary catalog
	# (id "standard_colony", falling back to the first cataloged colony).
	# The old res:// standard_colony_profile.tres default is treated as
	# legacy and redirected to the catalog too.
	"colony_profile_path": "",
	"food_spawn_count": 500,
	"ant_spawn_count": 5,
	"sim_speed_index": 0,
	"sim_speed_1": 1.0,
	"sim_speed_2": 5.0,
	"sim_speed_3": 10.0,
	"debug_show_heatmap": false,
	"debug_show_status_bars": false,
	"debug_show_influence_arrows": false,
	"map_size_x": 6800,
	"map_size_y": 3600,
	"obstacle_density": 0.00001,
	"obstacle_size_min": 15,
	"obstacle_size_max": 70,
	"terrain_seed": 0,

	# Debug Settings
	"log_level": DebugLogger.LogLevel.TRACE,
	"show_context": false,
}

## Category default states - defines which debug categories are on by default
## This is the SINGLE SOURCE OF TRUTH for category defaults
const DEFAULT_CATEGORY_STATES := {
	"category_task": false,
	"category_logic": true,
	"category_movement": false,
	"category_influence": false,
	"category_behavior": false,
	"category_condition": false,
	"category_context": false,
	"category_entity": true,
	"category_property": false,
	"category_transition": false,
	"category_hierarchy": false,
	"category_ui": false,
	"category_program": true,  # Program category should generally be on
	"category_data": false,
}

## UI constraints for settings - centralizes min/max/step for spinboxes
const SETTING_CONSTRAINTS := {
	"food_spawn_count": {"min": 0, "max": 2000, "step": 10},
	"map_size_x": {"min": 800, "max": 20000, "step": 100},
	"map_size_y": {"min": 600, "max": 20000, "step": 100},
	"obstacle_density": {"min": 0.0, "max": 0.001, "step": 0.000001},
	"obstacle_size_min": {"min": 5, "max": 100, "step": 1},
	"obstacle_size_max": {"min": 10, "max": 200, "step": 1},
	"terrain_seed": {"min": 0, "max": 999999, "step": 1},
	"master_volume": {"min": 0.0, "max": 1.0, "step": 0.05},
	# Colony profile constraints
	"initial_ants": {"min": 0, "max": 100, "step": 1},
	"max_ants": {"min": 1, "max": 200, "step": 1},
	"spawn_rate": {"min": 1.0, "max": 60.0, "step": 0.5},
	"colony_radius": {"min": 20.0, "max": 200.0, "step": 5.0},
	"ant_spawn_count": {"min": 1, "max": 100, "step": 1},
	"sim_speed_1": {"min": 0.1, "max": 50.0, "step": 0.1},
	"sim_speed_2": {"min": 0.1, "max": 50.0, "step": 0.1},
	"sim_speed_3": {"min": 0.1, "max": 50.0, "step": 0.1},
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
	# SettingsManager readies BEFORE ResourceLibrary (autoload order), so
	# catalog resolution must be deferred past the remaining _ready calls.
	_resolve_colony_profile.call_deferred()
	_is_initialized = true
	settings_initialized.emit()


#region Public Methods

## Returns whether settings have been fully initialized
func is_initialized() -> bool:
	return _is_initialized


## Get a setting value. Returns the default if setting doesn't exist.
func get_setting(setting_name: String, default_value: Variant = null) -> Variant:
	# Priority: stored value -> explicit default -> DEFAULT_SETTINGS -> DEFAULT_CATEGORY_STATES
	if _settings.has(setting_name):
		return _settings[setting_name]

	if default_value != null:
		return default_value

	if DEFAULT_SETTINGS.has(setting_name):
		return DEFAULT_SETTINGS[setting_name]

	if DEFAULT_CATEGORY_STATES.has(setting_name):
		return DEFAULT_CATEGORY_STATES[setting_name]

	return null


## Get the default value for a setting
func get_default(setting_name: String) -> Variant:
	if DEFAULT_SETTINGS.has(setting_name):
		return DEFAULT_SETTINGS[setting_name]
	if DEFAULT_CATEGORY_STATES.has(setting_name):
		return DEFAULT_CATEGORY_STATES[setting_name]
	return null


## Get constraints for a setting (for UI spinboxes, sliders, etc.)
func get_constraints(setting_name: String) -> Dictionary:
	return SETTING_CONSTRAINTS.get(setting_name, {})


## Set a setting value and save to disk
func set_setting(setting_name: String, value: Variant) -> void:
	if _settings.get(setting_name) != value:
		_settings[setting_name] = value
		save_settings()
		_apply_setting_side_effects(setting_name, value)
		setting_changed.emit(setting_name, value)
		logger.trace("Setting changed: %s = %s" % [setting_name, str(value)])


## Apply side effects when certain settings change
func _apply_setting_side_effects(setting_name: String, value: Variant) -> void:
	match setting_name:
		"log_level":
			DebugLogger.set_log_level(value)
		"show_context":
			DebugLogger.set_show_context(value)
		"colony_profile_path":
			_resolve_colony_profile()
		_:
			# Handle category settings (category_task, category_entity, etc.)
			if setting_name.begins_with("category_"):
				var category_name := setting_name.trim_prefix("category_").to_upper()
				if DebugLogger.Category.has(category_name):
					DebugLogger.set_category_enabled(
						DebugLogger.Category[category_name],
						value
					)


## Apply default settings for any missing values
func ensure_defaults() -> void:
	# Apply all default settings
	for setting_name in DEFAULT_SETTINGS:
		_set_default_if_missing(setting_name, DEFAULT_SETTINGS[setting_name])

	# Apply all category defaults
	for setting_name in DEFAULT_CATEGORY_STATES:
		_set_default_if_missing(setting_name, DEFAULT_CATEGORY_STATES[setting_name])


## Reset all settings to their default values
func reset_to_defaults() -> void:
	_settings.clear()
	ensure_defaults()
	apply_debug_settings()
	save_settings()
	logger.info("Settings reset to defaults")


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

## Resolves the active colony profile, preferring the ResourceLibrary
## catalog so every UI panel edits the SAME instance the sandbox spawns
## from. Resolution order:
##  1. A cataloged colony whose on-disk path matches colony_profile_path
##  2. The cataloged default (id "standard_colony")
##  3. The first cataloged colony
##  4. Direct load of colony_profile_path (external/legacy file that exists)
## A res:// path in the setting is treated as legacy and redirected to the
## catalog (the old default pointed at a res:// .tres whose reference chain
## has been migrated to user://).
func _resolve_colony_profile() -> void:
	var profile_path: String = get_setting("colony_profile_path")

	var entries: Array = ResourceLibrary.get_entries(ResourceLibrary.KIND_COLONY)

	if not profile_path.is_empty() and not profile_path.begins_with("res://"):
		for entry in entries:
			if entry.path == profile_path:
				_set_colony_profile(entry.resource, entry.path)
				return

	var by_id: ColonyProfile = ResourceLibrary.get_by_id(
		ResourceLibrary.KIND_COLONY, "standard_colony") as ColonyProfile
	if by_id:
		_set_colony_profile(by_id, by_id.resource_path)
		return

	if not entries.is_empty():
		var entry = entries[0]
		_set_colony_profile(entry.resource, entry.path)
		return

	if not profile_path.is_empty() and ResourceLoader.exists(profile_path):
		var loaded := load(profile_path) as ColonyProfile
		if loaded:
			_set_colony_profile(loaded, profile_path)
			return

	push_error("No colony profile could be resolved (catalog empty and no valid path)")


func _set_colony_profile(profile: ColonyProfile, path: String) -> void:
	_colony_profile = profile
	# Record without recursing through set_setting side effects.
	if _settings.get("colony_profile_path") != path:
		_settings["colony_profile_path"] = path
		save_settings()
	logger.info("Colony profile resolved: %s (%s)" % [profile.name, path])
	colony_profile_changed.emit(profile)


## Get the current colony profile (lazy: resolves from the catalog if a
## caller asks before the deferred startup resolution has run).
func get_colony_profile() -> ColonyProfile:
	if not _colony_profile:
		_resolve_colony_profile()
	return _colony_profile


## Update a property on the current colony profile
func update_colony_profile_property(property: String, value: Variant) -> Result:
	if not _colony_profile:
		return Result.new(Result.ErrorType.INVALID_RESOURCE, "No colony profile loaded")

	if not property in _colony_profile:
		return Result.new(Result.ErrorType.VALIDATION_FAILED, "Invalid property: %s" % property)

	_colony_profile.set(property, value)
	colony_profile_changed.emit(_colony_profile)
	return save_colony_profile()


## Update the initial ants count for a specific ant profile
func update_colony_initial_ants(profile_id: String, count: int) -> Result:
	if not _colony_profile:
		return Result.new(Result.ErrorType.INVALID_RESOURCE, "No colony profile loaded")

	_colony_profile.initial_ants[profile_id] = count
	colony_profile_changed.emit(_colony_profile)
	return save_colony_profile()


## Save the current colony profile through ResourceLibrary (validation,
## catalog refresh, rename handling — same pipeline as every other kind).
func save_colony_profile() -> Result:
	if not _colony_profile:
		return Result.new(Result.ErrorType.INVALID_RESOURCE, "No colony profile to save")

	var prev := _colony_profile.resource_path \
		if _colony_profile.resource_path.begins_with("user://behavior/") else ""
	var err := ResourceLibrary.save_resource(
		_colony_profile, ResourceLibrary.KIND_COLONY, prev)
	if err != OK:
		logger.error("Failed to save colony profile: %s" % error_string(err))
		return Result.new(Result.ErrorType.ACCESS_ERROR, "Failed to save: %s" % error_string(err))

	if _settings.get("colony_profile_path") != _colony_profile.resource_path:
		_settings["colony_profile_path"] = _colony_profile.resource_path
		save_settings()
	return Result.new()

#endregion


#region Debug Settings

## Apply debug-related settings to DebugLogger
func apply_debug_settings() -> void:
	# Apply logger settings
	DebugLogger.set_log_level(get_setting("log_level"))
	DebugLogger.set_show_context(get_setting("show_context"))

	# Apply category settings from our stored values
	for category in DebugLogger.Category.keys():
		var setting_key: String = "category_" + category.to_lower()
		var enabled: bool = get_setting(setting_key)
		DebugLogger.set_category_enabled(DebugLogger.Category[category], enabled)

#endregion


#region Persistence

## Gets the appropriate settings path based on runtime context
func get_settings_path() -> String:
	return EDITOR_SETTINGS_PATH if Engine.is_editor_hint() else RUNTIME_SETTINGS_PATH


## Sets a default value for a setting if it doesn't exist
func _set_default_if_missing(setting_name: String, default_value: Variant) -> void:
	if not setting_name in _settings:
		_settings[setting_name] = default_value


## Loads settings from disk
func load_settings() -> void:
	var settings_path: String = get_settings_path()

	if not FileAccess.file_exists(settings_path):
		logger.info("No settings file found, creating with defaults")
		ensure_defaults()
		save_settings()
		return

	var file := FileAccess.open(settings_path, FileAccess.READ)
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
	var json_string: String = JSON.stringify(_settings, "\t")

	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save settings: %s" % FileAccess.get_open_error())
		return

	file.store_string(json_string)

#endregion
