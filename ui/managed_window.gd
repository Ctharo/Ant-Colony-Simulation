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
##  - present() — restores last geometry, or fits-and-centers on first open
##
## Usage in a subclass _init():
##   setup_window("behavior_library", "Behavior Library",
##       Vector2i(420, 520), Vector2i(340, 380))
## Then show it with present() instead of popup_centered().
##
## Geometry rules (learned the hard way):
##  - Never rely on popup_centered(): it centers at the *requested* size, so
##    a window taller than the viewport gets clamped afterwards and ends up
##    pinned to an edge instead of centered.
##  - Bounds come from the EMBEDDER, not the parent. A popup opened as a
##    child of another Window would otherwise be measured against that
##    window's rect and shrunk/pinned inside it.
##  - Embedded windows draw their title bar ABOVE position.y, so the minimum
##    legal y is the title bar height, not 0 — clamping to 0 shoves the bar
##    off-screen and makes the window undraggable.
##  - Size must respect the content's real minimum (get_contents_minimum_size),
##    both on first open and when restoring a saved rect, or a rect persisted
##    while the layout was smaller hides controls forever.
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
var _geometry_saved_on_close: bool = false
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


## Show the window at a sane size and position:
##  - size is at least the content minimum, at most the usable viewport
##  - a saved rect is restored, then corrected by the same limits
##  - first open centers within the band below the title-bar margin
func present() -> void:
	var restored := _restore_geometry()

	var eff_min := _effective_min_size()
	min_size = eff_min  # user resizing can't hide controls either

	var bounds := _viewport_bounds()
	var top := _decoration_top()
	var usable_h := maxi(bounds.y - top, 1)

	var desired: Vector2i = size if restored else _default_size
	size = Vector2i(
		mini(maxi(desired.x, eff_min.x), bounds.x),
		mini(maxi(desired.y, eff_min.y), usable_h),
	)

	if restored:
		_clamp_to_bounds()
	else:
		position = Vector2i(
			maxi(0, (bounds.x - size.x) / 2),
			top + maxi(0, (usable_h - size.y) / 2),
		)

	show()
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
	_geometry_saved_on_close = true
	queue_free()


func _exit_tree() -> void:
	## Safety net for windows freed without close_requested (scene change).
	## Skipped after a normal close, which already saved.
	if not _geometry_saved_on_close:
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
	## Skip windows that never made it on screen (no id, or created but
	## never presented) so a broken open can't persist a garbage rect.
	if window_id.is_empty() or (not visible and not _geometry_restored):
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


## The layout's real minimum: the declared min_size or the content's
## computed minimum, whichever is larger. Only meaningful after the UI has
## been built — present() is always called after _build_ui()/_ready().
func _effective_min_size() -> Vector2i:
	var content := Vector2i(get_contents_minimum_size().ceil())
	return Vector2i(maxi(min_size.x, content.x), maxi(min_size.y, content.y))


## Height of the embedded title bar, drawn ABOVE position.y. The minimum
## legal y — clamping to 0 hides the bar and makes the window undraggable.
func _decoration_top() -> int:
	var h := get_theme_constant("title_height")
	return h if h > 0 else 32


## The area a window may occupy. For embedded windows this is the EMBEDDING
## viewport (the game window), regardless of what node the popup was
## parented to — a popup opened as a child of another ManagedWindow must be
## measured against the screen, not that window's rect. Native windows use
## the physical screen.
func _viewport_bounds() -> Vector2i:
	if is_embedded() and get_tree():
		return Vector2i(get_tree().root.get_visible_rect().size)
	return DisplayServer.screen_get_size()


## Keeps the window fully inside the visible bounds — including keeping the
## title bar below the top edge. Prevents "my designer vanished off-screen"
## and "I can't grab the title bar to move it".
func _clamp_to_bounds() -> void:
	var bounds := _viewport_bounds()
	var top := _decoration_top()
	size = Vector2i(mini(size.x, bounds.x), mini(size.y, maxi(bounds.y - top, 1)))
	position = Vector2i(
		clampi(position.x, 0, maxi(0, bounds.x - size.x)),
		clampi(position.y, top, maxi(top, bounds.y - size.y)),
	)
#endregion
