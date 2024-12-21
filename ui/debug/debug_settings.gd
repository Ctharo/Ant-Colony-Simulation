class_name DebugSettings
extends Control

var logger: Logger

@onready var log_level_option: OptionButton = %LogLevelOption
@onready var show_context_check: CheckBox = %ShowContextCheck
@onready var category_grid: GridContainer = %CategoryGrid

func _init() -> void:
	logger = Logger.new("settings", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	logger.info("Initializing Debug Settings UI")
	setup_log_levels()
	setup_categories()
	setup_signals()
	_load_current_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key
		_on_back_button_pressed()
		if is_inside_tree():
			get_viewport().set_input_as_handled()

#region Setup Methods
func setup_log_levels() -> void:
	if logger.is_trace_enabled():
		logger.trace("Setting up log level options")
	
	log_level_option.clear()
	for level in DebugLogger.LogLevel.keys():
		log_level_option.add_item(level, DebugLogger.LogLevel[level])

func setup_categories() -> void:
	if logger.is_trace_enabled():
		logger.trace("Setting up category checkboxes")
		
	for category in DebugLogger.Category.keys():
		var check = CheckBox.new()
		check.text = category
		check.name = category + "Check"
		check.add_theme_font_size_override("font_size", 16)
		category_grid.add_child(check)

func setup_signals() -> void:
	if logger.is_trace_enabled():
		logger.trace("Setting up UI signals")
		
	log_level_option.item_selected.connect(_on_log_level_changed)
	show_context_check.toggled.connect(_on_show_context_toggled)
	
	for check in category_grid.get_children():
		if check is CheckBox:
			var category = DebugLogger.Category[check.text]
			check.toggled.connect(_on_category_toggled.bind(category))
	
	$MarginContainer/ScrollContainer/VBoxContainer/ButtonContainer/BackButton.pressed.connect(_on_back_button_pressed)

#endregion

#region Settings Management
func _load_current_settings() -> void:
	if logger.is_trace_enabled():
		logger.trace("Loading current debug settings")
		
	# Set current log level
	log_level_option.selected = DebugLogger.log_level
	
	# Set show context checkbox
	show_context_check.set_pressed_no_signal(DebugLogger.show_context)
	
	# Set category checkboxes
	for check in category_grid.get_children():
		if check is CheckBox:
			var category = DebugLogger.Category[check.text]
			check.set_pressed_no_signal(DebugLogger.enabled_categories[category])

func _on_log_level_changed(index: int) -> void:
	var level = log_level_option.get_item_id(index)
	logger.info("Changing log level to: %s" % DebugLogger.LogLevel.keys()[level])
	DebugLogger.set_log_level(level)

func _on_show_context_toggled(button_pressed: bool) -> void:
	logger.info("%s context display" % ["Enabling" if button_pressed else "Disabling"])
	DebugLogger.set_show_context(button_pressed)

func _on_category_toggled(button_pressed: bool, category: DebugLogger.Category) -> void:
	var category_name = DebugLogger.Category.keys()[category]
	logger.info("%s category: %s" % ["Enabling" if button_pressed else "Disabling", category_name])
	DebugLogger.set_category_enabled(category, button_pressed)

#endregion

#region Navigation
func _on_back_button_pressed() -> void:
	if logger.is_trace_enabled():
		logger.trace("Returning to main menu")
	get_tree().change_scene_to_file("res://ui/main.tscn")
#endregion
