class_name InfluenceRenderer
extends Node2D

signal influence_visibility_changed(enabled: bool)

const STYLE = {
	"INFLUENCE_SETTINGS": {
		"OVERALL_COLOR": Color.WHITE,
		"ARROW_LENGTH": 50.0,
		"ARROW_WIDTH": 2.0,
		"ARROW_HEAD_SIZE": 8.0,
		"OVERALL_SCALE": 1.5,
		"IGNORE_TYPES": ["random"],
		"MIN_WEIGHT_THRESHOLD": 0.01
	}
}
var camera: Camera2D
var _current_ant: Ant
var _enabled: bool = false


func _ready() -> void:
	top_level = true
	camera = get_tree().get_first_node_in_group("camera")

func _process(_delta: float) -> void:
	queue_redraw()

func set_ant(ant: Ant) -> void:
	_current_ant = ant
	queue_redraw()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	influence_visibility_changed.emit(enabled)
	queue_redraw()

func _draw() -> void:
	if not (_current_ant and _current_ant.is_inside_tree() and _enabled):
		return

	draw_influences()

## Check if an influence should be ignored in visualization
func _should_ignore_influence(influence: Influence) -> bool:
	var influence_type = influence.name.to_snake_case().trim_suffix("_influence")
	return influence_type in STYLE.INFLUENCE_SETTINGS.IGNORE_TYPES

func draw_influences() -> void:
	var ant_pos = camera.global_to_ui(_current_ant.global_position)
	var influence_manager = _current_ant.influence_manager
	var valid_influences = _current_ant.influence_manager.current_profile.influences
	var total_weight = 0.0
	var influence_data = []

	for influence in valid_influences:
		var weight = influence_manager.eval_system.get_value(influence.weight)
		var direction = influence_manager.eval_system.get_value(influence.direction).normalized()

		if weight:
			total_weight += weight

		influence_data.append({
			"raw_weight": weight,
			"direction": direction,
			"color": influence.color,
			"name": influence.name
		})

	if total_weight < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
		return

	var total_direction = Vector2.ZERO

	for data in influence_data:
		data.normalized_weight = data.raw_weight / total_weight if total_weight > 0 else 0.0

		if data.normalized_weight < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue

		data.weighted_direction = data.direction * data.normalized_weight
		total_direction += data.weighted_direction

	influence_data.sort_custom(
		func(a, b): return a.normalized_weight < b.normalized_weight
	)

	var overall_length = STYLE.INFLUENCE_SETTINGS.ARROW_LENGTH * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
	draw_arrow(
		ant_pos,
		ant_pos + total_direction.normalized() * overall_length,
		STYLE.INFLUENCE_SETTINGS.OVERALL_COLOR,
		STYLE.INFLUENCE_SETTINGS.ARROW_WIDTH * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE,
		STYLE.INFLUENCE_SETTINGS.ARROW_HEAD_SIZE * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
	)

	for data in influence_data:
		if data.normalized_weight < STYLE.INFLUENCE_SETTINGS.MIN_WEIGHT_THRESHOLD:
			continue

		var arrow_length = STYLE.INFLUENCE_SETTINGS.ARROW_LENGTH * data.normalized_weight * STYLE.INFLUENCE_SETTINGS.OVERALL_SCALE
		var arrow_end = ant_pos + data.direction * arrow_length

		draw_arrow(
			ant_pos,
			arrow_end,
			data.color,
			STYLE.INFLUENCE_SETTINGS.ARROW_WIDTH,
			STYLE.INFLUENCE_SETTINGS.ARROW_HEAD_SIZE
		)

func draw_arrow(start: Vector2, end: Vector2, color: Color, width: float, head_size: float) -> void:
	draw_line(start, end, color, width)

	var direction = (end - start)
	var length = direction.length()
	if length <= head_size:
		return

	direction = direction.normalized()
	var right = direction.rotated(PI * 3/4) * head_size
	var left = direction.rotated(-PI * 3/4) * head_size

	var arrow_points = PackedVector2Array([
		end,
		end + right,
		end + left
	])

	draw_colored_polygon(arrow_points, color)
