extends Node2D

#region Constants
const STYLE = {
	"CELL_SIZE": 50,
	"CHUNK_SIZE": 16,
	"MAX_HEAT": 100.0
}

#region Member Variables
var _heatmaps: Dictionary = {}  # name -> {config: Pheromone, chunks: Dictionary}
var _entities: Dictionary = {}  # entity_id -> {type: String, colony_id: int}
var _debug_settings: Dictionary = {}  # entity_id -> bool
var update_thread: Thread
var update_lock: Mutex
var camera: Camera2D
var logger: Logger
var _is_quitting: bool = false
var _last_decay_time: int = 0
var update_interval: float = 1.0
#endregion

func _init() -> void:
	logger = Logger.new("heatmap_manager", DebugLogger.Category.MOVEMENT)
	update_lock = Mutex.new()
	top_level = true
	_last_decay_time = Time.get_ticks_msec()

func _ready() -> void:
	_start_update_thread()

## Create a new heatmap type from pheromone configuration
func create_heatmap_type(pheromone: Pheromone) -> void:
	var heatmap_name := pheromone.name.to_lower()
	if not _heatmaps.has(heatmap_name):
		_heatmaps[heatmap_name] = {
			"config": pheromone,
			"chunks": {}  # chunk_pos -> {cells: Dictionary, last_update: int}
		}

#region Entity Management
## Register entity with the heatmap system
func register_entity(entity: Node2D) -> void:
	var entity_id := entity.get_instance_id()
	if not _entities.has(entity_id):
		_entities[entity_id] = {
			"type": "ant" if entity is Ant else "colony",
			"colony_id": entity.colony.get_instance_id() if entity is Ant else entity_id
		}
		_debug_settings[entity_id] = false
		logger.debug("Registered entity %s" % entity.name)

## Remove entity from the heatmap system
func unregister_entity(entity: Node2D) -> void:
	var entity_id := entity.get_instance_id()
	
	update_lock.lock()
	_entities.erase(entity_id)
	_debug_settings.erase(entity_id)
	
	# Remove entity from all heatmaps
	for heatmap in _heatmaps.values():
		for chunk in heatmap.chunks.values():
			for cell in chunk.cells.values():
				cell.sources = cell.sources.filter(
					func(id: int) -> bool: return id != entity_id
				)
	update_lock.unlock()
	
	logger.debug("Unregistered entity %s" % entity.name)

func debug_draw(entity: Node2D, enabled: bool) -> void:
	_debug_settings[entity.get_instance_id()] = enabled
	queue_redraw()
#endregion

#region Heat Management
## Update heat for an entity
func update_entity_heat(
	entity: Node2D,
	delta: float,
	heat_type: String,
	factor: float = 1.0
) -> void:
	if not _heatmaps.has(heat_type):
		return

	var entity_id := entity.get_instance_id()
	var world_pos := entity.global_position
	var world_cell := HeatmapUtils.world_to_grid(world_pos, STYLE.CELL_SIZE)
	var base_heat: float = _heatmaps[heat_type].config.generating_rate * delta * factor

	update_lock.lock()
	_update_cell_heat(entity_id, world_cell, base_heat, heat_type)
	update_lock.unlock()

## Update heat for cells around entity
func _update_cell_heat(
	entity_id: int,
	center_cell: Vector2i,
	base_heat: float,
	heat_type: String
) -> void:
	var heatmap: HeatmapInstance = _heatmaps[heat_type]
	var cells := HeatmapUtils.get_cells_in_radius(
		center_cell,
		heatmap.config.heat_radius
	)

	for cell in cells:
		var distance := center_cell.distance_to(cell)
		var heat := HeatmapUtils.calculate_cell_heat(
			base_heat,
			distance,
			STYLE.MAX_HEAT
		)
		_add_heat_to_cell(entity_id, cell, heat, heat_type)

## Add heat to a specific cell
func _add_heat_to_cell(
	entity_id: int,
	world_cell: Vector2i,
	amount: float,
	heat_type: String
) -> void:
	var coords := HeatmapUtils.world_to_chunk_coords(world_cell, STYLE.CHUNK_SIZE)
	var chunk_pos := coords.chunk
	var local_pos := coords.local
	
	# Ensure chunk exists
	if not _heatmaps[heat_type].chunks.has(chunk_pos):
		_heatmaps[heat_type].chunks[chunk_pos] = {
			"cells": {},
			"last_update": Time.get_ticks_msec()
		}
	
	var chunk := _heatmaps[heat_type].chunks[chunk_pos]
	
	# Ensure cell exists
	if not chunk.cells.has(local_pos):
		chunk.cells[local_pos] = {
			"sources": {},
			"heat": 0.0
		}
	
	var cell := chunk.cells[local_pos]
	cell.sources = HeatmapUtils.add_heat_source(
		cell.sources,
		entity_id,
		amount,
		STYLE.MAX_HEAT
	)
	cell.heat = HeatmapUtils.calculate_total_heat(cell.sources.values())
#endregion

#region Thread Management
func _start_update_thread() -> void:
	update_thread = Thread.new()
	update_thread.start(_update_heatmap_thread)

func _update_heatmap_thread() -> void:
	while not _is_quitting:
		var current_time := Time.get_ticks_msec()
		var time_since_decay := (current_time - _last_decay_time) / 1000.0

		if time_since_decay >= update_interval:
			if update_lock.try_lock():
				_process_decay(time_since_decay)
				update_lock.unlock()
				_last_decay_time = current_time

		call_thread_safe("queue_redraw")
		OS.delay_msec(int(update_interval * 100))

func _process_decay(delta: float) -> void:
	for heatmap_data in _heatmaps.values():
		var chunks_to_remove := []
		
		for chunk_pos in heatmap_data.chunks:
			var chunk := heatmap_data.chunks[chunk_pos]
			var cells_to_remove := []
			
			for local_pos in chunk.cells:
				var cell := chunk.cells[local_pos]
				cell.sources = HeatmapUtils.update_heat_sources(
					cell.sources,
					heatmap_data.config.decay_rate,
					delta
				)
				
				if cell.sources.is_empty():
					cells_to_remove.append(local_pos)
				else:
					cell.heat = HeatmapUtils.calculate_total_heat(
						cell.sources.values()
					)
			
			for pos in cells_to_remove:
				chunk.cells.erase(pos)
				
			if chunk.cells.is_empty():
				chunks_to_remove.append(chunk_pos)
		
		for pos in chunks_to_remove:
			heatmap_data.chunks.erase(pos)

func _cleanup_thread() -> void:
	if update_thread and update_thread.is_started():
		_is_quitting = true
		update_thread.wait_to_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_thread()
#endregion

#region Heat Queries
## Get heat value at entity position
func get_heat_at_position(entity: Node2D, heat_type: String) -> float:
	if not _heatmaps.has(heat_type):
		return 0.0

	var entity_data := _entities[entity.get_instance_id()]
	var world_cell := HeatmapUtils.world_to_grid(
		entity.global_position,
		STYLE.CELL_SIZE
	)

	var result := 0.0
	update_lock.lock()
	result = _get_cell_heat(world_cell, heat_type, entity_data.colony_id)
	update_lock.unlock()

	return result

## Get heat value for a specific cell
func _get_cell_heat(
	world_cell: Vector2i,
	heat_type: String,
	colony_id: int
) -> float:
	var coords := HeatmapUtils.world_to_chunk_coords(world_cell, STYLE.CHUNK_SIZE)
	var chunk_pos := coords.chunk
	var local_pos := coords.local
	
	if not _heatmaps[heat_type].chunks.has(chunk_pos):
		return 0.0
		
	var chunk := _heatmaps[heat_type].chunks[chunk_pos]
	if not chunk.cells.has(local_pos):
		return 0.0
		
	var cell := chunk.cells[local_pos]
	return HeatmapUtils.get_colony_heat(cell.sources, _entities, colony_id)
#endregion

#region Drawing
func _draw() -> void:
	if not camera:
		return

	update_lock.lock()
	for heat_type in _heatmaps:
		_draw_heatmap(_heatmaps[heat_type])
	update_lock.unlock()

func _draw_heatmap(heatmap_data: Dictionary) -> void:
	for chunk_pos in heatmap_data.chunks:
		var chunk: HeatChunk = heatmap_data.chunks[chunk_pos]
		for local_pos in chunk.cells:
			var cell := chunk.cells[local_pos]
			var world_cell := HeatmapUtils.chunk_to_world_coords(
				chunk_pos,
				local_pos,
				STYLE.CHUNK_SIZE
			)
			
			var visible_heat := HeatmapUtils.filter_visible_sources(
				cell.sources,
				_debug_settings,
				_entities
			)
			
			if visible_heat <= 0:
				continue
				
			var color := HeatmapUtils.calculate_heat_color(
				heatmap_data.config.start_color,
				heatmap_data.config.end_color,
				visible_heat,
				STYLE.MAX_HEAT
			)
			
			var world_pos := HeatmapUtils.grid_to_world(world_cell, STYLE.CELL_SIZE)
			draw_rect(
				Rect2(world_pos, Vector2.ONE * STYLE.CELL_SIZE),
				color
			)
#endregion
