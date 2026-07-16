class_name BBNode
extends GraphNode
## Base for all builder nodes. Subclasses override _build(), input_count(),
## input_type(), output_type(), get_params()/set_params(), on_inputs()/on_value().
##
## Styling: every node gets a rounded panel and a per-type colored titlebar
## (see TITLE_COLORS). Port colors are updated live from evaluated values, so
## since GraphEdit draws wires as a gradient between the two port colors,
## bool wires literally glow green when TRUE and red when false.

signal params_changed
signal copy_debug_requested(node: BBNode)
signal node_context_requested(node: BBNode, at_screen_pos: Vector2)

const TYPE_FLOAT := 0
const TYPE_BOOL := 1

const COL_FLOAT := Color(0.38, 0.72, 1.0)
const COL_BOOL := Color(1.0, 0.66, 0.28)
const COL_TRUE := Color(0.4, 0.9, 0.5)
const COL_FALSE := Color(0.95, 0.4, 0.4)
const COL_NULL := Color(0.6, 0.6, 0.6)

# Swap these if the glyphs render as boxes in your font setup.
const GLYPH_COPY := "⧉"
const GLYPH_EXPAND := "+"
const GLYPH_COLLAPSE := "−"
const GLYPH_UNPACK := "⤢"

## Titlebar tint per node type — the main "prettier" hook.
const TITLE_COLORS := {
	"world_value": Color(0.15, 0.30, 0.46),
	"ant_value":   Color(0.36, 0.20, 0.34),  # used by BBWorldValueNode when group == "ant"
	"constant":    Color(0.24, 0.27, 0.34),
	"compare":     Color(0.12, 0.36, 0.37),
	"math":        Color(0.28, 0.24, 0.44),
	"and":         Color(0.33, 0.23, 0.42),
	"or":          Color(0.33, 0.23, 0.42),
	"not":         Color(0.33, 0.23, 0.42),
	"timer":       Color(0.44, 0.30, 0.10),
	"behavior":    Color(0.49, 0.34, 0.09),
	"condition":   Color(0.15, 0.38, 0.22),
}

var bb_type := ""
var last_value = null
var value_label: Label
## Persistent per-node state for stateful evaluation (used by ⏱ timer nodes).
var eval_state := {}

var _base_panel: StyleBox
var _base_titlebar: StyleBox


func _ready() -> void:
	_build()
	_add_title_buttons()
	_apply_style()


func _build() -> void:
	pass


func input_count() -> int:
	return 0


func input_type(_port: int) -> int:
	return TYPE_BOOL


## -1 = no output, otherwise TYPE_FLOAT / TYPE_BOOL. All nodes have <= 1 output.
func output_type() -> int:
	return -1


func get_params() -> Dictionary:
	return {}


func set_params(_p: Dictionary) -> void:
	pass


# ------------------------------------------------------------------ styling

func _titlebar_color() -> Color:
	return TITLE_COLORS.get(bb_type, Color(0.2, 0.22, 0.28))


func _apply_style() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.115, 0.125, 0.16, 0.985)
	panel.corner_radius_bottom_left = 9
	panel.corner_radius_bottom_right = 9
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 10

	var tbar := StyleBoxFlat.new()
	tbar.bg_color = _titlebar_color()
	tbar.corner_radius_top_left = 9
	tbar.corner_radius_top_right = 9
	tbar.content_margin_left = 12
	tbar.content_margin_right = 6
	tbar.content_margin_top = 5
	tbar.content_margin_bottom = 5

	add_theme_stylebox_override("panel", panel)
	add_theme_stylebox_override("titlebar", tbar)
	_base_panel = panel
	_base_titlebar = tbar


# ------------------------------------------------------- live value plumbing

## Called every evaluation pass, before on_value.
## values[i] is the evaluated input (or null); connected[i] is wire presence.
## Base implementation colors each input port from the value flowing into it,
## so the wire gradient shows green/red for bools. Subclasses that override
## this should call super.on_inputs(values, connected).
func on_inputs(values: Array, connected: Array) -> void:
	for p in input_count():
		if p >= get_input_port_count():
			break  # slots not fully built yet
		var slot := get_input_port_slot(p)
		if slot < 0:
			continue
		var is_conn: bool = p < connected.size() and connected[p]
		var v = values[p] if p < values.size() else null
		var col: Color = wire_color(v, input_type(p)) if is_conn \
			else (COL_FLOAT if input_type(p) == TYPE_FLOAT else COL_BOOL)
		set_slot_color_left(slot, col)


func on_value(v) -> void:
	last_value = v
	if value_label:
		value_label.text = "= %s" % fmt(v)
		value_label.add_theme_color_override("font_color", val_color(v))
	_update_outline(v)
	_color_output_port(v)


func _color_output_port(v) -> void:
	if output_type() < 0 or get_output_port_count() == 0:
		return
	var slot := get_output_port_slot(0)
	if slot >= 0:
		set_slot_color_right(slot, wire_color(v, output_type()))


## Color a value takes when travelling down a wire.
static func wire_color(v, port_type: int) -> Color:
	if v is bool:
		return COL_TRUE if v else COL_FALSE
	if v == null:
		return COL_NULL
	return COL_FLOAT if port_type == TYPE_FLOAT else COL_BOOL


## Green outline when the node's value is TRUE, red when false; none otherwise.
func _update_outline(v) -> void:
	if not (v is bool):
		remove_theme_stylebox_override("panel")
		remove_theme_stylebox_override("titlebar")
		if _base_panel:
			add_theme_stylebox_override("panel", _base_panel)
			add_theme_stylebox_override("titlebar", _base_titlebar)
		return
	if _base_panel == null:
		_base_panel = get_theme_stylebox("panel")
		_base_titlebar = get_theme_stylebox("titlebar")
	var col: Color = COL_TRUE if v else COL_FALSE
	var panel := _base_panel.duplicate()
	if panel is StyleBoxFlat:
		panel.border_width_left = 3
		panel.border_width_right = 3
		panel.border_width_bottom = 3
		panel.border_width_top = 0
		panel.border_color = col
		add_theme_stylebox_override("panel", panel)
	var tbar := _base_titlebar.duplicate()
	if tbar is StyleBoxFlat:
		tbar.border_width_left = 3
		tbar.border_width_right = 3
		tbar.border_width_top = 3
		tbar.border_width_bottom = 0
		tbar.border_color = col
		add_theme_stylebox_override("titlebar", tbar)


static func fmt(v) -> String:
	if v == null:
		return "—"
	if v is bool:
		return "TRUE" if v else "false"
	if v is float:
		return "%.2f" % v
	return str(v)


static func val_color(v) -> Color:
	if v == null:
		return COL_NULL
	if v is bool:
		return COL_TRUE if v else COL_FALSE
	return COL_FLOAT


func _make_value_footer() -> void:
	value_label = Label.new()
	value_label.text = "= —"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", COL_NULL)
	add_child(value_label)


func _add_title_buttons() -> void:
	var hb := get_titlebar_hbox()
	var copy_btn := Button.new()
	copy_btn.text = GLYPH_COPY
	copy_btn.flat = true
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.tooltip_text = "Copy this node's debug JSON (value + full input tree)"
	copy_btn.pressed.connect(func(): copy_debug_requested.emit(self))
	hb.add_child(copy_btn)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		node_context_requested.emit(self, get_global_mouse_position())
