class_name BaseContextMenu
extends Control

#region Constants
const OUTER_RADIUS: float = 90.0
const INNER_RADIUS: float = 60.0
const BUTTON_WIDTH: float = 80.0
const BUTTON_HEIGHT: float = 30.0
const LABEL_OFFSET: float = 15.0
const ICON_SIZE: Vector2 = Vector2(16, 16)
const ICON_OFFSET: Vector2 = Vector2(0, -5)

## Selection circle styling
const SELECTION_STYLE: Dictionary = {
	"CIRCLE_COLOR": Color(Color.WHITE, 0.5),
	"CIRCLE_WIDTH": 2.0
}

## Animation constants
const ANIMATION_DURATION: float = 0.3
#endregion

#region Properties
var is_open: bool = false
var containers: Array[Control] = []
var buttons: Array[Button] = []

@onready var screen_position: Vector2:
	get: return _screen_position

@onready var world_position: Vector2:
	get: return camera.ui_to_global(_screen_position)

var _screen_position: Vector2
var _selection_radius: float = 12.0
var tracked_ant: Ant = null
var tracked_colony: Colony = null
var camera: Camera2D
#endregion

func _ready() -> void:
	modulate.a = 0
	scale = Vector2.ZERO

func setup(p_camera: Camera2D) -> void:
	camera = p_camera

func _process(_delta: float) -> void:
	if tracked_ant and is_instance_valid(tracked_ant):
		_screen_position = camera.global_to_ui(tracked_ant.global_position)
	elif tracked_colony and is_instance_valid(tracked_colony):
		_screen_position = camera.global_to_ui(tracked_colony.global_position)

	position = screen_position
	queue_redraw()

func add_button(
		text: String,
		action_type: ContextMenuStyles.ActionType = ContextMenuStyles.ActionType.DEFAULT,
		icon: Texture2D = null
	) -> Button:

	# Create container for button and label
	var container := Control.new()
	container.custom_minimum_size = Vector2(OUTER_RADIUS * 2, OUTER_RADIUS * 2)
	add_child(container)

	# Create the arc button centered in the container
	var button := ArcButton.new()
	button.custom_minimum_size = container.custom_minimum_size
	container.add_child(button)

	# Add icon if provided
	if icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = ICON_SIZE
		icon_rect.size = ICON_SIZE
		icon_rect.position = Vector2(
			OUTER_RADIUS - ICON_SIZE.x/2,
			OUTER_RADIUS - ICON_SIZE.y/2
		) + ICON_OFFSET
		button.add_child(icon_rect)

	# Create label with correct positioning relative to its segment
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	containers.append(container)
	buttons.append(button)

	var colors = ContextMenuStyles.ACTION_COLORS[action_type]
	button.set_colors(colors.normal, colors.hover)

	return button

func arrange_buttons() -> void:
	var button_count := buttons.size()

	for i in range(button_count):
		var button := buttons[i] as ArcButton
		if not button:
			continue

		# Angle calculations
		var angle_step = TAU / button_count
		var start_angle = i * angle_step - PI / 2
		var end_angle = start_angle + angle_step
		var mid_angle = (start_angle + end_angle) / 2

		# Set button shape
		button.set_arc_shape(
			Vector2(OUTER_RADIUS, OUTER_RADIUS),
			OUTER_RADIUS,
			INNER_RADIUS,
			start_angle,
			end_angle
		)

		# Position label
		var label = containers[i].get_node_or_null("Label") as Label
		if label:
			var offset = Vector2(cos(mid_angle), sin(mid_angle)) * (OUTER_RADIUS + LABEL_OFFSET)
			label.position = Vector2(OUTER_RADIUS, OUTER_RADIUS) + offset - label.size / 2

func _animate_open() -> void:
	if is_open:
		return

	is_open = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, ANIMATION_DURATION)

	arrange_buttons()

func _animate_close() -> void:
	if not is_open:
		return

	is_open = false

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)
	tween.tween_property(self, "scale", Vector2.ZERO, ANIMATION_DURATION)
	tween.tween_callback(queue_free)

func close() -> void:
	if is_open:
		_animate_close()

func show_at(pos: Vector2, circle_radius: float = 12.0) -> void:
	_screen_position = pos
	_selection_radius = circle_radius
	position = pos
	show()
	_animate_open()

func _draw() -> void:
	if _selection_radius > 0 and camera:
		var scaled_radius := _selection_radius * camera.zoom.x
		draw_arc(
			Vector2.ZERO,
			scaled_radius,
			0,
			TAU,
			32,
			SELECTION_STYLE.CIRCLE_COLOR,
			SELECTION_STYLE.CIRCLE_WIDTH * camera.zoom.x
		)
