

extends Control

const MAP_SIZE_COEF = 4.0
var map_generator: MapGenerator
var logger: Logger
var _context_menu_manager: ContextMenuManager
var source_geometry: NavigationMeshSourceGeometryData2D
var loading_overlay: ColorRect

var ant_info_panel: AntInfoPanel
var colony_info_panel: ColonyInfoPanel
@onready var info_panels_container = %InfoPanelsContainer
@onready var world = %World
@onready var camera = $World/Camera2D

# Navigation properties
var heatmap_manager: HeatmapManager

# States
var _awaiting_colony_placement: bool = false

var initializing: bool = false

func _init() -> void:
	logger = Logger.new("sandbox", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	_setup_context_menu_manager()
	call_deferred("initialize")

func setup_loading_overlay() -> void:
	loading_overlay = ColorRect.new()
	loading_overlay.color = Color(0, 0, 0, 0.5)
	loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var label = Label.new()
	label.text = "Initializing..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)

	loading_overlay.add_child(label)
	add_child(loading_overlay)

func _setup_context_menu_manager() -> void:
	camera = %World/Camera2D
	camera.add_to_group("camera")

	var ui_layer = $UI

	_context_menu_manager = ContextMenuManager.new(camera, ui_layer)
	add_child(_context_menu_manager)
	_context_menu_manager.world = %World

	# Connect info panel signals
	_context_menu_manager.info_panel_requested.connect(_on_info_panel_requested)
	_context_menu_manager.info_panel_closed.connect(_on_info_panel_closed)


func initialize() -> bool:
	logger.info("Initializing sandbox...")
	size = get_viewport_rect().size * MAP_SIZE_COEF
	# Setup navigation before spawning ants
	var result: bool = await generate_map()
	if not result:
		logger.error("Problem generating map")
		return false
	logger.info("Map generation complete")
	result = setup_heatmap()
	if not result:
		logger.error("Problem setting up heatmap")
		return false
	logger.info("Heatmap setup complete")
	%World.position = size/2
	logger.info("Sandbox initialized")
	initializing = false
	return result


#region Panel Management
func _on_info_panel_requested(entity: Node) -> void:
	var panel: Control

	if entity is Colony:
		if colony_info_panel and colony_info_panel.current_colony == entity:
			colony_info_panel.queue_free()
			return

		if colony_info_panel:
			colony_info_panel.queue_free()

		colony_info_panel = preload("res://ui/debug/colony/colony_info_panel.tscn").instantiate()
		info_panels_container.add_child(colony_info_panel)
		colony_info_panel.show_colony_info(entity)
		panel = colony_info_panel

	elif entity is Ant:
		if ant_info_panel and ant_info_panel.current_ant == entity:
			ant_info_panel.queue_free()
			return

		if ant_info_panel:
			ant_info_panel.queue_free()

		ant_info_panel = preload("res://ui/debug/ant/ant_info_panel.tscn").instantiate()
		info_panels_container.add_child(ant_info_panel)
		ant_info_panel.show_ant_info(entity)
		panel = ant_info_panel

	if panel:
		panel.show()

func _on_info_panel_closed(entity: Node) -> void:
	if entity is Colony and colony_info_panel:
		colony_info_panel.queue_free()
	elif entity is Ant and ant_info_panel:
		ant_info_panel.queue_free()

func deselect_all() -> void:
	if is_instance_valid(ant_info_panel):
		ant_info_panel.queue_free()
	if is_instance_valid(colony_info_panel):
		colony_info_panel.queue_free()
#endregion

func _on_gui_input(event: InputEvent) -> void:
	if initializing:
		return
	if not event is InputEventMouseButton or not event.pressed:
		if event.is_action_pressed("ui_cancel"):
			_on_back_button_pressed()
			get_viewport().set_input_as_handled()
		return

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			var mouse_pos := get_global_mouse_position()
			_context_menu_manager.handle_click(mouse_pos)
			get_viewport().set_input_as_handled()

		MOUSE_BUTTON_RIGHT:
			deselect_all()
			_context_menu_manager.clear_active_menu()
			_context_menu_manager.close_ant_info()
#endregion

#region Scene Management
func transition_to_scene(scene_name: String) -> void:
	create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))

func _change_scene(scene_name: String) -> void:
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)
#endregion

#region Navigation Setup
func generate_map() -> bool:
	map_generator = MapGenerator.new()
	%World.add_child(map_generator)
	await map_generator.generate_navigation(size)
	return true

func setup_heatmap() -> bool:
	heatmap_manager = HeatmapManager.new()
	%World.add_child(heatmap_manager)
	heatmap_manager.add_to_group("heatmap")
	heatmap_manager.setup_camera(camera)
	return true

#endregion

func _exit_tree() -> void:
	ColonyManager.delete_all()


func _on_back_button_pressed() -> void:
	transition_to_scene("main")

func _draw() -> void:
	draw_rect(get_rect(), Color.RED, false)
