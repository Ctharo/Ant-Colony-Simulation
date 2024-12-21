class_name BaseContextMenu
extends Control

const RADIUS = 80.0
const BUTTON_ARC_WIDTH = 60.0  # Width of the curved button
const BUTTON_ARC_HEIGHT = 40.0  # Height of the curved button
const SELECTION_STYLE = {
	"CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"CIRCLE_WIDTH": 2.0
}
const BUTTON_SIZE = Vector2(100, 40)
const ANIMATION_DURATION = 0.3
const BUTTON_GAP = 0.1  # Gap between buttons in radians

var is_open := false
var containers: Array[Control] = []  # Store containers
var buttons: Array[Button] = []      # Store actual buttons

var selected_position := Vector2.ZERO  # Position of selected entity
var selection_radius := 12.0  # Default radius, can be overridden

var tracked_ant: Ant = null
var tracked_colony: Colony = null

func _ready() -> void:
	modulate.a = 0
	scale = Vector2.ZERO

func _process(delta: float) -> void:
	# Update position if tracking something
	if tracked_ant and is_instance_valid(tracked_ant):
		selected_position = tracked_ant.global_position
		position = selected_position
	elif tracked_colony and is_instance_valid(tracked_colony):
		selected_position = tracked_colony.global_position
		position = selected_position
	queue_redraw()

func add_button(text: String, style_normal: StyleBox, style_hover: StyleBox) -> Button:
	var container = Control.new()
	container.custom_minimum_size = Vector2(BUTTON_ARC_WIDTH, BUTTON_ARC_HEIGHT)
	add_child(container)
	
	var button = Button.new()
	button.custom_minimum_size = container.custom_minimum_size
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.pivot_offset = Vector2(BUTTON_ARC_WIDTH/2, BUTTON_ARC_HEIGHT/2)
	button.position = Vector2(-BUTTON_ARC_WIDTH/2, -BUTTON_ARC_HEIGHT/2)
	container.add_child(button)
	
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = button.custom_minimum_size
	button.add_child(label)
	
	containers.append(container)
	buttons.append(button)
	return button


func show_at(pos: Vector2, circle_radius: float = 12.0) -> void:
	selected_position = pos
	selection_radius = circle_radius
	position = pos
	show()
	_animate_open()

func _draw() -> void:
	if selection_radius > 0:
		draw_arc(
			selected_position - global_position,
			selection_radius,
			0,
			TAU,
			32,
			SELECTION_STYLE.CIRCLE_COLOR,
			SELECTION_STYLE.CIRCLE_WIDTH
		)


func _animate_open() -> void:
	if is_open:
		return
	
	is_open = true
	
	var num_buttons = containers.size()
	var angle_per_button = (TAU - (BUTTON_GAP * num_buttons)) / num_buttons
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION)
	
	for i in range(num_buttons):
		var container = containers[i]
		var button = buttons[i]
		
		# Calculate position along arc
		var angle = -PI/2 + i * (angle_per_button + BUTTON_GAP)
		var target_pos = Vector2(cos(angle), sin(angle)) * RADIUS
		
		# Position container
		tween.tween_property(container, "position", target_pos, ANIMATION_DURATION)
		
		# Rotate container to follow arc but keep text upright
		var target_rotation = angle + PI/2
		tween.tween_property(container, "rotation", target_rotation, ANIMATION_DURATION)
		tween.tween_property(button.get_child(0), "rotation", -target_rotation, ANIMATION_DURATION)



func close() -> void:
	if is_open:
		_animate_close()


func _animate_close() -> void:
	if not is_open:
		return
	
	is_open = false
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ZERO, ANIMATION_DURATION)
	
	for i in range(containers.size()):
		var container = containers[i]
		var button = buttons[i]
		tween.tween_property(container, "position", Vector2.ZERO, ANIMATION_DURATION)
		tween.tween_property(container, "rotation", 0.0, ANIMATION_DURATION)
		tween.tween_property(button.get_child(0), "rotation", 0.0, ANIMATION_DURATION)
	
	tween.tween_callback(queue_free)
