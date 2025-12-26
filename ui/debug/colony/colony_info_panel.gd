class_name ColonyInfoPanel
extends PanelContainer

signal highlight_ants(colony: Colony, enable: bool)
signal spawn_requested(colony: Colony, count: int, profile: AntProfile)

#region Constants
const STYLE = {
	"PANEL_SIZE": Vector2(340, 550),
	"SELECTION_CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"SELECTION_CIRCLE_WIDTH": 2.0
}
const ANT_HIGHLIGHT_RADIUS = 12.0
const ANT_HIGHLIGHT_COLOR = Color(Color.WHITE, 0.5)
#endregion

#region UI Components
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton

## Info Section
@onready var ant_count_label: Label = %AntCountLabel
@onready var food_collected_label: Label = %FoodCollectedLabel
@onready var radius_label: Label = %RadiusLabel

## Spawn Section
@onready var spawn_count_spin: SpinBox = %SpawnCountSpin
@onready var profile_option: OptionButton = %ProfileOption
@onready var spawn_button: Button = %SpawnButton

## Colony Profile Section
@onready var colony_profile_container: VBoxContainer = %ColonyProfileContainer
@onready var radius_spin: SpinBox = %RadiusSpin
@onready var max_ants_spin: SpinBox = %MaxAntsSpin
@onready var spawn_rate_spin: SpinBox = %SpawnRateSpin
@onready var dirt_color_picker: ColorPickerButton = %DirtColorPicker
@onready var darker_dirt_color_picker: ColorPickerButton = %DarkerDirtColorPicker

## Ant Profiles Section
@onready var ant_profiles_list: ItemList = %AntProfilesList
@onready var edit_ant_profile_button: Button = %EditAntProfileButton

## Visualization Section
@onready var show_heatmap_check: CheckButton = %ShowHeatmapCheck
@onready var nav_debug_check: CheckButton = %NavDebugCheck
@onready var highlight_ants_check: CheckButton = %HighlightAntsCheck
#endregion

#region Member Variables
var heatmap: HeatmapManager
var current_colony: Colony
var _profile_map: Dictionary = {}
#endregion


func _ready() -> void:
	custom_minimum_size = STYLE.PANEL_SIZE
	hide()
	heatmap = get_tree().get_first_node_in_group("heatmap")
	top_level = true
	
	_connect_signals()


func _connect_signals() -> void:
	close_button.pressed.connect(_on_close_pressed)
	spawn_button.pressed.connect(_on_spawn_pressed)
	profile_option.item_selected.connect(_on_profile_selected)
	
	radius_spin.value_changed.connect(_on_radius_changed)
	max_ants_spin.value_changed.connect(_on_max_ants_changed)
	spawn_rate_spin.value_changed.connect(_on_spawn_rate_changed)
	dirt_color_picker.color_changed.connect(_on_dirt_color_changed)
	darker_dirt_color_picker.color_changed.connect(_on_darker_dirt_changed)
	
	ant_profiles_list.item_selected.connect(_on_ant_profile_list_selected)
	edit_ant_profile_button.pressed.connect(_on_edit_ant_profile_pressed)
	
	show_heatmap_check.toggled.connect(_on_show_heatmap_toggled)
	nav_debug_check.toggled.connect(_on_nav_debug_toggled)
	highlight_ants_check.toggled.connect(_on_highlight_ants_toggled)


func _process(_delta: float) -> void:
	_update_info()
	queue_redraw()


#region Public Methods
func show_colony_info(colony: Colony) -> void:
	if not colony:
		return

	current_colony = colony
	title_label.text = "Colony %s" % colony.name
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)

	_sync_visualization_checkboxes()
	_populate_profile_options()
	_populate_colony_profile_values()
	_populate_ant_profiles_list()
	_update_info()
	
	show()
	queue_redraw()
#endregion


#region UI Update Methods
func _update_info() -> void:
	if not current_colony or not is_visible():
		return

	ant_count_label.text = "Ants: %d / %d" % [current_colony.ants.size(), current_colony.profile.max_ants if current_colony.profile else 0]
	food_collected_label.text = "Food Collected: %.1f units" % (current_colony.foods.mass if current_colony.foods else 0.0)
	radius_label.text = "Colony Radius: %.1f" % current_colony.radius


func _sync_visualization_checkboxes() -> void:
	show_heatmap_check.button_pressed = current_colony.heatmap_enabled
	highlight_ants_check.button_pressed = current_colony.highlight_ants_enabled
	nav_debug_check.button_pressed = current_colony.nav_debug_enabled


func _populate_profile_options() -> void:
	profile_option.clear()
	_profile_map.clear()
	
	if not current_colony or not current_colony.profile:
		return
	
	for i in range(current_colony.profile.ant_profiles.size()):
		var ant_profile = current_colony.profile.ant_profiles[i]
		if ant_profile:
			profile_option.add_item(ant_profile.name, i)
			_profile_map[i] = ant_profile
	
	if profile_option.item_count > 0:
		profile_option.select(0)


func _populate_colony_profile_values() -> void:
	if not current_colony or not current_colony.profile:
		return
	
	var profile = current_colony.profile
	
	radius_spin.set_value_no_signal(profile.radius)
	max_ants_spin.set_value_no_signal(profile.max_ants)
	spawn_rate_spin.set_value_no_signal(profile.spawn_rate)
	dirt_color_picker.color = profile.dirt_color
	darker_dirt_color_picker.color = profile.darker_dirt


func _populate_ant_profiles_list() -> void:
	ant_profiles_list.clear()
	
	if not current_colony or not current_colony.profile:
		return
	
	for ant_profile in current_colony.profile.ant_profiles:
		if ant_profile:
			var initial_count = current_colony.profile.initial_ants.get(ant_profile.id, 0)
			ant_profiles_list.add_item("%s (Initial: %d)" % [ant_profile.name, initial_count])
	
	edit_ant_profile_button.disabled = true
#endregion


#region Signal Handlers - Spawn
func _on_spawn_pressed() -> void:
	if not current_colony:
		return
	
	var count = int(spawn_count_spin.value)
	var selected_idx = profile_option.selected
	var profile: AntProfile = _profile_map.get(selected_idx)
	
	if profile and count > 0:
		var spawned = current_colony.spawn_ants(count, profile)
		spawn_requested.emit(current_colony, count, profile)


func _on_profile_selected(_index: int) -> void:
	pass
#endregion


#region Signal Handlers - Colony Profile
func _on_radius_changed(value: float) -> void:
	if current_colony and current_colony.profile:
		current_colony.profile.radius = value
		current_colony.radius = value


func _on_max_ants_changed(value: float) -> void:
	if current_colony and current_colony.profile:
		current_colony.profile.max_ants = int(value)


func _on_spawn_rate_changed(value: float) -> void:
	if current_colony and current_colony.profile:
		current_colony.profile.spawn_rate = value


func _on_dirt_color_changed(color: Color) -> void:
	if current_colony and current_colony.profile:
		current_colony.profile.dirt_color = color
		current_colony.dirt_color = color
		current_colony.queue_redraw()


func _on_darker_dirt_changed(color: Color) -> void:
	if current_colony and current_colony.profile:
		current_colony.profile.darker_dirt = color
		current_colony.darker_dirt = color
		current_colony.queue_redraw()
#endregion


#region Signal Handlers - Ant Profiles
func _on_ant_profile_list_selected(index: int) -> void:
	edit_ant_profile_button.disabled = index < 0


func _on_edit_ant_profile_pressed() -> void:
	var selected_indices = ant_profiles_list.get_selected_items()
	if selected_indices.is_empty() or not current_colony or not current_colony.profile:
		return
	
	var profile_idx = selected_indices[0]
	if profile_idx < current_colony.profile.ant_profiles.size():
		var ant_profile = current_colony.profile.ant_profiles[profile_idx]
		_open_ant_profile_editor(ant_profile)


func _open_ant_profile_editor(ant_profile: AntProfile) -> void:
	var editor = AntProfileEditorPopup.new()
	add_child(editor)
	editor.edit_profile(ant_profile)
	await editor.closed
	_populate_ant_profiles_list()
#endregion


#region Signal Handlers - Visualization
func _on_highlight_ants_toggled(enabled: bool) -> void:
	if current_colony:
		current_colony.highlight_ants_enabled = enabled
		highlight_ants.emit(current_colony, enabled)


func _on_nav_debug_toggled(enabled: bool) -> void:
	if current_colony:
		current_colony.nav_debug_enabled = enabled
		for ant in current_colony.ants:
			if ant.nav_agent:
				ant.nav_agent.debug_enabled = enabled


func _on_show_heatmap_toggled(enabled: bool) -> void:
	if current_colony:
		current_colony.heatmap_enabled = enabled
#endregion


#region Signal Handlers - Panel
func _on_close_pressed() -> void:
	queue_free()
#endregion


func _exit_tree() -> void:
	current_colony = null
