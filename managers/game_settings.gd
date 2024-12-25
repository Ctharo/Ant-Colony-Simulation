class_name GameSettings
extends Resource

const SETTINGS_PATH = "user://game_settings.tres"

# Debug Settings
@export var debug_log_level: int = DebugLogger.LogLevel.INFO
@export var debug_show_context: bool = false
@export var debug_enabled_categories: Dictionary = {}

# Game Configuration Settings
@export var default_ant_spawn_count: int = 10
@export var map_size: Vector2 = Vector2(100, 100)
@export var obstacle_density: float = 0.2
@export var terrain_seed: int = 0

# Additional game configuration options can be added here
@export var sound_volume: float = 1.0
@export var music_volume: float = 1.0
@export var difficulty_level: int = 1

static func load_settings() -> GameSettings:
	var settings: GameSettings
	if ResourceLoader.exists(SETTINGS_PATH):
		settings = ResourceLoader.load(SETTINGS_PATH) as GameSettings
		if settings == null:
			settings = GameSettings.new()
	else:
		settings = GameSettings.new()
		settings.initialize_default_categories()
	return settings

func save_settings() -> void:
	var error = ResourceSaver.save(self, SETTINGS_PATH)
	if error != OK:
		print("Failed to save game settings: ", error)

func initialize_default_categories() -> void:
	# Initialize debug categories with default values
	for category in DebugLogger.Category.keys():
		debug_enabled_categories[DebugLogger.Category[category]] = false

func apply_debug_settings() -> void:
	# Apply debug settings to DebugLogger
	DebugLogger.set_log_level(debug_log_level)
	DebugLogger.set_show_context(debug_show_context)

	# Apply category settings
	for category_enum in debug_enabled_categories:
		DebugLogger.set_category_enabled(category_enum, debug_enabled_categories[category_enum])

func reset_to_defaults() -> void:
	# Reset debug settings
	debug_log_level = DebugLogger.LogLevel.INFO
	debug_show_context = false
	initialize_default_categories()

	# Reset game configuration settings
	default_ant_spawn_count = 10
	map_size = Vector2(100, 100)
	obstacle_density = 0.2
	terrain_seed = 0
	sound_volume = 1.0
	music_volume = 1.0
	difficulty_level = 1
