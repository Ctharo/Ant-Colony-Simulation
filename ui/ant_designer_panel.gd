class_name AntDesignerPanel
extends ManagedWindow
## Designs ant *types/roles*: an AntProfile bundles a name (role), combat
## and movement stats, and the BehaviorProfile that is its complete decision
## surface (behaviors, priorities, channels). Profiles are persisted through
## ResourceLibrary (KIND_PROFILE) exactly like the Behavior Library's other
## resources.
##
## E2: the influence-profile and behavior-rule checklists are gone — both
## composition axes collapsed into the single behavior_profile reference.
## The per-role pheromone checklist is gone too: emission is authored as
## signaling behaviors and heat layers register from the full catalog
## (AntProfile.pheromones is deprecated); the Manage... entry point into
## the Pheromone Library survives.
##
## Opened from the sandbox debug menu ("Ant Roles"). Built entirely in code to
## match the project's runtime-UI convention (no separate .tscn).

const ROLE_TYPES: Array[String] = ["worker", "soldier", "scout", "custom"]

var logger: iLogger

# Left pane
var _profile_list: ItemList
var _new_btn: Button
var _dup_btn: Button
var _del_btn: Button

# Right pane (editor form)
var _name_edit: LineEdit
var _role_select: OptionButton
var _move_spin: SpinBox
var _vision_spin: SpinBox
var _size_spin: SpinBox
var _health_spin: SpinBox
var _damage_spin: SpinBox
var _cooldown_spin: SpinBox
var _combatant_check: CheckBox
var _spawn_select: OptionButton
var _behavior_profile_select: OptionButton
var _status: Label
var _save_btn: Button

var _confirm: ConfirmationDialog

# Working state
var _editing: AntProfile           # the live resource being edited
var _editing_path: String = ""     # on-disk path (empty for brand-new)
var _editing_writable: bool = true


func _init() -> void:
	setup_window("ant_designer", "Ant Designer",
		Vector2i(720, 640), Vector2i(560, 480))
	logger = iLogger.new("ant_designer", DebugLogger.Category.UI)


func _ready() -> void:
	_build_ui()
	_confirm = ConfirmationDialog.new()
	add_child(_confirm)
	ResourceLibrary.library_changed.connect(_on_library_changed)
	_refresh_profile_list()
	_new_profile()  # start on a blank role so the form is never empty


#region UI construction
func _build_ui() -> void:
	var root: HBoxContainer = HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	root.add_child(_build_left_pane())

	var right: ScrollContainer = ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(right)
	right.add_child(_build_editor())

	watch([_name_edit, _role_select, _move_spin, _vision_spin, _size_spin,
		_health_spin, _damage_spin, _cooldown_spin, _combatant_check,
		_spawn_select, _behavior_profile_select])


func _build_left_pane() -> Control:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(200, 0)
	vbox.add_theme_constant_override("separation", 6)

	var header: Label = Label.new()
	header.text = "Roles"
	vbox.add_child(header)

	_profile_list = ItemList.new()
	_profile_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_profile_list.item_selected.connect(_on_profile_selected)
	vbox.add_child(_profile_list)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	vbox.add_child(buttons)

	_new_btn = _mk_button("New", _new_profile)
	_dup_btn = _mk_button("Duplicate", _on_duplicate)
	_del_btn = _mk_button("Delete", _on_delete)
	buttons.add_child(_new_btn)
	buttons.add_child(_dup_btn)
	buttons.add_child(_del_btn)
	return vbox


func _build_editor() -> Control:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	vbox.add_child(_section("Identity"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "e.g. Soldier"
	vbox.add_child(_row("Name:", _name_edit))

	_role_select = OptionButton.new()
	for role: String in ROLE_TYPES:
		_role_select.add_item(role.capitalize())
	vbox.add_child(_row("Role type:", _role_select))

	vbox.add_child(_section("Stats"))
	_move_spin = _mk_spin(1.0, 200.0, 0.5)
	vbox.add_child(_row("Movement rate:", _move_spin))
	_vision_spin = _mk_spin(10.0, 500.0, 5.0)
	vbox.add_child(_row("Vision range:", _vision_spin))
	_size_spin = _mk_spin(0.25, 4.0, 0.05)
	vbox.add_child(_row("Size:", _size_spin))
	_health_spin = _mk_spin(1.0, 1000.0, 5.0)
	vbox.add_child(_row("Max health:", _health_spin))

	vbox.add_child(_section("Combat"))
	_combatant_check = CheckBox.new()
	_combatant_check.text = "Can attack"
	vbox.add_child(_combatant_check)
	_damage_spin = _mk_spin(0.0, 200.0, 1.0)
	vbox.add_child(_row("Attack damage:", _damage_spin))
	_cooldown_spin = _mk_spin(0.1, 10.0, 0.1)
	vbox.add_child(_row("Attack cooldown (s):", _cooldown_spin))

	vbox.add_child(_section("Spawning"))
	_spawn_select = OptionButton.new()
	vbox.add_child(_row("Spawn condition:", _spawn_select))
	_populate_spawn_options()

	# The decision surface: one reference replaces the old influence-profile
	# and behavior-rule checklists.
	vbox.add_child(_section("Behavior"))
	var bp_hint: Label = Label.new()
	bp_hint.text = "The role's full decision surface: behaviors, priorities, channels."
	bp_hint.add_theme_font_size_override("font_size", 11)
	bp_hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(bp_hint)
	_behavior_profile_select = OptionButton.new()
	_behavior_profile_select.tooltip_text = "Behavior profiles are authored in the Behavior Designer"
	vbox.add_child(_row("Behavior profile:", _behavior_profile_select))
	_populate_behavior_profile_options()

	# Pheromone CRUD entry point stays; the per-role checklist is gone —
	# emission is authored as signaling behaviors now, and heat layers
	# register from the full catalog (AntProfile.pheromones is deprecated).
	var pher_header: HBoxContainer = HBoxContainer.new()
	pher_header.add_theme_constant_override("separation", 8)
	var pher_label: Control = _section("Pheromones")
	pher_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pher_header.add_child(pher_label)
	var manage_btn: Button = _mk_button("Manage...", _on_manage_pheromones)
	manage_btn.tooltip_text = "Create and edit pheromones in the Pheromone Library"
	pher_header.add_child(manage_btn)
	vbox.add_child(pher_header)

	var pher_hint: Label = Label.new()
	pher_hint.text = "Deposit parameters live in the Pheromone Library; emission is a signaling behavior."
	pher_hint.add_theme_font_size_override("font_size", 11)
	pher_hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(pher_hint)

	vbox.add_child(HSeparator.new())

	_save_btn = _mk_button("Save", _on_save)
	vbox.add_child(_save_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status)

	_new_btn.tooltip_text = "Start a blank role"
	_dup_btn.tooltip_text = "Copy the current role as a new editable one"
	_del_btn.tooltip_text = "Delete the selected role (built-ins can't be deleted)"
	_save_btn.tooltip_text = "Save to user:// and push to live ants (Ctrl+S)"

	return vbox
#endregion


#region Small UI helpers
func _mk_button(text: String, handler: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(handler)
	return b


func _mk_spin(min_v: float, max_v: float, step: float) -> SpinBox:
	var s: SpinBox = SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size = Vector2(120, 0)
	return s


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _section(text: String) -> Control:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	return l
#endregion


#region Catalog-fed option pools
func _populate_spawn_options() -> void:
	_spawn_select.clear()
	_spawn_select.add_item("(never — placed only as initial ants)")
	_spawn_select.set_item_metadata(0, null)
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		var idx: int = _spawn_select.item_count
		_spawn_select.add_item(entry.display_name())
		_spawn_select.set_item_metadata(idx, entry.resource)


func _populate_behavior_profile_options() -> void:
	_behavior_profile_select.clear()
	_behavior_profile_select.add_item("(none — ant idles)")
	_behavior_profile_select.set_item_metadata(0, null)
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_BEHAVIOR_PROFILE):
		var idx: int = _behavior_profile_select.item_count
		_behavior_profile_select.add_item(entry.display_name())
		_behavior_profile_select.set_item_metadata(idx, entry.resource)


func _on_manage_pheromones() -> void:
	var panel: PheromoneLibraryPanel = PheromoneLibraryPanel.new()
	add_child(panel)
	panel.present()
#endregion


#region Profile list
func _refresh_profile_list() -> void:
	_profile_list.clear()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_PROFILE):
		var idx: int = _profile_list.add_item(entry.display_name())
		_profile_list.set_item_metadata(idx, entry)
		_profile_list.set_item_tooltip(idx, entry.path)


func _on_library_changed(kind: String) -> void:
	match kind:
		ResourceLibrary.KIND_PROFILE:
			_refresh_profile_list()
		ResourceLibrary.KIND_LOGIC:
			_populate_spawn_options()
			if _editing:
				_select_spawn(_editing.spawn_condition)
		ResourceLibrary.KIND_BEHAVIOR_PROFILE:
			_populate_behavior_profile_options()
			if _editing:
				_select_behavior_profile(_editing.behavior_profile)


func _on_profile_selected(index: int) -> void:
	var entry: ResourceLibrary.Entry = _profile_list.get_item_metadata(index)
	if not entry:
		return
	# Edit a working copy so cancelling (closing without save) never mutates
	# the cataloged resource. Shared nested refs are fine — save re-embeds them.
	_editing = ResourceLibrary.duplicate_for_edit(entry.resource) as AntProfile
	_editing_path = entry.path
	_editing_writable = entry.writable
	_load_form_from(_editing)
#endregion


#region New / duplicate / delete
func _new_profile() -> void:
	_editing = AntProfile.new()
	_editing.name = "New Role"
	_editing.movement_rate = 25.0
	_editing.vision_range = 100.0
	_editing.size = 1.0
	_editing.max_health = 100.0
	_editing.attack_damage = 0.0
	_editing.attack_cooldown = 0.8
	_editing.is_combatant = false
	_editing.role_type = "worker"
	_editing_path = ""
	_editing_writable = true
	_profile_list.deselect_all()
	_load_form_from(_editing)


func _on_duplicate() -> void:
	if not _editing:
		return
	var copy: AntProfile = ResourceLibrary.duplicate_for_edit(_editing) as AntProfile
	copy.name = "%s copy" % _editing.name
	_editing = copy
	_editing_path = ""
	_editing_writable = true
	_profile_list.deselect_all()
	_load_form_from(_editing)
	_set_status("Duplicated — edit and Save to write a new role.", false)


func _on_delete() -> void:
	var sel: PackedInt32Array = _profile_list.get_selected_items()

	if sel.is_empty():
		return

	var entry: ResourceLibrary.Entry = _profile_list.get_item_metadata(sel[0])

	if not entry or not entry.writable:
		_set_status("Built-in roles can't be deleted (duplicate to make an editable copy).", true)
		return
	_confirm.dialog_text = "Delete role '%s'?\nLive ants keep their in-memory copy until removed." % entry.resource.name

	for conn: Dictionary in _confirm.confirmed.get_connections():
		_confirm.confirmed.disconnect(conn.callable)

	_confirm.confirmed.connect(func() -> void:
		var deleted_name: String = entry.resource.name
		ResourceLibrary.delete_resource(entry)
		_new_profile()
		toast_info("Deleted role '%s'" % deleted_name)
	)
	_confirm.popup_centered()
#endregion


#region Form <-> resource
func _load_form_from(p: AntProfile) -> void:
	_name_edit.text = p.name
	_select_option_text(_role_select, p.role_type)
	_move_spin.value = p.movement_rate
	_vision_spin.value = p.vision_range
	_size_spin.value = p.size if p.size > 0.0 else 1.0
	_health_spin.value = p.max_health if p.max_health > 0.0 else 100.0
	_combatant_check.button_pressed = p.is_combatant
	_damage_spin.value = p.attack_damage
	_cooldown_spin.value = p.attack_cooldown if p.attack_cooldown > 0.0 else 0.8

	_select_behavior_profile(p.behavior_profile)

	_select_spawn(p.spawn_condition)
	_set_status("", false)
	_save_btn.disabled = false

	clear_dirty()


func _apply_form_to(p: AntProfile) -> void:
	p.name = _name_edit.text.strip_edges()           # setter re-derives id
	p.role_type = ROLE_TYPES[_role_select.selected]
	p.movement_rate = _move_spin.value
	p.vision_range = _vision_spin.value
	p.size = _size_spin.value
	p.max_health = _health_spin.value
	p.is_combatant = _combatant_check.button_pressed
	p.attack_damage = _damage_spin.value
	p.attack_cooldown = _cooldown_spin.value

	p.behavior_profile = _behavior_profile_select.get_item_metadata(_behavior_profile_select.selected) \
		if _behavior_profile_select.selected >= 0 else null

	p.spawn_condition = _spawn_select.get_item_metadata(_spawn_select.selected) \
		if _spawn_select.selected >= 0 else null
#endregion


#region Save
func _on_save() -> void:
	var name_text: String = _name_edit.text.strip_edges()
	if name_text.is_empty():
		_set_status("A role needs a name.", true)
		return

	_apply_form_to(_editing)

	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_PROFILE, _editing.id, _editing) \
			and _editing.id != _id_of_path(_editing_path):
		_set_status("Another role already uses the id '%s' — pick a different name." % _editing.id, true)
		return

	var prev: String = _editing_path if _editing_path.begins_with("user://") else ""
	if ResourceLibrary.save_resource(_editing, ResourceLibrary.KIND_PROFILE, prev) != OK:
		_set_status("Save failed — see log.", true)
		return

	_apply_to_live_ants(_editing)
	_set_status("Saved role '%s'. New ants of this role use it immediately." % _editing.name, false)

	clear_dirty()
	toast_success("Saved role '%s'" % _editing.name)

	# Re-select the freshly saved entry so further edits target it.
	_editing_path = _editing.resource_path
	_editing_writable = true


## Best-effort live update: any ant whose role matches this profile's id
## gets the new decision surface and stats without needing a respawn.
## A null behavior_profile idles the ant (the manager handles it silently
## here; the spawn path warns once).
func _apply_to_live_ants(p: AntProfile) -> void:
	var updated: int = 0
	for ant: Ant in AntManager.get_all():
		if ant.role != p.id:
			continue
		if ant.behavior_manager:
			ant.behavior_manager.set_profile(p.behavior_profile)
		ant.attack_damage = p.attack_damage
		ant.attack_cooldown = p.attack_cooldown
		ant.is_combatant = p.is_combatant
		ant.max_health = p.max_health
		updated += 1
	if updated > 0:
		logger.info("Applied role '%s' to %d live ant(s)" % [p.id, updated])
#endregion


#region Selection utilities
func _select_option_text(option: OptionButton, value: String) -> void:
	for i: int in range(option.item_count):
		if option.get_item_text(i).to_lower() == value.to_lower():
			option.select(i)
			return
	option.select(ROLE_TYPES.size() - 1)  # "custom"


func _select_spawn(cond: Logic) -> void:
	_spawn_select.select(0)
	if not cond:
		return
	for i: int in range(_spawn_select.item_count):
		var meta: Variant = _spawn_select.get_item_metadata(i)
		if meta and meta is Logic and meta.id == cond.id:
			_spawn_select.select(i)
			return


func _select_behavior_profile(bp: BehaviorProfile) -> void:
	_behavior_profile_select.select(0)
	if not bp:
		return
	for i: int in range(_behavior_profile_select.item_count):
		var meta: Variant = _behavior_profile_select.get_item_metadata(i)
		if meta and meta is BehaviorProfile and meta.id == bp.id:
			_behavior_profile_select.select(i)
			return


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
