extends Control

var title_label: Label
var button_container: VBoxContainer
var _designer_panel: BehaviorDesignerPanel

var logger: iLogger


func _init() -> void:
	logger = iLogger.new("main", DebugLogger.Category.PROGRAM)


func _ready() -> void:
	create_ui()
	animate_ui_elements()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key
		_on_quit_button_pressed()
		get_viewport().set_input_as_handled()


func create_ui() -> void:
	logger.trace("Creating main UI")
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var main_container: VBoxContainer = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_container.add_child(main_container)

	title_label = Label.new()
	title_label.text = "Ant Colony Simulation"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate.a = 0
	main_container.add_child(title_label)

	main_container.add_spacer(false)

	button_container = VBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(button_container)

	var _start_btn: Button = create_button("Start Simulation", button_container,
		_on_start_simulation_button_pressed)
	var _designer_btn: Button = create_button("Behavior Designer", button_container,
		_on_behavior_designer_button_pressed)
	var _settings_btn: Button = create_button("Settings", button_container,
		_on_settings_button_pressed)
	var _quit_btn: Button = create_button("Quit", button_container,
		_on_quit_button_pressed)

	logger.trace("Main UI created")


func create_button(text: String, parent: Control, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(250, 60)
	button.add_theme_font_size_override("font_size", 24)

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.2, 0.2)
	normal_style.border_width_bottom = 4
	normal_style.border_color = Color(0.3, 0.3, 0.3)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8

	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.25, 0.25, 0.25)
	hover_style.border_color = Color(1, 0.8, 0)

	var pressed_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.15, 0.15, 0.15)
	pressed_style.border_color = Color(0.8, 0.6, 0)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.modulate.a = 0
	parent.add_child(button)
	var _err_pressed: Error = button.pressed.connect(handler)
	return button


func animate_ui_elements() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	var _t_title: PropertyTweener = tween.tween_property(title_label, "modulate:a", 1.0, 0.5)

	var i: int = 0
	for child: Node in button_container.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var delay: float = 0.1 * float(i + 1)
		var _t_btn: PropertyTweener = tween.tween_property(
			button, "modulate:a", 1.0, 0.3).set_delay(delay)
		i += 1


func _on_start_simulation_button_pressed() -> void:
	logger.info("Start Simulation pressed")
	transition_to_scene("sandbox")


func _on_settings_button_pressed() -> void:
	logger.info("Settings pressed")
	transition_to_scene("settings")


func _on_behavior_designer_button_pressed() -> void:
	logger.info("Behavior Designer pressed")
	# Single instance: pressing again focuses the open window.
	if is_instance_valid(_designer_panel):
		_designer_panel.grab_focus()
		return
	_designer_panel = BehaviorDesignerPanel.new()
	add_child(_designer_panel)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func transition_to_scene(scene_name: String, in_folder: String = "") -> void:
	var path: String = in_folder + "/" if not in_folder.is_empty() else ""
	logger.trace("Transitioning to scene: %s" % (path + scene_name))
	var tween: Tween = create_tween()
	var _t_fade: PropertyTweener = tween.tween_property(self, "modulate:a", 0.0, 0.5)
	var _cb: CallbackTweener = tween.tween_callback(_change_scene.bind(path + scene_name))


func _change_scene(scene_name: String) -> void:
	var err: Error = get_tree().change_scene_to_file("res://ui/%s.tscn" % scene_name)
	if err != OK:
		logger.error("Failed to load scene: %s (%s)" % [scene_name, error_string(err)])
	else:
		logger.trace("Changed to scene: %s" % scene_name)
