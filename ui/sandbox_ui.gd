class_name SandboxUI
extends Control
## UI controller for the sandbox simulation view

var settings_manager: SettingsManager = SettingsManager

#region Node References
var camera: CameraController
var active_context_menu: BaseContextMenu
var active_ant_info: AntInfoPanel
var entity_info_panel: EntityInfoPanel
var hovered_entity_label: Label

@onready var overlay: ColorRect = %InitializingRect
@onready var info_panels_container := %InfoPanelsContainer
#endregion

#region Managers
var colony_manager = ColonyManager
var ant_manager = AntManager
var sandbox: Node2D
#endregion

#region State
var highlight_ants: bool = false
var DEFAULT_FOOD_SPAWN_NUM: int = 50

var initializing: bool = true:
	set(value):
		initializing = value
		if not initializing and is_instance_valid(overlay):
			overlay.queue_free()
			overlay = null
#endregion

#region Lifecycle
func _ready() -> void:
	camera = get_node("../../Camera2D")
	sandbox = get_node("../..")
	DEFAULT_FOOD_SPAWN_NUM = settings_manager.get_setting("food_spawn_count", 50)
	
	if is_instance_valid(overlay):
		overlay.visible = true


func _process(_delta: float) -> void:
	queue_redraw()
	_update_hovered_entity_label()


func _update_hovered_entity_label() -> void:
	if is_instance_valid(hovered_entity_label):
		hovered_entity_label.queue_free()
		hovered_entity_label = null
	
	if is_instance_valid(camera) and is_instance_valid(camera.hovered_entity):
		hovered_entity_label = Label.new()
		hovered_entity_label.name = "hovered_entity"
		hovered_entity_label.text = camera.hovered_entity.name
		add_child(hovered_entity_label)
		hovered_entity_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
#endregion

#region Input Handling
func _on_gui_input(event: InputEvent) -> void:
	if initializing:
		return
	
	if event is InputEventMouseButton and event.pressed:
		var screen_pos: Vector2 = event.position
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				handle_left_click(screen_pos)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				handle_right_click(screen_pos)
				get_viewport().set_input_as_handled()
#endregion

#region Click Handling
func handle_left_click(_screen_pos: Vector2) -> void:
	clear_active_menu()
	
	if is_instance_valid(camera) and is_instance_valid(camera.hovered_entity):
		show_info_panel(camera.hovered_entity)
	else:
		deselect_all()
		close_ant_info()


func handle_right_click(screen_pos: Vector2) -> void:
	clear_active_menu()
	
	if is_instance_valid(camera) and is_instance_valid(camera.hovered_entity):
		if camera.hovered_entity is Ant:
			show_ant_context_menu(camera.hovered_entity, screen_pos)
		elif camera.hovered_entity is Colony:
			show_colony_context_menu(camera.hovered_entity, screen_pos)
	else:
		show_empty_context_menu(screen_pos)
#endregion

#region Context Menu Management
func show_colony_context_menu(colony: Colony, screen_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = BaseContextMenu.new()
	active_context_menu.setup(camera)
	add_child(active_context_menu)
	
	active_context_menu.add_button("Spawn Ants",
		preload("res://ui/styles/spawn_normal.tres"),
		preload("res://ui/styles/spawn_hover.tres"))
	active_context_menu.add_button("Info",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))
	active_context_menu.add_button("Heatmap",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))
	active_context_menu.add_button("Destroy",
		preload("res://ui/styles/destroy_normal.tres"),
		preload("res://ui/styles/destroy_hover.tres"))
	
	active_context_menu.button_pressed.connect(
		func(index: int): _on_colony_menu_button_pressed(index, colony))
	active_context_menu.show_at(screen_pos, colony.radius)


func _on_colony_menu_button_pressed(index: int, colony: Colony) -> void:
	if not is_instance_valid(colony):
		return
	
	match index:
		0: # Spawn Ants
			var profile := settings_manager.get_colony_profile()
			var spawn_count := 5
			if profile and not profile.initial_ants.is_empty():
				spawn_count = profile.initial_ants.values()[0]
			var ants := colony.spawn_ants(spawn_count)
			for ant in ants:
				if not ant.is_inside_tree():
					sandbox.ant_container.add_child(ant)
		1: # Info
			show_info_panel(colony)
		2: # Heatmap
			colony.heatmap_enabled = !colony.heatmap_enabled
		3: # Destroy
			colony_manager.remove_colony(colony)
	
	clear_active_menu()


func show_empty_context_menu(screen_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = BaseContextMenu.new()
	active_context_menu.setup(camera)
	add_child(active_context_menu)
	
	active_context_menu.add_button("Spawn Colony",
		preload("res://ui/styles/spawn_normal.tres"),
		preload("res://ui/styles/spawn_hover.tres"))
	active_context_menu.add_button("Spawn Food",
		preload("res://ui/styles/spawn_normal.tres"),
		preload("res://ui/styles/spawn_hover.tres"))
	
	active_context_menu.button_pressed.connect(
		func(index: int): _on_empty_menu_button_pressed(index, screen_pos))
	active_context_menu.show_at(screen_pos)


func _on_empty_menu_button_pressed(index: int, screen_pos: Vector2) -> void:
	match index:
		0: # Spawn Colony
			_on_spawn_colony_requested(screen_pos)
		1: # Spawn Food
			_on_spawn_food_requested(screen_pos)
	
	clear_active_menu()


func show_ant_context_menu(ant: Ant, screen_pos: Vector2) -> void:
	clear_active_menu()
	active_context_menu = BaseContextMenu.new()
	active_context_menu.setup(camera)
	add_child(active_context_menu)
	
	active_context_menu.add_button("Info",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))
	active_context_menu.add_button("Track",
		preload("res://ui/styles/info_normal.tres"),
		preload("res://ui/styles/info_hover.tres"))
	active_context_menu.add_button("Kill",
		preload("res://ui/styles/destroy_normal.tres"),
		preload("res://ui/styles/destroy_hover.tres"))
	
	active_context_menu.button_pressed.connect(
		func(index: int): _on_ant_menu_button_pressed(index, ant))
	active_context_menu.show_at(screen_pos)


func _on_ant_menu_button_pressed(index: int, ant: Ant) -> void:
	if not is_instance_valid(ant):
		return
	
	match index:
		0: # Info
			show_info_panel(ant)
		1: # Track
			camera.track_entity(ant)
		2: # Kill
			ant_manager.remove_ant(ant)
	
	clear_active_menu()


func clear_active_menu() -> void:
	if is_instance_valid(active_context_menu):
		active_context_menu.queue_free()
		active_context_menu = null
#endregion

#region Info Panel Management
func show_info_panel(entity: Node) -> void:
	if not entity:
		return
	
	if is_instance_valid(entity_info_panel):
		if entity is Ant and entity_info_panel.get_current_ant() == entity:
			entity_info_panel.queue_free()
			entity_info_panel = null
			return
		if entity is Colony and entity_info_panel.get_current_colony() == entity:
			entity_info_panel.queue_free()
			entity_info_panel = null
			return
		
		entity_info_panel.queue_free()
		entity_info_panel = null
	
	entity_info_panel = preload("res://ui/entity_info_panel.tscn").instantiate()
	info_panels_container.add_child(entity_info_panel)
	
	if entity is Colony:
		entity_info_panel.highlight_ants.connect(_on_colony_highlight_ants_requested)
	
	entity_info_panel.closed.connect(_on_entity_info_panel_closed)
	entity_info_panel.show_entity_info(entity)


func _on_entity_info_panel_closed() -> void:
	entity_info_panel = null


func close_info_panel(entity: Node) -> void:
	if is_instance_valid(entity_info_panel):
		if entity is Colony and entity_info_panel.get_current_colony() == entity:
			entity_info_panel.queue_free()
			entity_info_panel = null
		elif entity is Ant and entity_info_panel.get_current_ant() == entity:
			entity_info_panel.queue_free()
			entity_info_panel = null


func close_ant_info() -> void:
	if is_instance_valid(active_ant_info):
		active_ant_info.queue_free()
		active_ant_info = null


func deselect_all() -> void:
	if is_instance_valid(entity_info_panel):
		entity_info_panel.queue_free()
		entity_info_panel = null
#endregion

#region Colony Handlers
func _on_spawn_colony_requested(screen_pos: Vector2) -> void:
	var world_pos := camera.screen_to_world(screen_pos)
	var colony := colony_manager.spawn_colony_at(world_pos)
	if colony:
		print("Spawned colony at: ", world_pos)
	else:
		push_warning("Failed to spawn colony")


func _on_colony_highlight_ants_requested(colony: Colony, enabled: bool) -> void:
	if not is_instance_valid(colony):
		return
	colony.highlight_ants_enabled = enabled
#endregion

#region Food Handlers
func _on_spawn_food_requested(screen_pos: Vector2) -> void:
	var world_pos := camera.screen_to_world(screen_pos)
	_spawn_food_at(world_pos, DEFAULT_FOOD_SPAWN_NUM)


func _spawn_food_at(world_pos: Vector2, count: int) -> void:
	var food_manager := get_tree().get_first_node_in_group("food_manager")
	if food_manager and food_manager.has_method("spawn_food_cluster"):
		food_manager.spawn_food_cluster(world_pos, count)
#endregion
