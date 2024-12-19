class_name ColonyInfoPanel
extends PanelContainer

#region Constants
const STYLE = {
	"PANEL_SIZE": Vector2(300, 200),
	"SELECTION_CIRCLE_COLOR": Color(1, 1, 1, 0.5),
	"SELECTION_CIRCLE_WIDTH": 2.0
}
#endregion

#region UI Components
@onready var title_label: Label = %TitleLabel
@onready var ant_count_label: Label = %AntCountLabel
@onready var food_collected_label: Label = %FoodCollectedLabel
@onready var radius_label: Label = %RadiusLabel
#endregion

## Current colony being displayed
var current_colony: Colony

func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()  # Start hidden
	
	# Set up rendering mode for our node
	top_level = true  # Make sure we draw above other nodes

func show_colony_info(colony: Colony) -> void:
	deselect_current()
	if not colony:
		return
		
	current_colony = colony
	show()
	
	# Enable heatmap visualization
	if current_colony:
		HeatmapManager.set_debug_draw(current_colony, true)
	
	# Update basic info
	title_label.text = "Colony %s" % colony.name
	update_colony_info()
	
	# Queue redraw for selection circle
	queue_redraw()

func deselect_current() -> void:
	if current_colony:
		HeatmapManager.set_debug_draw(current_colony, false)
	current_colony = null
	hide()
	queue_redraw()

func update_colony_info() -> void:
	if not current_colony or not is_visible():
		return
		
	ant_count_label.text = "Ants: %d" % current_colony.ants.size()
	food_collected_label.text = "Food Collected: %.1f units" % (current_colony.foods.mass if current_colony.foods else 0.0)
	radius_label.text = "Colony Radius: %.1f" % current_colony.radius

func _process(_delta: float) -> void:
	update_colony_info()
	queue_redraw()

func _draw() -> void:
	if current_colony and current_colony.is_inside_tree():
		# Draw selection circle
		draw_arc(
			current_colony.global_position,
			current_colony.radius,
			0,
			TAU,
			32,
			STYLE.SELECTION_CIRCLE_COLOR,
			STYLE.SELECTION_CIRCLE_WIDTH
		)

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			deselect_current()  # Right click to unselect
