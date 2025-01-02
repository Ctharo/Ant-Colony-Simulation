class_name ArcButton
extends Button

#region Properties
## Array of points defining the arc shape
var points: PackedVector2Array

## Normal state color of the arc
var normal_color: Color

## Hover state color of the arc
var hover_color: Color

## Current hover state
var is_hovered: bool = false

## Arc center point
var center: Vector2

## Arc radius
var radius: float

## Starting angle in radians
var start_angle: float

## End angle in radians
var end_angle: float
#endregion

func _ready() -> void:
	# Make button background transparent
	flat = true
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Remove default button styling
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _draw() -> void:
	if points.is_empty():
		return

	# Draw the filled arc
	var color: Color = hover_color if is_hovered else normal_color
	draw_colored_polygon(points, color)

	# Draw the arc border with a subtle white line
	var border_color := Color(1, 1, 1, 0.3)
	draw_multiline(points, border_color, 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var in_arc := is_point_in_arc(event.position)
		if is_hovered != in_arc:
			is_hovered = in_arc
			queue_redraw()

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and is_point_in_arc(event.position):
			pressed.emit()
			get_viewport().set_input_as_handled()

## Checks if a point is within the arc using polar coordinates
func is_point_in_arc(point: Vector2) -> bool:
	if points.is_empty():
		return false

	# Use a simple point-in-polygon check
	var winding_number := 0
	for i in range(points.size()):
		var a = points[i]
		var b = points[(i + 1) % points.size()]

		# Check if the point is within the edge bounds
		if ((a.y > point.y) != (b.y > point.y)) and \
			(point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x):
			winding_number += 1

	# If winding number is odd, the point is inside
	return winding_number % 2 == 1


## Sets up the arc's points based on the center point and radii
func set_points(p_points: PackedVector2Array) -> void:
	points = p_points
	queue_redraw()

## Updates the arc's geometry
func set_arc_shape(
		p_center: Vector2,
		p_outer_radius: float,
		p_inner_radius: float,
		p_start_angle: float,
		p_end_angle: float,
		segments: int = 32
	) -> void:

	center = p_center
	radius = p_outer_radius
	start_angle = p_start_angle
	end_angle = p_end_angle
	points = PackedVector2Array()

	var angle_step = (end_angle - start_angle) / segments

	# Outer arc points (clockwise)
	for i in range(segments + 1):
		var angle = start_angle + angle_step * i
		points.append(center + Vector2(cos(angle), sin(angle)) * p_outer_radius)

	# Inner arc points (counter-clockwise)
	for i in range(segments, -1, -1):
		var angle = start_angle + angle_step * i
		points.append(center + Vector2(cos(angle), sin(angle)) * p_inner_radius)

	queue_redraw()


## Updates the arc's colors
func set_colors(p_normal: Color, p_hover: Color) -> void:
	normal_color = p_normal
	hover_color = p_hover
	queue_redraw()
