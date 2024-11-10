extends Control

var title_label: Label
var button_container: VBoxContainer

func _ready():
	create_ui()
	animate_ui_elements()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key
		_on_quit_button_pressed()
		get_viewport().set_input_as_handled()

func create_ui():
	# Create a background
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1)  # Dark gray background
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Create a centered container for all UI elements
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	# Main vertical container
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_container.add_child(main_container)

	# Title
	title_label = Label.new()
	title_label.text = "Ant Colony Simulation"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0))  # Golden yellow color
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate.a = 0  # Start fully transparent
	main_container.add_child(title_label)

	# Add some space after the title
	main_container.add_spacer(false)

	# Create a container for buttons
	button_container = VBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(button_container)

	# Create buttons
	create_button("Start Simulation", button_container)
	create_button("Colony Editor", button_container)
	create_button("Ant Editor", button_container)
	create_button("Property Browser", button_container)
	create_button("Settings", button_container)
	create_button("Quit", button_container)

func create_button(text: String, parent: Control) -> Button:
	var button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(250, 60)
	button.add_theme_font_size_override("font_size", 24)

	# Custom styling
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.2, 0.2)
	normal_style.border_width_bottom = 4
	normal_style.border_color = Color(0.3, 0.3, 0.3)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.25, 0.25)
	hover_style.border_color = Color(1, 0.8, 0)  # Golden yellow color

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.15, 0.15)
	pressed_style.border_color = Color(0.8, 0.6, 0)  # Darker golden yellow

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.modulate.a = 0  # Start fully transparent
	parent.add_child(button)

	var function_name = "_on_" + text.to_lower().replace(" ", "_") + "_button_pressed"
	button.connect("pressed", Callable(self, function_name))

	return button

func animate_ui_elements():
	var tween = create_tween().set_parallel(true)

	# Fade in and slide down the title
	tween.tween_property(title_label, "modulate:a", 1.0, 0.5)


	var i: int = 0
	# Fade in and slide up the buttons
	for button in button_container.get_children():
		var delay = 0.1 * (i + 1)
		tween.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(delay)
		i += 1

func _on_start_simulation_button_pressed():
	DebugLogger.info(DebugLogger.Category.PROGRAM, "Start Simulation pressed")
	transition_to_scene("sandbox")

func _on_colony_editor_button_pressed():
	transition_to_scene("colony_editor")

func _on_ant_editor_button_pressed():
	transition_to_scene("ant_behavior_editor")

func _on_property_browser_button_pressed():
	transition_to_scene("property_browser")

func _on_settings_button_pressed():
	DebugLogger.info(DebugLogger.Category.PROGRAM, "Settings pressed")
	# Add your logic here

func _on_quit_button_pressed():
	get_tree().quit()

func transition_to_scene(scene_name: String):
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(Callable(self, "_change_scene").bind(scene_name))

func _change_scene(scene_name: String):
	var error = get_tree().change_scene_to_file("res://" + "ui" + "/" + scene_name + ".tscn")
	if error != OK:
		DebugLogger.error(DebugLogger.Category.PROGRAM, "Failed to load scene: " + scene_name)
