class_name PheromoneLibraryPanel
extends ManagedWindow
## Runtime library + editor for Pheromone resources: deposit parameters
## (decay, generation, radius, diffusion), visualization colors, and the
## emit condition (picked from the cataloged Logic expressions, so it has
## already passed the validator gates).
##
## Persisted through ResourceLibrary (KIND_PHEROMONE) like every other
## behavior resource. Opened from AntDesignerPanel's "Manage..." button.
## Built entirely in code to match the project's runtime-UI convention.

var logger: iLogger

# Left pane
var _item_list: ItemList
var _new_btn: Button
var _dup_btn: Button
var _del_btn: Button

# Right pane (editor form)
var _name_edit: LineEdit
var _decay_spin: SpinBox
var _generating_spin: SpinBox
var _radius_spin: SpinBox
var _diffusion_spin: SpinBox
var _start_color_btn: ColorPickerButton
var _end_color_btn: ColorPickerButton
var _condition_select: OptionButton
var _test_result_label: Label
var _status: Label
var _save_btn: Button

var _confirm: ConfirmationDialog

# Working state
var _editing: Pheromone            # working copy being edited
var _editing_path: String = ""     # on-disk path (empty for brand-new)
## Name at load time; renaming orphans heat layers keyed by the old name
## and breaks expressions passing it to pheromone_direction(...), so the
## save handler warns when this differs from the new name.
var _loaded_name: String = ""


func _init() -> void:
	setup_window("pheromone_library", "Pheromone Library",
		Vector2i(620, 560), Vector2i(520, 460))
	logger = iLogger.new("pheromone_library", DebugLogger.Category.UI)


func _ready() -> void:
	_build_ui()
	_confirm = ConfirmationDialog.new()
	add_child(_confirm)
	ResourceLibrary.library_changed.connect(_on_library_changed)
	_populate_condition_options()
	_refresh_list()
	_new_pheromone()  # start on a blank pheromone so the form is never empty


#region UI construction
func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	root.add_child(_build_left_pane())

	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(right)
	right.add_child(_build_editor())

	watch([_name_edit, _decay_spin, _generating_spin, _radius_spin,
		_diffusion_spin, _condition_select])
	# ColorPickerButton is a toggle button — watch() would mark dirty just
	# for opening the picker, so hook the actual color change instead.
	_start_color_btn.color_changed.connect(func(_c: Color) -> void: mark_dirty())
	_end_color_btn.color_changed.connect(func(_c: Color) -> void: mark_dirty())


func _build_left_pane() -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(180, 0)
	vbox.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = "Pheromones"
	vbox.add_child(header)

	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	vbox.add_child(_item_list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	vbox.add_child(buttons)

	_new_btn = _mk_button("New", _new_pheromone)
	_dup_btn = _mk_button("Duplicate", _on_duplicate)
	_del_btn = _mk_button("Delete", _on_delete)
	buttons.add_child(_new_btn)
	buttons.add_child(_dup_btn)
	buttons.add_child(_del_btn)

	_new_btn.tooltip_text = "Start a blank pheromone"
	_dup_btn.tooltip_text = "Copy the current pheromone as a new editable one"
	_del_btn.tooltip_text = "Delete the selected pheromone"
	return vbox


func _build_editor() -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	vbox.add_child(_section("Identity"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "e.g. food"
	_name_edit.tooltip_text = "Also the heatmap key and the string expressions pass to pheromone_direction(...) — renaming affects both."
	vbox.add_child(_row("Name:", _name_edit))

	vbox.add_child(_section("Deposit"))
	_decay_spin = _mk_spin(0.0, 10.0, 0.01)
	vbox.add_child(_row("Decay rate:", _decay_spin))
	_generating_spin = _mk_spin(0.0, 200.0, 0.5)
	vbox.add_child(_row("Generating rate:", _generating_spin))
	_radius_spin = _mk_spin(0, 16, 1)
	vbox.add_child(_row("Heat radius (cells):", _radius_spin))
	_diffusion_spin = _mk_spin(0.0, 1.0, 0.05)
	_diffusion_spin.tooltip_text = "Higher = faster spreading, lower = more concentrated trails"
	vbox.add_child(_row("Diffusion rate:", _diffusion_spin))

	vbox.add_child(_section("Visualization"))
	_start_color_btn = ColorPickerButton.new()
	_start_color_btn.edit_alpha = true
	_start_color_btn.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(_row("Start color:", _start_color_btn))
	_end_color_btn = ColorPickerButton.new()
	_end_color_btn.edit_alpha = true
	_end_color_btn.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(_row("End color:", _end_color_btn))

	vbox.add_child(_section("Emit condition"))
	_condition_select = OptionButton.new()
	vbox.add_child(_row("Condition:", _condition_select))

	var test_row := HBoxContainer.new()
	test_row.add_theme_constant_override("separation", 8)
	var test_btn := _mk_button("Test on live ant", _on_test_pressed)
	test_btn.tooltip_text = "Evaluate the emit condition against the first live ant"
	test_row.add_child(test_btn)
	_test_result_label = Label.new()
	_test_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_row.add_child(_test_result_label)
	vbox.add_child(test_row)

	vbox.add_child(HSeparator.new())

	_save_btn = _mk_button("Save", _on_save)
	_save_btn.tooltip_text = "Save to user:// (Ctrl+S)"
	vbox.add_child(_save_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status)

	return vbox
#endregion


#region Small UI helpers
func _mk_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	return b


func _mk_spin(min_v: float, max_v: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size = Vector2(120, 0)
	return s


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
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
#endregion


#region Option pools & list
func _populate_condition_options() -> void:
	var previous: Logic = null
	if _condition_select.selected > 0:
		previous = _condition_select.get_item_metadata(_condition_select.selected)

	_condition_select.clear()
	_condition_select.add_item("(always emitting)")
	_condition_select.set_item_metadata(0, null)
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		var idx := _condition_select.item_count
		_condition_select.add_item(entry.display_name())
		_condition_select.set_item_metadata(idx, entry.resource)
		if previous and entry.resource.get("id") == previous.id:
			_condition_select.select(idx)


func _refresh_list() -> void:
	var previous: Resource = null
	var sel := _item_list.get_selected_items()
	if not sel.is_empty():
		var prev_entry: ResourceLibrary.Entry = _item_list.get_item_metadata(sel[0])
		previous = prev_entry.resource if prev_entry else null

	_item_list.clear()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_PHEROMONE):
		var idx := _item_list.add_item(entry.display_name())
		_item_list.set_item_metadata(idx, entry)
		_item_list.set_item_tooltip(idx, entry.path)
		if entry.resource == previous:
			_item_list.select(idx)


func _on_library_changed(kind: String) -> void:
	if kind == ResourceLibrary.KIND_PHEROMONE:
		_refresh_list()
	elif kind == ResourceLibrary.KIND_LOGIC:
		_populate_condition_options()
#endregion


#region Selection / New / Duplicate / Delete
func _on_item_selected(index: int) -> void:
	var entry: ResourceLibrary.Entry = _item_list.get_item_metadata(index)
	if not entry:
		return
	# Edit a working copy so closing without save never mutates the cataloged
	# resource (shared condition refs are fine — save re-references them).
	_editing = ResourceLibrary.duplicate_for_edit(entry.resource) as Pheromone
	_editing_path = entry.path
	_load_form_from(_editing)


func _new_pheromone() -> void:
	_editing = Pheromone.new()
	_editing.name = "New Pheromone"
	_editing.decay_rate = 0.1
	_editing.generating_rate = 10.0
	_editing.heat_radius = 2
	_editing.diffusion_rate = 0.5
	_editing.start_color = Color(1, 1, 1, 0.1)
	_editing.end_color = Color(1, 1, 1, 0.25)
	_editing.condition = null
	_editing_path = ""
	_item_list.deselect_all()
	_load_form_from(_editing)


func _on_duplicate() -> void:
	if not _editing:
		return
	var copy := ResourceLibrary.duplicate_for_edit(_editing) as Pheromone
	copy.name = "%s copy" % _editing.name
	_editing = copy
	_editing_path = ""
	_item_list.deselect_all()
	_load_form_from(_editing)
	_set_status("Duplicated — edit and Save to write a new pheromone.", false)


func _on_delete() -> void:
	var sel := _item_list.get_selected_items()
	if sel.is_empty():
		return

	var entry: ResourceLibrary.Entry = _item_list.get_item_metadata(sel[0])
	if not entry:
		return

	_confirm.dialog_text = "Delete pheromone '%s'?\nProfiles referencing it will fail to load it next launch;\nlive ants keep their in-memory copy until removed." % entry.resource.name

	for conn in _confirm.confirmed.get_connections():
		_confirm.confirmed.disconnect(conn.callable)

	_confirm.confirmed.connect(func() -> void:
		var deleted_name: String = entry.resource.name
		ResourceLibrary.delete_resource(entry)
		_new_pheromone()
		toast_info("Deleted pheromone '%s'" % deleted_name)
	)
	_confirm.popup_centered()
#endregion


#region Form <-> resource
func _load_form_from(p: Pheromone) -> void:
	_loaded_name = p.name
	_name_edit.text = p.name
	_decay_spin.value = p.decay_rate
	_generating_spin.value = p.generating_rate
	_radius_spin.value = p.heat_radius
	_diffusion_spin.value = p.diffusion_rate
	_start_color_btn.color = p.start_color
	_end_color_btn.color = p.end_color
	_select_condition(p.condition)
	_test_result_label.text = ""
	_set_status("", false)
	clear_dirty()


func _apply_form_to(p: Pheromone) -> void:
	p.name = _name_edit.text.strip_edges()           # setter re-derives id
	p.decay_rate = _decay_spin.value
	p.generating_rate = _generating_spin.value
	p.heat_radius = int(_radius_spin.value)
	p.diffusion_rate = _diffusion_spin.value
	p.start_color = _start_color_btn.color
	p.end_color = _end_color_btn.color
	p.condition = _condition_select.get_item_metadata(_condition_select.selected) \
		if _condition_select.selected >= 0 else null


func _select_condition(cond: Logic) -> void:
	_condition_select.select(0)
	if not cond:
		return
	for i in range(_condition_select.item_count):
		var meta = _condition_select.get_item_metadata(i)
		if meta and meta is Logic and meta.id == cond.id:
			_condition_select.select(i)
			return
#endregion


#region Test & save
func _on_test_pressed() -> void:
	var cond: Logic = _condition_select.get_item_metadata(_condition_select.selected) \
		if _condition_select.selected >= 0 else null
	if not cond:
		_test_result_label.text = "No condition — always emitting."
		return
	var ants: Array[Ant] = AntManager.get_all()
	if ants.is_empty():
		_test_result_label.text = "No live ants to test against."
		return
	var ant: Ant = ants[0]
	var result: Variant = EvaluationSystem.get_value(cond, ant)
	_test_result_label.text = "Ant #%d → %s  (would %semit)" % [
		ant.id, str(result), "" if result else "not "
	]


func _on_save() -> void:
	var name_text := _name_edit.text.strip_edges()
	if name_text.is_empty():
		_set_status("A pheromone needs a name.", true)
		return

	_apply_form_to(_editing)

	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_PHEROMONE, _editing.id, _editing) \
			and _editing.id != _id_of_path(_editing_path):
		_set_status("Another pheromone already uses the id '%s' — pick a different name." % _editing.id, true)
		return

	var prev := _editing_path if _editing_path.begins_with("user://") else ""
	if ResourceLibrary.save_resource(_editing, ResourceLibrary.KIND_PHEROMONE, prev) != OK:
		_set_status("Save failed — see log.", true)
		toast_error("Save failed — see log.")
		return

	var msg := "Saved pheromone '%s'. Profiles pick it up on next save/spawn." % _editing.name
	if not _loaded_name.is_empty() and _loaded_name != _editing.name:
		msg += "\nRenamed from '%s': existing heat under the old name will decay away, and any expression passing \"%s\" to pheromone_direction/concentration now reads an empty layer." % [
			_loaded_name, _loaded_name]
	_set_status(msg, false)

	clear_dirty()
	toast_success("Saved pheromone '%s'" % _editing.name)

	_editing_path = _editing.resource_path
	_loaded_name = _editing.name
#endregion


#region Utilities
func _id_of_path(path: String) -> String:
	return path.get_file().get_basename() if not path.is_empty() else ""


func _set_status(text: String, is_error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color",
		Color.INDIAN_RED if is_error else Color.SEA_GREEN)
#endregion


func _confirm_shortcut() -> bool:
	_on_save()
	return true
