extends Control
class_name BehaviorEditor

signal behavior_saved

var rule_manager: RuleManager
var data_manager: DataManager

var behavior_list: ItemList
var add_rule_button: Button
var edit_rule_button: Button
var delete_rule_button: Button
var save_button: Button

var current_entity: String
var is_colony: bool

func _ready():
	rule_manager = RuleManager
	data_manager = DataManager
	create_ui()

func create_ui():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(main_container)

	var title = Label.new()
	title.text = "Behavior Editor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)

	behavior_list = ItemList.new()
	behavior_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	behavior_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(behavior_list)

	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)

	add_rule_button = Button.new()
	add_rule_button.text = "Add Rule"
	add_rule_button.connect("pressed", Callable(self, "_on_add_rule_pressed"))
	button_container.add_child(add_rule_button)

	edit_rule_button = Button.new()
	edit_rule_button.text = "Edit Rule"
	edit_rule_button.connect("pressed", Callable(self, "_on_edit_rule_pressed"))
	button_container.add_child(edit_rule_button)

	delete_rule_button = Button.new()
	delete_rule_button.text = "Delete Rule"
	delete_rule_button.connect("pressed", Callable(self, "_on_delete_rule_pressed"))
	button_container.add_child(delete_rule_button)

	save_button = Button.new()
	save_button.text = "Save Behavior"
	save_button.connect("pressed", Callable(self, "_on_save_pressed"))
	main_container.add_child(save_button)

func show_behavior(entity_name: String, _is_colony: bool):
	self.current_entity = entity_name
	self.is_colony = _is_colony
	behavior_list.clear()
	var behaviors = rule_manager.load_rules(entity_name, _is_colony)
	for rule in behaviors:
		behavior_list.add_item(rule_manager.format_rule(rule))
	show()

func _on_add_rule_pressed():
	var rule_dialog = RuleEditorDialog.new()
	rule_dialog.rule_created.connect(Callable(self, "_on_rule_created"))
	add_child(rule_dialog)
	rule_dialog.popup_centered()

func _on_edit_rule_pressed():
	var selected_items = behavior_list.get_selected_items()
	if selected_items.is_empty():
		show_error("No rule selected for editing")
		return
	var selected_rule = rule_manager.parse_rule(behavior_list.get_item_text(selected_items[0]))
	var rule_dialog = RuleEditorDialog.new()
	rule_dialog.set_rule(selected_rule)
	rule_dialog.connect("rule_updated", Callable(self, "_on_rule_updated").bind(selected_items[0]))
	add_child(rule_dialog)
	rule_dialog.popup_centered()

func _on_delete_rule_pressed():
	var selected_items = behavior_list.get_selected_items()
	if selected_items.is_empty():
		show_error("No rule selected for deletion")
		return
	behavior_list.remove_item(selected_items[0])

func _on_save_pressed():
	var updated_behavior = []
	for i in range(behavior_list.get_item_count()):
		updated_behavior.append(rule_manager.parse_rule(behavior_list.get_item_text(i)))
	rule_manager.save_rules(current_entity, updated_behavior, is_colony)
	hide()
	emit_signal("behavior_saved")

func _on_rule_created(new_rule: Dictionary):
	behavior_list.add_item(rule_manager.format_rule(new_rule))

func _on_rule_updated(updated_rule: Dictionary, index: int):
	behavior_list.set_item_text(index, rule_manager.format_rule(updated_rule))

func show_error(message: String):
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	add_child(error_dialog)
	error_dialog.popup_centered()
