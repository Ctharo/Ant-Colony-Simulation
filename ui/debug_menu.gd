class_name DebugMenu
extends HBoxContainer
## Top-bar debug menu: spawn counts, simulation speed, pause, and global
## ant visualization toggles. All values persist via SettingsManager
## (set_setting saves to disk on every change).
##
## Created at runtime by SandboxUI and added into ControlPanel/HBoxContainer.

#region Constants
const SPEED_SETTINGS: Array[String] = ["sim_speed_1", "sim_speed_2", "sim_speed_3"]
## Physics frames between visualization re-applies. This keeps newly spawned
## ants and per-ant info-panel toggles consistent with the global switches.
const REAPPLY_INTERVAL: int = 30
#endregion

#region Member Variables
var settings_manager: SettingsManager = SettingsManager
var logger: iLogger

var _sandbox: Node2D
var _status_overlay: StatusBarsOverlay
var _paused: bool = false

var _designer_panel: BehaviorDesignerPanel
var _food_spin: SpinBox
var _ant_spin: SpinBox
var _speed_button: Button
var _pause_button: Button
var _heatmap_check: CheckButton
var _bars_check: CheckButton
var _influence_check: CheckButton
#endregion


func _init() -> void:
	logger = iLogger.new("debug_menu", DebugLogger.Category.UI)


## Must be called before adding to the tree
func setup(sandbox: Node2D) -> void:
	_sandbox = sandbox


#region Lifecycle
func _ready() -> void:
	_build_ui()
	_load_values()
	_connect_signals()

	_apply_speed()
	_apply_all_visualizations()


func _exit_tree() -> void:
	## Never leak speed/pause into other scenes (main menu, settings, ...).
	## Saved settings re-apply the speed next time the sandbox loads.
	Engine.time_scale = 1.0
	if get_tree():
		get_tree().paused = false
	if is_instance_valid(_status_overlay):
		_status_overlay.queue_free()


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() % REAPPLY_INTERVAL != 0:
		return
	## Only reapply the "on" states; an "off" global switch shouldn't
	## fight the per-ant toggles in the info panel.
	if settings_manager.get_setting("debug_show_heatmap"):
		_apply_heatmap(true)
	if settings_manager.get_setting("debug_show_influence_arrows"):
		_apply_influence(true)
#endregion


#region UI Construction
func _build_ui() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = BoxContainer.ALIGNMENT_CENTER

	_food_spin = _add_spin_row("Food:", "food_spawn_count", "Food items spawned when the sandbox starts")	
	_ant_spin = _add_spin_row("Ants:", "ant_spawn_count", "Ants spawned when the sandbox starts")

	add_child(VSeparator.new())

	_speed_button = Button.new()
	_speed_button.focus_mode = Control.FOCUS_NONE
	_speed_button.tooltip_text = "Cycle simulation speed (TAB)"
	add_child(_speed_button)

	_pause_button = Button.new()
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.tooltip_text = "Pause/resume simulation (Space)"
	_pause_button.text = "Pause"
	add_child(_pause_button)

	add_child(VSeparator.new())

	_heatmap_check = _add_check("Heatmap")
	_bars_check = _add_check("Health/Energy")
	_influence_check = _add_check("Influence Arrows")
		
	var designer_btn := Button.new()
	designer_btn.text = "Designer"
	designer_btn.tooltip_text = "Visual behavior designer: expression trees, live values, re-eval policies"
	designer_btn.pressed.connect(_on_designer_pressed)
	add_child(designer_btn)

func _add_spin_row(label_text: String, setting_name: String, tooltip: String = "") -> SpinBox:
	var label := Label.new()
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = tooltip
	add_child(label)

	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(90, 0)
	var constraints: Dictionary = settings_manager.get_constraints(setting_name)
	spin.tooltip_text = "%s\nRange: %s–%s" % [tooltip, constraints.get("min", 0), constraints.get("max", 100)]	
	spin.min_value = constraints.get("min", 0)
	spin.max_value = constraints.get("max", 100)
	spin.step = constraints.get("step", 1)
	add_child(spin)
	return spin


func _add_check(text: String) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.focus_mode = Control.FOCUS_NONE
	add_child(check)
	return check
#endregion


#region Value Loading & Signals
func _load_values() -> void:
	_food_spin.set_value_no_signal(float(settings_manager.get_setting("food_spawn_count")))
	_ant_spin.set_value_no_signal(float(settings_manager.get_setting("ant_spawn_count")))
	_heatmap_check.set_pressed_no_signal(bool(settings_manager.get_setting("debug_show_heatmap")))
	_bars_check.set_pressed_no_signal(bool(settings_manager.get_setting("debug_show_status_bars")))
	_influence_check.set_pressed_no_signal(bool(settings_manager.get_setting("debug_show_influence_arrows")))
	_update_speed_label()


func _connect_signals() -> void:
	_food_spin.value_changed.connect(
		func(v: float): settings_manager.set_setting("food_spawn_count", int(v)))
	_ant_spin.value_changed.connect(
		func(v: float): settings_manager.set_setting("ant_spawn_count", int(v)))

	_speed_button.pressed.connect(_cycle_speed)
	_pause_button.pressed.connect(_toggle_pause)

	_heatmap_check.toggled.connect(_on_heatmap_toggled)
	_bars_check.toggled.connect(_on_bars_toggled)
	_influence_check.toggled.connect(_on_influence_toggled)

	AntManager.ant_spawned.connect(_on_ant_spawned)
	settings_manager.setting_changed.connect(_on_setting_changed)


## Keep the menu in sync if a setting is changed elsewhere (settings menu)
func _on_setting_changed(setting_name: String, value: Variant) -> void:
	match setting_name:
		"food_spawn_count":
			_food_spin.set_value_no_signal(float(value))
		"ant_spawn_count":
			_ant_spin.set_value_no_signal(float(value))
		"sim_speed_1", "sim_speed_2", "sim_speed_3":
			_apply_speed()
#endregion


#region Input Handling
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	## Don't hijack keys while the user is typing in a field
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return

	match key.keycode:
		KEY_TAB:
			_cycle_speed()
			get_viewport().set_input_as_handled()
		KEY_SPACE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
#endregion


#region Simulation Speed & Pause
func _get_speeds() -> Array[float]:
	var speeds: Array[float] = []
	for key in SPEED_SETTINGS:
		speeds.append(float(settings_manager.get_setting(key)))
	return speeds


func _get_speed_index() -> int:
	return clampi(int(settings_manager.get_setting("sim_speed_index")), 0, SPEED_SETTINGS.size() - 1)


func _cycle_speed() -> void:
	var index := (_get_speed_index() + 1) % SPEED_SETTINGS.size()
	settings_manager.set_setting("sim_speed_index", index)
	_apply_speed()


func _apply_speed() -> void:
	Engine.time_scale = _get_speeds()[_get_speed_index()]
	_update_speed_label()
	logger.debug("Simulation speed set to %.1fx" % Engine.time_scale)


func _update_speed_label() -> void:
	_speed_button.text = "Speed: %.1fx" % _get_speeds()[_get_speed_index()]


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_pause_button.text = "Resume" if _paused else "Pause"
	logger.debug("Simulation %s" % ("paused" if _paused else "resumed"))
#endregion


#region Visualization Toggles
func _on_heatmap_toggled(enabled: bool) -> void:
	settings_manager.set_setting("debug_show_heatmap", enabled)
	_apply_heatmap(enabled)


func _on_bars_toggled(enabled: bool) -> void:
	settings_manager.set_setting("debug_show_status_bars", enabled)
	_apply_status_bars(enabled)


func _on_influence_toggled(enabled: bool) -> void:
	settings_manager.set_setting("debug_show_influence_arrows", enabled)
	_apply_influence(enabled)

func _on_designer_pressed() -> void:
	if is_instance_valid(_designer_panel):
		_designer_panel.grab_focus()
		return
	_designer_panel = BehaviorDesignerPanel.new()
	get_tree().root.add_child(_designer_panel)
	_designer_panel.present()

func _apply_all_visualizations() -> void:
	_apply_heatmap(bool(settings_manager.get_setting("debug_show_heatmap")))
	_apply_status_bars(bool(settings_manager.get_setting("debug_show_status_bars")))
	_apply_influence(bool(settings_manager.get_setting("debug_show_influence_arrows")))


func _apply_heatmap(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("ant"):
		if is_instance_valid(node):
			HeatmapManager.debug_draw(node, enabled)


func _apply_influence(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("ant"):
		var ant := node as Ant
		if is_instance_valid(ant) and ant.influence_manager:
			ant.influence_manager.set_visualization_enabled(enabled)


func _apply_status_bars(enabled: bool) -> void:
	if enabled:
		if not is_instance_valid(_status_overlay) and is_instance_valid(_sandbox):
			_status_overlay = StatusBarsOverlay.new()
			_status_overlay.name = "AntStatusBarsOverlay"
			_sandbox.add_child(_status_overlay)
	else:
		if is_instance_valid(_status_overlay):
			_status_overlay.queue_free()
		_status_overlay = null


## Apply the active toggles to ants spawned after the switch was flipped
func _on_ant_spawned(ant: Ant, _colony: Colony) -> void:
	if not is_instance_valid(ant):
		return
	if settings_manager.get_setting("debug_show_heatmap"):
		HeatmapManager.debug_draw(ant, true)
	if settings_manager.get_setting("debug_show_influence_arrows") and ant.influence_manager:
		ant.influence_manager.set_visualization_enabled(true)
#endregion


## Single world-space overlay that draws health/energy bars above every ant.
## One Node2D drawing all bars each frame is far cheaper than per-ant nodes.
## top_level with an identity transform means local coords == world coords,
## so pan/zoom is handled naturally by the camera (same principle as the
## context-menu SelectionIndicator).
class StatusBarsOverlay:
	extends Node2D

	const BAR_WIDTH := 24.0
	const BAR_HEIGHT := 3.0
	const BAR_SPACING := 2.0
	const Y_OFFSET := -18.0
	const BG_COLOR := Color(0.1, 0.1, 0.1, 0.7)
	const HEALTH_COLOR := Color(0.2, 0.8, 0.2)
	const ENERGY_COLOR := Color(0.25, 0.45, 1.0)
	const LOW_COLOR := Color.RED

	func _ready() -> void:
		top_level = true
		z_index = 15

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for node in get_tree().get_nodes_in_group("ant"):
			var ant := node as Ant
			if not is_instance_valid(ant) or ant.is_dead:
				continue
			var origin: Vector2 = ant.global_position + Vector2(-BAR_WIDTH / 2.0, Y_OFFSET)
			_draw_bar(origin, ant.health_level / Ant.HEALTH_MAX, HEALTH_COLOR)
			_draw_bar(
				origin + Vector2(0.0, BAR_HEIGHT + BAR_SPACING),
				ant.energy_level / Ant.ENERGY_MAX,
				ENERGY_COLOR
			)

	func _draw_bar(origin: Vector2, pct: float, color: Color) -> void:
		pct = clampf(pct, 0.0, 1.0)
		draw_rect(Rect2(origin, Vector2(BAR_WIDTH, BAR_HEIGHT)), BG_COLOR)
		var fill := color if pct >= 0.25 else LOW_COLOR
		if pct > 0.0:
			draw_rect(Rect2(origin, Vector2(BAR_WIDTH * pct, BAR_HEIGHT)), fill)
