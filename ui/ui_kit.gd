class_name UiKit
extends Object
## Static factory helpers so every runtime-built control gets the same
## modern affordances: tooltip on hover, pointing-hand cursor, and
## labels that actually show their tooltips (Labels ignore the mouse
## by default, which silently eats tooltip_text).


static func button(text: String, tooltip: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(handler)
	return btn


static func check(text: String, tooltip: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.tooltip_text = tooltip
	c.focus_mode = Control.FOCUS_NONE
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return c


## Label + control on one row; the tooltip shows when hovering either.
static func labeled_row(label_text: String, control: Control,
		tooltip: String = "", label_width: float = 90.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(label_width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_PASS  # let tooltips fire
	label.tooltip_text = tooltip
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip and control.tooltip_text.is_empty():
		control.tooltip_text = tooltip
	row.add_child(control)
	return row


## Small dim hint text (for inline explanations under fields).
static func hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.modulate = Color(1, 1, 1, 0.6)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l
