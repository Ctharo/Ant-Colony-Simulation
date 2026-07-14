class_name RuleEditorPopup
extends ManagedWindow
## Runtime editor for AntRule resources — presented to the user as the
## "Behavior Editor". A Behavior = condition + action + priority. Display-
## layer rename only: the class, ResourceLibrary.KIND_RULE, the window id
## "rule_editor" (kept so saved window geometry survives), and all .tres
## files are unchanged.
##
## CONDITION MODES (Maintainerr-style: matching criteria on top, action
## below):
## - None      — the behavior always fires.
## - Builder   — an embedded ConditionBuilder. On save the compiled
##               expression is persisted as a Logic resource OWNED by this
##               behavior (named "<behavior> condition", builder_data set),
##               saved to the library BEFORE the behavior itself — leaves
##               before parents, so the condition is never embedded as a
##               subresource.
## - Library   — pick an existing library expression (the pre-builder
##               behavior; also the reuse path for shared conditions).
##
## DIVERGENCE: builder_data is editor metadata; expression_string is the
## runtime truth. If a builder-authored condition's raw expression was
## hand-edited afterwards (or the vocabulary changed how rows compile),
## opening it here recompiles builder_data headlessly, compares, and shows
## a warning: the raw expression is what runs, and saving from the builder
## will overwrite it.

signal saved(resource: AntRule)

enum CondMode { NONE, BUILDER, LIBRARY }

const COND_MODE_LABELS: Array[String] = [
	"(none — always fires)",
	"Build conditions",
	"Use library expression",
]

var editing: AntRule
var _previous_path: String = ""

var _name_edit: LineEdit
var _cond_mode_select: OptionButton
var _divergence_banner: Label
var _builder: ConditionBuilder
var _library_row: HBoxContainer
var _condition_select: OptionButton
var _action_select: OptionButton
var _priority_spin: SpinBox
var _enabled_check: CheckBox
var _desc_edit: LineEdit
var _status: Label


func _init() -> void:
	setup_window("rule_editor", "Behavior Editor",
		Vector2i(760, 680), Vector2i(640, 560))


func open_for(res: Resource, path: String, writable: bool) -> void:
	_previous_path = path if writable else ""
	editing = ResourceLibrary.duplicate_for_edit(res) if not path.is_empty() else res
	_build_ui(not path.is_empty() and not writable)
	present()


func _build_ui(is_builtin: bool) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	if is_builtin:
		var banner := Label.new()
		banner.text = "Built-in resource — saving creates an editable copy in user://"
		banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner.add_theme_color_override("font_color", Color.GOLD)
		vbox.add_child(banner)

	_name_edit = LineEdit.new()
	_name_edit.text = editing.name
	vbox.add_child(_labeled_row("Name:", _name_edit))

	# --- Condition block (Maintainerr layout: criteria first) ---
	_cond_mode_select = OptionButton.new()
	for label in COND_MODE_LABELS:
		_cond_mode_select.add_item(label)
	_cond_mode_select.item_selected.connect(func(_i: int) -> void: _sync_cond_mode())
	vbox.add_child(_labeled_row("Condition:", _cond_mode_select))

	_divergence_banner = Label.new()
	_divergence_banner.text = "⚠ This condition's raw expression was edited outside the builder — the raw expression is what currently runs. Saving from the builder will overwrite it with the compiled rows below."
	_divergence_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_divergence_banner.add_theme_color_override("font_color", Color.GOLD)
	_divergence_banner.add_theme_font_size_override("font_size", 11)
	_divergence_banner.visible = false
	vbox.add_child(_divergence_banner)

	_builder = ConditionBuilder.new()
	_builder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_builder.changed.connect(func() -> void:
		mark_dirty()
		# Any builder edit supersedes the hand-edited state — the warning
		# has served its purpose once the user starts rebuilding.
		_divergence_banner.visible = false
	)
	vbox.add_child(_builder)

	_library_row = HBoxContainer.new()
	_library_row.add_theme_constant_override("separation", 6)
	var lib_label := Label.new()
	lib_label.text = "Expression:"
	lib_label.custom_minimum_size = Vector2(90, 0)
	_library_row.add_child(lib_label)
	_condition_select = OptionButton.new()
	_condition_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_LOGIC):
		_condition_select.add_item(entry.display_name())
		_condition_select.set_item_metadata(_condition_select.item_count - 1, entry.resource)
		if editing.condition and entry.resource.id == editing.condition.id:
			_condition_select.select(_condition_select.item_count - 1)
	_library_row.add_child(_condition_select)
	vbox.add_child(_library_row)

	# --- Action block ---
	_action_select = OptionButton.new()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_ACTION):
		_action_select.add_item(entry.display_name())
		_action_select.set_item_metadata(_action_select.item_count - 1, entry.resource)
		if editing.action and entry.resource.id == editing.action.id:
			_action_select.select(_action_select.item_count - 1)
	vbox.add_child(_labeled_row("Action:", _action_select))

	_priority_spin = SpinBox.new()
	_priority_spin.min_value = -100
	_priority_spin.max_value = 100
	_priority_spin.value = editing.priority
	vbox.add_child(_labeled_row("Priority:", _priority_spin))

	_enabled_check = CheckBox.new()
	_enabled_check.button_pressed = editing.enabled
	vbox.add_child(_labeled_row("Enabled:", _enabled_check))

	_desc_edit = LineEdit.new()
	_desc_edit.text = editing.description
	vbox.add_child(_labeled_row("Description:", _desc_edit))

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color.INDIAN_RED)
	vbox.add_child(_status)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 6)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save)
	button_row.add_child(save_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(queue_free)
	button_row.add_child(cancel_btn)
	vbox.add_child(button_row)

	_name_edit.tooltip_text = "Unique name; the id is derived from it"
	_cond_mode_select.tooltip_text = "When this behavior may fire: always, when the built conditions pass, or when a shared library expression is true"
	_condition_select.tooltip_text = "Existing library expression gating this behavior (reusable across behaviors)"
	_action_select.tooltip_text = "Action executed when the condition passes"
	_priority_spin.tooltip_text = "Higher priority behaviors are evaluated first; first passing behavior acts"
	_enabled_check.tooltip_text = "Disabled behaviors stay in the profile but are skipped at runtime"
	_desc_edit.tooltip_text = "Shown in library lists and profile editors"

	watch([_name_edit, _cond_mode_select, _condition_select, _action_select,
		_priority_spin, _enabled_check, _desc_edit])

	_init_condition_mode()


## Picks the starting mode from the existing condition and, for builder-
## authored conditions, loads the rows and runs divergence detection.
func _init_condition_mode() -> void:
	var mode := CondMode.NONE
	if editing.condition:
		mode = CondMode.BUILDER if not editing.condition.builder_data.is_empty() \
			else CondMode.LIBRARY

	if mode == CondMode.BUILDER:
		_builder.load_data(editing.condition.builder_data)
		# expression_string is authoritative; if it no longer matches what
		# the rows compile to (hand edit, or vocabulary changes altered
		# compilation), warn before the user unknowingly overwrites it.
		var recompiled := _builder.get_expression().strip_edges()
		_divergence_banner.visible = \
			recompiled != editing.condition.expression_string.strip_edges()
		clear_dirty()  # load_data emitted changed; opening isn't an edit

	_cond_mode_select.select(mode)
	_sync_cond_mode()


func _sync_cond_mode() -> void:
	var mode := _cond_mode_select.selected
	_builder.visible = mode == CondMode.BUILDER
	_library_row.visible = mode == CondMode.LIBRARY
	if mode != CondMode.BUILDER:
		_divergence_banner.visible = false


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


func _on_save() -> void:
	editing.name = _name_edit.text.strip_edges()
	if editing.id.is_empty():
		_status.text = "Name is required."
		return
	if ResourceLibrary.has_id_conflict(ResourceLibrary.KIND_RULE, editing.id, editing):
		_status.text = "Another behavior already uses the id '%s'." % editing.id
		return
	if _action_select.selected < 0:
		_status.text = "A behavior needs an action."
		return

	match _cond_mode_select.selected:
		CondMode.NONE:
			editing.condition = null
		CondMode.LIBRARY:
			if _condition_select.selected < 0:
				_status.text = "Pick a library expression, or switch the condition to none/builder."
				return
			editing.condition = _condition_select.get_item_metadata(_condition_select.selected)
		CondMode.BUILDER:
			if not _save_builder_condition():
				return  # _status already set

	editing.action = _action_select.get_item_metadata(_action_select.selected)
	editing.priority = int(_priority_spin.value)
	editing.enabled = _enabled_check.button_pressed
	editing.description = _desc_edit.text

	if ResourceLibrary.save_resource(editing, ResourceLibrary.KIND_RULE, _previous_path) != OK:
		_status.text = "Save failed — see log."
		toast_error("Save failed — see log.")
		return

	# Priority may have changed: re-sort live behavior managers
	for ant: Ant in AntManager.get_all():
		if ant.behavior_manager:
			ant.behavior_manager.resort()

	saved.emit(editing)
	clear_dirty()
	Toast.success(get_parent(), "Saved behavior '%s'" % editing.name)
	_request_close()


## Compiles the builder rows into the behavior's condition Logic and saves
## it to the library FIRST (leaves before parents — the behavior must
## reference an already-on-disk condition, never embed it). Returns false
## with _status set on any failure.
func _save_builder_condition() -> bool:
	if _builder.is_empty():
		# No rows == always true == null condition (existing semantics).
		editing.condition = null
		return true

	var errors := _builder.get_errors()
	if not errors.is_empty():
		_status.text = "Condition is invalid:\n%s" % "\n".join(errors)
		return false

	var cond: Logic
	var cond_prev := ""
	if editing.condition and not editing.condition.builder_data.is_empty():
		# This behavior already owns a builder-authored condition: update it
		# in place (same id/name/eval policy). Work on a copy so live ants
		# see nothing until the save lands; a built-in forks to user://.
		cond_prev = editing.condition.resource_path \
			if editing.condition.resource_path.begins_with("user://") else ""
		cond = ResourceLibrary.duplicate_for_edit(editing.condition)
	else:
		# Converting from none/library: mint a fresh condition owned by
		# this behavior. A library condition picked earlier is NOT touched
		# — shared expressions stay shared.
		cond = _make_condition_resource()

	cond.expression_string = _builder.get_expression()
	cond.builder_data = _builder.to_data()
	cond.type = TYPE_BOOL

	if ResourceLibrary.save_resource(cond, ResourceLibrary.KIND_LOGIC, cond_prev) != OK:
		_status.text = "Saving the condition expression failed — see log."
		toast_error("Save failed — see log.")
		return false

	# Drop parsed states/caches so live ants pick up the new expression.
	EvaluationSystem.invalidate_expression(cond.id)

	editing.condition = cond
	return true


## New builder-owned condition, named after the behavior with id-conflict
## dedupe ("forage condition", "forage condition 2", ...). It shows up in
## the Expressions list like any other Logic — the catalog stays unified.
func _make_condition_resource() -> Logic:
	var cond := Logic.new()
	var base := "%s condition" % editing.name
	var candidate := base
	var n := 2
	while ResourceLibrary.has_id_conflict(
			ResourceLibrary.KIND_LOGIC, candidate.to_snake_case(), cond):
		candidate = "%s %d" % [base, n]
		n += 1
	cond.name = candidate
	cond.description = "Built with the condition builder for behavior '%s'." % editing.name
	return cond
