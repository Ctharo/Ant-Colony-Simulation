class_name BBNode
extends GraphNode
## Base for all builder nodes. Subclasses override _build(), input_count(),
## input_type(), output_type(), get_params()/set_params(), on_inputs()/on_value().

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
const GLYPH_EYE := "👁"

var bb_type := ""
var last_value = null
var value_label: Label


func _ready() -> void:
	_build()
	_add_title_buttons()


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


## Called every evaluation pass, before on_value.
## values[i] is the evaluated input (or null); connected[i] is wire presence.
func on_inputs(_values: Array, _connected: Array) -> void:
	pass


func on_value(v) -> void:
	last_value = v
	if value_label:
		value_label.text = "= %s" % fmt(v)
		value_label.add_theme_color_override("font_color", val_color(v))


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
