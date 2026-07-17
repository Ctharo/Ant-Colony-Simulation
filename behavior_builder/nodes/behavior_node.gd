class_name BBBehaviorNode
extends BBNode
## Terminal node: "do ACTION when condition is true", optionally AT a target.
## ACTION is stubbed for now — the node flashes, counts, and prints on every
## rising edge (false/unknown -> true) so you can test conditions live.
##
## The TARGET port (teal, optional) accepts a picked item from the list
## pipeline, e.g. SENSE(ants) → FILTER is_ally is FALSE → PICK nearest.
## When wired, the node shows the live target and includes it in the fire
## print — this is where a real "move_to(target)" hookup will read from.
##
## The green/red body tint comes from the base class now, so no
## self_modulate hack is needed here anymore.

var fire_label: Label
var target_label: Label
var fires: int = 0

var _prev: bool = false
var _target: Variant = null


func _init() -> void:
	bb_type = "behavior"
	title = "⚡ BEHAVIOR"


func _build() -> void:
	var when_lab: Label = Label.new()
	when_lab.text = "WHEN (true/false)"
	add_child(when_lab)  # slot 0 — input port 0 (bool)

	target_label = Label.new()
	target_label.text = "TARGET (optional)"
	target_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	add_child(target_label)  # slot 1 — input port 1 (entity)

	var act_lab: Label = Label.new()
	act_lab.text = "→ ACTION  (stub for now)"
	act_lab.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	add_child(act_lab)

	fire_label = Label.new()
	fire_label.text = "fired ×0"
	add_child(fire_label)

	set_slot(0, true, TYPE_BOOL, COL_BOOL, false, 0, Color.WHITE)
	set_slot(1, true, TYPE_ENTITY, COL_ENTITY, false, 0, Color.WHITE)
	_make_value_footer()


func input_count() -> int:
	return 2


func input_type(port: int) -> int:
	return TYPE_BOOL if port == 0 else TYPE_ENTITY


func on_inputs(values: Array, connected: Array) -> void:
	super.on_inputs(values, connected)
	var target_wired: bool = connected.size() > 1 and bool(connected[1])
	_target = values[1] if target_wired and values.size() > 1 else null
	if target_wired:
		target_label.text = "TARGET ▸ %s" % fmt(_target)
		target_label.add_theme_color_override("font_color", val_color(_target))
	else:
		target_label.text = "TARGET (optional)"
		target_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))


func on_value(v: Variant) -> void:
	super.on_value(v)
	var now: bool = v is bool and bool(v)
	if now and not _prev:
		fires += 1
		fire_label.text = "fired ×%d" % fires
		fire_label.add_theme_color_override("font_color", COL_TRUE)
		var target_note: String = "  target: %s" % fmt(_target) if _target != null else ""
		print("[BehaviorBuilder] BEHAVIOR FIRED (%s)  ×%d%s" % [name, fires, target_note])
		_flash()
	_prev = now


func _flash() -> void:
	var tw: Tween = create_tween()
	modulate = Color(1.7, 1.7, 1.0)
	var _tweener: PropertyTweener = tw.tween_property(
		self, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_CUBIC)
