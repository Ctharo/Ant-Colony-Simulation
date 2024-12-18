class_name AntLogicDebugPanel
extends HBoxContainer

var info_panel: AntInfoPanel
var logic_panel: LogicDebugPanel

func _init(p_info_panel: AntInfoPanel) -> void:
	info_panel = p_info_panel
	
	# Add the existing info panel
	add_child(info_panel)
	
	# Add the new logic debug panel
	logic_panel = LogicDebugPanel.new()
	add_child(logic_panel)
	
	# Initialize when an ant is selected
	info_panel.visibility_changed.connect(_on_info_panel_visibility_changed)

func _on_info_panel_visibility_changed() -> void:
	if info_panel.visible and info_panel.current_ant:
		var ant = info_panel.current_ant
		if ant.action_manager:
			logic_panel.initialize(ant.action_manager.evaluation_system)
			logic_panel.show()
			logic_panel.update_tree()
			logic_panel.update_cache_stats()
	else:
		logic_panel.hide()
