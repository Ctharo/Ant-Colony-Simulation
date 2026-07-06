class_name LogicEditorPopup
extends ManagedWindow
## Runtime editor for Logic expression resources.

signal saved(resource: Logic)

## Variant.Type values exposed in the type dropdown
const TYPE_OPTIONS: Array = [
	["Bool", TYPE_BOOL],
	["Int", TYPE_INT],
	["Float", TYPE_FLOAT],
	["String", TYPE_STRING],
	["Vector2", TYPE_VECTOR2],
	["Object", TYPE_OBJECT],
]

var editing: Logic
var _previous_path: String = ""
var _previous_id: String = ""
var _nested: Array[Logic] = []

var _banner: Label
var _name_edit: LineEdit
var _type_select: OptionButton
var _expr_edit: TextEdit
var _validation_label: Label
var _desc_edit: LineEdit
var _nested_list: ItemList
var _nested_picker: OptionButton
var _vocab_list: ItemList
var _test_result_label: Label


func _init() -> void:
	setup_window("expression_editor", "Expression Editor",
		Vector2i(500, 800), Vector2i(460, 700))
	


func open_for(res: Resource, path: String, writable: bool) -> void:
	_previous_path = path if writable else ""
	# Work on a copy so live ants aren't affected until Save; a read-only
	# built-in is forked permanently (saves land in user://).
	editing = ResourceLibrary.duplicate_for_edit(res) if not path.is_empty() else res
	_previous_id = editing.id
	_nested.assign(editing.nested_expressions)
	_build_ui(writable, path)
	present()

func _build_ui(writable: bool, path: String) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	if not path.is_empty() and not writable:
		_banner = Label.new()
		_banner.text = "Built-in resource — saving creates an editable copy in user://"
		_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_banner.add_theme_color_override("font_color", Color.GOLD)
		vbox.add_child(_banner)

	_name_edit = LineEdit.new()
	_name_edit.text = editing.name
	vbox.add_child(_labeled_row("Name:", _name_edit))

	_type_select = OptionButton.new()
	for opt in TYPE_OPTIONS:
		_type_select.add_item(opt[0])
	_select_type(editing.type)
	vbox.add_child(_labeled_row("Returns:", _type_select))

	var expr_label := Label.new()
	expr_label.text = "Expression (nested names below are usable as variables):"
	vbox.add_child(expr_label)

	_expr_edit = TextEdit.new()
	_expr_edit.text = editing.expression_string
	_expr_edit.custom_minimum_size = Vector2(0, 90)
	_expr_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_expr_edit.text_changed.connect(_validate)
	vbox.add_child(_expr_edit)

	_validation_label = Label.new()
	_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_validation_label)

	var vocab_label := Label.new()
	vocab_label.text = "Available identifiers (double-click to insert):"
	vbox.add_child(vocab_label)

	_vocab_list = ItemList.new()
	_vocab_list.custom_minimum_size = Vector2(0, 90)
	_vocab_list.item_activated.connect(_on_vocab_activated)
	vbox.add_child(_vocab_list)
	_populate_vocabulary()

	# --- Test row (before the Save/Cancel button_row) ---
	var test_row := HBoxContainer.new()
	test_row.add_theme_constant_override("separation", 6)
	test_row.add_child(_action_button("Test on live ant", _on_test_pressed))
	_test_result_label = Label.new()
	_test_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_test_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_row.add_child(_test_result_label)
	vbox.add_child(test_row)

	_desc_edit = LineEdit.new()
	_desc_edit.text = editing.description
	vbox.add_child(_labeled_row("Description:", _desc_edit))

	var nested_label := Label.new()
	nested_label.text = "Nested expressions:"
	vbox.add_child(nested_label)

	_nested_list = ItemList.new()
	_nested_list.custom_minimum_size = Vector2(0, 110)
	_nested_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_nested_list)

	var nested_row := HBoxContainer.new()
	nested_row.add_theme_constant_override("separation", 6)
	_nested_picker = OptionButton.new()
	_nested_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nested_row.add_child(_nested_picker)
	nested_row.add_child(_action_button("Add", _on_add_nested))
	nested_row.add_child(_action_button("Remove", _on_remove_nested))
	vbox.add_child(nested_row)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 6)
	button_row.add_child(_action_button("Save", _on_save))
	button_row.add_child(_action_button("Cancel", queue_free))
	vbox.add_child(button_row)

	# Force re-parse on live ants (id may have changed on rename)
	EvaluationSystem.invalidate_expression(_previous_id)
	EvaluationSystem.invalidate_expression(editing.id)

	_name_edit.tooltip_text = "Unique name; the id is derived from it"
	_type_select.tooltip_text = "Variant type this expression must return"
	_expr_edit.tooltip_text = "Godot Expression syntax; nested expression ids are usable as variables"
	_desc_edit.tooltip_text = "Shown in library lists and pickers"
	_nested_list.tooltip_text = "Sub-expressions available as variables inside this one"
	_nested_picker.tooltip_text = "Pick an expression to nest"

	watch([_name_edit, _type_select, _expr_edit, _desc_edit])
	
	_refresh_nested()
	_validate()

func _labeled_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _action_button(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(handler)
	return btn


func _select_type(variant_type: int) -> void:
	for i in TYPE_OPTIONS.size():
		if TYPE_OPTIONS[i][1] == variant_type:
			_type_select.select(i)
			return
	_type_select.select(0)


#region Nested expressions
func _refresh_nested() -> void:
	_nested_list.clear()
	for nested in _nested:
		_nested_list.add_item("%s  (%s)" % [nested.id, nested.name])

	_nested_picker.clear()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		var logic: Logic = entry.resource
		if logic == editing or logic in _nested or logic.id == _previous_id:
			continue
		if _creates_cycle(logic, editing):
			continue
		_nested_picker.add_item(entry.display_name())
		_nested_picker.set_item_metadata(_nested_picker.item_count - 1, logic)


## True if adding candidate under host would create a reference cycle
## (which would infinitely recurse in EvaluationSystem).
func _creates_cycle(candidate: Logic, host: Logic) -> bool:
	if candidate == host or candidate.id == _previous_id:
		return true
	for nested in candidate.nested_expressions:
		if _creates_cycle(nested, host):
			return true
	return false


func _on_add_nested() -> void:
	var idx := _nested_picker.selected
	if idx < 0:
		return
	var logic: Logic = _nested_picker.get_item_metadata(idx)
	if logic and logic not in _nested:
		_nested.append(logic)
		_refresh_nested()
		_validate()
	

func _on_remove_nested() -> void:
	var sel := _nested_list.get_selected_items()
	if sel.is_empty():
		return
	_nested.remove_at(sel[0])
	_refresh_nested()
	_validate()
#endregion

func _populate_vocabulary() -> void:
	_vocab_list.clear()
	# Nested expression bindings first — they're what this expression composes
	for nested in _nested:
		var idx := _vocab_list.add_item("%s  [nested]" % nested.id)
		_vocab_list.set_item_metadata(idx, nested.id)
		_vocab_list.set_item_tooltip(idx, nested.description)
	for entry: Dictionary in AntSenses.get_vocabulary():
		var display: String = entry.get("signature", entry.name)
		var idx := _vocab_list.add_item("%s  [%s]" % [display, entry.kind])
		_vocab_list.set_item_metadata(idx, entry.name + ("()" if entry.kind == "method" else ""))


func _on_vocab_activated(index: int) -> void:
	_expr_edit.insert_text_at_caret(_vocab_list.get_item_metadata(index))
	_expr_edit.grab_focus()
	_validate()


func _on_test_pressed() -> void:
	if not _validate():
		return
	var ants: Array[Ant] = AntManager.get_all()
	if ants.is_empty():
		_test_result_label.text = "No live ants to test against."
		return

	# Throwaway Logic with a unique id so it can't collide with or pollute
	# the cache of any real expression.
	var probe := Logic.new()
	probe.name = "editor probe"
	probe.id = "__editor_probe_%d" % Time.get_ticks_usec()
	probe.expression_string = _expr_edit.text
	probe.nested_expressions.assign(_nested)

	var ant: Ant = ants[0]
	var result: Variant = EvaluationSystem.get_value(probe, ant)
	EvaluationSystem.invalidate_expression(probe.id)

	_test_result_label.text = "Ant #%d → %s  (%s)" % [
		ant.id, str(result), type_string(typeof(result))
	]

func _validate() -> bool:
	var ids := PackedStringArray()
	for nested in _nested:
		ids.append(nested.id)

	var expr := Expression.new()
	var err := expr.parse(_expr_edit.text, ids)
	if err != OK:
		_validation_label.text = "Parse error: %s" % expr.get_error_text()
		_validation_label.add_theme_color_override("font_color", Color.INDIAN_RED)
		return false

	_validation_label.text = "Parses OK. Other identifiers resolve against the ant at runtime."
	_validation_label.add_theme_color_override("font_color", Color.SEA_GREEN)
	return true


func _on_save() -> void:
	if not _validate():
		return

	editing.name = _name_edit.text.strip_edges()
	if editing.id.is_empty():
		_validation_label.text = "Name is required."
		_validation_label.add_theme_color_override("font_color", Color.INDIAN_RED)
		return
	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_LOGIC, editing.id, editing) \
			and editing.id != _previous_id:
		_validation_label.text = "Another expression already uses the id '%s' — pick a different name." % editing.id
		_validation_label.add_theme_color_override("font_color", Color.INDIAN_RED)
		return

	editing.expression_string = _expr_edit.text
	editing.type = TYPE_OPTIONS[_type_select.selected][1]
	editing.description = _desc_edit.text
	editing.nested_expressions.assign(_nested)

	if ResourceLibrary.save_resource(editing, ResourceLibrary.KIND_LOGIC, _previous_path) != OK:
		_validation_label.text = "Save failed — see log."
		toast_error("Save failed — see log.")
		return


	saved.emit(editing)
	clear_dirty()
	Toast.success(get_parent(), "Saved expression '%s'" % editing.name)
	_request_close()
