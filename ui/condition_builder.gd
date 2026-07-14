class_name ConditionBuilder
extends VBoxContainer
## Maintainerr-style visual condition builder: sections of dropdown-driven
## comparison rows that compile to a plain Expression string.
##
## Model (mirrors Maintainerr's rule editor):
## - A ROW is one comparison: [operator] [first value] [action] [second value]
##   - operator: AND/OR chaining with the previous row. The very first row
##     of the whole builder has no operator; the first row of every LATER
##     section carries the SECTION operator (how the whole section combines
##     with everything before it).
##   - first value: an atomic sense (AntSenses vocabulary, grouped by
##     category) or a derived read (distance-to-position, speed).
##   - action: comparison operator, filtered by the first value's type.
##   - second value: a typed literal, or another sense/constant of a
##     compatible type.
## - A SECTION groups rows; rows chain left-to-right inside it.
##
## COMPILATION: the builder is a pure front-end — it emits an ordinary
## expression string (left-associative, explicitly parenthesized, so
## evaluation order matches the visual top-to-bottom reading exactly like
## Maintainerr's). Everything downstream (EvaluationSystem, the three
## LogicValidator gates, caching, purity detection) is untouched; the
## compiled string is still parse- and whitelist-validated live and again
## at save (gates 2 and 3).
##
## The builder deliberately supports a SUBSET of the behavior language:
## no arithmetic on the first value, no parameterized senses (pheromone
## reads), no cross-type tricks. The raw expression editor remains the
## escape hatch for anything beyond it.
##
## SERIALIZATION: to_data()/load_data() round-trip the visual structure as
## a plain Dictionary (persisted as Logic.builder_data). The model contains
## only value types — widget references are never stored.
##
## HEADLESS USE: the model works without the control ever entering the
## tree — load_data()/get_expression() are UI-safe when _ready hasn't run.
## compile_data() wraps that for one-shot recompiles (the Behavior Editor
## uses it for divergence detection against a hand-edited
## expression_string).
##
## Built entirely in code, per the project's runtime-UI convention.

signal changed

## Bump when the to_data() schema changes (persisted in Logic.builder_data).
const DATA_VERSION := 1

const OP_AND := "and"
const OP_OR := "or"

## Comparison actions per type class. [label, opcode]
## Opcodes: infix operators are used verbatim; "not"/"" are the bool forms;
## bare names (contains, begins_with, ends_with) compile to method calls —
## all of which are in LogicValidator.VALUE_METHODS.
const OPS_NUM: Array = [
	["=", "=="], ["≠", "!="],
	["<", "<"], ["≤", "<="], [">", ">"], ["≥", ">="],
]
const OPS_BOOL: Array = [
	["is true", ""], ["is false", "not"],
]
const OPS_STRING: Array = [
	["equals", "=="], ["not equals", "!="],
	["contains", "contains"], ["begins with", "begins_with"],
	["ends with", "ends_with"],
]

## Sections model. Only plain value types live here (see SERIALIZATION).
## section := { "op": "and"|"or", "rows": Array[Dictionary] }
## row     := { "op": "and"|"or", "first": String (catalog key),
##              "action": String (opcode), "second_kind": "literal"|"sense",
##              "second": Variant (literal) , "second_sense": String (key) }
var _sections: Array[Dictionary] = []

## Catalog of selectable values, derived from AntSenses.get_vocabulary().
## entry := { key, label, category, type ("num"|"bool"|"String"),
##            compile (expression fragment), doc, first_ok (bool) }
var _catalog: Array[Dictionary] = []
var _by_key: Dictionary = {}

var _sections_box: VBoxContainer
var _scroll: ScrollContainer
var _preview_label: Label
var _status_label: Label

var _no_nested: Array[Logic] = []  # builder output never uses nested ids


## One-shot headless recompile: what expression would this builder_data
## produce today? Used for divergence detection (compare against the
## Logic's stored expression_string).
static func compile_data(data: Dictionary) -> String:
	var builder := ConditionBuilder.new()
	builder.load_data(data)
	var expr := builder.get_expression()
	builder.free()  # never entered the tree — free manually
	return expr


func _init() -> void:
	_build_catalog()


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_sections_box = VBoxContainer.new()
	_sections_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_sections_box)

	var add_section_btn := Button.new()
	add_section_btn.text = "+ Add section"
	add_section_btn.tooltip_text = "A section groups conditions; whole sections combine with AND/OR, like Maintainerr."
	add_section_btn.pressed.connect(_on_add_section)
	add_child(add_section_btn)

	var preview_panel := PanelContainer.new()
	add_child(preview_panel)
	var preview_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		preview_margin.add_theme_constant_override("margin_%s" % side, 8)
	preview_panel.add_child(preview_margin)
	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 4)
	preview_margin.add_child(preview_box)

	_preview_label = Label.new()
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.add_theme_font_size_override("font_size", 12)
	_preview_label.tooltip_text = "The expression this builder compiles to. It goes through the same validation and evaluation as a hand-written one."
	preview_box.add_child(_preview_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	preview_box.add_child(_status_label)

	if _sections.is_empty():
		_sections.append(_new_section())
	_rebuild_ui()


#region Public API
## Compiled expression string; "" when the builder holds no conditions
## (callers treat empty as "always true", matching AntRule's null condition).
func get_expression() -> String:
	var parts: Array[String] = []
	for section: Dictionary in _sections:
		var sec_expr := _compile_section(section)
		if sec_expr.is_empty():
			continue
		if parts.is_empty():
			parts.append(sec_expr)
		else:
			parts.assign(["(%s %s %s)" % [parts[0], section.op, sec_expr]])
	return parts[0] if not parts.is_empty() else ""


## Validation errors for the current compiled expression (empty = valid).
func get_errors() -> PackedStringArray:
	var expr := get_expression()
	if expr.is_empty():
		return PackedStringArray()
	var parser := Expression.new()
	if parser.parse(expr, PackedStringArray()) != OK:
		return PackedStringArray(["Parse error: %s" % parser.get_error_text()])
	return LogicValidator.validate(expr, _no_nested)


func is_valid() -> bool:
	return get_errors().is_empty()


func is_empty() -> bool:
	for section: Dictionary in _sections:
		if not section.rows.is_empty():
			return false
	return true


func clear() -> void:
	_sections.clear()
	_sections.append(_new_section())
	_rebuild_ui()
	changed.emit()


## Visual structure as plain data (persisted as Logic.builder_data so
## builder-authored conditions reopen in the builder).
func to_data() -> Dictionary:
	var sections_out: Array = []
	for section: Dictionary in _sections:
		var rows_out: Array = []
		for row: Dictionary in section.rows:
			rows_out.append({
				"op": row.op,
				"first": row.first,
				"action": row.action,
				"second_kind": row.second_kind,
				"second": row.second,
				"second_sense": row.second_sense,
			})
		sections_out.append({ "op": section.op, "rows": rows_out })
	return { "version": DATA_VERSION, "sections": sections_out }


## Restores a to_data() structure. Rows referencing senses that no longer
## exist in the catalog are dropped with a status warning (vocabulary may
## have changed since the data was authored). Safe to call before the
## control enters the tree (headless).
func load_data(data: Dictionary) -> void:
	_sections.clear()
	var dropped := 0
	for sec_in: Dictionary in data.get("sections", []):
		var section := _new_section()
		section.op = OP_OR if sec_in.get("op") == OP_OR else OP_AND
		for row_in: Dictionary in sec_in.get("rows", []):
			var first: String = row_in.get("first", "")
			if not _by_key.has(first):
				dropped += 1
				continue
			var row := _new_row()
			row.op = OP_OR if row_in.get("op") == OP_OR else OP_AND
			row.first = first
			row.action = str(row_in.get("action", row.action))
			if not _valid_action(row.first, row.action):
				row.action = _default_action(row.first)
			row.second_kind = "sense" if row_in.get("second_kind") == "sense" else "literal"
			row.second = row_in.get("second", _default_literal(row.first))
			row.second_sense = str(row_in.get("second_sense", ""))
			if row.second_kind == "sense" and not _by_key.has(row.second_sense):
				row.second_kind = "literal"
				row.second = _default_literal(row.first)
				dropped += 1
			section.rows.append(row)
		_sections.append(section)
	if _sections.is_empty():
		_sections.append(_new_section())
	_rebuild_ui()
	if dropped > 0 and is_instance_valid(_status_label):
		_status_label.text = "%d condition(s) referenced senses that no longer exist and were dropped or reset." % dropped
		_status_label.add_theme_color_override("font_color", Color.GOLD)
	changed.emit()
#endregion


#region Catalog
## Builds the selectable-value catalog from the live AntSenses vocabulary.
## - bool/int/float/String senses: direct entries.
## - Vector2 position senses: derived "distance to X" (float) — positions
##   can't be compared directly, and Vector2.INF sentinels make distance
##   comparisons degrade safely by design.
## - velocity: derived "speed" (velocity.length()).
## - Constants (ENERGY_MAX, ...): second-value only (first_ok = false).
## - Parameterized methods (pheromone reads) are excluded — raw editor only.
func _build_catalog() -> void:
	_catalog.clear()
	_by_key.clear()
	for entry: Dictionary in AntSenses.get_vocabulary():
		# Zero-arg methods reflect as "name()"; anything else has params.
		if entry.kind == "method" and entry.signature != entry.name + "()":
			continue
		var frag: String = entry.name + ("()" if entry.kind == "method" else "")
		var is_const: bool = entry.category == AntSenses.CAT_CONST

		match entry.returns:
			"bool":
				_add_catalog(entry.name, entry.name, entry.category,
					"bool", frag, entry.doc, not is_const)
			"int", "float":
				_add_catalog(entry.name, entry.name, entry.category,
					"num", frag, entry.doc, not is_const)
			"String":
				_add_catalog(entry.name, entry.name, entry.category,
					"String", frag, entry.doc, not is_const)
			"Vector2":
				if entry.name == "velocity":
					_add_catalog("speed", "speed", entry.category, "num",
						"velocity.length()",
						"Current speed in pixels/sec (velocity length).", true)
				elif entry.name.contains("position") and entry.name != "global_position":
					_add_catalog("dist:" + entry.name,
						"distance to " + entry.name.trim_suffix("_position"),
						entry.category, "num",
						"global_position.distance_to(%s)" % frag,
						"Distance in pixels from this ant to %s. INF when none — comparisons like '< 50' are then false." % entry.name,
						true)
				# global_position itself: no sensible standalone comparison.


func _add_catalog(key: String, label: String, category: String,
		type: String, compile_frag: String, doc: String, first_ok: bool) -> void:
	var entry := {
		"key": key, "label": label, "category": category, "type": type,
		"compile": compile_frag, "doc": doc, "first_ok": first_ok,
	}
	_catalog.append(entry)
	_by_key[key] = entry


func _ops_for(key: String) -> Array:
	match _by_key[key].type:
		"bool": return OPS_BOOL
		"String": return OPS_STRING
		_: return OPS_NUM


func _valid_action(key: String, opcode: String) -> bool:
	for op: Array in _ops_for(key):
		if op[1] == opcode:
			return true
	return false


func _default_action(key: String) -> String:
	return _ops_for(key)[0][1]


func _default_literal(key: String) -> Variant:
	return "" if _by_key[key].type == "String" else 0.0


func _default_first() -> String:
	for entry: Dictionary in _catalog:
		if entry.first_ok:
			return entry.key
	return ""
#endregion


#region Model helpers
func _new_section() -> Dictionary:
	return { "op": OP_AND, "rows": [] as Array[Dictionary] }


func _new_row() -> Dictionary:
	var first := _default_first()
	return {
		"op": OP_AND,
		"first": first,
		"action": _default_action(first) if not first.is_empty() else "==",
		"second_kind": "literal",
		"second": _default_literal(first) if not first.is_empty() else 0.0,
		"second_sense": "",
	}
#endregion


#region UI construction
## Full rebuild from the model. Structural edits (add/remove, first-value
## or second-kind changes) rebuild; op/literal edits only touch the model
## and preview — that split is what keeps the builder feeling snappy.
## No-op headless (before _ready): the model is authoritative, the UI is
## a projection of it.
func _rebuild_ui() -> void:
	if not is_instance_valid(_sections_box):
		return

	for child in _sections_box.get_children():
		child.queue_free()

	for si in _sections.size():
		_sections_box.add_child(_make_section_panel(si))

	_refresh_preview()


func _make_section_panel(si: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "Section %d" % (si + 1)
	title.add_theme_font_size_override("font_size", 12)
	title.modulate = Color(1, 1, 1, 0.7)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var add_btn := Button.new()
	add_btn.text = "+ Add condition"
	add_btn.pressed.connect(func() -> void: _on_add_row(si))
	header.add_child(add_btn)

	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.tooltip_text = "Delete this section and its conditions"
	del_btn.pressed.connect(func() -> void: _on_delete_section(si))
	header.add_child(del_btn)
	vbox.add_child(header)

	var rows: Array = _sections[si].rows
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "(no conditions in this section)"
		empty.add_theme_font_size_override("font_size", 11)
		empty.modulate = Color(1, 1, 1, 0.5)
		vbox.add_child(empty)
	for ri in rows.size():
		vbox.add_child(_make_row(si, ri))

	return panel


func _make_row(si: int, ri: int) -> HBoxContainer:
	var row: Dictionary = _sections[si].rows[ri]
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	# --- Operator slot (fixed width so first-value columns align) ---
	var op_slot := _make_op_control(si, ri)
	op_slot.custom_minimum_size = Vector2(72, 0)
	hbox.add_child(op_slot)

	# --- First value ---
	var first_select := OptionButton.new()
	first_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first_select.fit_to_longest_item = false
	var last_category := ""
	for entry: Dictionary in _catalog:
		if not entry.first_ok:
			continue
		if entry.category != last_category:
			first_select.add_separator(entry.category)
			last_category = entry.category
		first_select.add_item(entry.label)
		var idx := first_select.item_count - 1
		first_select.set_item_metadata(idx, entry.key)
		first_select.set_item_tooltip(idx, entry.doc)
		if entry.key == row.first:
			first_select.select(idx)
	first_select.item_selected.connect(func(idx: int) -> void:
		var key: String = first_select.get_item_metadata(idx)
		var prev_type: String = _by_key[row.first].type if _by_key.has(row.first) else ""
		row.first = key
		# Keep action/second when the type class is unchanged (e.g. energy
		# → health): the comparison still makes sense. Reset otherwise.
		if _by_key[key].type != prev_type:
			row.action = _default_action(key)
			row.second_kind = "literal"
			row.second = _default_literal(key)
			row.second_sense = ""
			_rebuild_ui()
		else:
			_refresh_preview()
		changed.emit()
	)
	hbox.add_child(first_select)

	# --- Action ---
	var action_select := OptionButton.new()
	action_select.custom_minimum_size = Vector2(96, 0)
	for op: Array in _ops_for(row.first):
		action_select.add_item(op[0])
		action_select.set_item_metadata(action_select.item_count - 1, op[1])
		if op[1] == row.action:
			action_select.select(action_select.item_count - 1)
	action_select.item_selected.connect(func(idx: int) -> void:
		row.action = action_select.get_item_metadata(idx)
		_refresh_preview()
		changed.emit()
	)
	hbox.add_child(action_select)

	# --- Second value (none for bool actions) ---
	if _by_key[row.first].type != "bool":
		var kind_select := OptionButton.new()
		kind_select.add_item("Value")
		kind_select.add_item("Sense")
		kind_select.tooltip_text = "Compare against a fixed value, or against another sense/constant (like Maintainerr's custom value vs. property)."
		kind_select.select(1 if row.second_kind == "sense" else 0)
		kind_select.item_selected.connect(func(idx: int) -> void:
			row.second_kind = "sense" if idx == 1 else "literal"
			if row.second_kind == "sense" and row.second_sense.is_empty():
				row.second_sense = _first_compatible_sense(row.first)
			_rebuild_ui()
			changed.emit()
		)
		hbox.add_child(kind_select)
		hbox.add_child(_make_second_widget(row))

	# --- Delete row ---
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.tooltip_text = "Remove this condition"
	del_btn.pressed.connect(func() -> void: _on_delete_row(si, ri))
	hbox.add_child(del_btn)

	return hbox


## The leading slot: nothing on the very first row, the SECTION operator on
## the first row of later sections, the row operator otherwise.
func _make_op_control(si: int, ri: int) -> Control:
	if si == 0 and ri == 0:
		return Control.new()  # spacer

	var select := OptionButton.new()
	select.add_item("AND")
	select.add_item("OR")
	if ri == 0:
		select.tooltip_text = "How this whole SECTION combines with everything above it."
		select.select(1 if _sections[si].op == OP_OR else 0)
		select.item_selected.connect(func(idx: int) -> void:
			_sections[si].op = OP_OR if idx == 1 else OP_AND
			_refresh_preview()
			changed.emit()
		)
	else:
		var row: Dictionary = _sections[si].rows[ri]
		select.tooltip_text = "How this condition chains with the previous one in this section."
		select.select(1 if row.op == OP_OR else 0)
		select.item_selected.connect(func(idx: int) -> void:
			row.op = OP_OR if idx == 1 else OP_AND
			_refresh_preview()
			changed.emit()
		)
	return select


func _make_second_widget(row: Dictionary) -> Control:
	var type: String = _by_key[row.first].type

	if row.second_kind == "sense":
		var sense_select := OptionButton.new()
		sense_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var last_category := ""
		for entry: Dictionary in _catalog:
			if entry.type != type or entry.key == row.first:
				continue
			if entry.category != last_category:
				sense_select.add_separator(entry.category)
				last_category = entry.category
			sense_select.add_item(entry.label)
			var idx := sense_select.item_count - 1
			sense_select.set_item_metadata(idx, entry.key)
			sense_select.set_item_tooltip(idx, entry.doc)
			if entry.key == row.second_sense:
				sense_select.select(idx)
		sense_select.item_selected.connect(func(idx: int) -> void:
			row.second_sense = sense_select.get_item_metadata(idx)
			_refresh_preview()
			changed.emit()
		)
		return sense_select

	if type == "String":
		var edit := LineEdit.new()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text = str(row.second)
		edit.placeholder_text = "text..."
		edit.text_changed.connect(func(text: String) -> void:
			row.second = text
			_refresh_preview()
			changed.emit()
		)
		return edit

	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(96, 0)
	spin.step = 0.1
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.min_value = -1000000
	spin.max_value = 1000000
	spin.value = float(row.second) if row.second is float or row.second is int else 0.0
	spin.value_changed.connect(func(value: float) -> void:
		row.second = value
		_refresh_preview()
		changed.emit()
	)
	return spin


func _first_compatible_sense(first_key: String) -> String:
	var type: String = _by_key[first_key].type
	for entry: Dictionary in _catalog:
		if entry.type == type and entry.key != first_key:
			return entry.key
	return ""
#endregion


#region Structural edits
func _on_add_section() -> void:
	var section := _new_section()
	section.rows.append(_new_row())
	_sections.append(section)
	_rebuild_ui()
	changed.emit()


func _on_delete_section(si: int) -> void:
	_sections.remove_at(si)
	if _sections.is_empty():
		_sections.append(_new_section())
	_rebuild_ui()
	changed.emit()


func _on_add_row(si: int) -> void:
	_sections[si].rows.append(_new_row())
	_rebuild_ui()
	changed.emit()


func _on_delete_row(si: int, ri: int) -> void:
	_sections[si].rows.remove_at(ri)
	_rebuild_ui()
	changed.emit()
#endregion


#region Compilation
## Left-associative fold with explicit parentheses so evaluation order
## matches the visual top-to-bottom chain: r1 op r2 op r3 compiles to
## ((r1 op r2) op r3) — never relying on and/or precedence.
func _compile_section(section: Dictionary) -> String:
	var acc := ""
	for row: Dictionary in section.rows:
		var frag := _compile_row(row)
		if frag.is_empty():
			continue
		acc = frag if acc.is_empty() else "(%s %s %s)" % [acc, row.op, frag]
	return acc


func _compile_row(row: Dictionary) -> String:
	if not _by_key.has(row.first):
		return ""
	var entry: Dictionary = _by_key[row.first]
	var first: String = entry.compile

	match entry.type:
		"bool":
			return "not %s" % first if row.action == "not" else first
		"String":
			var second := _compile_second(row)
			if row.action in ["==", "!="]:
				return "%s %s %s" % [first, row.action, second]
			return "%s.%s(%s)" % [first, row.action, second]
		_:
			return "%s %s %s" % [first, row.action, _compile_second(row)]


func _compile_second(row: Dictionary) -> String:
	if row.second_kind == "sense" and _by_key.has(row.second_sense):
		return _by_key[row.second_sense].compile

	if _by_key[row.first].type == "String":
		var text := str(row.second).replace("\\", "\\\\").replace("\"", "\\\"")
		return "\"%s\"" % text

	var value := float(row.second) if row.second is float or row.second is int else 0.0
	if absf(value - roundf(value)) < 0.000001:
		return "%d" % int(value)
	return str(value)
#endregion


#region Preview
func _refresh_preview() -> void:
	if not is_instance_valid(_preview_label):
		return

	var expr := get_expression()
	if expr.is_empty():
		_preview_label.text = "(no conditions — always true)"
		_status_label.text = ""
		return

	_preview_label.text = expr

	var errors := get_errors()
	if errors.is_empty():
		_status_label.text = "Valid."
		_status_label.add_theme_color_override("font_color", Color.SEA_GREEN)
	else:
		_status_label.text = "\n".join(errors)
		_status_label.add_theme_color_override("font_color", Color.INDIAN_RED)
#endregion
