class_name BBBehaviorNode
extends BBNode
## Terminal node: "do ACTION when condition is true".
## ACTION is stubbed for now — the node flashes, counts, and prints on every
## rising edge (false/unknown -> true) so you can test conditions live.

var fire_label: Label
var fires := 0
var _prev := false


func _init() -> void:
	bb_type = "behavior"
	title = "⚡ BEHAVIOR"


func _build() -> void:
	var when := Label.new()
	when.text = "WHEN (true/false)"
	add_child(when)  # slot 0 — input port 0

	var act := Label.new()
	act.text = "→ ACTION  (stub for now)"
	act.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	add_child(act)

	fire_label = Label.new()
	fire_label.text = "fired ×0"
	add_child(fire_label)

	set_slot(0, true, TYPE_BOOL, COL_BOOL, false, 0, Color.WHITE)
	_make_value_footer()


func input_count() -> int:
	return 1


func input_type(_port: int) -> int:
	return TYPE_BOOL


func on_value(v) -> void:
	super.on_value(v)
	var now: bool = v is bool and v
	if now and not _prev:
		fires += 1
		fire_label.text = "fired ×%d" % fires
		fire_label.add_theme_color_override("font_color", COL_TRUE)
		print("[BehaviorBuilder] BEHAVIOR FIRED (%s)  ×%d" % [name, fires])
		_flash()
	_prev = now
	self_modulate = Color(1.12, 1.12, 0.95) if now else Color.WHITE


func _flash() -> void:
	var tw := create_tween()
	modulate = Color(1.7, 1.7, 1.0)
	tw.tween_property(self, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_CUBIC)
