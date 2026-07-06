class_name Toast
extends PanelContainer
## Temporary status message ("Saved", "Deleted", "Save failed — see log").
## Fades in at the bottom-center of its host window, holds (longer for longer
## text), then fades out and frees itself. Multiple toasts stack upward.
##
## Usage from anywhere:
##   Toast.success(self, "Saved role '%s'" % name)
##   Toast.error(self, "Save failed — see log")
##   Toast.info(get_tree().root, "Cache cleared")
##
## ManagedWindow exposes toast_success/error/info(text) as shortcuts.
##
## The toast attaches to the *Window* that owns the host node, so a message
## triggered from inside an embedded popup renders inside that popup rather
## than hiding behind it in the main viewport. If the host window is already
## being freed (editor popups that save-and-close), pass the popup's parent
## as the host so the toast outlives it:
##   Toast.success(get_parent(), "Saved '%s'" % editing.name)
##   queue_free()

enum Kind { INFO, SUCCESS, ERROR }

#region Constants
const BG_COLORS := {
	Kind.INFO: Color(0.16, 0.18, 0.22, 0.95),
	Kind.SUCCESS: Color(0.10, 0.26, 0.15, 0.95),
	Kind.ERROR: Color(0.30, 0.10, 0.10, 0.95),
}
const BORDER_COLORS := {
	Kind.INFO: Color(0.45, 0.55, 0.70),
	Kind.SUCCESS: Color.SEA_GREEN,
	Kind.ERROR: Color.INDIAN_RED,
}
const MARGIN_BOTTOM: float = 14.0
const STACK_GAP: float = 6.0
const SLIDE_DISTANCE: float = 8.0
const FADE_IN: float = 0.15
const FADE_OUT: float = 0.35
## Hold time scales with message length so errors stay readable.
const MIN_HOLD: float = 1.6
const HOLD_PER_CHAR: float = 0.03
#endregion

var _text: String = ""
var _kind: Kind = Kind.INFO


#region Static API
static func success(host: Node, text: String) -> void:
	_spawn(host, text, Kind.SUCCESS)


static func error(host: Node, text: String) -> void:
	_spawn(host, text, Kind.ERROR)


static func info(host: Node, text: String) -> void:
	_spawn(host, text, Kind.INFO)


static func _spawn(host: Node, text: String, kind: Kind) -> void:
	if host == null or not is_instance_valid(host):
		return

	var window: Window = host if host is Window else host.get_window()
	## A window that is saving-and-closing can't host a toast; climb out of it.
	while window and window.is_queued_for_deletion():
		var up: Node = window.get_parent()
		window = up.get_window() if up else null
	if window == null:
		return

	var toast := Toast.new()
	toast._text = text
	toast._kind = kind
	window.add_child(toast)
#endregion


#region Lifecycle
func _init() -> void:
	## Never intercept clicks, and keep animating while the sim is paused.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	add_to_group("toasts")


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLORS[_kind]
	style.border_color = BORDER_COLORS[_kind]
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = _text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	size = get_combined_minimum_size()
	_reposition()
	_animate()
#endregion


#region Placement & animation
## Bottom-center of the host window, stacked above earlier live toasts.
func _reposition() -> void:
	var bounds: Vector2 = get_parent_area_size()
	var stack := 0
	for sibling in get_parent().get_children():
		if sibling == self:
			break
		if sibling is Toast:
			stack += 1
	position = Vector2(
		(bounds.x - size.x) * 0.5,
		bounds.y - size.y - MARGIN_BOTTOM - stack * (size.y + STACK_GAP)
	)


func _animate() -> void:
	var rest_y := position.y
	position.y += SLIDE_DISTANCE
	modulate.a = 0.0

	var hold := MIN_HOLD + _text.length() * HOLD_PER_CHAR

	var tween := create_tween()
	## Tweens inherit tree pause otherwise; toasts must run while paused.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	tween.parallel().tween_property(self, "position:y", rest_y, FADE_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(hold)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(queue_free)
#endregion
