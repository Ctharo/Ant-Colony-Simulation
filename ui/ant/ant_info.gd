class_name AntInfo
extends PanelContainer

#region Constants
const STYLE = {
	"PANEL_SIZE": Vector2(250, 160),
	"EXPANDED_SIZE": Vector2(250, 320),
	"BAR_BG_COLOR": Color(0.2, 0.2, 0.2),
	"HEALTH_COLOR": Color(0.2, 0.8, 0.2),
	"ENERGY_COLOR": Color(0.2, 0.2, 0.8),
	"LOW_COLOR": Color.RED,
	"MED_COLOR": Color.ORANGE,
}
#endregion

#region Variables
## Reference to currently displayed ant
var current_ant: Ant = null

## Whether the influences panel is expanded
var is_expanded: bool = false
#endregion

#region Onready Variables
@onready var title_label: Label = %TitleLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var food_label: Label = %FoodLabel
@onready var action_label: Label = %ActionLabel
@onready var expand_button: Button = %ExpandButton
@onready var influences_container: VBoxContainer = %InfluencesContainer
#endregion

#region Lifecycle Methods
func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	setup_styling()
	influences_container.hide()
	expand_button.pressed.connect(_on_expand_pressed)

func _process(_delta: float) -> void:
	if current_ant and is_instance_valid(current_ant):
		_update_display()
#endregion

#region Public Methods
## Display info for the given ant
func show_ant_info(ant: Ant) -> void:
	if not is_instance_valid(ant):
		return
		
	current_ant = ant
	title_label.text = "Ant #%d" % ant.id
	show()
	_update_display()

## Clear current ant and hide panel
func clear() -> void:
	current_ant = null
	hide()
#endregion

#region Private Methods
## Set up initial styling
func setup_styling() -> void:
	# Style health bar
	var health_style = StyleBoxFlat.new()
	health_style.bg_color = STYLE.HEALTH_COLOR
	health_style.corner_radius_top_left = 3
	health_style.corner_radius_top_right = 3
	health_style.corner_radius_bottom_left = 3
	health_style.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("fill", health_style)
	
	# Style energy bar
	var energy_style = StyleBoxFlat.new()
	energy_style.bg_color = STYLE.ENERGY_COLOR
	energy_style.corner_radius_top_left = 3
	energy_style.corner_radius_top_right = 3
	energy_style.corner_radius_bottom_left = 3
	energy_style.corner_radius_bottom_right = 3
	energy_bar.add_theme_stylebox_override("fill", energy_style)
	
	# Style background bars
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = STYLE.BAR_BG_COLOR
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("background", bg_style)
	energy_bar.add_theme_stylebox_override("background", bg_style.duplicate())

## Update the display with current ant info
func _update_display() -> void:
	if not current_ant:
		return
		
	# Update bars
	var health_percent = (current_ant.health_level / current_ant.health_max) * 100.0
	health_bar.value = health_percent
	_update_bar_color(health_bar, health_percent, STYLE.HEALTH_COLOR)
	
	var energy_percent = (current_ant.energy_level / current_ant.energy_max) * 100.0
	energy_bar.value = energy_percent
	_update_bar_color(energy_bar, energy_percent, STYLE.ENERGY_COLOR)
	
	# Update labels
	food_label.text = "Carried Food: %.1f units" % (current_ant.foods.mass if current_ant.foods else 0.0)
	action_label.text = "Action: %s" % (current_ant.action_manager._current_action_id if current_ant.action_manager else "None")
	
	# Update influences if expanded
	if is_expanded:
		_update_influences()

## Update the color of a progress bar based on value
func _update_bar_color(bar: ProgressBar, value: float, normal_color: Color) -> void:
	var style = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if value > 66:
		style.bg_color = normal_color
	elif value > 33:
		style.bg_color = STYLE.MED_COLOR
	else:
		style.bg_color = STYLE.LOW_COLOR

## Clear and update the influences display
func _update_influences() -> void:
	# Clear existing influences
	for child in influences_container.get_children():
		if child is HBoxContainer:  # Skip the header
			child.queue_free()
			
	if not current_ant or not current_ant.action_manager:
		return
		
	var current_action = current_ant.action_manager._actions.get(
		current_ant.action_manager._current_action_id
	)
	
	if not current_action or not current_action is Move:
		return
		
	# Add influence entries
	for influence in current_action.influences:
		_add_influence_entry(influence)

## Add a single influence entry to the influences container
func _add_influence_entry(influence: Influence) -> void:
	var entry = HBoxContainer.new()
	
	# Color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(16, 16)
	color_rect.color = influence.color
	entry.add_child(color_rect)
	
	# Name label
	var name_label = Label.new()
	name_label.text = influence.name.trim_suffix(" influence").capitalize()
	entry.add_child(name_label)
	
	influences_container.add_child(entry)

## Handle expand button press
func _on_expand_pressed() -> void:
	is_expanded = !is_expanded
	
	if is_expanded:
		custom_minimum_size = STYLE.EXPANDED_SIZE
		influences_container.show()
		expand_button.text = "▼"
		_update_influences()
	else:
		custom_minimum_size = STYLE.PANEL_SIZE
		influences_container.hide()
		expand_button.text = "▶"
#endregion
