

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

func _init() -> void:
	logger = Logger.new("sandbox", DebugLogger.Category.PROGRAM)

func _ready() -> void:
	var result = await initialize()
	if not result:
		logger.error("Problem initializing map")
	else:
		logger.info("Map initialized")
	_setup_context_menu_manager()


func _setup_context_menu_manager() -> void:
	camera = %World/Camera2D
	camera.add_to_group("camera")
	var ui_layer = $UI
	_context_menu_manager = ContextMenuManager.new(camera, ui_layer)
	add_child(_context_menu_manager)

	# Connect context menu signals to local methods
	_context_menu_manager.spawn_ants_requested.connect(_on_spawn_ants_requested)
	_context_menu_manager.show_colony_info_requested.connect(_on_show_colony_info_requested)
	_context_menu_manager.destroy_colony_requested.connect(_on_destroy_colony_requested)
	_context_menu_manager.show_ant_info_requested.connect(_on_show_ant_info_requested)
	_context_menu_manager.destroy_ant_requested.connect(_on_destroy_ant_requested)
	_context_menu_manager.spawn_colony_requested.connect(spawn_colony)

func initialize() -> bool:
	# Setup navigation before spawning ants
	var result: bool = await setup_navigation()
	heatmap_manager = HeatmapManager.new()
	%World.add_child(heatmap_manager)
	heatmap_manager.add_to_group("heatmap")
	heatmap_manager.setup_camera(camera)
	return result


#region Selection Logic
func _find_closest_colony(world_pos: Vector2) -> Colony:
	var closest_colony: Colony = null
	var closest_distance: float = 100.0  # Maximum selection distance for colonies

	for colony in ColonyManager.get_all().to_array():
		var distance = colony.global_position.distance_to(world_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_colony = colony

	return closest_colony

func _find_closest_ant(world_pos: Vector2) -> Ant:
	var closest_ant: Ant = null
	var closest_distance: float = 100.0  # Maximum selection distance

	for ant in AntManager.get_all().to_array():
		var distance = ant.global_position.distance_to(world_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_ant = ant

	return closest_ant

func _is_within_colony_distance(colony: Colony, pos: Vector2) -> bool:
	return colony.global_position.distance_to(pos) <= colony.radius

func _is_within_selection_distance(ant: Ant, pos: Vector2) -> bool:
	return ant.global_position.distance_to(pos) <= 20.0
#endregion


#region Context Menu Callbacks


func _on_show_colony_info_requested(colony: Colony) -> void:
	show_colony_info(colony)

func _on_spawn_ants_requested(colony: Colony) -> void:
	colony.spawn_ants(10, true)

func _on_destroy_colony_requested(colony: Colony) -> void:
	logger.info("Destroyed colony " % str(colony.name))
	ColonyManager.remove_colony(colony)

func _on_show_ant_info_requested(ant: Ant) -> void:
	show_ant_info(ant)

func _on_destroy_ant_requested(ant: Ant) -> void:
	logger.info("Destroyed ant " % ant.name)
	AntManager.remove_ant(ant)
#endregion

#region Panel Management
func show_ant_info(ant: Ant) -> void:
	if ant_info_panel and ant_info_panel != null:
		if ant == ant_info_panel.current_ant:
			ant_info_panel.queue_free()
			return
		ant_info_panel.queue_free()
	ant_info_panel = load("res://ui/debug/ant/ant_info_panel.tscn").instantiate()
	info_panels_container.add_child(ant_info_panel)
	ant_info_panel.show_ant_info(ant)
	ant_info_panel.show()

func show_colony_info(colony: Colony) -> void:
	if colony_info_panel and colony_info_panel != null:
		if colony == colony_info_panel.current_colony:
			colony_info_panel.queue_free()
			return
		colony_info_panel.queue_free()
	colony_info_panel = load("res://ui/debug/colony/colony_info_panel.tscn").instantiate()
	info_panels_container.add_child(colony_info_panel)
	colony_info_panel.show_colony_info(colony)
	colony_info_panel.show()

func deselect_all() -> void:
	if ant_info_panel and ant_info_panel != null:
		ant_info_panel.queue_free()
	if colony_info_panel and colony_info_panel != null:
		colony_info_panel.queue_free()
#endregion

#region Colony Management
func spawn_colony(ui_position: Vector2) -> Colony:
	logger.debug("Spawn colony pipeline started")
	logger.debug("Input UI position: %s" % str(ui_position))
	var colony = ColonyManager.spawn_colony()
	%World.add_child(colony)
	var global_pos = camera.ui_to_global(ui_position)
	colony.global_position = global_pos
	logger.info("Spawned new colony %s at position %s" % [colony.name, str(colony.global_position)])
	colony.spawn_ants(10, true)
	return colony
#endregion


#region Colony Management
func _on_spawn_colony_pressed() -> void:
	_awaiting_colony_placement = true

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_check_selections()
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			deselect_all()
			_context_menu_manager.clear_active_menu()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

func _check_selections() -> void:
	var mouse_pos = get_global_mouse_position()
	if _awaiting_colony_placement:
		spawn_colony(mouse_pos)
		_awaiting_colony_placement = false
		return

	if not _context_menu_manager:
		return

	_context_menu_manager.clear_active_menu()

	# Check for colony selection first
	var closest_colony = _find_closest_colony(mouse_pos)
	var closest_ant = _find_closest_ant(mouse_pos)

	if closest_colony and _is_within_colony_distance(closest_colony, mouse_pos):
		_context_menu_manager.show_colony_context_menu(closest_colony, closest_colony.position)
	elif closest_ant and _is_within_selection_distance(closest_ant, mouse_pos):
		_context_menu_manager.show_ant_context_menu(closest_ant, closest_ant.position)
	else:
		_context_menu_manager.show_empty_context_menu(camera.global_to_ui(mouse_pos))

func _get_object_at_position(p_position: Vector2) -> Node2D:
	var p_world = %World
	for child in p_world.get_children():
		if child is Colony or child is Ant:
			if p_position.distance_to(child.global_position) <= child.radius:
				return child
	return null
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
