class_name DraggablePanel
extends PanelContainer
## Base class for draggable, expandable panels with persistent positioning.
## Extend this class and override panel_id to get automatic save/load of position and expanded state.

#region Signals
signal drag_started
signal drag_ended
signal collapsed
signal expanded
#endregion

#region Constants
const DRAG_HANDLE_HEIGHT: int = 30
const EDGE_PADDING: int = 10
const COLLAPSE_ANIMATION_DURATION: float = 0.15
const DEFAULT_MIN_SIZE: Vector2 = Vector2(200, 100)
const COLLAPSED_HEIGHT: int = 40
#endregion

#region Export Variables
## Unique identifier for this panel, used for saving/loading state
@export var panel_id: String = ""
## Whether this panel can be dragged
@export var draggable: bool = true
## Whether this panel can be collapsed
@export var collapsible: bool = true
## Whether to save position between sessions
@export var save_position: bool = true
## Whether to save expanded state between sessions
@export var save_expanded_state: bool = true
#endregion

#region Member Variables
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_expanded: bool = true
var _expanded_size: Vector2 = Vector2.ZERO
var _content_container: Control
var _header_container: Control
var _collapse_button: Button
var _settings_manager: Node
var _initialized: bool = false
#endregion


#region Virtual Methods
## Override in subclass to return the content container that should be hidden when collapsed
func _get_content_container() -> Control:
	return null


## Override in subclass to return the header container used for dragging
func _get_header_container() -> Control:
	return null


## Override in subclass to customize the collapse button
func _get_collapse_button() -> Button:
	return null


## Override in subclass for additional initialization after panel setup
func _on_panel_ready() -> void:
	pass


## Override in subclass to get default position when no saved position exists
func _get_default_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(viewport_size.x - size.x - EDGE_PADDING, EDGE_PADDING)
#endregion


#region Lifecycle
func _ready() -> void:
	_settings_manager = get_node_or_null("/root/SettingsManager")
	
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_content_container = _get_content_container()
	_header_container = _get_header_container()
	_collapse_button = _get_collapse_button()
	
	_setup_dragging()
	_setup_collapse_button()
	
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	## Deferred initialization to ensure size is correct
	_expanded_size = size
	_load_panel_state()
	_on_panel_ready()
	_initialized = true


func _setup_dragging() -> void:
	if not draggable:
		return
	
	if _header_container:
		_header_container.gui_input.connect(_on_header_gui_input)
		_header_container.mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		gui_input.connect(_on_panel_gui_input)


func _setup_collapse_button() -> void:
	if not collapsible:
		return
	
	if _collapse_button:
		_collapse_button.pressed.connect(_toggle_collapsed)
		_update_collapse_button_text()
#endregion


#region Input Handling
func _on_header_gui_input(event: InputEvent) -> void:
	_handle_drag_input(event)


func _on_panel_gui_input(event: InputEvent) -> void:
	## Only drag from the top portion if no header container specified
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var mouse_event: InputEventMouse = event as InputEventMouse
		if mouse_event.position.y <= DRAG_HANDLE_HEIGHT:
			_handle_drag_input(event)


func _handle_drag_input(event: InputEvent) -> void:
	if not draggable:
		return
	
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_start_drag(mouse_button.global_position)
			else:
				_end_drag()
			accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_drag(mouse_motion.global_position)
		accept_event()


func _input(event: InputEvent) -> void:
	## Handle drag even when mouse leaves the panel
	if _is_dragging:
		if event is InputEventMouseMotion:
			var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
			_update_drag(mouse_motion.global_position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mouse_button: InputEventMouseButton = event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
				_end_drag()
				get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	## Stop mouse events from propagating to camera
	if event is InputEventMouseButton:
		accept_event()
#endregion


#region Drag Operations
func _start_drag(global_mouse_pos: Vector2) -> void:
	_is_dragging = true
	_drag_offset = global_position - global_mouse_pos
	drag_started.emit()


func _update_drag(global_mouse_pos: Vector2) -> void:
	if not _is_dragging:
		return
	
	var new_pos: Vector2 = global_mouse_pos + _drag_offset
	global_position = _clamp_to_viewport(new_pos)


func _end_drag() -> void:
	if not _is_dragging:
		return
	
	_is_dragging = false
	drag_ended.emit()
	_save_panel_state()


func _clamp_to_viewport(pos: Vector2) -> Vector2:
	## Clamp panel position to keep it fully visible within viewport
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = size
	
	var clamped_x: float = clampf(pos.x, EDGE_PADDING, viewport_size.x - panel_size.x - EDGE_PADDING)
	var clamped_y: float = clampf(pos.y, EDGE_PADDING, viewport_size.y - panel_size.y - EDGE_PADDING)
	
	return Vector2(clamped_x, clamped_y)
#endregion


#region Collapse Operations
func _toggle_collapsed() -> void:
	if _is_expanded:
		collapse()
	else:
		expand()


func collapse() -> void:
	if not collapsible or not _is_expanded:
		return
	
	_is_expanded = false
	_expanded_size = size
	
	if _content_container:
		var tween: Tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_content_container, "modulate:a", 0.0, COLLAPSE_ANIMATION_DURATION)
		tween.tween_callback(_content_container.hide)
		tween.tween_property(self, "custom_minimum_size:y", COLLAPSED_HEIGHT, COLLAPSE_ANIMATION_DURATION)
	
	_update_collapse_button_text()
	collapsed.emit()
	_save_panel_state()


func expand() -> void:
	if not collapsible or _is_expanded:
		return
	
	_is_expanded = true
	
	if _content_container:
		_content_container.modulate.a = 0.0
		_content_container.show()
		
		var tween: Tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "custom_minimum_size:y", _expanded_size.y, COLLAPSE_ANIMATION_DURATION)
		tween.tween_property(_content_container, "modulate:a", 1.0, COLLAPSE_ANIMATION_DURATION)
	
	_update_collapse_button_text()
	expanded.emit()
	_save_panel_state()


func _update_collapse_button_text() -> void:
	if _collapse_button:
		_collapse_button.text = "▼" if _is_expanded else "▶"


func is_expanded() -> bool:
	return _is_expanded
#endregion


#region Persistence
func _get_settings_key() -> String:
	if panel_id.is_empty():
		return ""
	return "panel_state_%s" % panel_id


func _save_panel_state() -> void:
	if not _initialized:
		return
	
	var settings_key: String = _get_settings_key()
	if settings_key.is_empty() or not _settings_manager:
		return
	
	var state: Dictionary = {}
	
	if save_position:
		state["position_x"] = global_position.x
		state["position_y"] = global_position.y
	
	if save_expanded_state:
		state["expanded"] = _is_expanded
	
	if not state.is_empty():
		_settings_manager.set_setting(settings_key, state)


func _load_panel_state() -> void:
	var settings_key: String = _get_settings_key()
	if settings_key.is_empty() or not _settings_manager:
		_apply_default_position()
		return
	
	var state: Variant = _settings_manager.get_setting(settings_key)
	
	if state == null or not state is Dictionary:
		_apply_default_position()
		return
	
	var state_dict: Dictionary = state as Dictionary
	
	if save_position and state_dict.has("position_x") and state_dict.has("position_y"):
		var saved_pos: Vector2 = Vector2(state_dict["position_x"], state_dict["position_y"])
		global_position = _clamp_to_viewport(saved_pos)
	else:
		_apply_default_position()
	
	if save_expanded_state and state_dict.has("expanded"):
		var should_expand: bool = state_dict["expanded"]
		if should_expand and not _is_expanded:
			expand()
		elif not should_expand and _is_expanded:
			collapse()


func _apply_default_position() -> void:
	var default_pos: Vector2 = _get_default_position()
	global_position = _clamp_to_viewport(default_pos)


## Force save the current panel state
func save_state() -> void:
	_save_panel_state()


## Reset panel to default position
func reset_position() -> void:
	_apply_default_position()
	_save_panel_state()
#endregion


#region Public Methods
## Set panel position with bounds checking
func set_panel_position(pos: Vector2) -> void:
	global_position = _clamp_to_viewport(pos)
	_save_panel_state()


## Get whether the panel is currently being dragged
func is_dragging() -> bool:
	return _is_dragging
#endregion
