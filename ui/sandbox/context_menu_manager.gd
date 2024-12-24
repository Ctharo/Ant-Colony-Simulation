class_name ContextMenuManager
extends Node

var world: Node2D
## Camera node reference
var camera: CameraController
## Active context menu
var active_context_menu: BaseContextMenu
## UI layer reference 
var ui_layer: CanvasLayer

#region Managers
var colony_manager = ColonyManager
var ant_manager = AntManager
#endregion

#region Signals for UI Updates
signal info_panel_requested(entity: Node)
signal info_panel_closed(entity: Node)
#endregion

func _init(p_camera: Camera2D, p_ui_layer: CanvasLayer) -> void:
	camera = p_camera
	ui_layer = p_ui_layer

func show_ant_context_menu(ant: Ant, world_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = AntContextMenu.new()
	active_context_menu.setup(camera)
	ui_layer.add_child(active_context_menu)
	
	active_context_menu.show_info_requested.connect(_on_ant_info_requested)
	active_context_menu.destroy_ant_requested.connect(_on_ant_destroy_requested)
	active_context_menu.track_ant_requested.connect(_on_ant_track_requested)
	active_context_menu.show_for_ant(world_pos, ant)

func show_colony_context_menu(colony: Colony, world_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = ColonyContextMenu.new()
	active_context_menu.setup(camera)
	ui_layer.add_child(active_context_menu)
	
	active_context_menu.spawn_ants_requested.connect(_on_colony_spawn_ants_requested)
	active_context_menu.show_info_requested.connect(_on_colony_info_requested)
	active_context_menu.destroy_colony_requested.connect(_on_colony_destroy_requested)
	active_context_menu.heatmap_requested.connect(_on_colony_heatmap_requested)
	active_context_menu.show_for_colony(world_pos, colony)

func show_empty_context_menu(world_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = EmptyContextMenu.new()
	active_context_menu.setup(camera)
	ui_layer.add_child(active_context_menu)
	active_context_menu.spawn_colony_requested.connect(_on_spawn_colony_requested)
	active_context_menu.show_at_position(world_pos)

func _on_spawn_colony_requested(position: Vector2) -> void:
	var colony = colony_manager.spawn_colony_at(camera.ui_to_global(position))
	world.add_child(colony)
	colony.spawn_ants(5)

func clear_active_menu() -> void:
	if is_instance_valid(active_context_menu):
		active_context_menu.close()
		active_context_menu = null

#region Colony Handlers
func _on_colony_spawn_ants_requested(colony: Colony) -> void:
	if is_instance_valid(colony):
		colony.spawn_ants(5)

func _on_colony_info_requested(colony: Colony) -> void:
	if is_instance_valid(colony):
		info_panel_requested.emit(colony)

func _on_colony_destroy_requested(colony: Colony) -> void:
	if is_instance_valid(colony):
		colony_manager.remove_colony(colony)
		
func _on_colony_heatmap_requested(colony: Colony) -> void:
	if is_instance_valid(colony):
		colony.heatmap_enabled = !colony.heatmap_enabled
#endregion

func handle_click(world_position: Vector2) -> void:
	clear_active_menu()
	
	var closest_colony := _find_closest_colony(world_position)
	var closest_ant := _find_closest_ant(world_position)
	
	if closest_colony and _is_within_radius(closest_colony, world_position):
		show_colony_context_menu(closest_colony, closest_colony.position)
	elif closest_ant and _is_within_radius(closest_ant, world_position):
		show_ant_context_menu(closest_ant, closest_ant.position)
	else:
		show_empty_context_menu(camera.global_to_ui(world_position))

func _find_closest_colony(position: Vector2) -> Colony:
	var colonies := get_tree().get_nodes_in_group("colony")
	var closest: Colony
	var closest_distance := INF
	
	for colony in colonies:
		if not is_instance_valid(colony):
			continue
			
		var distance := position.distance_to(colony.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = colony
			
	return closest

func _find_closest_ant(position: Vector2) -> Ant:
	var ants := get_tree().get_nodes_in_group("ant")
	var closest: Ant
	var closest_distance := INF
	
	for ant in ants:
		if not is_instance_valid(ant):
			continue
			
		var distance := position.distance_to(ant.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = ant
			
	return closest

func _is_within_radius(entity: Node2D, position: Vector2) -> bool:
	if entity is Colony:
		return position.distance_to(entity.global_position) <= entity.radius
	else:
		return position.distance_to(entity.global_position) <= 50.0
#region Ant Handlers
func _on_ant_info_requested(ant: Ant) -> void:
	if is_instance_valid(ant):
		info_panel_requested.emit(ant)

func _on_ant_destroy_requested(ant: Ant) -> void:
	if is_instance_valid(ant):
		ant_manager.remove_ant(ant)

func _on_ant_track_requested(ant: Ant) -> void:
	if is_instance_valid(ant):
		if is_instance_valid(camera.tracked_entity) and ant == camera.tracked_entity:
			camera.stop_tracking()
			return
		camera.track_entity(ant)
#endregion
