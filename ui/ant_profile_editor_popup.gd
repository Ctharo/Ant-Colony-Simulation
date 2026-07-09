class_name AntProfileEditorPopup
extends ManagedWindow

signal closed(profile: AntProfile)

#region Constants
const WINDOW_SIZE = Vector2i(450, 600)
#endregion

#region Member Variables
var editing_profile: AntProfile
var _influence_profiles: Array[InfluenceProfile] = [] as Array[InfluenceProfile]
var _rules: Array[AntRule] = []
#endregion


func _init() -> void:
	setup_window("ant_profile_editor", "Edit Ant Profile",
		WINDOW_SIZE, Vector2i(380, 480))


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	_add_basic_section(vbox)
	_add_separator(vbox)
	_add_stats_section(vbox)
	_add_separator(vbox)
	_add_movement_influences_section(vbox)
	_add_separator(vbox)
	_add_behavior_rules_section(vbox)
	_add_separator(vbox)
	_add_pheromones_section(vbox)
	_add_separator(vbox)
	_add_buttons(vbox)


func _add_separator(parent: Control) -> void:
	var sep = HSeparator.new()
	parent.add_child(sep)


func _add_section_label(parent: Control, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


#region Basic Info Section
func _add_basic_section(parent: Control) -> void:
	_add_section_label(parent, "Basic Info")
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	# Name
	var name_row = _create_row("Name:")
	var name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)
	container.add_child(name_row)


func _on_name_changed(new_text: String) -> void:
	if editing_profile:
		editing_profile.name = new_text
#endregion


#region Stats Section
func _add_stats_section(parent: Control) -> void:
	_add_section_label(parent, "Stats")
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	# Movement Rate
	var movement_row = _create_row("Movement Rate:")
	var movement_spin = SpinBox.new()
	movement_spin.name = "MovementRateSpin"
	movement_spin.min_value = 1.0
	movement_spin.max_value = 100.0
	movement_spin.step = 0.5
	movement_spin.value_changed.connect(_on_movement_rate_changed)
	movement_row.add_child(movement_spin)
	container.add_child(movement_row)
	
	# Vision Range
	var vision_row = _create_row("Vision Range:")
	var vision_spin = SpinBox.new()
	vision_spin.name = "VisionRangeSpin"
	vision_spin.min_value = 10.0
	vision_spin.max_value = 500.0
	vision_spin.step = 5.0
	vision_spin.value_changed.connect(_on_vision_range_changed)
	vision_row.add_child(vision_spin)
	container.add_child(vision_row)
	
	# Size
	var size_row = _create_row("Size:")
	var size_spin = SpinBox.new()
	size_spin.name = "SizeSpin"
	size_spin.min_value = 0.5
	size_spin.max_value = 5.0
	size_spin.step = 0.1
	size_spin.value_changed.connect(_on_size_changed)
	size_row.add_child(size_spin)
	container.add_child(size_row)


func _on_movement_rate_changed(value: float) -> void:
	if editing_profile:
		editing_profile.movement_rate = value


func _on_vision_range_changed(value: float) -> void:
	if editing_profile:
		editing_profile.vision_range = value


func _on_size_changed(value: float) -> void:
	if editing_profile:
		editing_profile.size = value
#endregion


#region Movement Influences Section
func _add_movement_influences_section(parent: Control) -> void:
	_add_section_label(parent, "Movement Influences")
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var list = ItemList.new()
	list.name = "InfluencesList"
	list.custom_minimum_size = Vector2(0, 100)
	list.select_mode = ItemList.SELECT_SINGLE
	list.item_selected.connect(_on_influence_selected)
	container.add_child(list)
	
	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 10)
	container.add_child(buttons_row)
	
	var view_btn = Button.new()
	view_btn.name = "ViewInfluenceBtn"
	view_btn.text = "View Details"
	view_btn.disabled = true
	view_btn.pressed.connect(_on_view_influence_pressed)
	buttons_row.add_child(view_btn)

#region Behavior Rules Section
func _add_behavior_rules_section(parent: Control) -> void:
	_add_section_label(parent, "Behavior Rules")

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)

	var hint = Label.new()
	hint.name = "RulesHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	container.add_child(hint)

	var list = ItemList.new()
	list.name = "RulesList"
	list.custom_minimum_size = Vector2(0, 100)
	list.select_mode = ItemList.SELECT_SINGLE
	list.item_selected.connect(_on_rule_selected)
	list.item_activated.connect(func(_i: int) -> void: _on_edit_rule_pressed())
	container.add_child(list)

	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 10)
	container.add_child(buttons_row)

	var add_btn = Button.new()
	add_btn.text = "Add"
	add_btn.pressed.connect(_on_add_rule_pressed)
	buttons_row.add_child(add_btn)

	var new_btn = Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_rule_pressed)
	buttons_row.add_child(new_btn)

	var edit_btn = Button.new()
	edit_btn.name = "EditRuleBtn"
	edit_btn.text = "Edit"
	edit_btn.disabled = true
	edit_btn.pressed.connect(_on_edit_rule_pressed)
	buttons_row.add_child(edit_btn)

	var remove_btn = Button.new()
	remove_btn.name = "RemoveRuleBtn"
	remove_btn.text = "Remove"
	remove_btn.disabled = true
	remove_btn.pressed.connect(_on_remove_rule_pressed)
	buttons_row.add_child(remove_btn)


func _on_rule_selected(_index: int) -> void:
	var has_selection := not (_find_node("RulesList") as ItemList).get_selected_items().is_empty()
	(_find_node("EditRuleBtn") as Button).disabled = not has_selection
	(_find_node("RemoveRuleBtn") as Button).disabled = not has_selection


func _refresh_rules_list() -> void:
	var list = _find_node("RulesList") as ItemList
	var hint = _find_node("RulesHint") as Label
	if not list:
		return

	list.clear()
	# Display in evaluation order
	var sorted := _rules.duplicate()
	sorted.sort_custom(func(a: AntRule, b: AntRule) -> bool: return a.priority > b.priority)
	for rule: AntRule in sorted:
		var idx := list.add_item("[%d]  %s%s" % [
			rule.priority, rule.name, "" if rule.enabled else "  (disabled)"
		])
		list.set_item_metadata(idx, rule)
		list.set_item_tooltip(idx, rule.description)

	if hint:
		hint.text = "Empty list = built-in defaults (harvest / store / rest)." \
			if _rules.is_empty() else \
			"Evaluated top-down each tick; first passing rule acts."


func _on_add_rule_pressed() -> void:
	var picker := _RulePicker.new()
	add_child(picker)
	var rule: AntRule = await picker.rule_selected
	if rule and rule not in _rules:
		_rules.append(rule)
		_commit_rules()


func _on_new_rule_pressed() -> void:
	var p_popup := RuleEditorPopup.new()
	add_child(p_popup)
	p_popup.saved.connect(func(rule: AntRule) -> void:
		if rule not in _rules:
			_rules.append(rule)
		_commit_rules()
	)
	p_popup.open_for(AntRule.new(), "", true)


func _on_edit_rule_pressed() -> void:
	var list = _find_node("RulesList") as ItemList
	var sel := list.get_selected_items()
	if sel.is_empty():
		return
	var rule: AntRule = list.get_item_metadata(sel[0])
	var entry := _library_entry_for(rule)

	var p_popup := RuleEditorPopup.new()
	add_child(p_popup)
	p_popup.saved.connect(func(saved_rule: AntRule) -> void:
		# Editing a built-in forks it: swap the profile's reference to the fork
		var idx := _rules.find(rule)
		if idx >= 0 and saved_rule != rule:
			_rules[idx] = saved_rule
		_commit_rules()
	)
	if entry:
		p_popup.open_for(entry.resource, entry.path, entry.writable)
	else:
		# Rule not in library (e.g. embedded in the .tres) — edit in place, writable
		p_popup.open_for(rule, "", true)


func _on_remove_rule_pressed() -> void:
	var list = _find_node("RulesList") as ItemList
	var sel := list.get_selected_items()
	if sel.is_empty():
		return
	_rules.erase(list.get_item_metadata(sel[0]) as AntRule)
	_commit_rules()


func _library_entry_for(rule: AntRule) -> ResourceLibrary.Entry:
	for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_RULE):
		if entry.resource == rule:
			return entry
	return null


## Writes rules back to the profile, persists it, and pushes the new rule set
## onto every live ant running this profile.
func _commit_rules() -> void:
	if not editing_profile:
		return
	editing_profile.behavior_rules.assign(_rules)
	_refresh_rules_list()
	_save_profile()
	_apply_rules_to_live_ants()


func _apply_rules_to_live_ants() -> void:
	var effective: Array[AntRule] = []
	if _rules.is_empty():
		for path in Ant.DEFAULT_BEHAVIOR_RULES:
			effective.append(load(path))
	else:
		effective.assign(_rules)

	for ant: Ant in AntManager.get_all():
		if ant.profile == editing_profile and ant.behavior_manager:
			ant.behavior_manager.set_rules(effective)


func _save_profile() -> void:
	var prev := editing_profile.resource_path
	ResourceLibrary.save_resource(editing_profile, ResourceLibrary.KIND_PROFILE,
		prev if prev.begins_with("user://") else "")
#endregion

## Minimal awaitable rule picker (mirrors AntProfileSelector's contract)
class _RulePicker:
	extends ManagedWindow
	signal rule_selected(rule: AntRule)

	var _list: ItemList

	func _init() -> void:
		setup_window("rule_picker", "Add Rule",
			Vector2i(320, 400), Vector2i(280, 320), true)

	func _close_now() -> void:
		rule_selected.emit(null)
		super()

	func _ready() -> void:
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_%s" % side, 10)
		add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)

		_list = ItemList.new()
		_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_list.item_activated.connect(func(_i: int) -> void: _confirm())
		vbox.add_child(_list)

		for entry: ResourceLibrary.Entry in ResourceLibrary.get_entries(ResourceLibrary.KIND_RULE):
			var idx := _list.add_item(entry.display_name())
			_list.set_item_metadata(idx, entry.resource)

		var btn := Button.new()
		btn.text = "Add Selected"
		btn.pressed.connect(_confirm)
		vbox.add_child(btn)
		present()

	func _confirm() -> void:
		var sel := _list.get_selected_items()
		rule_selected.emit(_list.get_item_metadata(sel[0]) if not sel.is_empty() else null)
		queue_free()

func _on_influence_selected(_index: int) -> void:
	var view_btn = _find_node("ViewInfluenceBtn") as Button
	if view_btn:
		view_btn.disabled = false


func _on_view_influence_pressed() -> void:
	var list = _find_node("InfluencesList") as ItemList
	if not list:
		return
	
	var selected = list.get_selected_items()
	if selected.is_empty() or not editing_profile:
		return
	
	var idx = selected[0]
	if idx < editing_profile.movement_influences.size():
		var influence_profile = editing_profile.movement_influences[idx]
		_show_influence_profile_details(influence_profile)


func _show_influence_profile_details(profile: InfluenceProfile) -> void:
	var p_popup = InfluenceProfileViewPopup.new()
	add_child(p_popup)
	p_popup.show_profile(profile)
#endregion


#region Pheromones Section
func _add_pheromones_section(parent: Control) -> void:
	_add_section_label(parent, "Pheromones")
	
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var list = ItemList.new()
	list.name = "PheromonesList"
	list.custom_minimum_size = Vector2(0, 80)
	list.select_mode = ItemList.SELECT_SINGLE
	container.add_child(list)
#endregion


#region Buttons Section
func _add_buttons(parent: Control) -> void:
	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 10)
	parent.add_child(buttons_row)
	
	var done_btn = Button.new()
	done_btn.text = "Done"
	done_btn.pressed.connect(_on_done_pressed)
	buttons_row.add_child(done_btn)
#endregion


#region Public Methods
func edit_profile(profile: AntProfile) -> void:
	editing_profile = profile
	set_window_title("Edit Ant Profile: %s" % profile.name)
	_populate_fields()
	present()


func _populate_fields() -> void:
	if not editing_profile:
		return
	
	# Basic info
	var name_edit = _find_node("NameEdit") as LineEdit
	if name_edit:
		name_edit.text = editing_profile.name
	
	# Stats
	var movement_spin = _find_node("MovementRateSpin") as SpinBox
	if movement_spin:
		movement_spin.set_value_no_signal(editing_profile.movement_rate)
	
	var vision_spin = _find_node("VisionRangeSpin") as SpinBox
	if vision_spin:
		vision_spin.set_value_no_signal(editing_profile.vision_range)
	
	var size_spin = _find_node("SizeSpin") as SpinBox
	if size_spin:
		size_spin.set_value_no_signal(editing_profile.size)
	
	# Movement Influences
	var influences_list = _find_node("InfluencesList") as ItemList
	if influences_list:
		influences_list.clear()
		for influence_profile in editing_profile.movement_influences:
			if influence_profile:
				influences_list.add_item(influence_profile.name)
	
	# Pheromones
	var pheromones_list = _find_node("PheromonesList") as ItemList
	if pheromones_list:
		pheromones_list.clear()
		for pheromone in editing_profile.pheromones:
			if pheromone:
				pheromones_list.add_item(pheromone.name)
#endregion


#region Utility Methods
func _create_row(label_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _find_node(node_name: String) -> Node:
	return find_child(node_name, true, false)
#endregion


#region Signal Handlers
func _on_done_pressed() -> void:
	_request_close()

#endregion

## Edits apply to the live resource immediately; persist them on close
## instead of offering to discard.
func _has_unsaved_changes() -> bool:
	return false  # never block closing — we save instead


func _close_now() -> void:
	if dirty:
		_save_profile()
		Toast.success(get_parent(), "Saved profile '%s'" % editing_profile.name)
	closed.emit(editing_profile)
	super()
