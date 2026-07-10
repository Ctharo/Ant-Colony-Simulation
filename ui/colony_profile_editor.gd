class_name ColonyProfileEditor
extends ManagedWindow
## Runtime editor for ColonyProfile resources: colony parameters, the ant
## roles available to the colony (from the ResourceLibrary profile catalog),
## and per-role initial spawn counts.
##
## Migrated to the ManagedWindow pattern: built entirely in code (delete
## colony_profile_editor.tscn), geometry persistence, dirty tracking,
## Esc/Ctrl+S, and Cancel routed through _request_close() so unsaved edits
## get the discard confirmation instead of a silent queue_free().
##
## Persistence goes through ResourceLibrary (KIND_COLONY) — the old direct
## ResourceSaver path wrote into res://resources/profiles/colony/, which is
## read-only in exported builds and outside every catalog.
##
## Public API kept compatible with ColonyProfilePanel:
##   edit_profile(profile) / create_new_profile(), `closed(result)` signal
##   (result = the saved ColonyProfile, or null if closed without saving).

signal closed(result: Variant)

var editing_profile: ColonyProfile
var _editing_path: String = ""
var _saved_result: ColonyProfile = null

# Form controls
var _name_edit: LineEdit
var _radius_spin: SpinBox
var _max_ants_spin: SpinBox
var _spawn_rate_spin: SpinBox
var _dirt_color_btn: ColorPickerButton
var _darker_dirt_btn: ColorPickerButton
var _roles_box: VBoxContainer
var _status: Label

var logger: iLogger


func _init() -> void:
	setup_window("colony_profile_editor", "Colony Profile",
		Vector2i(460, 560), Vector2i(400, 460))
	logger = iLogger.new("colony_profile_editor", DebugLogger.Category.UI)


#region Public API
func edit_profile(profile: ColonyProfile) -> void:
	# Work on a copy so closing without save never mutates the cataloged
	# resource; save re-references shared AntProfiles.
	editing_profile = ResourceLibrary.duplicate_for_edit(profile) as ColonyProfile
	_editing_path = profile.resource_path
	set_window_title("Edit Colony Profile: %s" % profile.name)
	_build_ui()
	_load_form()
	present()


func create_new_profile() -> void:
	editing_profile = ColonyProfile.new()
	editing_profile.name = "New Colony"
	_editing_path = ""
	set_window_title("New Colony Profile")
	_build_ui()
	_load_form()
	present()
#endregion


#region UI construction
func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "e.g. Standard Colony"
	vbox.add_child(_row("Name:", _name_edit))

	vbox.add_child(_section("Parameters"))
	_radius_spin = _mk_spin("colony_radius", 60.0)
	vbox.add_child(_row("Radius:", _radius_spin))
	_max_ants_spin = _mk_spin("max_ants", 25)
	vbox.add_child(_row("Max ants:", _max_ants_spin))
	_spawn_rate_spin = _mk_spin("spawn_rate", 10.0)
	vbox.add_child(_row("Spawn rate (s):", _spawn_rate_spin))

	vbox.add_child(_section("Appearance"))
	_dirt_color_btn = ColorPickerButton.new()
	_dirt_color_btn.edit_alpha = true
	_dirt_color_btn.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(_row("Dirt color:", _dirt_color_btn))
	_darker_dirt_btn = ColorPickerButton.new()
	_darker_dirt_btn.edit_alpha = true
	_darker_dirt_btn.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(_row("Darker dirt:", _darker_dirt_btn))

	vbox.add_child(_section("Ant roles"))
	var hint := Label.new()
	hint.text = "Checked roles are available to the colony; the count is how many spawn initially."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

	_roles_box = VBoxContainer.new()
	vbox.add_child(_roles_box)
	_populate_role_rows()

	vbox.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.tooltip_text = "Save to the colony library (Ctrl+S)"
	save_btn.pressed.connect(_on_save)
	buttons.add_child(save_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_request_close)
	buttons.add_child(cancel_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status)

	watch([_name_edit, _radius_spin, _max_ants_spin, _spawn_rate_spin])
	_dirt_color_btn.color_changed.connect(func(_c: Color) -> void: mark_dirty())
	_darker_dirt_btn.color_changed.connect(func(_c: Color) -> void: mark_dirty())

	ResourceLibrary.library_changed.connect(_on_library_changed)


func _populate_role_rows() -> void:
	for child in _roles_box.get_children():
		child.queue_free()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_PROFILE):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var check := CheckBox.new()
		check.text = entry.display_name()
		check.tooltip_text = entry.path
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.set_meta("resource", entry.resource)
		row.add_child(check)

		var count := SpinBox.new()
		count.min_value = 0
		count.max_value = 100
		count.step = 1
		count.custom_minimum_size = Vector2(90, 0)
		count.editable = false
		count.tooltip_text = "Initial ants of this role"
		row.add_child(count)

		check.toggled.connect(func(on: bool) -> void:
			count.editable = on
			mark_dirty()
		)
		count.value_changed.connect(func(_v: float) -> void: mark_dirty())

		row.set_meta("check", check)
		row.set_meta("count", count)
		_roles_box.add_child(row)


func _on_library_changed(kind: String) -> void:
	if kind != ResourceLibrary.KIND_PROFILE:
		return
	_populate_role_rows()
	if editing_profile:
		_apply_role_rows.call_deferred()
#endregion


#region Form <-> resource
func _load_form() -> void:
	_name_edit.text = editing_profile.name
	_radius_spin.value = editing_profile.radius
	_max_ants_spin.value = editing_profile.max_ants
	_spawn_rate_spin.value = editing_profile.spawn_rate
	_dirt_color_btn.color = editing_profile.dirt_color
	_darker_dirt_btn.color = editing_profile.darker_dirt
	_apply_role_rows()
	_status.text = ""
	clear_dirty()


## Checks roles by id (with the same name fallback the other panels use, so
## colonies still holding pre-migration res:// references show correctly and
## upgrade on the next save).
func _apply_role_rows() -> void:
	var wanted_ids := {}
	for ap: AntProfile in editing_profile.ant_profiles:
		if ap:
			wanted_ids[ap.id] = true
			wanted_ids[ap.name.to_snake_case()] = true
	for row in _roles_box.get_children():
		var check: CheckBox = row.get_meta("check")
		var count: SpinBox = row.get_meta("count")
		var res: AntProfile = check.get_meta("resource")
		var on: bool = res and wanted_ids.has(res.id)
		check.set_pressed_no_signal(on)
		count.editable = on
		count.set_value_no_signal(editing_profile.initial_ants.get(res.id, 0) if res else 0)


func _apply_form() -> void:
	editing_profile.name = _name_edit.text.strip_edges()  # setter re-derives id
	editing_profile.radius = _radius_spin.value
	editing_profile.max_ants = int(_max_ants_spin.value)
	editing_profile.spawn_rate = _spawn_rate_spin.value
	editing_profile.dirt_color = _dirt_color_btn.color
	editing_profile.darker_dirt = _darker_dirt_btn.color

	var roles: Array[AntProfile] = []
	var initial := {}
	for row in _roles_box.get_children():
		var check: CheckBox = row.get_meta("check")
		var count: SpinBox = row.get_meta("count")
		if not check.button_pressed:
			continue
		var res: AntProfile = check.get_meta("resource")
		if not res:
			continue
		roles.append(res)
		if int(count.value) > 0:
			initial[res.id] = int(count.value)
	editing_profile.ant_profiles = roles
	editing_profile.initial_ants = initial
#endregion


#region Save / close
func _on_save() -> void:
	var name_text := _name_edit.text.strip_edges()
	if name_text.is_empty():
		_set_status("A colony profile needs a name.", true)
		return

	_apply_form()

	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_COLONY,
			editing_profile.id, editing_profile) \
			and editing_profile.id != _id_of_path(_editing_path):
		_set_status("Another colony already uses the id '%s' — pick a different name." % editing_profile.id, true)
		return

	var prev := _editing_path if _editing_path.begins_with("user://behavior/") else ""
	if ResourceLibrary.save_resource(editing_profile, ResourceLibrary.KIND_COLONY, prev) != OK:
		_set_status("Save failed — see log.", true)
		toast_error("Save failed — see log.")
		return

	_saved_result = editing_profile
	_editing_path = editing_profile.resource_path
	clear_dirty()
	Toast.success(get_parent(), "Saved colony '%s'" % editing_profile.name)
	_request_close()


func _close_now() -> void:
	closed.emit(_saved_result)
	super()


func _confirm_shortcut() -> bool:
	_on_save()
	return true
#endregion


#region Small UI helpers
func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130, 0)
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


## SpinBox constrained by SettingsManager's SETTING_CONSTRAINTS.
func _mk_spin(constraint_key: String, fallback: float) -> SpinBox:
	var s := SpinBox.new()
	var c: Dictionary = SettingsManager.get_constraints(constraint_key)
	s.min_value = c.get("min", 0.0)
	s.max_value = c.get("max", 1000.0)
	s.step = c.get("step", 1.0)
	s.value = fallback
	s.custom_minimum_size = Vector2(110, 0)
	return s


func _id_of_path(path: String) -> String:
	return path.get_file().get_basename() if not path.is_empty() else ""


func _set_status(text: String, is_error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color",
		Color.INDIAN_RED if is_error else Color.SEA_GREEN)
#endregion
