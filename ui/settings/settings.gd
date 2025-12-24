class_name Settings
extends Control

const SETTINGS_PATH = "user://settings.json"


## Logger instance for this class
var logger: iLogger
var settings_manager: SettingsManager = SettingsManager


## Reference to the tab container
@onready var tab_container: TabContainer = %TabContainer

## Reference to difficulty option button
@onready var difficulty_option: OptionButton = %DifficultyOption

## Reference to master volume slider
@onready var master_volume: HSlider = %HSlider

## Simulation settings references
@onready var ant_spawn_count: SpinBox = %AntSpawnCount/SpinBox
@onready var food_spawn_count: SpinBox = %FoodSpawnCount/SpinBox
@onready var map_size_x: SpinBox = %MapSize/XSpinBox
@onready var map_size_y: SpinBox = %MapSize/YSpinBox
@onready var obstacle_density: SpinBox = %ObstacleDensity/SpinBox
@onready var obstacle_size_min: SpinBox = %ObstacleSize/MinSpinBox
@onready var obstacle_size_max: SpinBox = %ObstacleSize/MaxSpinBox
@onready var terrain_seed: SpinBox = %TerrainSeed/SpinBox

## Debug settings references
@onready var log_level_option: OptionButton = %LogLevelOption
@onready var show_context_check: CheckBox = %ShowContextCheck
@onready var category_grid: GridContainer = %CategoryGrid

func _init() -> void:
	logger = iLogger.new("settings", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	logger.info("Initializing Settings UI")
	setup_game_options()
	setup_debug_options()
	setup_signals()
	load_ui_state()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key
		_on_back_button_pressed()
		if is_inside_tree():
			get_viewport().set_input_as_handled()

#region Settings Management

#endregion

func load_ui_state() -> void:
	logger.trace("Loading UI state from settings")

	# Load game values
	difficulty_option.selected = settings_manager.get_setting("difficulty", 1)
	master_volume.value = settings_manager.get_setting("master_volume", 1.0)
	log_level_option.selected = settings_manager.get_setting("log_level", DebugLogger.LogLevel.INFO)
	show_context_check.button_pressed = settings_manager.get_setting("show_context", true)

	# Load simulation settings
	ant_spawn_count.value = settings_manager.get_setting("ant_spawn_count", 10)
	food_spawn_count.value = settings_manager.get_setting("food_spawn_count", 500)
	map_size_x.value = settings_manager.get_setting("map_size_x", 6800)
	map_size_y.value = settings_manager.get_setting("map_size_y", 3600)
	obstacle_density.value = settings_manager.get_setting("obstacle_density", 0.00001)
	obstacle_size_min.value = settings_manager.get_setting("obstacle_size_min", 15)
	obstacle_size_max.value = settings_manager.get_setting("obstacle_size_max", 70)

	terrain_seed.value = settings_manager.get_setting("terrain_seed", 0)

	# Load debug category states
	for check in category_grid.get_children():
		if check is CheckBox:
			var setting_key = "category_" + check.text.to_lower()
			check.button_pressed = settings_manager.get_setting(setting_key, true)

#region Setup Methods
func setup_game_options() -> void:
	logger.trace("Setting up game options")

	# Setup difficulty options
	difficulty_option.clear()
	difficulty_option.add_item("Easy", 0)
	difficulty_option.add_item("Normal", 1)
	difficulty_option.add_item("Hard", 2)

func setup_debug_options() -> void:
	logger.trace("Setting up debug options")

	# Setup log levels
	log_level_option.clear()
	for level in DebugLogger.LogLevel.keys():
		log_level_option.add_item(level, DebugLogger.LogLevel[level])

	# Setup categories
	for category in DebugLogger.Category.keys():
		var check = CheckBox.new()
		check.text = category
		check.name = category + "Check"
		check.add_theme_font_size_override("font_size", 16)
		category_grid.add_child(check)

func setup_signals() -> void:
	logger.trace("Setting up UI signals")

	difficulty_option.item_selected.connect(_on_difficulty_changed)
	master_volume.value_changed.connect(_on_master_volume_changed)
	log_level_option.item_selected.connect(_on_log_level_changed)
	show_context_check.toggled.connect(_on_show_context_toggled)

	# Simulation settings signals
	ant_spawn_count.value_changed.connect(_on_ant_spawn_count_changed)
	food_spawn_count.value_changed.connect(_on_food_spawn_count_changed)
	map_size_x.value_changed.connect(_on_map_size_changed)
	map_size_y.value_changed.connect(_on_map_size_changed)
	obstacle_density.value_changed.connect(_on_obstacle_density_changed)
	obstacle_size_min.value_changed.connect(_on_obstacle_min_size_changed)
	obstacle_size_max.value_changed.connect(_on_obstacle_max_size_changed)

	terrain_seed.value_changed.connect(_on_terrain_seed_changed)

	for check in category_grid.get_children():
		if check is CheckBox:
			var category = DebugLogger.Category[check.text]
			check.toggled.connect(_on_category_toggled.bind(category))

	$MarginContainer/VBoxContainer/ButtonContainer/BackButton.pressed.connect(_on_back_button_pressed)
#endregion

#region Simulation Settings Handlers
func _on_ant_spawn_count_changed(value: float) -> void:
	logger.trace("Changing ant spawn count to: %d" % value)
	settings_manager.set_setting("ant_spawn_count", value)

func _on_food_spawn_count_changed(value: float) -> void:
	logger.trace("Changing food spawn count to: %d" % value)
	settings_manager.set_setting("food_spawn_count", value)

func _on_map_size_changed(value: float) -> void:
	logger.trace("Updating map size to: %d x %d" % [map_size_x.value, map_size_y.value])
	settings_manager.set_setting("map_size_x", map_size_x.value)
	settings_manager.set_setting("map_size_y", map_size_y.value)

func _on_obstacle_density_changed(value: float) -> void:
	logger.trace("Changing obstacle density to: %.2f" % value)
	settings_manager.set_setting("obstacle_density", value)

func _on_obstacle_min_size_changed(value: float) -> void:
	settings_manager.set_setting("obstacle_size_min", value)

func _on_obstacle_max_size_changed(value: float) -> void:
	settings_manager.set_setting("obstacle_size_max", value)

func _on_terrain_seed_changed(value: float) -> void:
	logger.trace("Changing terrain seed to: %d" % value)
	settings_manager.set_setting("terrain_seed", value)
#endregion

#region Other Signal Handlers
func _on_difficulty_changed(index: int) -> void:
	logger.info("Changing difficulty to: %s" % difficulty_option.get_item_text(index))
	settings_manager.set_setting("difficulty", index)

func _on_master_volume_changed(value: float) -> void:
	logger.info("Changing master volume to: %.2f" % value)
	settings_manager.set_setting("master_volume", value)

func _on_log_level_changed(index: int) -> void:
	var level = log_level_option.get_item_id(index)
	logger.info("Changing log level to: %s" % DebugLogger.LogLevel.keys()[level])
	settings_manager.set_setting("log_level", level)
	DebugLogger.set_log_level(level)

func _on_show_context_toggled(button_pressed: bool) -> void:
	logger.info("%s context display" % ["Enabling" if button_pressed else "Disabling"])
	settings_manager.set_setting("show_context", button_pressed)
	DebugLogger.set_show_context(button_pressed)

func _on_category_toggled(button_pressed: bool, category: DebugLogger.Category) -> void:
	var category_name = DebugLogger.Category.keys()[category]
	logger.info("%s category: %s" % ["Enabling" if button_pressed else "Disabling",
		category_name])
	var setting_key = "category_" + category_name.to_lower()
	settings_manager.set_setting(setting_key, button_pressed)
	DebugLogger.set_category_enabled(category, button_pressed)
#endregion

#region Navigation
func _on_back_button_pressed() -> void:
	logger.trace("Returning to main menu")
	get_tree().change_scene_to_file("res://ui/main.tscn")
#endregion
