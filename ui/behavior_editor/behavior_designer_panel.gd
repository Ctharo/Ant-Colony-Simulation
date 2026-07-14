class_name BehaviorDesignerPanel
extends ManagedWindow
## Visual behavior designer: renders behaviors and their nested Logic
## expression trees, shows live values and evaluation costs against a probe
## ant, and edits each expression's re-evaluation policy (frame cache,
## always, timer, event triggers, sticky). Policies persist through
## ResourceLibrary exactly like other behavior resources — editing a
## built-in forks it to user://.
##
## TERMINOLOGY: a "Behavior" is what the data layer still calls an AntRule
## (condition + action + priority). The rename is display-layer only —
## class names, ResourceLibrary.KIND_RULE, and .tres files are unchanged.
##
## This is the PRIMARY authoring window: the left pane offers full CRUD
## (New / Edit / Duplicate / Delete), double-clicking a list entry opens the
## matching editor popup, and double-clicking any expression row in the tree
## opens the Logic editor for that expression directly.
##
## BUILDER CONDITIONS: expressions with non-empty builder_data (authored in
## the ConditionBuilder) render their sections/rows as readable child lines
## and carry a "[built]" tag. If the raw expression no longer matches what
## the rows compile to (hand edit / vocabulary change), the tag becomes a
## gold "⚠ built, diverged" badge — the raw expression is what runs.
## Double-click still opens the raw expression editor (the escape hatch);
## visual editing happens through the owning behavior.
##
## Opened from the sandbox debug menu ("Designer") and from the main menu.
## Without a running sandbox there are no live ants: the probe label reads
## "no live ants" and the Value column stays blank, but all authoring works.
## Built entirely in code to match the project's runtime-UI convention
## (no separate .tscn).
##
## Reading the tree:
## - Each row is one Logic expression: "name — expression string".
## - Mode column shows the caching policy (color-coded).
## - Value column shows what an ant currently *sees* (i.e. it goes through
##   the same cache the behavior system uses, so stale-by-design values
##   display as stale).
## - Recalcs / Hits / Avg come from EvaluationSystem's stats: recalcs are
##   real computations, hits were served from cache. Raising the hit rate
##   is what makes ants cheaper to process.

const REFRESH_INTERVAL := 0.25

const MODE_ORDER: Array = [
	Logic.EvalMode.FRAME,
	Logic.EvalMode.ALWAYS,
	Logic.EvalMode.TIMER,
	Logic.EvalMode.EVENT,
	Logic.EvalMode.STICKY,
]

const MODE_LABELS: Dictionary = {
	Logic.EvalMode.FRAME: "Frame",
	Logic.EvalMode.ALWAYS: "Always",
	Logic.EvalMode.TIMER: "Timer",
	Logic.EvalMode.EVENT: "Event",
	Logic.EvalMode.STICKY: "Sticky",
}

const MODE_COLORS: Dictionary = {
	Logic.EvalMode.FRAME: Color(0.75, 0.75, 0.75),
	Logic.EvalMode.ALWAYS: Color(0.94, 0.50, 0.50),
	Logic.EvalMode.TIMER: Color(0.55, 0.85, 0.95),
	Logic.EvalMode.EVENT: Color(0.98, 0.75, 0.45),
	Logic.EvalMode.STICKY: Color(0.55, 0.90, 0.60),
}

const MODE_HINTS: Dictionary = {
	Logic.EvalMode.FRAME: "Recomputed at most once per frame (16 ms cache). The default — safe, but does the most work of the cached modes.",
	Logic.EvalMode.ALWAYS: "No caching: recomputed on every call, possibly several times per frame if referenced by multiple parents. Most expensive; only for values that must never be stale.",
	Logic.EvalMode.TIMER: "Cached for a fixed interval. Ideal for slow-changing senses (visible food, distance to colony) — 250–1000 ms is usually imperceptible.",
	Logic.EvalMode.EVENT: "Cached until one of the checked ant signals fires, then recomputed on next use. Cheapest option when a value only changes on discrete events.",
	Logic.EvalMode.STICKY: "Computed once per ant, then cached until 'Invalidate now' (or a library edit) clears it. For values that are effectively constant per ant.",
}

enum Col { NAME, MODE, VALUE, RECALCS, HITS, AVG }

const KINDS: Array[String] = [ResourceLibrary.KIND_RULE, ResourceLibrary.KIND_LOGIC]
const KIND_LABELS: Array[String] = ["Behaviors", "Expressions"]

var logger: iLogger

# Top bar
var _kind_select: OptionButton
var _live_check: CheckButton
var _probe_label: Label

# Left pane
var _item_list: ItemList
var _edit_btn: Button
var _dup_btn: Button
var _del_btn: Button
var _confirm: ConfirmationDialog

# Right pane
var _tree: Tree
var _totals_label: Label

# Policy editor
var _editor_box: PanelContainer
var _sel_label: Label
var _mode_select: OptionButton
var _interval_row: HBoxContainer
var _interval_spin: SpinBox
var _trigger_row: HBoxContainer
var _trigger_checks: Array[CheckBox] = []
var _hint_label: Label
var _status: Label

var _refresh_timer: Timer


func _init() -> void:
	setup_window("behavior_designer", "Behavior Designer",
		Vector2i(920, 640), Vector2i(720, 480))
	logger = iLogger.new("behavior_designer", DebugLogger.Category.UI)


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	root.add_child(_build_top_bar())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	split.add_child(_build_left_pane())
	split.add_child(_build_right_pane())

	_totals_label = Label.new()
	_totals_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_totals_label)

	var gating_hint := Label.new()
	gating_hint.text = "Parents gate children: a cached parent won't re-read its nested expressions until the parent itself re-evaluates."
	gating_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gating_hint.add_theme_font_size_override("font_size", 11)
	gating_hint.modulate = Color(1, 1, 1, 0.6)
	root.add_child(gating_hint)

	_confirm = ConfirmationDialog.new()
	add_child(_confirm)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = REFRESH_INTERVAL
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh_live)
	add_child(_refresh_timer)

	ResourceLibrary.library_changed.connect(func(_k: String) -> void: _refresh_list())
	_refresh_list()


#region UI construction
func _build_top_bar() -> HBoxContainer:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)

	_kind_select = OptionButton.new()
	for label in KIND_LABELS:
		_kind_select.add_item(label)
	_kind_select.item_selected.connect(func(_i: int) -> void: _refresh_list())
	top.add_child(_kind_select)

	_live_check = CheckButton.new()
	_live_check.text = "Live values"
	_live_check.button_pressed = true
	_live_check.tooltip_text = "Probe values through the same cache the ants use — stale-by-design values display as stale."
	top.add_child(_live_check)

	top.add_child(VSeparator.new())

	_probe_label = Label.new()
	_probe_label.text = "Probe: —"
	top.add_child(_probe_label)

	return top


func _build_left_pane() -> VBoxContainer:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)

	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(190, 0)
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(func(_i: int) -> void:
		_rebuild_tree()
		_update_crud_buttons()
	)
	_item_list.item_activated.connect(func(_i: int) -> void: _edit_selected_entry())
	left.add_child(_item_list)

	var crud := HBoxContainer.new()
	crud.add_theme_constant_override("separation", 4)
	left.add_child(crud)

	crud.add_child(_small_btn("New", _on_new,
		"Create a new resource of the selected kind"))
	_edit_btn = _small_btn("Edit", _edit_selected_entry,
		"Edit the selection (built-ins fork to user:// on save). Double-click also works.")
	crud.add_child(_edit_btn)
	_dup_btn = _small_btn("Dup", _on_duplicate,
		"Copy the selection as a new editable resource")
	crud.add_child(_dup_btn)
	_del_btn = _small_btn("Del", _on_delete,
		"Delete from user:// (built-ins can't be deleted)")
	crud.add_child(_del_btn)

	return left


func _small_btn(text: String, handler: Callable, tooltip: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(handler)
	return btn


func _build_right_pane() -> VBoxContainer:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.columns = 6
	_tree.column_titles_visible = true
	_tree.set_column_title(Col.NAME, "Expression")
	_tree.set_column_title(Col.MODE, "Mode")
	_tree.set_column_title(Col.VALUE, "Value")
	_tree.set_column_title(Col.RECALCS, "Recalcs")
	_tree.set_column_title(Col.HITS, "Cache hits")
	_tree.set_column_title(Col.AVG, "Avg cost")
	_tree.set_column_expand(Col.NAME, true)
	for col in [Col.MODE, Col.VALUE, Col.RECALCS, Col.HITS, Col.AVG]:
		_tree.set_column_expand(col, false)
	_tree.set_column_custom_minimum_width(Col.MODE, 64)
	_tree.set_column_custom_minimum_width(Col.VALUE, 110)
	_tree.set_column_custom_minimum_width(Col.RECALCS, 66)
	_tree.set_column_custom_minimum_width(Col.HITS, 96)
	_tree.set_column_custom_minimum_width(Col.AVG, 72)
	_tree.item_selected.connect(_on_tree_item_selected)
	_tree.item_activated.connect(_on_tree_item_activated)
	right.add_child(_tree)

	right.add_child(_build_policy_editor())
	return right


func _build_policy_editor() -> PanelContainer:
	_editor_box = PanelContainer.new()
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_%s" % side, 8)
	_editor_box.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	inner.add_child(vbox)

	_sel_label = Label.new()
	_sel_label.text = "Select an expression in the tree to edit its re-evaluation policy."
	vbox.add_child(_sel_label)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	var mode_label := Label.new()
	mode_label.text = "Re-evaluate:"
	mode_row.add_child(mode_label)
	_mode_select = OptionButton.new()
	for mode in MODE_ORDER:
		_mode_select.add_item(MODE_LABELS[mode])
		_mode_select.set_item_metadata(_mode_select.item_count - 1, mode)
	_mode_select.item_selected.connect(func(_i: int) -> void: _sync_editor_visibility())
	mode_row.add_child(_mode_select)
	vbox.add_child(mode_row)

	_interval_row = HBoxContainer.new()
	_interval_row.add_theme_constant_override("separation", 6)
	var interval_label := Label.new()
	interval_label.text = "Interval (ms):"
	_interval_row.add_child(interval_label)
	_interval_spin = SpinBox.new()
	_interval_spin.min_value = 16
	_interval_spin.max_value = 60000
	_interval_spin.step = 1
	_interval_spin.value = 500
	_interval_row.add_child(_interval_spin)
	vbox.add_child(_interval_row)

	_trigger_row = HBoxContainer.new()
	_trigger_row.add_theme_constant_override("separation", 10)
	var trigger_label := Label.new()
	trigger_label.text = "Re-eval on:"
	_trigger_row.add_child(trigger_label)
	for sig_name in EvaluationSystem.TRIGGER_SIGNAL_WHITELIST:
		var cb := CheckBox.new()
		cb.text = sig_name
		_trigger_checks.append(cb)
		_trigger_row.add_child(cb)
	vbox.add_child(_trigger_row)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_hint_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	var apply_btn := Button.new()
	apply_btn.text = "Apply && Save"
	apply_btn.pressed.connect(_on_apply)
	button_row.add_child(apply_btn)
	var invalidate_btn := Button.new()
	invalidate_btn.text = "Invalidate now"
	invalidate_btn.tooltip_text = "Clear this expression's cached values on all ants (forces recompute on next use)."
	invalidate_btn.pressed.connect(_on_invalidate)
	button_row.add_child(invalidate_btn)
	vbox.add_child(button_row)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status)

	_set_editor_enabled(false)
	return _editor_box


func _set_editor_enabled(enabled: bool) -> void:
	_mode_select.disabled = not enabled
	_interval_spin.editable = enabled
	for cb in _trigger_checks:
		cb.disabled = not enabled


func _sync_editor_visibility() -> void:
	var mode: int = _current_mode()
	_interval_row.visible = mode == Logic.EvalMode.TIMER
	_trigger_row.visible = mode == Logic.EvalMode.EVENT
	_hint_label.text = MODE_HINTS.get(mode, "")


func _current_mode() -> int:
	var idx := _mode_select.selected
	return _mode_select.get_item_metadata(idx) if idx >= 0 else Logic.EvalMode.FRAME
#endregion


#region List / tree population
func _current_kind() -> String:
	return KINDS[_kind_select.selected]


func _selected_entry() -> ResourceLibrary.Entry:
	var sel := _item_list.get_selected_items()
	if sel.is_empty():
		return null
	return _item_list.get_item_metadata(sel[0])


func _refresh_list() -> void:
	var previous: Resource = null
	var prev_entry := _selected_entry()
	if prev_entry:
		previous = prev_entry.resource

	_item_list.clear()
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(_current_kind()):
		var idx := _item_list.add_item(entry.display_name())
		_item_list.set_item_metadata(idx, entry)
		_item_list.set_item_tooltip(idx, entry.path)
		if entry.resource == previous:
			_item_list.select(idx)

	if _item_list.get_selected_items().is_empty() and _item_list.item_count > 0:
		_item_list.select(0)
	_update_crud_buttons()
	_rebuild_tree()


func _update_crud_buttons() -> void:
	var entry := _selected_entry()
	_edit_btn.disabled = entry == null
	_dup_btn.disabled = entry == null
	_del_btn.disabled = entry == null or not entry.writable


func _rebuild_tree() -> void:
	_tree.clear()
	_status.text = ""
	_set_editor_enabled(false)
	_sel_label.text = "Select an expression in the tree to edit its re-evaluation policy."

	var entry := _selected_entry()
	if not entry:
		return

	var root := _tree.create_item()
	if entry.resource is AntRule:
		var rule: AntRule = entry.resource
		var header := _tree.create_item(root)
		header.set_text(Col.NAME, "Behavior: %s   (priority %d%s)" % [
			rule.name, rule.priority, "" if rule.enabled else ", disabled"
		])
		header.set_selectable(Col.NAME, false)

		if rule.condition:
			_add_logic_item(header, rule.condition, {}, "condition: ")
		else:
			var always := _tree.create_item(header)
			always.set_text(Col.NAME, "condition: (always true)")
			always.set_selectable(Col.NAME, false)

		var act := _tree.create_item(header)
		act.set_text(Col.NAME, "action: %s" % (rule.action.name if rule.action else "(none)"))
		act.set_selectable(Col.NAME, false)
		if rule.action:
			for param: Logic in rule.action.params:
				_add_logic_item(act, param, {}, "param: ")
	elif entry.resource is Logic:
		_add_logic_item(root, entry.resource, {}, "")

	_refresh_live()


## Recursively adds a Logic (and its nested expressions) to the tree.
## `seen` guards against reference cycles, which would otherwise recurse
## forever (the logic editor prevents creating them, but stay safe).
func _add_logic_item(parent: TreeItem, logic: Logic, seen: Dictionary, prefix: String) -> void:
	var item := _tree.create_item(parent)
	var display := logic.name if not logic.name.is_empty() else logic.id
	var expr := logic.expression_string.replace("\n", " ").strip_edges()
	if expr.length() > 44:
		expr = expr.substr(0, 41) + "..."
	item.set_text(Col.NAME, "%s%s  —  %s" % [prefix, display, expr])
	item.set_tooltip_text(Col.NAME, "%s\n\n%s\n\nDouble-click to open in the expression editor." % [
		logic.expression_string, logic.description
	])
	item.set_metadata(Col.NAME, logic)
	_update_mode_cell(item, logic)

	if not logic.builder_data.is_empty():
		_decorate_builder_item(item, logic)

	if seen.has(logic.id):
		item.set_text(Col.NAME, item.get_text(Col.NAME) + "  (cycle!)")
		return
	seen[logic.id] = true
	for nested: Logic in logic.nested_expressions:
		_add_logic_item(item, nested, seen, "")
	seen.erase(logic.id)


## Builder-authored condition: "[built]" tag (gold "⚠ built, diverged" when
## the raw expression no longer matches the rows), plus readable
## section/row child lines. The child lines carry no Logic metadata, so
## the policy editor and live-value walker skip them automatically.
func _decorate_builder_item(item: TreeItem, logic: Logic) -> void:
	var recompiled := ConditionBuilder.compile_data(logic.builder_data).strip_edges()
	var diverged := recompiled != logic.expression_string.strip_edges()

	item.set_text(Col.NAME, item.get_text(Col.NAME)
		+ ("   ⚠ built, diverged" if diverged else "   [built]"))

	var tooltip := item.get_tooltip_text(Col.NAME)
	tooltip += "\n\nBuilt with the condition builder — edit the owning behavior for the visual editor; the expression editor here is the raw escape hatch."
	if diverged:
		item.set_custom_color(Col.NAME, Color.GOLD)
		tooltip += "\n\n⚠ The raw expression no longer matches the builder rows (hand-edited, or the vocabulary changed how rows compile). The raw expression is what runs; saving from the builder would overwrite it."
	item.set_tooltip_text(Col.NAME, tooltip)

	var sections := ConditionBuilder.describe_data(logic.builder_data)
	var single := sections.size() == 1
	for si in sections.size():
		var sec: Dictionary = sections[si]
		# One section: flatten rows directly under the expression — the
		# grouping adds nothing. Multiple: show section headers with the
		# combining operator, exactly as the builder lays them out.
		var row_parent := item
		if not single:
			var sec_item := _tree.create_item(item)
			sec_item.set_text(Col.NAME, ("Section %d" % (si + 1)) if si == 0
				else "%s Section %d" % [str(sec.op).to_upper(), si + 1])
			sec_item.set_selectable(Col.NAME, false)
			sec_item.set_custom_color(Col.NAME, Color(0.75, 0.85, 1.0, 0.9))
			row_parent = sec_item
		for line: String in sec.rows:
			var row_item := _tree.create_item(row_parent)
			row_item.set_text(Col.NAME, line)
			row_item.set_selectable(Col.NAME, false)
			row_item.set_custom_color(Col.NAME, Color(1, 1, 1, 0.65))


func _update_mode_cell(item: TreeItem, logic: Logic) -> void:
	var label: String = MODE_LABELS.get(logic.eval_mode, "?")
	if logic.eval_mode == Logic.EvalMode.TIMER:
		label += " %dms" % logic.eval_interval_ms
	item.set_text(Col.MODE, label)
	item.set_custom_color(Col.MODE, MODE_COLORS.get(logic.eval_mode, Color.WHITE))
	item.set_tooltip_text(Col.MODE, MODE_HINTS.get(logic.eval_mode, ""))
#endregion


#region CRUD (New / Edit / Duplicate / Delete)
func _on_new() -> void:
	match _current_kind():
		ResourceLibrary.KIND_LOGIC:
			_open_editor(LogicEditorPopup.new(), Logic.new(), "", true)
		ResourceLibrary.KIND_RULE:
			_open_editor(RuleEditorPopup.new(), AntRule.new(), "", true)


## Double-click on the left list, or the Edit button: Behavior entries open
## the behavior editor, Expression entries open the logic editor.
func _edit_selected_entry() -> void:
	var entry := _selected_entry()
	if not entry:
		return
	if entry.resource is AntRule:
		_open_editor(RuleEditorPopup.new(), entry.resource, entry.path, entry.writable)
	elif entry.resource is Logic:
		_open_editor(LogicEditorPopup.new(), entry.resource, entry.path, entry.writable)


func _on_duplicate() -> void:
	var entry := _selected_entry()
	if not entry:
		return
	var copy: Resource = ResourceLibrary.duplicate_for_edit(entry.resource)
	copy.name = "%s copy" % copy.name
	if copy is AntRule:
		_open_editor(RuleEditorPopup.new(), copy, "", true)
	elif copy is Logic:
		_open_editor(LogicEditorPopup.new(), copy, "", true)


func _on_delete() -> void:
	var entry := _selected_entry()
	if not entry or not entry.writable:
		return
	_confirm.dialog_text = "Delete '%s'?\nAnts currently referencing it keep the in-memory copy until restart." % entry.resource.name
	# Reconnect confirmed for this specific entry
	for conn in _confirm.confirmed.get_connections():
		_confirm.confirmed.disconnect(conn.callable)
	_confirm.confirmed.connect(func() -> void:
		var deleted_name: String = entry.resource.name
		ResourceLibrary.delete_resource(entry)
		toast_info("Deleted '%s'" % deleted_name)
	)
	_confirm.popup_centered()


func _open_editor(popup: Window, res: Resource, path: String, writable: bool) -> void:
	add_child(popup)
	popup.open_for(res, path, writable)
	# library_changed (already connected) refreshes the list on save; this
	# restores the tree, whose selection is lost when the saved resource
	# instance replaces the one being displayed.
	if popup.has_signal("saved"):
		popup.saved.connect(func(_r: Resource) -> void: _rebuild_tree())


## Double-click on a tree row: open the Logic editor for that expression.
## Nested built-ins embedded without their own file open with an empty path,
## i.e. as "new" — saving writes a standalone user:// copy (the built-in
## parent on disk still references the embedded original after restart; fork
## the parent too to make it permanent).
func _on_tree_item_activated() -> void:
	var logic := _selected_logic()
	if not logic:
		return
	var path := logic.resource_path
	_open_editor(LogicEditorPopup.new(), logic, path, path.begins_with("user://"))
#endregion


#region Live refresh
func _refresh_live() -> void:
	if not visible:
		return

	var ant: Ant = null
	var ants: Array[Ant] = AntManager.get_all()
	for candidate: Ant in ants:
		if is_instance_valid(candidate) and not candidate.is_dead:
			ant = candidate
			break
	_probe_label.text = "Probe: Ant #%d" % ant.id if ant else "Probe: no live ants"

	var root := _tree.get_root()
	if root:
		_walk_items(root, ant)

	var totals: Dictionary = EvaluationSystem.get_stats_totals()
	var total: int = totals.evals + totals.hits
	_totals_label.text = "Global: %d recalcs, %d cache hits (%.0f%% served from cache)" % [
		totals.evals, totals.hits,
		(100.0 * totals.hits / total) if total > 0 else 0.0
	]


func _walk_items(item: TreeItem, ant: Ant) -> void:
	var logic: Logic = item.get_metadata(Col.NAME) as Logic
	if logic:
		if _live_check.button_pressed and is_instance_valid(ant):
			var value: Variant = EvaluationSystem.get_value(logic, ant)
			var text := str(value)
			var previous: Variant = item.get_metadata(Col.VALUE)
			item.set_text(Col.VALUE, text)
			# Flash values that changed since the last UI tick
			item.set_custom_color(Col.VALUE,
				Color(1.0, 0.9, 0.4) if previous != null and previous != text
				else Color(0.85, 0.85, 0.85))
			item.set_metadata(Col.VALUE, text)
		elif not _live_check.button_pressed:
			item.set_text(Col.VALUE, "")

		var stats: Dictionary = EvaluationSystem.get_expression_stats(logic.id)
		if not stats.is_empty():
			var evals: int = stats.evals
			var hits: int = stats.hits
			var lookups := evals + hits
			item.set_text(Col.RECALCS, str(evals))
			item.set_text(Col.HITS, "%d (%.0f%%)" % [
				hits, (100.0 * hits / lookups) if lookups > 0 else 0.0
			])
			item.set_text(Col.AVG, "%.0f µs" % (stats.total_us / max(evals, 1)))

	var child := item.get_first_child()
	while child:
		_walk_items(child, ant)
		child = child.get_next()
#endregion


#region Policy editing
func _selected_logic() -> Logic:
	var item := _tree.get_selected()
	if not item:
		return null
	return item.get_metadata(Col.NAME) as Logic


func _on_tree_item_selected() -> void:
	var logic := _selected_logic()
	if not logic:
		_set_editor_enabled(false)
		_sel_label.text = "Select an expression in the tree to edit its re-evaluation policy."
		return

	_set_editor_enabled(true)
	var writable := logic.resource_path.begins_with("user://")
	_sel_label.text = "Editing: %s%s" % [
		logic.name if not logic.name.is_empty() else logic.id,
		"" if writable else "   [built-in — saving forks to user://]"
	]

	for i in _mode_select.item_count:
		if _mode_select.get_item_metadata(i) == logic.eval_mode:
			_mode_select.select(i)
			break
	_interval_spin.value = logic.eval_interval_ms
	for cb in _trigger_checks:
		cb.button_pressed = cb.text in logic.retrigger_signals
	_sync_editor_visibility()
	_status.text = ""


func _on_apply() -> void:
	var logic := _selected_logic()
	if not logic:
		return

	logic.eval_mode = _current_mode()
	logic.eval_interval_ms = int(_interval_spin.value)
	var triggers := PackedStringArray()
	for cb in _trigger_checks:
		if cb.button_pressed:
			triggers.append(cb.text)
	logic.retrigger_signals = triggers

	if logic.eval_mode == Logic.EvalMode.EVENT and triggers.is_empty():
		_status.text = "Event mode needs at least one trigger signal — otherwise the value would never refresh (use Sticky for that)."
		return

	var previous_path := logic.resource_path
	var was_builtin := previous_path.begins_with("res://")
	var err := ResourceLibrary.save_resource(logic, ResourceLibrary.KIND_LOGIC,
		previous_path if previous_path.begins_with("user://") else "")
	if err != OK:
		_status.text = "Save failed — see log."
		toast_error("Save failed — see log.")
		return

	# Drop parsed states, cached values, and stale trigger wiring so the new
	# policy takes effect immediately on live ants.
	EvaluationSystem.invalidate_expression(logic.id)

	var item := _tree.get_selected()
	if item:
		_update_mode_cell(item, logic)

	_status.text = "Saved."
	toast_success("Policy saved")
	if was_builtin:
		_status.text += " Forked built-in to user:// — live ants use it now, but built-in parents on disk still reference the res:// original after restart. Fork the parent too to make this permanent."


func _on_invalidate() -> void:
	var logic := _selected_logic()
	if not logic:
		return
	EvaluationSystem.invalidate_expression(logic.id)
	_status.text = "Cache cleared for '%s' on all ants — next use recomputes." % logic.id
	toast_info("Cache cleared for '%s'" % logic.id)
#endregion
