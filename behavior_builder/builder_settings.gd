class_name BBBuilderSettings
extends RefCounted
## Persisted UI prefs for the graph editor (grid/snap toggles), so they
## survive across sessions instead of resetting to GraphEdit's own defaults
## (grid visible, snapping on). Persisted to user://behavior_builder_settings.json.

const SAVE_PATH: String = "user://behavior_builder_settings.json"

var show_grid: bool = false
var snapping_enabled: bool = false


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		show_grid = bool(d.get("show_grid", show_grid))
		snapping_enabled = bool(d.get("snapping_enabled", snapping_enabled))


func save_to_disk() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"show_grid": show_grid,
		"snapping_enabled": snapping_enabled,
	}, "  "))
