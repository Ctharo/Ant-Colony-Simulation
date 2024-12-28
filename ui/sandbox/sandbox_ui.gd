class_name SandboxUI
extends Control

## Camera node reference
var camera: CameraController
## Active context menu
var active_context_menu: BaseContextMenu
## Active ant info
var active_ant_info: AntInfo

@onready var overlay: ColorRect = %InitializingRect

#region Node References
@onready var info_panels_container := %InfoPanelsContainer
var ant_info_panel: AntInfoPanel
var colony_info_panel: ColonyInfoPanel
#endregion

#region Managers
var colony_manager = ColonyManager
var ant_manager = AntManager
var sandbox: Node2D
#endregion

#region Default Spawn Values
const DEFAULT_SPAWN_NUM = 5
const DEFAULT_FOOD_SPAWN_NUM = 500
#endregion

var initializing: bool = true :
	set(value):
		initializing = value
		if not initializing and is_instance_valid(overlay):
			overlay.queue_free()
			overlay = null

func _ready() -> void:
	camera = get_node("../../Camera2D")
	sandbox = get_node("../..")
	if is_instance_valid(overlay):
		overlay.visible = true

func _process(_delta: float) -> void:
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	if initializing:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				handle_click(get_global_mouse_position())
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				deselect_all()
				clear_active_menu()

#region Click Handling
func handle_click(screen_position: Vector2) -> void:
	clear_active_menu()
	var world_position: Vector2 = camera.ui_to_global(screen_position)
	var closest_colony := _find_closest_colony(world_position)
	var closest_ant := _find_closest_ant(world_position)


	if closest_colony and _is_within_radius(closest_colony, world_position):
		show_colony_context_menu(closest_colony, screen_position)
	elif closest_ant and _is_within_radius(closest_ant, world_position):
		show_ant_info(closest_ant)
	else:
		close_ant_info()
		show_empty_context_menu(screen_position)

func _find_closest_colony(world_position: Vector2) -> Colony:
	var colonies := get_tree().get_nodes_in_group("colony")
	var closest: Colony
	var closest_distance := INF

	for colony in colonies:
		if not is_instance_valid(colony):
			continue
		var distance := world_position.distance_to(colony.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = colony
	return closest

func _find_closest_ant(world_position: Vector2) -> Ant:
	var ants := get_tree().get_nodes_in_group("ant")
	var closest: Ant
	var closest_distance := INF

	for ant in ants:
		if not is_instance_valid(ant):
			continue
		var distance := world_position.distance_to(ant.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = ant
	return closest

func _is_within_radius(entity: Node2D, world_position: Vector2) -> bool:
	if entity is Colony:
		return world_position.distance_to(entity.global_position) <= entity.radius
	return world_position.distance_to(entity.global_position) <= 50.0
#endregion

#region Context Menu Management
func show_ant_context_menu(ant: Ant, world_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = AntContextMenu.new()
	active_context_menu.setup(camera)
	add_child(active_context_menu)

	active_context_menu.show_info_requested.connect(_on_ant_info_requested)
	active_context_menu.destroy_ant_requested.connect(_on_ant_destroy_requested)
	active_context_menu.track_ant_requested.connect(_on_ant_track_requested)
	active_context_menu.show_for_ant(world_pos, ant)

func show_colony_context_menu(colony: Colony, world_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = ColonyContextMenu.new()
	active_context_menu.setup(camera)
	add_child(active_context_menu)

	active_context_menu.spawn_ants_requested.connect(_on_colony_spawn_ants_requested)
	active_context_menu.show_info_requested.connect(_on_colony_info_requested)
	active_context_menu.destroy_colony_requested.connect(_on_colony_destroy_requested)
	active_context_menu.heatmap_requested.connect(_on_colony_heatmap_requested)
	active_context_menu.show_for_colony(world_pos, colony)

func show_empty_context_menu(world_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = EmptyContextMenu.new()
	active_context_menu.setup(camera)
	add_child(active_context_menu)
	active_context_menu.spawn_colony_requested.connect(_on_spawn_colony_requested)
	active_context_menu.spawn_foods_requested.connect(_on_spawn_food_requested)
	active_context_menu.show_at_position(world_pos)

func clear_active_menu() -> void:
	if is_instance_valid(active_context_menu):
		active_context_menu.close()
		active_context_menu = null
#endregion

#region Entity Info Management
func show_ant_info(ant: Ant) -> void:
	close_ant_info()
	if not is_instance_valid(ant):
		return
	var info: AntInfo = preload("res://ui/ant/ant_info.tscn").instantiate()
	add_child(info)
	info.show_ant_info(ant, camera)
	active_ant_info = info

func close_ant_info() -> void:
	if is_instance_valid(active_ant_info):
		active_ant_info.queue_free()
	active_ant_info = null

func show_info_panel(entity: Node) -> void:
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

func close_info_panel(entity: Node) -> void:
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

#region Colony Handlers
func _on_spawn_colony_requested(screen_position: Vector2) -> void:
	var world_position = camera.ui_to_global(screen_position)
	var colony = colony_manager.spawn_colony_at(world_position)
	sandbox.add_child(colony)
	colony.spawn_ants(DEFAULT_SPAWN_NUM)

func _on_colony_spawn_ants_requested(colony: Colony) -> void:
	if is_instance_valid(colony):
		colony.spawn_ants(DEFAULT_SPAWN_NUM)

func _on_colony_info_requested(colony: Colony) -> void:
	if is_instance_valid(colony):
		show_info_panel(colony)

func _on_colony_destroy_requested(colony: Colony) -> void:
	if is_instance_valid(colony):
		colony_manager.remove_colony(colony)

func _on_colony_heatmap_requested(colony: Colony) -> void:
	if is_instance_valid(colony):
		colony.heatmap_enabled = !colony.heatmap_enabled
#endregion

#region Ant Handlers
func _on_ant_info_requested(ant: Ant) -> void:
	if is_instance_valid(ant):
		show_info_panel(ant)

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

#region Food Handlers
func _on_spawn_food_requested(screen_position: Vector2) -> void:
	var world_position = camera.ui_to_global(screen_position)
	var foods = FoodManager.spawn_foods(DEFAULT_FOOD_SPAWN_NUM)
	for food: Food in foods:
		var wiggle: Vector2 = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		$"../../FoodContainer".add_child(food)
		food.global_position = world_position + wiggle
#endregion
