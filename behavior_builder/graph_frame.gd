class_name BBGraphFrame
extends Control
## The "grassy space": a rounded green panel with a light-blue border that
## hugs every GraphNode in the paired GraphEdit (plus padding), sitting on a
## black backdrop. It is drawn BEHIND the GraphEdit — whose panel is made
## transparent so the grass shows through behind its connection wires and
## nodes — so the frame reads as the boundary of the space the nodes live in.
##
## The paired GraphEdit's built-in grid is disabled (transparent grid theme
## colors); this control redraws a subtle grid CLIPPED to the frame while the
## GraphEdit's show_grid toggle is on, so grid lines never bleed onto the
## black outside.
##
## Batch 1 (canvas restyle). The enter-node view (next) will pin each
## condition's OUTPUT terminal to this frame's right edge, so the frame rect
## computed here is the anchor that work reuses.

## Padding (screen px) between the node bounding box and the frame border.
const PADDING: float = 48.0
const GRASS_COLOR: Color = Color(0.208, 0.404, 0.235)
const BORDER_COLOR: Color = Color(0.482, 0.741, 0.949)
const BORDER_WIDTH: int = 4
const CORNER_RADIUS: int = 22
## Faint grid over the grass; alpha kept low so it never competes with nodes.
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.05)
const GRID_STEP: float = 20.0
## Below this on-screen spacing the grid is too dense to read — skip it.
const GRID_MIN_SCREEN_STEP: float = 7.0

## The GraphEdit whose nodes this frame hugs. Set by BBGraphPanel before the
## frame enters the tree.
var graph: GraphEdit = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# Cheap: one bounding-box pass + a few draw calls. Keeps the frame glued
	# to panning, zooming, and node moves without wiring per-node signals.
	# Can be made event-driven later if it ever shows up in a profile.
	queue_redraw()


func _draw() -> void:
	if graph == null:
		return
	var frame: Rect2 = _frame_rect()
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = GRASS_COLOR
	box.border_color = BORDER_COLOR
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	draw_style_box(box, frame)

	if graph.show_grid:
		_draw_grid(frame.grow(-float(BORDER_WIDTH)))


## Bounding box of every visible GraphNode (+ padding), in this control's
## local coordinates. GraphEdit places a child with graph-space
## position_offset P and size S at local `P * zoom - scroll_offset`, size
## `S * zoom` (the inverse of the screen→graph transform the panel uses).
func _frame_rect() -> Rect2:
	var has_any: bool = false
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	var zoom: float = graph.zoom
	var scroll: Vector2 = graph.scroll_offset
	for child: Node in graph.get_children():
		var node: GraphNode = child as GraphNode
		if node == null or node.is_queued_for_deletion() or not node.visible:
			continue
		var top_left: Vector2 = node.position_offset * zoom - scroll
		var bottom_right: Vector2 = top_left + node.size * zoom
		min_x = minf(min_x, top_left.x)
		min_y = minf(min_y, top_left.y)
		max_x = maxf(max_x, bottom_right.x)
		max_y = maxf(max_y, bottom_right.y)
		has_any = true
	if not has_any:
		return Rect2()
	return Rect2(
		min_x - PADDING, min_y - PADDING,
		(max_x - min_x) + PADDING * 2.0, (max_y - min_y) + PADDING * 2.0)


## Grid lines aligned to graph-space multiples of GRID_STEP, clipped to `rect`.
func _draw_grid(rect: Rect2) -> void:
	var zoom: float = graph.zoom
	var step: float = GRID_STEP * zoom
	if step < GRID_MIN_SCREEN_STEP:
		return
	var scroll: Vector2 = graph.scroll_offset
	var x: float = ceilf((rect.position.x + scroll.x) / step) * step - scroll.x
	while x <= rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), GRID_COLOR, 1.0)
		x += step
	var y: float = ceilf((rect.position.y + scroll.y) / step) * step - scroll.y
	while y <= rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), GRID_COLOR, 1.0)
		y += step
