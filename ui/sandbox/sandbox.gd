

extends Control

var logger: Logger
var _context_menu_manager: ContextMenuManager
var source_geometry: NavigationMeshSourceGeometryData2D

var ant_info_panel: AntInfoPanel
var colony_info_panel: ColonyInfoPanel
@onready var info_panels_container = %InfoPanelsContainer
@onready var world = %World
@onready var camera = $World/Camera2D

# Navigation properties
var heatmap_manager: HeatmapManager

# States
var _awaiting_colony_placement: bool = false

var generating_map: bool = false

func _init() -> void:
	logger = Logger.new("sandbox", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	generating_map = true
	var result = await initialize()
	if not result:
		logger.error("Problem initializing map")
	else:
		generating_map = false
		logger.info("Map initialized")
	_setup_context_menu_manager()


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
	# Setup navigation before spawning ants
	var result: bool = await setup_navigation()
	heatmap_manager = HeatmapManager.new()
	%World.add_child(heatmap_manager)
	heatmap_manager.add_to_group("heatmap")
	heatmap_manager.setup_camera(camera)
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
	if ant_info_panel:
		ant_info_panel.queue_free()
	if colony_info_panel:
		colony_info_panel.queue_free()
#endregion

func _on_gui_input(event: InputEvent) -> void:
	if generating_map:
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
func setup_navigation() -> bool:
	var map_gen = MapGenerator.new()
	%World.add_child(map_gen)
	await map_gen.generate_navigation(get_viewport_rect())
	return true

#endregion

#region Utils
func get_random_position() -> Vector2:
	var viewport_rect := get_viewport_rect()
	var x := randf_range(0, viewport_rect.size.x)
	var y := randf_range(0, viewport_rect.size.y)
	return Vector2(x, y)
#endregion

func _exit_tree() -> void:
	ColonyManager.delete_all()


func _on_back_button_pressed() -> void:
	transition_to_scene("main")
