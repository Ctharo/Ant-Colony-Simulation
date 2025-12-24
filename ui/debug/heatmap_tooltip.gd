class_name HeatmapTooltip
extends Control
## Displays pheromone values for heat cells around the mouse cursor
## Similar to RimWorld's beauty overlay visualization

#region Constants
const STYLE = {
	"TOOLTIP_RADIUS": 3,  # Number of cells around cursor to show
	"FONT_SIZE": 10,
	"BG_COLOR": Color(0, 0, 0, 0.6),
	"TEXT_COLOR": Color.WHITE,
	"CELL_SIZE": 50,  # Should match HeatmapManager.STYLE.CELL_SIZE
	"PADDING": Vector2(4, 2),
	"MIN_HEAT_TO_SHOW": 0.01  # Don't show values below this threshold
}
#endregion

#region Member Variables
var camera: Camera2D
var heatmap_manager: Node2D
var _font: Font
var _is_enabled: bool = false
#endregion

func _ready() -> void:
	# Get font from theme or use default
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

func setup(p_camera: Camera2D, p_heatmap_manager: Node2D) -> void:
	camera = p_camera
	heatmap_manager = p_heatmap_manager

func set_enabled(enabled: bool) -> void:
	_is_enabled = enabled
	visible = enabled
	queue_redraw()

func _process(_delta: float) -> void:
	if _is_enabled:
		queue_redraw()

func _draw() -> void:
	if not _is_enabled or not camera or not heatmap_manager:
		return

	# Get mouse position in world coordinates
	var mouse_screen_pos := get_global_mouse_position()
	var mouse_world_pos: Vector2 = camera.ui_to_global(mouse_screen_pos)

	# Get center cell
	var center_cell := _world_to_cell(mouse_world_pos)

	# Collect all heat values for cells in radius
	var cell_data: Array[Dictionary] = []

	for dx in range(-STYLE.TOOLTIP_RADIUS, STYLE.TOOLTIP_RADIUS + 1):
		for dy in range(-STYLE.TOOLTIP_RADIUS, STYLE.TOOLTIP_RADIUS + 1):
			var cell_pos := center_cell + Vector2i(dx, dy)
			var cell_world_pos := _cell_to_world(cell_pos)
			var cell_screen_pos: Vector2 = camera.global_to_ui(cell_world_pos + Vector2.ONE * STYLE.CELL_SIZE * 0.5)

			# Get heat values for each pheromone type
			var heat_values := _get_heat_values_at_cell(cell_pos)

			if not heat_values.is_empty():
				cell_data.append({
					"screen_pos": cell_screen_pos,
					"heat_values": heat_values
				})

	# Draw heat values for each cell
	for data in cell_data:
		_draw_cell_tooltip(data.screen_pos, data.heat_values)

func _get_heat_values_at_cell(cell_pos: Vector2i) -> Dictionary:
	var heat_values := {}

	# Access heatmap data through the manager
	if not heatmap_manager.has_method("get_all_heat_at_cell"):
		# Fallback: try to access _heatmaps directly if method doesn't exist
		if "_heatmaps" in heatmap_manager:
			var heatmaps: Dictionary = heatmap_manager._heatmaps
			var debug_settings: Dictionary = heatmap_manager._debug_settings if "_debug_settings" in heatmap_manager else {}

			for heat_type in heatmaps:
				var heatmap = heatmaps[heat_type]
				var chunk_pos := _world_to_chunk(cell_pos)
				var local_pos := _world_to_local_cell(cell_pos)

				if heatmap.chunks.has(chunk_pos):
					var chunk = heatmap.chunks[chunk_pos]
					if chunk.cells.has(local_pos):
						var cell = chunk.cells[local_pos]
						var visible_heat := _calculate_visible_heat(cell, debug_settings)
						if visible_heat >= STYLE.MIN_HEAT_TO_SHOW:
							heat_values[heat_type] = visible_heat
		return heat_values

	return heatmap_manager.get_all_heat_at_cell(cell_pos)

func _calculate_visible_heat(cell_data: Dictionary, debug_settings: Dictionary) -> float:
	var visible_heat: float = 0.0
	for source_id in cell_data.sources:
		var entity: Node2D = instance_from_id(source_id)
		if not is_instance_valid(entity):
			continue

		if entity is Ant:
			var colony: Node2D = entity.colony
			if colony and (debug_settings.get(source_id, false) or debug_settings.get(colony.get_instance_id(), false)):
				visible_heat += cell_data.sources[source_id]
	return visible_heat

func _draw_cell_tooltip(screen_pos: Vector2, heat_values: Dictionary) -> void:
	if heat_values.is_empty():
		return

	# Build text lines
	var lines: Array[String] = []
	for pheromone_type in heat_values:
		var value: float = heat_values[pheromone_type]
		var abbreviation := _get_pheromone_abbreviation(pheromone_type)
		lines.append("%s:%.1f" % [abbreviation, value])

	var text := "\n".join(lines)

	# Calculate text size
	var text_size := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, STYLE.FONT_SIZE)
	var bg_size := text_size + STYLE.PADDING * 2

	# Draw background
	var bg_rect := Rect2(
		screen_pos - bg_size / 2,
		bg_size
	)
	draw_rect(bg_rect, STYLE.BG_COLOR)

	# Draw text
	var text_pos := screen_pos - text_size / 2 + Vector2(0, _font.get_ascent(STYLE.FONT_SIZE))
	draw_multiline_string(
		_font,
		text_pos,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		STYLE.FONT_SIZE,
		-1,
		STYLE.TEXT_COLOR
	)

func _get_pheromone_abbreviation(pheromone_type: String) -> String:
	match pheromone_type.to_lower():
		"home":
			return "H"
		"food":
			return "F"
		_:
			return pheromone_type.substr(0, 1).to_upper()

#region Coordinate Conversion (mirrors HeatmapManager)
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / STYLE.CELL_SIZE),
		floori(world_pos.y / STYLE.CELL_SIZE)
	)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * STYLE.CELL_SIZE

func _world_to_chunk(world_cell: Vector2i) -> Vector2i:
	const CHUNK_SIZE = 16  # Should match HeatmapManager
	return Vector2i(
		floori(float(world_cell.x) / CHUNK_SIZE),
		floori(float(world_cell.y) / CHUNK_SIZE)
	)

func _world_to_local_cell(world_cell: Vector2i) -> Vector2i:
	const CHUNK_SIZE = 16
	return Vector2i(
		posmod(world_cell.x, CHUNK_SIZE),
		posmod(world_cell.y, CHUNK_SIZE)
	)
#endregion
