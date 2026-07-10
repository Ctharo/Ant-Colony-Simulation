class_name InfluenceLibraryPanel
extends ManagedWindow
## Runtime library + editor for the steering layer, replacing the view-only
## InfluenceProfileViewPopup with real CRUD. Two tabs:
##
##  - Influences: a Vector2 Logic expression with a debug color and an
##    optional gate condition (picked from the cataloged Logic expressions).
##    Validated live against LogicValidator like the expression editor, with
##    a probe evaluation against a live ant.
##
##  - Steering Profiles: enter/exit condition checklists (any-true
##    semantics; exit conditions make the profile sticky — see
##    InfluenceManager) and the set of influences summed while active.
##
## Persisted through ResourceLibrary (KIND_INFLUENCE /
## KIND_INFLUENCE_PROFILE). Opened from the Ant Designer's "Manage..."
## button next to Movement influences, or the debug menu.

var logger: iLogger

var _tabs: TabContainer

# --- Influences tab ---
var _infl_list: ItemList
var _infl_name_edit: LineEdit
var _infl_expr_edit: TextEdit
var _infl_color_btn: ColorPickerButton
var _infl_gate_select: OptionButton
var _infl_desc_edit: LineEdit
var _infl_validation: Label
var _infl_test_label: Label
var _infl_status: Label

var _editing_infl: Influence
var _editing_infl_path: String = ""

# --- Profiles tab ---
var _prof_list: ItemList
var _prof_name_edit: LineEdit
var _prof_enter_box: VBoxContainer
var _prof_exit_box: VBoxContainer
var _prof_infl_box: VBoxContainer
var _prof_status: Label

var _editing_prof: InfluenceProfile
var _editing_prof_path: String = ""

var _confirm: ConfirmationDialog


func _init() -> void:
	setup_window("influence_library", "Influence Library",
		Vector2i(760, 640), Vector2i(600, 500))
	logger = iLogger.new("influence_library", DebugLogger.Category.UI)


func _ready() -> void:
	_build_ui()
	_confirm = ConfirmationDialog.new()
	add_child(_confirm)
	ResourceLibrary.library_changed.connect(_on_library_changed)
	_refresh_influence_list()
	_refresh_profile_list()
	_new_influence()
	_new_profile()


#region UI construction
func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	add_child(margin)

	_tabs = TabContainer.new()
	margin.add_child(_tabs)

	var infl_tab := _build_influence_tab()
	infl_tab.name = "Influences"
	_tabs.add_child(infl_tab)

	var prof_tab := _build_profile_tab()
	prof_tab.name = "Steering Profiles"
	_tabs.add_child(prof_tab)

	watch([_infl_name_edit, _infl_expr_edit, _infl_gate_select, _infl_desc_edit,
		_prof_name_edit])
	_infl_color_btn.color_changed.connect(func(_c: Color) -> void: mark_dirty())


func _build_influence_tab() -> Control:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 10)

	root.add_child(_build_list_pane("Influences", "_infl"))

	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(right)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	right.add_child(vbox)

	_infl_name_edit = LineEdit.new()
	_infl_name_edit.placeholder_text = "e.g. food influence"
	vbox.add_child(_row("Name:", _infl_name_edit))

	vbox.add_child(_section("Direction expression (Vector2)"))
	_infl_expr_edit = TextEdit.new()
	_infl_expr_edit.custom_minimum_size = Vector2(0, 80)
	_infl_expr_edit.placeholder_text = "e.g. pheromone_direction(\"food\").normalized() * 2.5"
	_infl_expr_edit.text_changed.connect(_validate_influence_soft)
	vbox.add_child(_infl_expr_edit)

	_infl_validation = Label.new()
	_infl_validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_infl_validation)

	_infl_color_btn = ColorPickerButton.new()
	_infl_color_btn.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(_row("Debug color:", _infl_color_btn))

	_infl_gate_select = OptionButton.new()
	_infl_gate_select.tooltip_text = "The influence only contributes while this condition is true"
	vbox.add_child(_row("Gate condition:", _infl_gate_select))

	_infl_desc_edit = LineEdit.new()
	vbox.add_child(_row("Description:", _infl_desc_edit))

	var test_row := HBoxContainer.new()
	test_row.add_theme_constant_override("separation", 8)
	var test_btn := _mk_button("Test on live ant", _on_influence_test)
	test_row.add_child(test_btn)
	_infl_test_label = Label.new()
	_infl_test_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_row.add_child(_infl_test_label)
	vbox.add_child(test_row)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_mk_button("Save influence", _on_influence_save))

	_infl_status = Label.new()
	_infl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_infl_status)

	return root


func _build_profile_tab() -> Control:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 10)

	root.add_child(_build_list_pane("Profiles", "_prof"))

	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(right)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	right.add_child(vbox)

	_prof_name_edit = LineEdit.new()
	_prof_name_edit.placeholder_text = "e.g. look for food"
	vbox.add_child(_row("Name:", _prof_name_edit))

	vbox.add_child(_section("Enter conditions (any true = eligible)"))
	var enter_hint := _hint("Empty = always eligible. First eligible profile in the ant's list wins.")
	vbox.add_child(enter_hint)
	_prof_enter_box = VBoxContainer.new()
	vbox.add_child(_prof_enter_box)

	vbox.add_child(_section("Exit conditions (any true = release)"))
	var exit_hint := _hint("With exit conditions the profile is sticky: it holds until one fires. Empty = displaceable any tick.")
	vbox.add_child(exit_hint)
	_prof_exit_box = VBoxContainer.new()
	vbox.add_child(_prof_exit_box)

	vbox.add_child(_section("Influences (summed while active)"))
	_prof_infl_box = VBoxContainer.new()
	vbox.add_child(_prof_infl_box)

	_populate_profile_pools()

	vbox.add_child(HSeparator.new())
	vbox.add_child(_mk_button("Save profile", _on_profile_save))

	_prof_status = Label.new()
	_prof_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_prof_status)

	return root


## Left pane (list + New/Duplicate/Delete) shared between tabs; `which` is
## "_infl" or "_prof" and routes button handlers.
func _build_list_pane(header_text: String, which: String) -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(190, 0)
	vbox.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = header_text
	vbox.add_child(header)

	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	vbox.add_child(buttons)

	if which == "_infl":
		_infl_list = list
		list.item_selected.connect(_on_influence_selected)
		buttons.add_child(_mk_button("New", _new_influence))
		buttons.add_child(_mk_button("Duplicate", _on_influence_duplicate))
		buttons.add_child(_mk_button("Delete", _on_influence_delete))
	else:
		_prof_list = list
		list.item_selected.connect(_on_profile_selected)
		buttons.add_child(_mk_button("New", _new_profile))
		buttons.add_child(_mk_button("Duplicate", _on_profile_duplicate))
		buttons.add_child(_mk_button("Delete", _on_profile_delete))

	return vbox
#endregion


#region Option pools & lists
func _populate_gate_options() -> void:
	var previous: Logic = null
	if _infl_gate_select.selected > 0:
		previous = _infl_gate_select.get_item_metadata(_infl_gate_select.selected)

	_infl_gate_select.clear()
	_infl_gate_select.add_item("(no gate — always contributes)")
	_infl_gate_select.set_item_metadata(0, null)
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		var idx := _infl_gate_select.item_count
		_infl_gate_select.add_item(entry.display_name())
		_infl_gate_select.set_item_metadata(idx, entry.resource)
		if previous and entry.resource.get("id") == previous.id:
			_infl_gate_select.select(idx)


func _populate_profile_pools() -> void:
	_populate_check_box(_prof_enter_box, ResourceLibrary.KIND_LOGIC)
	_populate_check_box(_prof_exit_box, ResourceLibrary.KIND_LOGIC)
	_populate_check_box(_prof_infl_box, ResourceLibrary.KIND_INFLUENCE)


func _populate_check_box(box: VBoxContainer, kind: String) -> void:
	for child in box.get_children():
		child.queue_free()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(kind):
		var c := CheckBox.new()
		c.text = entry.display_name()
		c.tooltip_text = entry.resource.get("expression_string") \
			if entry.resource.get("expression_string") else entry.path
		c.set_meta("resource", entry.resource)
		c.toggled.connect(func(_on: bool) -> void: mark_dirty())
		box.add_child(c)


func _refresh_influence_list() -> void:
	_refresh_entry_list(_infl_list, ResourceLibrary.KIND_INFLUENCE)
	_populate_gate_options()


func _refresh_profile_list() -> void:
	_refresh_entry_list(_prof_list, ResourceLibrary.KIND_INFLUENCE_PROFILE)


func _refresh_entry_list(list: ItemList, kind: String) -> void:
	var previous: Resource = null
	var sel := list.get_selected_items()
	if not sel.is_empty():
		var prev_entry: ResourceLibrary.Entry = list.get_item_metadata(sel[0])
		previous = prev_entry.resource if prev_entry else null

	list.clear()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(kind):
		var idx := list.add_item(entry.display_name())
		list.set_item_metadata(idx, entry)
		list.set_item_tooltip(idx, entry.path)
		if entry.resource == previous:
			list.select(idx)


func _on_library_changed(kind: String) -> void:
	match kind:
		ResourceLibrary.KIND_INFLUENCE:
			_refresh_influence_list()
			_populate_check_box(_prof_infl_box, ResourceLibrary.KIND_INFLUENCE)
			if _editing_prof:
				_apply_profile_checks.call_deferred()
		ResourceLibrary.KIND_INFLUENCE_PROFILE:
			_refresh_profile_list()
		ResourceLibrary.KIND_LOGIC:
			_populate_gate_options()
			_populate_check_box(_prof_enter_box, ResourceLibrary.KIND_LOGIC)
			_populate_check_box(_prof_exit_box, ResourceLibrary.KIND_LOGIC)
			if _editing_prof:
				_apply_profile_checks.call_deferred()
#endregion


#region Influences: selection / CRUD
func _on_influence_selected(index: int) -> void:
	var entry: ResourceLibrary.Entry = _infl_list.get_item_metadata(index)
	if not entry:
		return
	_editing_infl = ResourceLibrary.duplicate_for_edit(entry.resource) as Influence
	_editing_infl_path = entry.path
	_load_influence_form()


func _new_influence() -> void:
	_editing_infl = Influence.new()
	_editing_infl.name = "New Influence"
	_editing_infl.expression_string = "Vector2(1, 0).rotated(global_rotation)"
	_editing_infl_path = ""
	if _infl_list:
		_infl_list.deselect_all()
	_load_influence_form()


func _on_influence_duplicate() -> void:
	if not _editing_infl:
		return
	var copy := ResourceLibrary.duplicate_for_edit(_editing_infl) as Influence
	copy.name = "%s copy" % _editing_infl.name
	_editing_infl = copy
	_editing_infl_path = ""
	_infl_list.deselect_all()
	_load_influence_form()
	_set_infl_status("Duplicated — edit and Save to write a new influence.", false)


func _on_influence_delete() -> void:
	_delete_selected(_infl_list, "influence", _new_influence)


func _load_influence_form() -> void:
	_infl_name_edit.text = _editing_infl.name
	_infl_expr_edit.text = _editing_infl.expression_string
	_infl_color_btn.color = _editing_infl.color
	_infl_desc_edit.text = _editing_infl.description
	_select_gate(_editing_infl.condition)
	_infl_test_label.text = ""
	_infl_validation.text = ""
	_set_infl_status("", false)
	clear_dirty()


func _select_gate(cond: Logic) -> void:
	_infl_gate_select.select(0)
	if not cond:
		return
	for i in range(_infl_gate_select.item_count):
		var meta = _infl_gate_select.get_item_metadata(i)
		if meta and meta is Logic and meta.id == cond.id:
			_infl_gate_select.select(i)
			return


func _apply_influence_form() -> void:
	_editing_infl.name = _infl_name_edit.text.strip_edges()  # re-derives id
	_editing_infl.expression_string = _infl_expr_edit.text
	_editing_infl.color = _infl_color_btn.color
	_editing_infl.description = _infl_desc_edit.text
	_editing_infl.condition = _infl_gate_select.get_item_metadata(_infl_gate_select.selected) \
		if _infl_gate_select.selected >= 0 else null


func _validate_influence_soft() -> void:
	_validate_influence()


func _validate_influence() -> bool:
	var expr := Expression.new()
	var err := expr.parse(_infl_expr_edit.text, PackedStringArray())
	if err != OK:
		_infl_validation.text = "Parse error: %s" % expr.get_error_text()
		_infl_validation.add_theme_color_override("font_color", Color.INDIAN_RED)
		return false

	var boundary := LogicValidator.validate(_infl_expr_edit.text, [] as Array[Logic])
	if not boundary.is_empty():
		_infl_validation.text = "\n".join(boundary)
		_infl_validation.add_theme_color_override("font_color", Color.INDIAN_RED)
		return false

	_infl_validation.text = "Parses OK. Identifiers resolve against the ant at runtime."
	_infl_validation.add_theme_color_override("font_color", Color.SEA_GREEN)
	return true


func _on_influence_test() -> void:
	if not _validate_influence():
		return
	var ants: Array[Ant] = AntManager.get_all()
	if ants.is_empty():
		_infl_test_label.text = "No live ants to test against."
		return

	# Throwaway probe with a unique id so it can't pollute a real cache.
	var probe := Influence.new()
	probe.name = "editor probe"
	probe.id = "__influence_probe_%d" % Time.get_ticks_usec()
	probe.expression_string = _infl_expr_edit.text

	var ant: Ant = ants[0]
	var result: Variant = EvaluationSystem.get_value(probe, ant)
	EvaluationSystem.invalidate_expression(probe.id)

	if result is Vector2:
		_infl_test_label.text = "Ant #%d → %s  (length %.2f)" % [
			ant.id, str(result), result.length()]
	else:
		_infl_test_label.text = "Ant #%d → %s  (%s — NOT a Vector2, save will reject)" % [
			ant.id, str(result), type_string(typeof(result))]


func _on_influence_save() -> void:
	if _infl_name_edit.text.strip_edges().is_empty():
		_set_infl_status("An influence needs a name.", true)
		return
	if not _validate_influence():
		_set_infl_status("Fix the expression first.", true)
		return

	_apply_influence_form()

	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_INFLUENCE,
			_editing_infl.id, _editing_infl) \
			and _editing_infl.id != _id_of_path(_editing_infl_path):
		_set_infl_status("Another influence already uses the id '%s'." % _editing_infl.id, true)
		return

	var prev := _editing_infl_path if _editing_infl_path.begins_with("user://") else ""
	if ResourceLibrary.save_resource(_editing_infl, ResourceLibrary.KIND_INFLUENCE, prev) != OK:
		_set_infl_status("Save failed — see log.", true)
		return

	EvaluationSystem.invalidate_expression(_editing_infl.id)
	_editing_infl_path = _editing_infl.resource_path
	clear_dirty()
	toast_success("Saved influence '%s'" % _editing_infl.name)
	_set_infl_status("Saved. Ants evaluating it pick up the change on next parse.", false)
#endregion


#region Profiles: selection / CRUD
func _on_profile_selected(index: int) -> void:
	var entry: ResourceLibrary.Entry = _prof_list.get_item_metadata(index)
	if not entry:
		return
	_editing_prof = ResourceLibrary.duplicate_for_edit(entry.resource) as InfluenceProfile
	_editing_prof_path = entry.path
	_load_profile_form()


func _new_profile() -> void:
	_editing_prof = InfluenceProfile.new()
	_editing_prof.name = "New Profile"
	_editing_prof_path = ""
	if _prof_list:
		_prof_list.deselect_all()
	_load_profile_form()


func _on_profile_duplicate() -> void:
	if not _editing_prof:
		return
	var copy := ResourceLibrary.duplicate_for_edit(_editing_prof) as InfluenceProfile
	copy.name = "%s copy" % _editing_prof.name
	_editing_prof = copy
	_editing_prof_path = ""
	_prof_list.deselect_all()
	_load_profile_form()
	_set_prof_status("Duplicated — edit and Save to write a new profile.", false)


func _on_profile_delete() -> void:
	_delete_selected(_prof_list, "steering profile", _new_profile)


func _load_profile_form() -> void:
	_prof_name_edit.text = _editing_prof.name
	_apply_profile_checks()
	_set_prof_status("", false)
	clear_dirty()


func _apply_profile_checks() -> void:
	_check_by_id(_prof_enter_box, _ids_of(_editing_prof.enter_conditions))
	_check_by_id(_prof_exit_box, _ids_of(_editing_prof.get("exit_conditions") if _editing_prof.get("exit_conditions") != null else []))
	_check_by_id(_prof_infl_box, _ids_of(_editing_prof.influences))


func _apply_profile_form() -> void:
	_editing_prof.name = _prof_name_edit.text.strip_edges()  # re-derives id

	var enter: Array[Logic] = []
	for c in _prof_enter_box.get_children():
		if c is CheckBox and c.button_pressed:
			enter.append(c.get_meta("resource"))
	_editing_prof.enter_conditions = enter

	var exit: Array[Logic] = []
	for c in _prof_exit_box.get_children():
		if c is CheckBox and c.button_pressed:
			exit.append(c.get_meta("resource"))
	_editing_prof.exit_conditions = exit

	var influences: Array[Logic] = []
	for c in _prof_infl_box.get_children():
		if c is CheckBox and c.button_pressed:
			influences.append(c.get_meta("resource"))
	_editing_prof.influences = influences


func _on_profile_save() -> void:
	if _prof_name_edit.text.strip_edges().is_empty():
		_set_prof_status("A profile needs a name.", true)
		return

	_apply_profile_form()

	if _editing_prof.influences.is_empty():
		_set_prof_status("A profile with no influences would freeze the ant — check at least one.", true)
		return

	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_INFLUENCE_PROFILE,
			_editing_prof.id, _editing_prof) \
			and _editing_prof.id != _id_of_path(_editing_prof_path):
		_set_prof_status("Another profile already uses the id '%s'." % _editing_prof.id, true)
		return

	var prev := _editing_prof_path if _editing_prof_path.begins_with("user://") else ""
	if ResourceLibrary.save_resource(_editing_prof, ResourceLibrary.KIND_INFLUENCE_PROFILE, prev) != OK:
		_set_prof_status("Save failed — see log.", true)
		return

	_editing_prof_path = _editing_prof.resource_path
	clear_dirty()
	toast_success("Saved profile '%s'" % _editing_prof.name)
	_set_prof_status("Saved. Ant roles referencing it use it immediately.", false)
#endregion


#region Shared helpers
func _delete_selected(list: ItemList, noun: String, after: Callable) -> void:
	var sel := list.get_selected_items()
	if sel.is_empty():
		return
	var entry: ResourceLibrary.Entry = list.get_item_metadata(sel[0])
	if not entry:
		return

	_confirm.dialog_text = "Delete %s '%s'?\nAnything referencing it will fail to load it next launch." % [
		noun, entry.resource.name]

	for conn in _confirm.confirmed.get_connections():
		_confirm.confirmed.disconnect(conn.callable)

	_confirm.confirmed.connect(func() -> void:
		var deleted_name: String = entry.resource.name
		ResourceLibrary.delete_resource(entry)
		after.call()
		toast_info("Deleted %s '%s'" % [noun, deleted_name])
	)
	_confirm.popup_centered()


func _ids_of(resources: Array) -> Dictionary:
	var out := {}
	for r in resources:
		if r and r.get("id"):
			out[r.id] = true
	return out


func _check_by_id(box: VBoxContainer, wanted: Dictionary) -> void:
	for c in box.get_children():
		if c is CheckBox:
			var res: Resource = c.get_meta("resource")
			c.set_pressed_no_signal(res != null and wanted.has(res.get("id")))


func _mk_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	return b


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _section(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	return l


func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.modulate = Color(1, 1, 1, 0.6)
	return l


func _id_of_path(path: String) -> String:
	return path.get_file().get_basename() if not path.is_empty() else ""


func _set_infl_status(text: String, is_error: bool) -> void:
	_infl_status.text = text
	_infl_status.add_theme_color_override("font_color",
		Color.INDIAN_RED if is_error else Color.SEA_GREEN)


func _set_prof_status(text: String, is_error: bool) -> void:
	_prof_status.text = text
	_prof_status.add_theme_color_override("font_color",
		Color.INDIAN_RED if is_error else Color.SEA_GREEN)
#endregion


## Ctrl+S saves whichever tab is visible.
func _confirm_shortcut() -> bool:
	if _tabs.current_tab == 0:
		_on_influence_save()
	else:
		_on_profile_save()
	return true
