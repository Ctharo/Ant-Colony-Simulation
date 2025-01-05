class_name SandboxUI
extends Control

var settings_manager: SettingsManager = SettingsManager

## Camera node reference
var camera: CameraController
## Active context menu
var active_context_menu: BaseContextMenu
## Active ant info
var active_ant_info: AntInfo

@onready var overlay: ColorRect = %InitializingRect
var highlight_ants: bool = false
#region Node References
@onready var info_panels_container := %InfoPanelsContainer
var ant_info_panel: AntInfoPanel
var colony_info_panel: ColonyInfoPanel
var hovered_entity_label: Label
#endregion

#region Managers
var colony_manager = ColonyManager
var ant_manager = AntManager
var sandbox: Node2D
#endregion

#region Default Spawn Values
var DEFAULT_SPAWN_NUM = settings_manager.get_setting("ant_spawn_count", 1)
var DEFAULT_FOOD_SPAWN_NUM = settings_manager.get_setting("food_spawn_count", 50)
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
	
	if is_instance_valid(hovered_entity_label):
		hovered_entity_label.queue_free()
		hovered_entity_label = null
		
	if is_instance_valid(camera) and is_instance_valid(camera.hovered_entity):
		hovered_entity_label = Label.new()
		hovered_entity_label.name = "hovered_entity"
		hovered_entity_label.text = camera.hovered_entity.name
		add_child(hovered_entity_label)
		hovered_entity_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)

func _on_gui_input(event: InputEvent) -> void:
	if initializing:
		return
	if event is InputEventMouseButton and event.pressed:
		var screen_position := get_global_mouse_position()
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				handle_left_click(screen_position)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				show_empty_context_menu(screen_position)
				get_viewport().set_input_as_handled()

#region Click Handling
func handle_left_click(_screen_position: Vector2) -> void:
	clear_active_menu()
	
	if is_instance_valid(camera) and is_instance_valid(camera.hovered_entity):
		if camera.hovered_entity is Ant:
			show_ant_info(camera.hovered_entity)
		elif camera.hovered_entity is Colony:
			show_info_panel(camera.hovered_entity)
	else:
		deselect_all()
		close_ant_info()

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
	if entity is Colony and is_instance_valid(entity):
		if is_instance_valid(colony_info_panel) and colony_info_panel.current_colony == entity:
			colony_info_panel.queue_free()
			return
		if is_instance_valid(colony_info_panel):
			colony_info_panel.queue_free()
		colony_info_panel = preload("res://ui/debug/colony/colony_info_panel.tscn").instantiate()
		info_panels_container.add_child(colony_info_panel)
		colony_info_panel.highlight_ants.connect(_on_colony_highlight_ants_requested)
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

func _on_colony_highlight_ants_requested(colony: Colony, enabled: bool) -> void:
	if not is_instance_valid(colony):
		highlight_ants = false
		return
	highlight_ants = enabled
		
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
		var radius = randf_range(0, 50)
		var angle = randf_range(0, TAU)  # TAU is 2π, a full circle
		var wiggle = Vector2(
			radius * cos(angle),
			radius * sin(angle)
		)
		$"../../FoodContainer".add_child(food)
		food.global_position = world_position + wiggle
#endregion

func _draw() -> void:
	var selected_colony = colony_info_panel.current_colony if is_instance_valid(colony_info_panel) else null
	var hovered_colony = camera.hovered_entity
	
	if is_instance_valid(selected_colony):
		for ant: Ant in selected_colony.ants:
			draw_arc(
				   camera.global_to_ui(ant.global_position),
				   12,
				   0,          # Start angle (radians)
				   TAU,        # End angle (full circle)
				   32,         # Number of points
				   Color.WHITE # Circle color
				)
			
	if (is_instance_valid(hovered_colony) and hovered_colony is Colony and hovered_colony.highlight_ants_enabled):
		for ant: Ant in hovered_colony.ants:
			draw_arc(
				   camera.global_to_ui(ant.global_position),
				   12,
				   0,          # Start angle (radians)
				   TAU,        # End angle (full circle)
				   32,         # Number of points
				   Color.WHITE # Circle color
				)
