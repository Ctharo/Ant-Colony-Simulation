extends Node
## Runtime catalog + persistence for behavior resources (Logic, AntAction, AntRule).
## Built-ins under res:// are read-only reference material; user-authored files
## live under user://behavior/ and are the only ones that can be saved/deleted.

signal library_changed(kind: String)

const KIND_LOGIC := "logic"
const KIND_ACTION := "action"
const KIND_RULE := "rule"
const KIND_PROFILE := "profile"


const BUILTIN_ROOTS: Array[String] = [
	"res://resources/expressions",
	"res://resources/behavior",
	"res://resources/profiles",
]

const USER_ROOTS: Dictionary = {
	KIND_LOGIC: "user://behavior/expressions",
	KIND_ACTION: "user://behavior/actions",
	KIND_RULE: "user://behavior/rules",
	KIND_PROFILE: "user://behavior/profiles",
}

const _EXPRESSION_BUILTINS: PackedStringArray = [
	"true", "false", "null", "PI", "TAU", "INF", "NAN",
	"and", "or", "not", "in",
	"abs", "min", "max", "clamp", "clampf", "clampi", "pow", "sqrt",
	"floor", "ceil", "round", "sign", "fmod", "lerp", "inverse_lerp",
	"float", "int", "str", "bool",
	"sin", "cos", "tan", "atan2", "deg_to_rad", "rad_to_deg",
	"randf", "randi", "randf_range", "randi_range",
	"Vector2", "Vector2i", "Color",
]

class Entry:
	var resource: Resource
	var path: String
	var writable: bool

	func _init(p_resource: Resource, p_path: String, p_writable: bool) -> void:
		resource = p_resource
		path = p_path
		writable = p_writable
		

	func display_name() -> String:
		var n: String = resource.name if not resource.name.is_empty() else path.get_file()
		return n if writable else "%s  [built-in]" % n

var _catalog: Dictionary = {}
var logger: iLogger


func _ready() -> void:
	logger = iLogger.new("resource_library", DebugLogger.Category.DATA)
	for kind: String in USER_ROOTS:
		DirAccess.make_dir_recursive_absolute(USER_ROOTS[kind])
	rescan()


func rescan() -> void:
	_catalog = { KIND_LOGIC: [], KIND_ACTION: [], KIND_RULE: [] , KIND_PROFILE: []}
	for root in BUILTIN_ROOTS:
		_scan_dir(root, false)
	for kind: String in USER_ROOTS:
		_scan_dir(USER_ROOTS[kind], true)
	for kind: String in _catalog:
		_catalog[kind].sort_custom(func(a: Entry, b: Entry) -> bool:
			return a.display_name().naturalnocasecmp_to(b.display_name()) < 0
		)
	for kind: String in _catalog:
		library_changed.emit(kind)


## Lints every Logic expression: flags identifiers that are neither nested
## bindings, AntSenses vocabulary, nor Expression built-ins. Run once from
## the debug menu (or a breakpoint) after any vocabulary change.
func audit_expressions() -> void:
	var known := {}
	for entry: Dictionary in AntSenses.get_vocabulary():
		known[entry.name] = true
	for builtin in _EXPRESSION_BUILTINS:
		known[builtin] = true

	var ident_regex := RegEx.create_from_string("(?<![.\\w])[A-Za-z_][A-Za-z0-9_]*")
	var string_regex := RegEx.create_from_string("\"[^\"]*\"")
	var issues := 0

	for entry: Entry in get_entries(KIND_LOGIC):
		var logic: Logic = entry.resource
		var bound := {}
		for nested: Logic in logic.nested_expressions:
			bound[nested.id] = true

		var stripped := string_regex.sub(logic.expression_string, "", true)
		for m: RegExMatch in ident_regex.search_all(stripped):
			var ident := m.get_string()
			if not known.has(ident) and not bound.has(ident):
				logger.warn("audit: '%s' (%s) uses unknown identifier '%s'" % [
					logic.name, entry.path, ident
				])
				issues += 1

	logger.info("Expression audit complete: %d issue(s)" % issues)

func _scan_dir(dir_path: String, writable: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var full := dir_path.path_join(fname)
		if dir.current_is_dir():
			if not fname.begins_with("."):
				_scan_dir(full, writable)
		elif fname.get_extension() == "tres":
			_register_file(full, writable)
		fname = dir.get_next()
	dir.list_dir_end()


func _register_file(path: String, writable: bool) -> void:
	var res: Resource = ResourceLoader.load(path)
	if not res:
		logger.warn("Failed to load resource: %s" % path)
		return
	var kind := _kind_of(res)
	if kind.is_empty():
		return
	_catalog[kind].append(Entry.new(res, path, writable))


## Classification by script type. Influence subclasses Logic but is managed
## through InfluenceProfiles, so it's excluded from the generic logic list.
func _kind_of(res: Resource) -> String:
	if res is AntProfile:
		return KIND_PROFILE
	if res is AntRule:
		return KIND_RULE
	if res is AntAction:
		return KIND_ACTION
	if res is Influence:
		return ""
	if res is Logic:
		return KIND_LOGIC
	return ""


func get_entries(kind: String) -> Array:
	return _catalog.get(kind, [])


## True if another entry of this kind already uses this id.
func has_id_conflict(kind: String, id: String, exclude: Resource) -> bool:
	for entry: Entry in get_entries(kind):
		if entry.resource != exclude and entry.resource.get("id") == id:
			return true
	return false


## Saves to user://. previous_path handles renames (stale file removal) and
## the fork case: a built-in edited in the UI lands here as a new user file.
func save_resource(res: Resource, kind: String, previous_path: String = "") -> Error:
	var dir: String = USER_ROOTS[kind]
	DirAccess.make_dir_recursive_absolute(dir)

	var id: String = res.get("id")
	var fname := ("%s.tres" % id) if not id.is_empty() else ("unnamed_%d.tres" % res.get_instance_id())
	var path := dir.path_join(fname)

	var err := ResourceSaver.save(res, path)
	if err != OK:
		logger.error("Save failed (%s): %s" % [error_string(err), path])
		return err

	res.take_over_path(path)

	# Renamed user file: remove the file under the old name
	if not previous_path.is_empty() and previous_path != path \
			and previous_path.begins_with("user://"):
		DirAccess.remove_absolute(previous_path)

	logger.info("Saved %s -> %s" % [kind, path])
	rescan()
	return OK


func delete_resource(entry: Entry) -> Error:
	if not entry.writable:
		return ERR_FILE_NO_PERMISSION
	var err := DirAccess.remove_absolute(entry.path)
	if err == OK:
		logger.info("Deleted %s" % entry.path)
		rescan()
	return err


## Editable working copy: new resource instance, shared nested/param refs.
func duplicate_for_edit(res: Resource) -> Resource:
	return res.duplicate(false)
