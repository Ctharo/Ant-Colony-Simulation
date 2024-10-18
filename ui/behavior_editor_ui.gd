extends Popup
class_name BehaviorEditorUI

signal rule_added(rule)
signal rule_edited(index, rule)
signal rule_deleted(index)

var rule_manager: RuleManager
var behavior_list: ItemList
var rule_list: ItemList
var add_rule_button: Button
var edit_rule_button: Button
var delete_rule_button: Button

func _ready():
	rule_manager = RuleManager
	create_ui()

func create_ui():
	var vbox = VBoxContainer.new()
	add_child(vbox)

	behavior_list = ItemList.new()
	behavior_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(behavior_list)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	add_rule_button = Button.new()
	add_rule_button.text = "Add Rule"
	add_rule_button.connect("pressed", Callable(self, "_on_add_rule_pressed"))
	hbox.add_child(add_rule_button)

	edit_rule_button = Button.new()
	edit_rule_button.text = "Edit Rule"
	edit_rule_button.connect("pressed", Callable(self, "_on_edit_rule_pressed"))
	hbox.add_child(edit_rule_button)

	delete_rule_button = Button.new()
	delete_rule_button.text = "Delete Rule"
	delete_rule_button.connect("pressed", Callable(self, "_on_delete_rule_pressed"))
	hbox.add_child(delete_rule_button)

func set_rules(rules: Array):
	behavior_list.clear()
	for rule in rules:
		behavior_list.add_item(rule_manager.format_rule(rule))

func get_rules() -> Array:
	var rules = []
	for i in range(behavior_list.get_item_count()):
		rules.append(rule_manager.parse_rule(behavior_list.get_item_text(i)))
	return rules

func _on_add_rule_pressed():
	var new_rule = {
		"property": BehaviorConfig.property_options[0],
		"operator": BehaviorConfig.ComparisonOperator.EQUAL,
		"value": "0",
		"action": BehaviorConfig.action_options[0]
	}
	behavior_list.add_item(rule_manager.format_rule(new_rule))
	emit_signal("rule_added", new_rule)

func _on_edit_rule_pressed():
	var selected_items = rule_list.get_selected_items()
	if selected_items.is_empty():
		show_error("No rule selected for editing")
		return
	
	var selected_rule = rule_list.get_item_text(selected_items[0])
	var rule_data = rule_manager.parse_rule(selected_rule)
	
	var rule_editor = RuleEditorDialog.new()
	rule_editor.set_rule(rule_data)
	rule_editor.connect("rule_saved", Callable(self, "_on_rule_saved").bind(selected_items[0]))
	add_child(rule_editor)
	rule_editor.popup_centered()

func _on_rule_saved(new_rule: Dictionary, rule_index: int):
	rule_list.set_item_text(rule_index, rule_manager.format_rule(new_rule))
	emit_signal("rule_edited", rule_index, new_rule)

func _on_save_rule_changes(rule_index: int, edit_dialog: Window):
	var new_rule = rule_manager.get_rule_from_dialog(edit_dialog)
	behavior_list.set_item_text(rule_index, rule_manager.format_rule(new_rule))
	edit_dialog.queue_free()
	emit_signal("rule_edited", rule_index, new_rule)

func _on_delete_rule_pressed():
	var selected_items = behavior_list.get_selected_items()
	if selected_items.is_empty():
		show_error("No rule selected for deletion")
		return
	var index = selected_items[0]
	behavior_list.remove_item(index)
	emit_signal("rule_deleted", index)

func show_error(message: String):
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	add_child(error_dialog)
	error_dialog.popup_centered()
