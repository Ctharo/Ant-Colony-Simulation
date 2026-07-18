class_name BehaviorGraphEditorPopup
extends ManagedWindow
## Graph-based runtime editor for AntRule resources — the full replacement
## for RuleEditorPopup (Batch C; RuleEditorPopup and the row-based
## ConditionBuilder are retired). A Behavior keeps its shape: condition +
## action + priority — the graph IS the condition; action, priority,
## enabled, and description live in the form bar above it.
##
## CONDITION SEMANTICS
## - The graph must contain exactly ONE ⚡ Output node; whatever is wired
##   into it is the condition result.
## - An EMPTY graph (only the pre-placed Output, nothing wired) means:
##     • the behavior had no condition → stays null ("always fires"), or
##     • the behavior had a NON-graph condition (a seeded raw-expression
##       Logic like can_harvest) → that condition is PRESERVED, so opening
##       a legacy behavior just to change its priority never destroys its
##       expression. A banner explains; wiring any node switches to
##       replace-on-save.
## - A NON-empty graph persists as a GraphLogic OWNED by this behavior
##   ("<behavior> condition", id-deduped), saved to the library BEFORE the
##   behavior itself — leaves before parents, so the condition is never
##   embedded as a subresource.
##
## VALIDATION: gate 1 lives here — the panel's `edited` signal triggers
## BBGraphValidator on every change; errors surface in the status line and
## block Save. Gates 2 and 3 (save + first evaluation) were wired in
## Batch B via LogicValidator.validate_logic.
##
## After a successful condition save: EvaluationSystem.invalidate_expression
## then BBEval.clear_states_tagged("glogic:<id>@") — cached values drop AND
## timer holds restart, so edited hold durations apply immediately
## (Batch B patch doc, verification point C).
##
## Window id is NEW ("behavior_graph_editor") — deliberately not reusing
## "rule_editor", whose persisted 760×680 geometry is far too small for a
## graph canvas.

signal saved(resource: AntRule)

var editing: AntRule
var _previous_path: String = ""
var _had_nongraph_condition: bool = false

var _name_edit: LineEdit
var _action_select: OptionButton
var _priority_spin: SpinBox
var _enabled_check: CheckBox
var _desc_edit: LineEdit
var _legacy_banner: Label
var _panel: BBGraphPanel
var _status: Label


func _init() -> void:
	setup_window("behavior_graph_editor", "Behavior Editor",
		Vector2i(1360, 860), Vector2i(1040, 680))


func open_for(res: Resource, path: String, writable: bool) -> void:
	_previous_path = path if writable else ""
	editing = ResourceLibrary.duplicate_for_edit(res) if not path.is_empty() else res
	_build_ui()
	_load_condition()
	present()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ---- form bar (the AntRule shape: name / action / priority / enabled)
	var form: HBoxContainer = HBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	vbox.add_child(form)

	_name_edit = LineEdit.new()
	_name_edit.text = editing.name
	_name_edit.custom_minimum_size = Vector2(220, 0)
	_name_edit.placeholder_text = "Behavior name"
	form.add_child(_labeled("Name:", _name_edit))

	_action_select = OptionButton.new()
	_action_select.custom_minimum_size = Vector2(200, 0)
	_populate_actions()
	form.add_child(_labeled("Action:", _action_select))

	_priority_spin = SpinBox.new()
	_priority_spin.min_value = 0
	_priority_spin.max_value = 1000
	_priority_spin.step = 1
	_priority_spin.value = editing.priority
	form.add_child(_labeled("Priority:", _priority_spin))

	_enabled_check = CheckBox.new()
	_enabled_check.text = "Enabled"
	_enabled_check.button_pressed = editing.enabled
	form.add_child(_enabled_check)

	_legacy_banner = Label.new()
	_legacy_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legacy_banner.add_theme_color_override("font_color", Color.GOLD)
	_legacy_banner.visible = false
	vbox.add_child(_legacy_banner)

	# ---- graph panel (the condition)
	_panel = BBGraphPanel.new()
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel)
	var _err_edited: Error = _panel.edited.connect(_on_graph_edited)

	# ---- description + status + buttons
	_desc_edit = LineEdit.new()
	_desc_edit.text = editing.description
	_desc_edit.placeholder_text = "Description (shown in library lists and profile editors)"
	vbox.add_child(_desc_edit)

	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_status)

	var save_btn: Button = Button.new()
	save_btn.text = "Save"
	var _es: Error = save_btn.pressed.connect(_on_save)
	bottom.add_child(save_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	var _ec: Error = cancel_btn.pressed.connect(_request_close)
	bottom.add_child(cancel_btn)

	_name_edit.tooltip_text = "Unique name; the id is derived from it"
	_action_select.tooltip_text = "Action executed when the condition passes"
	_priority_spin.tooltip_text = "Higher priority behaviors are evaluated first; first passing behavior acts"
	_enabled_check.tooltip_text = "Disabled behaviors stay in the profile but are skipped at runtime"
	_desc_edit.tooltip_text = "Shown in library lists and profile editors"

	watch([_name_edit, _action_select, _priority_spin, _enabled_check, _desc_edit])


func _populate_actions() -> void:
	_action_select.clear()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_ACTION):
		var idx: int = _action_select.item_count
		_action_select.add_item(entry.display_name())
		_action_select.set_item_metadata(idx, entry.resource)
		if editing.action != null and entry.resource.get("id") == editing.action.id:
			_action_select.select(idx)


## Loads the existing condition into the panel, or seeds a fresh ⚡ Output.
func _load_condition() -> void:
	var graph_cond: GraphLogic = editing.condition as GraphLogic
	if graph_cond != null and not graph_cond.graph_data.is_empty():
		_panel.load_graph(graph_cond.graph_data)
	else:
		_panel.spawn_output_node()
		if editing.condition != null:
			# Legacy raw-expression condition (seeded rules, hand-authored
			# Logic): preserved while the graph stays empty.
			_had_nongraph_condition = true
			_legacy_banner.text = (
				"This behavior's condition is a raw expression ('%s'). It stays in effect while the graph below is empty; wiring any nodes and saving REPLACES it with the graph."
				% editing.condition.name)
			_legacy_banner.visible = true
	clear_dirty()  # loading is not an edit
	_refresh_validation()


func _on_graph_edited() -> void:
	mark_dirty()
	_refresh_validation()


## Gate 1: live validation on every graph change.
func _refresh_validation() -> void:
	if _panel == null or _status == null:
		return
	if _panel.is_graph_empty():
		_status.text = "Empty graph — %s" % (
			"the existing raw-expression condition stays in effect." if _had_nongraph_condition
			else "this behavior always fires.")
		_status.remove_theme_color_override("font_color")
		return
	var problems: PackedStringArray = _current_problems()
	if problems.is_empty():
		_status.text = "Condition is valid."
		_status.add_theme_color_override("font_color", Color.SEA_GREEN)
	else:
		_status.text = "⚠ %s" % "  •  ".join(problems)
		_status.add_theme_color_override("font_color", Color.GOLD)


## Structural + whitelist problems for the CURRENT graph (non-empty case).
func _current_problems() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var outputs: int = _panel.output_node_count()
	if outputs == 0:
		problems.append("Add one ⚡ Output node and wire the condition into it.")
	elif outputs > 1:
		problems.append("Exactly one ⚡ Output node is allowed (found %d)." % outputs)
	problems.append_array(_panel.current_errors())
	return problems


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

	if not _save_graph_condition():
		return  # _status already set

	editing.action = _action_select.get_item_metadata(_action_select.selected)
	editing.priority = int(_priority_spin.value)
	editing.enabled = _enabled_check.button_pressed
	editing.description = _desc_edit.text

	if ResourceLibrary.save_resource(editing, ResourceLibrary.KIND_RULE, _previous_path) != OK:
		_status.text = "Save failed — see log."
		toast_error("Save failed — see log.")
		return

	# Priority may have changed: re-sort live behavior managers.
	for ant: Ant in AntManager.get_all():
		if ant.behavior_manager != null:
			ant.behavior_manager.resort()

	saved.emit(editing)
	clear_dirty()
	Toast.success(get_parent(), "Saved behavior '%s'" % editing.name)
	_request_close()


## Persists the graph as this behavior's GraphLogic condition — library
## FIRST (leaves before parents). Returns false with _status set on any
## failure. Empty graph: keeps a legacy raw-expression condition, or null.
func _save_graph_condition() -> bool:
	if _panel.is_graph_empty():
		if not _had_nongraph_condition:
			editing.condition = null
		return true  # legacy condition (if any) preserved untouched

	var problems: PackedStringArray = _current_problems()
	if not problems.is_empty():
		_status.text = "Condition is invalid:\n%s" % "\n".join(problems)
		return false

	var cond: GraphLogic
	var cond_prev: String = ""
	var existing: GraphLogic = editing.condition as GraphLogic
	if existing != null:
		# This behavior already owns a graph condition: update it in place
		# (same id/name/eval policy). Work on a copy so live ants see
		# nothing until the save lands.
		cond_prev = existing.resource_path \
			if existing.resource_path.begins_with("user://") else ""
		cond = ResourceLibrary.duplicate_for_edit(existing) as GraphLogic
	else:
		# Converting from none/legacy: mint a fresh condition owned by this
		# behavior. A legacy raw-expression Logic picked up elsewhere is
		# NOT touched — shared expressions stay shared; this behavior just
		# stops referencing it.
		cond = _make_condition_resource()

	cond.graph_data = _panel.serialize_graph()
	cond.type = TYPE_BOOL

	if ResourceLibrary.save_resource(cond, ResourceLibrary.KIND_LOGIC, cond_prev) != OK:
		_status.text = "Saving the condition graph failed — see log."
		toast_error("Save failed — see log.")
		return false

	# Drop cached values AND timer holds so live ants pick up the new
	# graph immediately (Batch B verification point C — order matters).
	EvaluationSystem.invalidate_expression(cond.id)
	BBEval.clear_states_tagged("glogic:%s@" % cond.id)

	editing.condition = cond
	_had_nongraph_condition = false
	_legacy_banner.visible = false
	return true


## New behavior-owned condition, named after the behavior with id-conflict
## dedupe ("forage condition", "forage condition 2", ...). It shows up in
## the Expressions list like any other Logic — the catalog stays unified.
func _make_condition_resource() -> GraphLogic:
	var cond: GraphLogic = GraphLogic.new()
	var base: String = "%s condition" % editing.name
	var candidate: String = base
	var n: int = 2
	while ResourceLibrary.has_id_conflict(
			ResourceLibrary.KIND_LOGIC, candidate.to_snake_case(), cond):
		candidate = "%s %d" % [base, n]
		n += 1
	cond.name = candidate
	cond.description = "Graph condition for behavior '%s'." % editing.name
	return cond


func _labeled(text: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl: Label = Label.new()
	lbl.text = text
	row.add_child(lbl)
	row.add_child(control)
	return row


func _confirm_shortcut() -> bool:
	_on_save()
	return true
