class_name ColonyInfoPanel
extends PanelContainer

signal highlight_ants(colony: Colony, enable: bool)

#region Constants
const STYLE = {
	"PANEL_SIZE": Vector2(300, 250),
	"SELECTION_CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"SELECTION_CIRCLE_WIDTH": 2.0
}
const ANT_HIGHLIGHT_RADIUS = 12.0
const ANT_HIGHLIGHT_COLOR = Color(Color.WHITE, 0.5)
#endregion

#region UI Components
@onready var title_label: Label = %TitleLabel
@onready var ant_count_label: Label = %AntCountLabel
@onready var food_collected_label: Label = %FoodCollectedLabel
@onready var radius_label: Label = %RadiusLabel
@onready var close_button: Button = %CloseButton
@onready var show_heatmap_check: CheckButton = %ShowHeatmapCheck
@onready var nav_debug_check: CheckButton = %NavDebugCheck
@onready var highlight_ants_check: CheckButton = %HighlightAntsCheck

var heatmap: HeatmapManager

#endregion


## Current colony being displayed
var current_colony: Colony

func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()  # Start hidden
	heatmap = get_tree().get_first_node_in_group("heatmap")
	top_level = true


func _process(_delta: float) -> void:
	update_colony_info()
	queue_redraw()

func show_colony_info(colony: Colony) -> void:
	if not colony:
		return

	current_colony = colony

	# Update basic info
	title_label.text = "Colony %s" % colony.name
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)

	# Sync checkboxes with colony state
	show_heatmap_check.button_pressed = colony.heatmap_enabled
	highlight_ants_check.button_pressed = colony.highlight_ants_enabled
	nav_debug_check.button_pressed = colony.nav_debug_enabled

	update_colony_info()
	show()

	# Queue redraw for selection circle
	queue_redraw()

func update_colony_info() -> void:
	if not current_colony or not is_visible():
		return

	ant_count_label.text = "Ants: %d" % current_colony.ants.size()
	food_collected_label.text = "Food Collected: %s units" % (current_colony.foods.mass if current_colony.foods else 0.0)
	radius_label.text = "Colony Radius: %.1f" % current_colony.radius


func _on_highlight_ants_toggled(enabled: bool) -> void:
	if current_colony:
		current_colony.highlight_ants_enabled = enabled
		highlight_ants.emit(current_colony, enabled)

func _on_nav_debug_toggled(enabled: bool) -> void:
	if current_colony:
		current_colony.nav_debug_enabled = enabled
		# Toggle nav debug for all existing ants
		for ant in current_colony.ants:
			if ant.nav_agent:
				ant.nav_agent.debug_enabled = enabled


func _on_close_pressed() -> void:
	queue_free()

func _on_show_heatmap_toggled(enabled: bool) -> void:
	if current_colony:
		current_colony.heatmap_enabled = enabled

func _exit_tree() -> void:
	current_colony = null
