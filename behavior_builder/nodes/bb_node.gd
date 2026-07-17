class_name BBNode
extends GraphNode
## Base for all builder nodes. Subclasses override _build(), input_count(),
## input_type(), output_type(), get_params()/set_params(), on_inputs()/on_value().
##
## VISUAL LANGUAGE — each channel means exactly ONE thing, so states can't
## be confused with each other:
##   • BORDER      → interaction only. Bright white border + glow = selected.
##                   Gold border = another reference of the selected ◈ condition.
##                   Values NEVER touch the border.
##   • BODY TINT   → live bool value: the panel washes softly green when TRUE,
##                   red when false. No tint for numbers / lists / unknown.
##   • VALUE PILL  → the footer chip always shows the exact value, colored.
##   • PORTS/WIRES → data type: float cyan, bool amber, list violet,
##                   entity teal. Bool wires recolor green/red live.

signal params_changed
signal copy_debug_requested(node: BBNode)
signal node_context_requested(node: BBNode, at_screen_pos: Vector2)

const TYPE_FLOAT: int = 0
const TYPE_BOOL: int = 1
const TYPE_LIST: int = 2    ## a list of sensed items (ants, food, ...)
const TYPE_ENTITY: int = 3  ## one item picked out of a list

const COL_FLOAT: Color = Color(0.38, 0.72, 1.0)
const COL_BOOL: Color = Color(1.0, 0.66, 0.28)
const COL_LIST: Color = Color(0.72, 0.52, 1.0)
const COL_ENTITY: Color = Color(0.36, 0.88, 0.82)
const COL_TRUE: Color = Color(0.4, 0.9, 0.5)
const COL_FALSE: Color = Color(0.95, 0.4, 0.4)
const COL_NULL: Color = Color(0.6, 0.6, 0.6)
## Selection border/glow — deliberately near-white so it can't be read as
## a TRUE (green) or false (red) indicator.
const COL_SELECTED: Color = Color(0.96, 0.98, 1.0)
## "Other references of the selected condition" border.
const COL_REFERENCE: Color = Color(1.0, 0.84, 0.32)

const BODY_COLOR: Color = Color(0.115, 0.125, 0.16, 0.985)
## How strongly a bool value washes the body / titlebar. Kept subtle so the
## selection border stays the loudest thing on screen.
const VALUE_TINT_BODY: float = 0.14
const VALUE_TINT_TITLEBAR: float = 0.24

# Swap these if the glyphs render as boxes in your font setup.
const GLYPH_COPY: String = "⧉"
const GLYPH_EXPAND: String = "+"
const GLYPH_COLLAPSE: String = "−"
const GLYPH_UNPACK: String = "⤢"

## Titlebar tint per node type — the main "prettier" hook.
const TITLE_COLORS: Dictionary = {
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
	# list pipeline
	"sense_list":  Color(0.30, 0.18, 0.44),
	"filter":      Color(0.26, 0.22, 0.40),
	"sort":        Color(0.22, 0.26, 0.40),
	"pick":        Color(0.14, 0.36, 0.34),
	"item_value":  Color(0.12, 0.32, 0.30),
	"list_count":  Color(0.24, 0.27, 0.34),
}

var bb_type: String = ""
var last_value: Variant = null
var value_label: Label
## Persistent per-node state for stateful evaluation (used by ⏱ timer nodes).
var eval_state: Dictionary = {}


func _ready() -> void:
	_build()
	_add_title_buttons()
	refresh_style()


func _build() -> void:
	pass


func input_count() -> int:
	return 0


func input_type(_port: int) -> int:
	return TYPE_BOOL


## -1 = no output, otherwise one of the TYPE_* consts. All nodes have <= 1 output.
func output_type() -> int:
	return -1


func get_params() -> Dictionary:
	return {}


func set_params(_p: Dictionary) -> void:
	pass


# ------------------------------------------------------------------ styling

func _titlebar_color() -> Color:
	return TITLE_COLORS.get(bb_type, Color(0.2, 0.22, 0.28))


## Rebuilds all four styleboxes (normal + selected) from the current value.
## Borders live ONLY on the *_selected variants (and on _style_extra hooks),
## so a green/red value can never be mistaken for selection or vice versa.
func refresh_style() -> void:
	var body_col: Color = BODY_COLOR
	var head_col: Color = _titlebar_color()
	if last_value is bool:
		var value_col: Color = COL_TRUE if bool(last_value) else COL_FALSE
		body_col = body_col.lerp(value_col, VALUE_TINT_BODY)
		body_col.a = BODY_COLOR.a
		head_col = head_col.lerp(value_col, VALUE_TINT_TITLEBAR)

	var panel: StyleBoxFlat = _make_panel(body_col)
	var tbar: StyleBoxFlat = _make_titlebar(head_col)
	_style_extra(panel, tbar)

	var panel_sel: StyleBoxFlat = panel.duplicate() as StyleBoxFlat
	var tbar_sel: StyleBoxFlat = tbar.duplicate() as StyleBoxFlat
	_apply_selection_border(panel_sel, tbar_sel)

	add_theme_stylebox_override("panel", panel)
	add_theme_stylebox_override("titlebar", tbar)
	add_theme_stylebox_override("panel_selected", panel_sel)
	add_theme_stylebox_override("titlebar_selected", tbar_sel)


func _make_panel(bg: Color) -> StyleBoxFlat:
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = bg
	panel.corner_radius_bottom_left = 9
	panel.corner_radius_bottom_right = 9
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 10
	return panel


func _make_titlebar(bg: Color) -> StyleBoxFlat:
	var tbar: StyleBoxFlat = StyleBoxFlat.new()
	tbar.bg_color = bg
	tbar.corner_radius_top_left = 9
	tbar.corner_radius_top_right = 9
	tbar.content_margin_left = 12
	tbar.content_margin_right = 6
	tbar.content_margin_top = 5
	tbar.content_margin_bottom = 5
	return tbar


## Hook for subclasses to decorate the UNSELECTED styleboxes (e.g. the gold
## reference border on ◈ condition nodes). Base does nothing.
func _style_extra(_panel: StyleBoxFlat, _tbar: StyleBoxFlat) -> void:
	pass


## Loud, unmistakable selection: thick near-white border + outer glow.
static func _apply_selection_border(panel: StyleBoxFlat, tbar: StyleBoxFlat) -> void:
	panel.border_width_left = 3
	panel.border_width_right = 3
	panel.border_width_bottom = 3
	panel.border_width_top = 0
	panel.border_color = COL_SELECTED
	panel.shadow_color = Color(COL_SELECTED.r, COL_SELECTED.g, COL_SELECTED.b, 0.35)
	panel.shadow_size = 7
	tbar.border_width_left = 3
	tbar.border_width_right = 3
	tbar.border_width_top = 3
	tbar.border_width_bottom = 0
	tbar.border_color = COL_SELECTED
	tbar.shadow_color = Color(COL_SELECTED.r, COL_SELECTED.g, COL_SELECTED.b, 0.35)
	tbar.shadow_size = 7


## Gold reference border (shared helper for subclasses' _style_extra).
static func apply_reference_border(panel: StyleBoxFlat, tbar: StyleBoxFlat) -> void:
	panel.border_width_left = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.border_width_top = 0
	panel.border_color = COL_REFERENCE
	tbar.border_width_left = 2
	tbar.border_width_right = 2
	tbar.border_width_top = 2
	tbar.border_width_bottom = 0
	tbar.border_color = COL_REFERENCE


# ------------------------------------------------------- live value plumbing

## Called every evaluation pass, before on_value.
## values[i] is the evaluated input (or null); connected[i] is wire presence.
## Base implementation colors each input port from the value flowing into it,
## so the wire gradient shows green/red for bools. Subclasses that override
## this should call super.on_inputs(values, connected).
func on_inputs(values: Array, connected: Array) -> void:
	for p: int in input_count():
		if p >= get_input_port_count():
			break  # slots not fully built yet
		var slot: int = get_input_port_slot(p)
		if slot < 0:
			continue
		var is_conn: bool = p < connected.size() and bool(connected[p])
		var v: Variant = values[p] if p < values.size() else null
		var col: Color = wire_color(v, input_type(p)) if is_conn else port_color(input_type(p))
		set_slot_color_left(slot, col)


func on_value(v: Variant) -> void:
	# Only rebuild styleboxes when the bool-tint state actually changes;
	# the value pill updates every pass.
	var restyle_needed: bool = _tint_key(last_value) != _tint_key(v)
	last_value = v
	if value_label:
		_update_value_pill(v)
	if restyle_needed:
		refresh_style()
	_color_output_port(v)


## Collapses a value to its visual tint bucket: -1 none, 0 false, 1 true.
static func _tint_key(v: Variant) -> int:
	if v is bool:
		return 1 if bool(v) else 0
	return -1


func _color_output_port(v: Variant) -> void:
	if output_type() < 0 or get_output_port_count() == 0:
		return
	var slot: int = get_output_port_slot(0)
	if slot >= 0:
		set_slot_color_right(slot, wire_color(v, output_type()))


## Color a value takes when travelling down a wire.
static func wire_color(v: Variant, port_type: int) -> Color:
	if v is bool:
		return COL_TRUE if bool(v) else COL_FALSE
	if v == null:
		return COL_NULL
	if v is Array:
		return COL_LIST
	if v is Dictionary:
		return COL_ENTITY
	return port_color(port_type)


## The resting (no-value) color of a port of the given type.
static func port_color(port_type: int) -> Color:
	match port_type:
		TYPE_FLOAT:
			return COL_FLOAT
		TYPE_BOOL:
			return COL_BOOL
		TYPE_LIST:
			return COL_LIST
		TYPE_ENTITY:
			return COL_ENTITY
	return COL_NULL


static func fmt(v: Variant) -> String:
	if v == null:
		return "—"
	if v is bool:
		return "TRUE" if bool(v) else "false"
	if v is float:
		return "%.2f" % float(v)
	if v is Array:
		var arr: Array = v
		return "%d item%s" % [arr.size(), "" if arr.size() == 1 else "s"]
	if v is Dictionary:
		var item: Dictionary = v
		return "%s #%d @ %.0f" % [
			str(item.get("kind", "?")), int(item.get("id", -1)), float(item.get("distance", 0.0))]
	return str(v)


static func val_color(v: Variant) -> Color:
	if v == null:
		return COL_NULL
	if v is bool:
		return COL_TRUE if bool(v) else COL_FALSE
	if v is Array:
		return COL_LIST
	if v is Dictionary:
		return COL_ENTITY
	return COL_FLOAT


# ---------------------------------------------------------------- value pill

func _make_value_footer() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	value_label = Label.new()
	row.add_child(value_label)
	add_child(row)
	_update_value_pill(null)


## The footer value is a rounded "status chip", not raw text: bools get a
## solid green/red pill with dark text (readable at a glance from far zoom),
## everything else a dark pill with type-colored text.
func _update_value_pill(v: Variant) -> void:
	value_label.text = fmt(v)
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.corner_radius_top_left = 7
	pill.corner_radius_top_right = 7
	pill.corner_radius_bottom_left = 7
	pill.corner_radius_bottom_right = 7
	pill.content_margin_left = 9
	pill.content_margin_right = 9
	pill.content_margin_top = 1
	pill.content_margin_bottom = 1
	var fg: Color
	if v is bool:
		pill.bg_color = COL_TRUE if bool(v) else COL_FALSE
		fg = Color(0.07, 0.09, 0.08)
	else:
		pill.bg_color = Color(0.17, 0.18, 0.23)
		fg = val_color(v)
	value_label.add_theme_stylebox_override("normal", pill)
	value_label.add_theme_color_override("font_color", fg)


func _add_title_buttons() -> void:
	var hb: HBoxContainer = get_titlebar_hbox()
	var copy_btn: Button = Button.new()
	copy_btn.text = GLYPH_COPY
	copy_btn.flat = true
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.tooltip_text = "Copy this node's debug JSON (value + full input tree)"
	var _err: Error = copy_btn.pressed.connect(
		func() -> void: copy_debug_requested.emit(self))
	hb.add_child(copy_btn)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		node_context_requested.emit(self, get_global_mouse_position())
