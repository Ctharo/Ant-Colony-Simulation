class_name ManagedWindow
extends Window
## Base class for all runtime tool windows (library, designer, editors).
##
## Adds modern window behavior on top of Godot's embedded Window:
##  - Persistent size & position per window_id (via SettingsManager)
##  - Clamped to the visible viewport so a window can never be lost off-screen
##  - Esc closes (releases text-field focus first), Ctrl+S / Ctrl+Enter confirms
##  - Built-in dirty tracking: mark_dirty()/clear_dirty(), a "●" title marker,
##    and an automatic discard-confirmation on close while dirty
##  - watch(controls) wires change signals from form controls to mark_dirty()
##  - toast_success/error/info(text) for temporary status messages (Toast)
##  - present() — restores last geometry, or centers on first open
##
## Usage in a subclass _init():
##   setup_window("behavior_library", "Behavior Library",
##       Vector2i(420, 520), Vector2i(340, 380))
## Then show it with present() instead of popup_centered().
##
## CRUD editors: call watch([...]) at the end of _build_ui(), clear_dirty()
## after a successful save (and after programmatically loading a form —
## SpinBox.value= and CheckBox.button_pressed= emit change signals), and
## override _confirm_shortcut() to route Ctrl+S to the save handler.

#region Member Variables
var window_id: String = ""
## True when the user has unsaved edits. Setting it updates the title marker;
## the default _has_unsaved_changes() returns this flag.
var dirty: bool = false:
	set(value):
		if dirty == value:
			return
		dirty = value
		if _base_title.is_empty():
			_base_title = title
		title = ("● " + _base_title) if dirty else _base_title

var _base_title: String = ""
var _default_size: Vector2i = Vector2i(480, 400)
var _geometry_restored: bool = false
var _close_confirm: ConfirmationDialog
#endregion


#region Setup
## Call from the subclass _init(). Replaces the old boilerplate
## (title / size / min_size / process_mode / close_requested).
func setup_window(id: String, p_title: String, p_size: Vector2i,
		p_min_size: Vector2i, p_transient: bool = false) -> void:
	window_id = id
	title = p_title
	_base_title = p_title
	_default_size = p_size
	size = p_size
	min_size = p_min_size
	unresizable = false
	transient = p_transient
	process_mode = Node.PROCESS_MODE_ALWAYS

	close_requested.connect(_request_close)
	window_input.connect(_on_window_input)
	focus_entered.connect(move_to_foreground)


## Show the window: restore saved geometry if we have it, else center.
func present() -> void:
	if _restore_geometry():
		show()
	else:
		popup_centered(_default_size)
	_clamp_to_bounds()
	grab_focus()


## Update the visible title while keeping the dirty marker consistent.
## Use this instead of assigning `title` for dynamic titles
## (e.g. "Edit Ant Profile: Soldier").
func set_window_title(p_title: String) -> void:
	_base_title = p_title
	title = ("● " + _base_title) if dirty else _base_title
#endregion


#region Dirty tracking
func mark_dirty() -> void:
	dirty = true


func clear_dirty() -> void:
	dirty = false


## Connects each control's change signal to mark_dirty(). Call once at the
## end of _build_ui() with every user-editable form control. Note: setting
## SpinBox.value or CheckBox.button_pressed in code DOES emit these signals,
## so call clear_dirty() after programmatically populating a form.
func watch(controls: Array) -> void:
	for c in controls:
		if c is LineEdit:
			c.text_changed.connect(func(_t: String) -> void: mark_dirty())
		elif c is TextEdit:
			c.text_changed.connect(mark_dirty)
		elif c is Range:  # SpinBox, Slider, ProgressBar-likes
			c.value_changed.connect(func(_v: float) -> void: mark_dirty())
		elif c is OptionButton:  # must precede BaseButton — OptionButton is one
			c.item_selected.connect(func(_i: int) -> void: mark_dirty())
		elif c is BaseButton:  # CheckBox / CheckButton
			c.toggled.connect(func(_on: bool) -> void: mark_dirty())
#endregion


#region Toasts
func toast_success(text: String) -> void:
	Toast.success(self, text)


func toast_error(text: String) -> void:
	Toast.error(self, text)


func toast_info(text: String) -> void:
	Toast.info(self, text)
#endregion


#region Virtual hooks
## Closing while this returns true asks for confirmation first.
## Default: the built-in dirty flag. Override for custom logic.
func _has_unsaved_changes() -> bool:
	return dirty


## Override to handle Ctrl+S / Ctrl+Enter (e.g. call _on_save()).
## Return true if the shortcut was consumed.
func _confirm_shortcut() -> bool:
	return false
#endregion


#region Close handling
func _request_close() -> void:
	if _has_unsaved_changes():
		_show_close_confirm()
		return
	_close_now()


func _show_close_confirm() -> void:
	if not _close_confirm:
		_close_confirm = ConfirmationDialog.new()
		_close_confirm.dialog_text = "Discard unsaved changes?"
		_close_confirm.ok_button_text = "Discard"
		_close_confirm.confirmed.connect(_close_now)
		add_child(_close_confirm)
	_close_confirm.popup_centered()


func _close_now() -> void:
	_save_geometry()
	queue_free()


func _exit_tree() -> void:
	## Safety net for windows freed without close_requested (scene change).
	_save_geometry()
#endregion


#region Keyboard
func _on_window_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	match key.keycode:
		KEY_ESCAPE:
			## First Esc while typing just leaves the field; second closes.
			var focus: Control = gui_get_focus_owner()
			if focus is LineEdit or focus is TextEdit:
				focus.release_focus()
			else:
				_request_close()
			set_input_as_handled()
		KEY_S, KEY_ENTER, KEY_KP_ENTER:
			if key.is_command_or_control_pressed() and _confirm_shortcut():
				set_input_as_handled()
#endregion


#region Geometry persistence & clamping
func _geometry_key() -> String:
	return "win_%s_rect" % window_id


func _save_geometry() -> void:
	if window_id.is_empty() or not visible and not _geometry_restored:
		return
	SettingsManager.set_setting(_geometry_key(), {
		"x": position.x, "y": position.y,
		"w": size.x, "h": size.y,
	})


func _restore_geometry() -> bool:
	if window_id.is_empty():
		return false
	var rect: Variant = SettingsManager.get_setting(_geometry_key())
	if not rect is Dictionary or not rect.has_all(["x", "y", "w", "h"]):
		return false
	size = Vector2i(maxi(int(rect.w), min_size.x), maxi(int(rect.h), min_size.y))
	position = Vector2i(int(rect.x), int(rect.y))
	_geometry_restored = true
	return true


## Keeps the window fully inside the parent viewport (embedded windows) or
## the screen (native). Prevents "my designer vanished off-screen".
func _clamp_to_bounds() -> void:
	var bounds: Vector2i
	var parent := get_parent()
	if parent and parent.get_viewport():
		bounds = Vector2i(parent.get_viewport().get_visible_rect().size)
	else:
		bounds = DisplayServer.screen_get_size()

	size = Vector2i(mini(size.x, bounds.x), mini(size.y, bounds.y))
	position = Vector2i(
		clampi(position.x, 0, maxi(0, bounds.x - size.x)),
		clampi(position.y, 0, maxi(0, bounds.y - size.y)),
	)
#endregion
