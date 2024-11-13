class_name PropertyBrowser
extends Window

#region Signals
## Emitted when a property is selected
signal property_selected(property_path: String)

## Emitted when all initial content is created
signal content_created
#endregion

#region Constants
## Window configuration
const WINDOW_SIZE_PERCENTAGE := 0.62

## Number of items to process per frame for staged creation
const ITEMS_PER_FRAME = 50

## Tree columns configuration
const TREE_COLUMNS := {
	"NAME": 0,
	"TYPE": 1,
	"VALUE": 2,
	"DEPENDENCIES": 3
}
#endregion

#region Components
## UI Builder component for constructing the interface
var ui_builder: PropertyBrowserUIBuilder

## Navigation manager component for handling browsing
var navigation_manager: PropertyBrowserNavigation

## Property manager component for handling property display and interaction
var property_manager: PropertyManager
#endregion

#region Member Variables
## Number of food items to simulate
var foods_to_spawn: int = randi_range(0, 0)

## Number of ants to simulate
var ants_to_spawn: int = randi_range(0, 0)

## Number of pheromones to simulate
var pheromones_to_spawn: int = randi_range(0, 0)

## Reference to current Ant instance
var current_ant: Ant

## Current browsing mode (Direct/Group)
var current_mode: String = "Direct"

## Currently selected property group
var current_group: String
#endregion

#region UI Properties
## Mode selection dropdown
var mode_switch: OptionButton

## List of available property groups
var group_list: ItemList

## Tree view showing property details
var properties_tree: Tree

## Label showing selected property path
var path_label: Label

## Label showing current group name
var group_label: Label

## Label showing property description
var description_label: Label

## Back button for navigation
var back_button: Button

## Label for content loading information
var loading_label: Label
#endregion

#region Initialization
## Called when the node enters the scene tree
func _ready() -> void:
	DebugLogger.set_log_level(DebugLogger.LogLevel.TRACE)
	DebugLogger.set_from_enabled("property_browser")
	DebugLogger.set_from_enabled("property_access")
	DebugLogger.set_from_enabled("property_browser_navigation")
	_trace("PropertyBrowser UI initialization complete")
	_configure_window()
	_initialize_ui_builder()
	_initialize_navigation()
	_initialize_property_manager()
	generate_content()

## Handle unhandled input events
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

## Configure window properties
func _configure_window() -> void:
	title = "Ant Property Browser"
	visibility_changed.connect(func(): visible = true)
	
	unresizable = false
	
	var screen_size := DisplayServer.screen_get_size()
	size = screen_size * WINDOW_SIZE_PERCENTAGE
	position = Vector2.ZERO

## Initialize the UI builder component
func _initialize_ui_builder() -> bool:
	ui_builder = PropertyBrowserUIBuilder.new()
	ui_builder.close_requested.connect(_on_close_pressed)
	
	var refs = ui_builder.create_ui(self)
	properties_tree = refs.properties_tree
	group_list = refs.group_list
	mode_switch = refs.mode_switch
	path_label = refs.path_label
	group_label = refs.group_label
	description_label = refs.description_label
	back_button = refs.back_button
	loading_label = refs.loading_label
	
	return true

## Initialize the navigation manager component
func _initialize_navigation() -> void:
	navigation_manager = PropertyBrowserNavigation.new({
		back_button = back_button,
		path_label = path_label,
		group_label = group_label,
		group_list = group_list,
		properties_tree = properties_tree
	})
	
	# Connect navigation signals
	back_button.pressed.connect(navigation_manager.navigate_back)
	group_list.item_selected.connect(_on_group_selected)
	properties_tree.item_selected.connect(_on_property_selected)
	properties_tree.item_activated.connect(_on_property_activated)  # Add this for double-click
	navigation_manager.path_changed.connect(_on_path_changed)

## Initialize the property manager component
func _initialize_property_manager() -> void:
	property_manager = PropertyManager.new(properties_tree, description_label)

#endregion

#region Navigation Handlers
## Handle selection in group list
func _on_group_selected(index: int) -> void:
	var group_text = group_list.get_item_text(index)
	var path = Path.parse(group_text)
	navigation_manager.handle_activation(path)

## Handle single-click property selection
func _on_property_selected() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		return
		
	var node = selected.get_metadata(0) as NestedProperty
	if node:
		# Just update the path label for selection
		path_label.text = node.path.full
		property_selected.emit(node.path.full)

## Handle double-click property activation
func _on_property_activated() -> void:
	var selected = properties_tree.get_selected()
	if not selected:
		return
		
	var node = selected.get_metadata(0) as NestedProperty
	if not node:
		return
		
	if node.type == NestedProperty.Type.CONTAINER:
		# Navigate into containers on double-click
		navigation_manager.handle_activation(node.path)
	else:
		# Just update path for properties
		path_label.text = node.path.full
		
## Handle path changes in navigation
func _on_path_changed(new_path: Path) -> void:
	if not current_ant:
		return
		
	# Empty path means we're at root - nothing to update
	if new_path.is_root():
		return
		
	# Get the property group using the first part of the path
	var group = current_ant.get_property_group(new_path.get_group_name())
	if not group:
		return
		
	# Get the appropriate node based on path depth
	var node: NestedProperty
	if new_path.is_group_root():
		# If we're at group root (e.g., "reach"), get the root node
		node = group.get_root()
	else:
		# Otherwise get the node at the subpath (e.g., for "reach.foods", get node at "foods")
		node = group.get_at_path(new_path.get_subpath())
	
	if node:
		property_manager.update_property_view(node)
#endregion

#region Public Interface
## Show properties for the given ant
func create_ant_to_browse() -> void:
	var ant: Ant = Ant.new()
	var colony: Colony = Colony.new()
	ant.colony = colony
	
	ant.global_position = _get_random_position()
	colony.global_position = _get_random_position()
	ant.carried_food.add_food(randf_range(0.0, 200.0))
	
	add_child(ant)
	ant.set_physics_process(false)
	ant.set_process(false)
	current_ant = ant
	navigation_manager.set_ant(ant)
#endregion

#region Component Creation
## Create simulation components
func generate_content() -> void:
	create_ant_to_browse()
	if foods_to_spawn + pheromones_to_spawn + ants_to_spawn > 0:
		ui_builder.show_loading_indicator(self)
	
	var to_create = {
		"food": foods_to_spawn,
		"pheromones": pheromones_to_spawn,
		"ants": ants_to_spawn
	}
	_staged_creation(to_create, current_ant)

## Create components in stages to avoid freezing
func _staged_creation(params: Dictionary, main_ant: Ant) -> void:
	var items_created: int = params.values().reduce(func(accum, value): return accum + value, 0)
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.016
	timer.connect("timeout", Callable(self, "_create_batch").bind(params, timer))
	timer.start()
	
	await content_created
	loading_label.text = "Finished! Created %s items" % items_created
	await get_tree().create_timer(2.5).timeout
	loading_label.queue_free()
	loading_label = null

## Create a batch of components
func _create_batch(params: Dictionary, timer: Timer) -> void:
	var items_created = 0
	
	while params.food > 0 and items_created < ITEMS_PER_FRAME:
		loading_label.text = "Creating content: food (%s)" % params.food
		var food = Food.new(randf_range(0.0, 50.0))
		food.global_position = _get_random_position()
		add_child(food)
		params.food -= 1
		items_created += 1

	while params.food == 0 and params.pheromones == 0 and params.ants > 0 and items_created < ITEMS_PER_FRAME:
		loading_label.text = "Creating content: ants (%s)" % params.ants
		var ant = Ant.new()
		ant.global_position = _get_random_position()
		add_child(ant)
		ant.set_physics_process(false)
		ant.set_process(false)
		params.ants -= 1
		items_created += 1

	while params.food == 0 and params.pheromones > 0 and items_created < ITEMS_PER_FRAME:
		loading_label.text = "Creating content: pheromones (%s)" % params.pheromones
		var pheromone = Pheromone.new(
			_get_random_position(),
			["food", "home"].pick_random(),
			randf_range(0.0, 100.0),
			Ants.all().as_array().pick_random()
		)
		add_child(pheromone)
		params.pheromones -= 1
		items_created += 1

	if params.food == 0 and params.pheromones == 0 and params.ants == 0:
		timer.queue_free()
		content_created.emit()
#endregion

#region Helper Functions
## Get a random position within the simulation area
func _get_random_position() -> Vector2:
	return Vector2(randf_range(0, 1800), randf_range(0, 800))

## Log a trace message
func _trace(message: String) -> void:
	DebugLogger.trace(DebugLogger.Category.PROPERTY,
		message,
		{"from": "property_browser"}
	)

## Log an error message
func _error(message: String) -> void:
	DebugLogger.error(DebugLogger.Category.PROPERTY,
		message,
		{"from": "property_browser"}
	)

## Log a warning message
func _warn(message: String) -> void:
	DebugLogger.warn(DebugLogger.Category.PROPERTY,
		message,
		{"from": "property_browser"}
	)

## Handle close button press
func _on_close_pressed() -> void:
	transition_to_scene("main")

## Transition to a new scene
func transition_to_scene(scene_name: String) -> void:
	var tween := create_tween().tween_callback(Callable(self, "_change_scene").bind(scene_name))
	await tween.finished
	queue_free()

## Change to a new scene
func _change_scene(scene_name: String) -> void:
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)
#endregion
