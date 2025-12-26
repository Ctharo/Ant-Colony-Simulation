class_name Settings
extends Control

## Logger instance for this class
var logger: iLogger

## Reference to the autoload
var settings_manager: SettingsManager


## Reference to the tab container
@onready var tab_container: TabContainer = %TabContainer

## Game settings references
@onready var difficulty_option: OptionButton = %DifficultyOption
@onready var master_volume: HSlider = %HSlider

## Simulation settings references
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
	logger = iLogger.new("settings", DebugLogger.Category.UI)


func _ready() -> void:
	# Get the autoload reference
	settings_manager = SettingsManager
	
	logger.info("Initializing Settings UI")
	_setup_ui_structure()
	_apply_constraints()
	_load_all_values()
	_connect_signals()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


#region UI Setup

## Sets up the structure of UI elements (options, checkboxes, etc.)
func _setup_ui_structure() -> void:
	_setup_difficulty_options()
	_setup_log_level_options()
	_setup_category_checkboxes()


## Setup difficulty dropdown options
func _setup_difficulty_options() -> void:
	difficulty_option.clear()
	difficulty_option.add_item("Easy", 0)
	difficulty_option.add_item("Normal", 1)
	difficulty_option.add_item("Hard", 2)


## Setup log level dropdown options
func _setup_log_level_options() -> void:
	log_level_option.clear()
	for level_name in DebugLogger.LogLevel.keys():
		var level_value: int = DebugLogger.LogLevel[level_name]
		log_level_option.add_item(level_name, level_value)


## Dynamically create category checkboxes
func _setup_category_checkboxes() -> void:
	# Clear any existing children first
	for child in category_grid.get_children():
		child.queue_free()
	
	# Create a checkbox for each category
	for category_name in DebugLogger.Category.keys():
		var check := CheckBox.new()
		check.text = category_name
		check.name = category_name + "Check"
		check.add_theme_font_size_override("font_size", 16)
		category_grid.add_child(check)


## Apply constraints from SettingsManager to all spinboxes/sliders
func _apply_constraints() -> void:
	_apply_spinbox_constraints(food_spawn_count, "food_spawn_count")
	_apply_spinbox_constraints(map_size_x, "map_size_x")
	_apply_spinbox_constraints(map_size_y, "map_size_y")
	_apply_spinbox_constraints(obstacle_density, "obstacle_density")
	_apply_spinbox_constraints(obstacle_size_min, "obstacle_size_min")
	_apply_spinbox_constraints(obstacle_size_max, "obstacle_size_max")
	_apply_spinbox_constraints(terrain_seed, "terrain_seed")
	
	# Volume slider
	var volume_constraints := settings_manager.get_constraints("master_volume")
	if not volume_constraints.is_empty():
		master_volume.min_value = volume_constraints.get("min", 0.0)
		master_volume.max_value = volume_constraints.get("max", 1.0)
		master_volume.step = volume_constraints.get("step", 0.05)


## Apply constraints to a single spinbox
func _apply_spinbox_constraints(spinbox: SpinBox, setting_name: String) -> void:
	if not spinbox:
		return
	
	var constraints := settings_manager.get_constraints(setting_name)
	if constraints.is_empty():
		return
	
	spinbox.min_value = constraints.get("min", spinbox.min_value)
	spinbox.max_value = constraints.get("max", spinbox.max_value)
	spinbox.step = constraints.get("step", spinbox.step)

#endregion


#region Value Loading

## Load all values from SettingsManager into UI elements
func _load_all_values() -> void:
	logger.trace("Loading UI state from settings")
	_load_game_values()
	_load_simulation_values()
	_load_debug_values()


## Load game-related settings
func _load_game_values() -> void:
	difficulty_option.selected = settings_manager.get_setting("difficulty")
	master_volume.value = settings_manager.get_setting("master_volume")


## Load simulation-related settings
func _load_simulation_values() -> void:
	food_spawn_count.value = settings_manager.get_setting("food_spawn_count")
	map_size_x.value = settings_manager.get_setting("map_size_x")
	map_size_y.value = settings_manager.get_setting("map_size_y")
	obstacle_density.value = settings_manager.get_setting("obstacle_density")
	obstacle_size_min.value = settings_manager.get_setting("obstacle_size_min")
	obstacle_size_max.value = settings_manager.get_setting("obstacle_size_max")
	terrain_seed.value = settings_manager.get_setting("terrain_seed")


## Load debug-related settings
func _load_debug_values() -> void:
	# Load log level - find the item index that matches the stored value
	var stored_level: int = settings_manager.get_setting("log_level")
	for i in range(log_level_option.item_count):
		if log_level_option.get_item_id(i) == stored_level:
			log_level_option.selected = i
			break
	
	show_context_check.button_pressed = settings_manager.get_setting("show_context")
	
	# Load category checkbox states - wait a frame for dynamically created checkboxes
	await get_tree().process_frame
	for check in category_grid.get_children():
		if check is CheckBox:
			var setting_key: String = "category_" + check.text.to_lower()
			check.button_pressed = settings_manager.get_setting(setting_key)

#endregion


#region Signal Connections

## Connect all UI signals to handlers
func _connect_signals() -> void:
	logger.trace("Connecting UI signals")
	
	# Game settings
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	master_volume.value_changed.connect(_on_master_volume_changed)
	
	# Simulation settings
	food_spawn_count.value_changed.connect(_on_setting_changed.bind("food_spawn_count"))
	map_size_x.value_changed.connect(_on_map_size_changed)
	map_size_y.value_changed.connect(_on_map_size_changed)
	obstacle_density.value_changed.connect(_on_setting_changed.bind("obstacle_density"))
	obstacle_size_min.value_changed.connect(_on_setting_changed.bind("obstacle_size_min"))
	obstacle_size_max.value_changed.connect(_on_setting_changed.bind("obstacle_size_max"))
	terrain_seed.value_changed.connect(_on_setting_changed.bind("terrain_seed"))
	
	# Debug settings
	log_level_option.item_selected.connect(_on_log_level_changed)
	show_context_check.toggled.connect(_on_show_context_toggled)
	
	# Category checkboxes - connect after waiting for them to be created
	_connect_category_signals()
	
	# Navigation
	$MarginContainer/VBoxContainer/ButtonContainer/BackButton.pressed.connect(_on_back_button_pressed)


## Connect category checkbox signals (called after checkboxes are created)
func _connect_category_signals() -> void:
	# Wait for dynamically created checkboxes
	await get_tree().process_frame
	for check in category_grid.get_children():
		if check is CheckBox:
			var category: DebugLogger.Category = DebugLogger.Category[check.text]
			check.toggled.connect(_on_category_toggled.bind(category))

#endregion


#region Signal Handlers - Game Settings

func _on_difficulty_changed(index: int) -> void:
	logger.info("Changing difficulty to: %s" % difficulty_option.get_item_text(index))
	settings_manager.set_setting("difficulty", index)


func _on_master_volume_changed(value: float) -> void:
	logger.info("Changing master volume to: %.2f" % value)
	settings_manager.set_setting("master_volume", value)

#endregion


#region Signal Handlers - Simulation Settings

## Generic handler for simple value->setting updates
func _on_setting_changed(value: float, setting_name: String) -> void:
	logger.trace("Changing %s to: %s" % [setting_name, str(value)])
	settings_manager.set_setting(setting_name, value)


func _on_map_size_changed(_value: float) -> void:
	logger.trace("Updating map size to: %d x %d" % [int(map_size_x.value), int(map_size_y.value)])
	settings_manager.set_setting("map_size_x", int(map_size_x.value))
	settings_manager.set_setting("map_size_y", int(map_size_y.value))

#endregion


#region Signal Handlers - Debug Settings

func _on_log_level_changed(index: int) -> void:
	var level: int = log_level_option.get_item_id(index)
	logger.info("Changing log level to: %s" % DebugLogger.LogLevel.keys()[level])
	settings_manager.set_setting("log_level", level)


func _on_show_context_toggled(button_pressed: bool) -> void:
	logger.info("%s context display" % ["Enabling" if button_pressed else "Disabling"])
	settings_manager.set_setting("show_context", button_pressed)


func _on_category_toggled(button_pressed: bool, category: DebugLogger.Category) -> void:
	var category_name: String = DebugLogger.Category.keys()[category]
	logger.info("%s category: %s" % ["Enabling" if button_pressed else "Disabling", category_name])
	var setting_key := "category_" + category_name.to_lower()
	settings_manager.set_setting(setting_key, button_pressed)

#endregion


#region Navigation

func _on_back_button_pressed() -> void:
	logger.trace("Returning to main menu")
	get_tree().change_scene_to_file("res://ui/main.tscn")

#endregion
