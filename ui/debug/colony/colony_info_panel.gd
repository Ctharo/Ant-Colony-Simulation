class_name ColonyInfoPanel
extends PanelContainer

#region Constants
const STYLE = {
	"PANEL_SIZE": Vector2(300, 300),
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
@onready var ant_count_edit: SpinBox = %AntCountEdit
@onready var spawn_ants_button: Button = %SpawnAntsButton
@onready var close_button: Button = %CloseButton
@onready var show_heatmap_check: CheckButton = %ShowHeatmapCheck
@onready var highlight_ants_check: CheckButton = %HighlightAntsCheck

# Spawning parameters
const BATCH_SIZE = 10  # Number of ants to spawn per batch
const FRAMES_BETWEEN_BATCHES = 5  # Frames to wait between batches

# Spawning state
var _pending_spawns: int = 0
var _frames_until_next_batch: int = 0
var _is_spawning: bool = false
#endregion

signal colony_closed

## Current colony being displayed
var current_colony: Colony

func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()  # Start hidden

func _process(delta: float) -> void:
	update_colony_info()
	_handle_spawning(delta)
	queue_redraw()

func show_colony_info(colony: Colony) -> void:
	if not colony:
		return

	current_colony = colony
	show()

	# Update basic info
	title_label.text = "Colony %s" % colony.name
	update_colony_info()

	# Queue redraw for selection circle
	queue_redraw()

func update_colony_info() -> void:
	if not current_colony or not is_visible():
		return

	ant_count_label.text = "Ants: %d" % current_colony.ants.size()
	food_collected_label.text = "Food Collected: %.1f units" % (current_colony.foods.mass if current_colony.foods else 0.0)
	radius_label.text = "Colony Radius: %.1f" % current_colony.radius

func _draw() -> void:
	if not current_colony or not current_colony.is_inside_tree():
		return

	# Draw colony selection circle
	draw_arc(
		current_colony.global_position - global_position,
		current_colony.radius,
		0,
		TAU,
		32,
		STYLE.SELECTION_CIRCLE_COLOR,
		STYLE.SELECTION_CIRCLE_WIDTH
	)

	# Draw ant highlights if enabled
	if highlight_ants_check.button_pressed:
		for ant in current_colony.ants:
			if ant and ant.is_inside_tree():
				draw_arc(
					ant.global_position - global_position,
					ANT_HIGHLIGHT_RADIUS,
					0,
					TAU,
					16,  # Less segments for better performance
					ANT_HIGHLIGHT_COLOR,
					2.0
				)

func _on_spawn_ants_pressed() -> void:
	if current_colony:
		start_spawning(ant_count_edit.value)

func _on_show_heatmap_toggled(enabled: bool) -> void:
	if current_colony:
		HeatmapManager.set_debug_draw(current_colony, enabled)

func _on_highlight_ants_toggled(enabled: bool) -> void:
	queue_redraw()

func start_spawning(num_to_spawn: int) -> void:
	_pending_spawns = num_to_spawn
	_is_spawning = true
	_frames_until_next_batch = 0

func _handle_spawning(delta: float) -> void:
	if not _is_spawning:
		return

	if _frames_until_next_batch > 0:
		_frames_until_next_batch -= 1
		return

	if _pending_spawns <= 0:
		_finish_spawning()
		return

	var batch_size = mini(BATCH_SIZE, _pending_spawns)
	_spawn_batch(batch_size)

	_frames_until_next_batch = FRAMES_BETWEEN_BATCHES

func _spawn_batch(size: int) -> void:
	var ants = current_colony.spawn_ants(size, true)
	_pending_spawns -= size

func _finish_spawning() -> void:
	_is_spawning = false

func _on_close_pressed() -> void:
	queue_free()

func _exit_tree() -> void:
	if current_colony:
		HeatmapManager.set_debug_draw(current_colony, false)
		current_colony.is_highlighted = false
	current_colony = null
	show_heatmap_check.button_pressed = false
	highlight_ants_check.button_pressed = false
