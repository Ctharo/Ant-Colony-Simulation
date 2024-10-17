class_name MainMenu
extends Control

var title_label: Label
var button_container: VBoxContainer

func _ready():
	create_ui()
	animate_ui_elements()

func create_ui():
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
	# in reverse order because I can't figure out else to get them to load correctly
	create_button("Quit", button_container)
	create_button("Settings", button_container)
	create_button("Colony Editor", button_container)
	create_button("Start Simulation", button_container)

func create_button(text: String, parent: Control) -> Button:
	var button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(200, 50)
	button.modulate.a = 0  # Start fully transparent
	parent.add_child(button)
	
	var function_name = "_on_" + text.to_lower().replace(" ", "_") + "_button_pressed"
	button.connect("pressed", Callable(self, function_name))
	
	return button

func animate_ui_elements():
	var tween = create_tween().set_parallel(true)
	
	# Fade in and slide down the title
	var title_target_y = title_label.position.y + 50
	tween.tween_property(title_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(title_label, "position:y", title_target_y, 0.5).from(title_label.position.y - 50)
	
	await tween.finished
	
	# Calculate initial button y-position based on the title's position
	var initial_button_y = title_target_y + 80  # Adjust the offset as needed
	
	# Get all buttons and iterate in reverse order
	var buttons = button_container.get_children()
	for button in buttons:
		var i: int = button.get_index()
		var delay = 0.1 * (buttons.size() - 1 - i)
		var target_y = initial_button_y + (50 * (buttons.size() - 1 - i))
		
		# Apply the animations with adjusted position
		tween = create_tween().set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(delay)
		tween.tween_property(button, "position:y", target_y, 0.3).from(button.position.y).set_delay(delay)

func _on_start_simulation_button_pressed():
	push_warning("Start Simulation functionality not yet implemented")

func _on_colony_editor_button_pressed():
	transition_to_scene("colony_editor")

func _on_settings_button_pressed():
	push_warning("Settings functionality not yet implemented")

func _on_quit_button_pressed():
	get_tree().quit()

func transition_to_scene(scene_name: String):
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(Callable(self, "_change_scene").bind(scene_name))

func _change_scene(scene_name: String):
	var error = get_tree().change_scene_to_file("res://" + scene_name + "/" + scene_name + ".tscn")
	if error != OK:
		push_error("Failed to load scene: " + scene_name)
