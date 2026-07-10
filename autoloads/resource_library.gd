extends Node
## Runtime catalog + persistence for behavior resources (Logic, AntAction,
## AntRule, AntProfile, Pheromone, Influence, InfluenceProfile). Everything
## lives under user://behavior/ and is fully editable: defaults are generated
## in code by DefaultLibrarySeeder on first run (see that file for the
## never-clobber / deletions-stick policy), so the project no longer ships
## any built-in .tres under res://.
##
## Consequences of the all-user model:
## - Every Entry is writable; the old fork-a-built-in-on-save path is gone.
## - Deleting a default is permanent (the seed manifest remembers it).
## - res://entities/pheromone/resources and res://resources/influences are
##   both deletable once you've launched with the v4 seeder (its migration
##   passes swap profile references off res://). Remember ant.tscn still
##   bakes res:// pheromones on the Ant node — clear that export too.

signal library_changed(kind: String)

const KIND_LOGIC := "logic"
const KIND_ACTION := "action"
const KIND_RULE := "rule"
const KIND_PROFILE := "profile"
const KIND_PHEROMONE := "pheromone"
const KIND_INFLUENCE := "influence"
const KIND_INFLUENCE_PROFILE := "influence_profile"

const USER_ROOTS: Dictionary = {
	KIND_LOGIC: "user://behavior/expressions",
	KIND_ACTION: "user://behavior/actions",
	KIND_RULE: "user://behavior/rules",
	KIND_PROFILE: "user://behavior/profiles",
	KIND_PHEROMONE: "user://behavior/pheromones",
	KIND_INFLUENCE: "user://behavior/influences",
	KIND_INFLUENCE_PROFILE: "user://behavior/influence_profiles",
}

class Entry:
	var resource: Resource
	var path: String
	## Always true in the all-user model; kept so existing UI code compiles
	## unchanged. Remove once no panel reads it.
	var writable: bool

	func _init(p_resource: Resource, p_path: String, p_writable: bool = true) -> void:
		resource = p_resource
		path = p_path
		writable = p_writable

	func display_name() -> String:
		return resource.name if not resource.name.is_empty() else path.get_file()

var _catalog: Dictionary = {}
var logger: iLogger


func _ready() -> void:
	logger = iLogger.new("resource_library", DebugLogger.Category.DATA)
	for kind: String in USER_ROOTS:
		DirAccess.make_dir_recursive_absolute(USER_ROOTS[kind])
	# Generate any missing defaults BEFORE the first scan so the catalog
	# (and everything that queries it during startup) sees them.
	DefaultLibrarySeeder.seed()
	rescan()

func rescan() -> void:
	_catalog = {}
	for kind: String in USER_ROOTS:
		_catalog[kind] = []
	for kind: String in USER_ROOTS:
		_scan_dir(USER_ROOTS[kind])
	for kind: String in _catalog:
		_catalog[kind].sort_custom(func(a: Entry, b: Entry) -> bool:
			return a.display_name().naturalnocasecmp_to(b.display_name()) < 0
		)
	for kind: String in _catalog:
		library_changed.emit(kind)


func get_entries(kind: String) -> Array:
	return _catalog.get(kind, [])


## Resource with the given id, or null. This is the lookup that replaced
## hardcoded res:// paths (e.g. Ant.DEFAULT_RULE_IDS).
func get_by_id(kind: String, id: String) -> Resource:
	for entry: Entry in get_entries(kind):
		if entry.resource.get("id") == id:
			return entry.resource
	return null


## True if another entry of this kind already uses this id.
func has_id_conflict(kind: String, id: String, exclude: Resource) -> bool:
	for entry: Entry in get_entries(kind):
		if entry.resource != exclude and entry.resource.get("id") == id:
			return true
	return false


## Saves to user://. previous_path handles renames (stale file removal).
##
## Validation gates:
##  - KIND_LOGIC and KIND_INFLUENCE resources ARE Logic and go through
##    LogicValidator directly (influences additionally must be Vector2-typed).
##  - Every kind is then walked for embedded/attached Logic (a Pheromone's
##    emit condition, an Influence's gate condition, an InfluenceProfile's
##    enter/exit conditions and influence list) and each is validated too —
##    a hand-edited .tres can't smuggle a non-whitelisted expression in
##    through a parent resource.
func save_resource(res: Resource, kind: String, previous_path: String = "") -> Error:
	if kind == KIND_LOGIC or kind == KIND_INFLUENCE:
		var errors := LogicValidator.validate_logic(res)
		if not errors.is_empty():
			push_error("Refusing to save %s '%s': %s" % [kind, res.id, "; ".join(errors)])
			return ERR_INVALID_DATA

	var embedded := _embedded_logic_errors(res, kind)
	if not embedded.is_empty():
		push_error("Refusing to save %s '%s': %s" % [
			kind, str(res.get("id")), "; ".join(embedded)])
		return ERR_INVALID_DATA

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

	# Renamed file: remove the file under the old name
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


## Logic resources embedded inside (or attached to) a resource of the given
## kind, validated with the same whitelist as first-class Logic.
func _embedded_logic_errors(res: Resource, kind: String) -> PackedStringArray:
	var errors := PackedStringArray()
	match kind:
		KIND_PHEROMONE:
			var cond: Logic = res.get("condition")
			if cond:
				for e: String in LogicValidator.validate_logic(cond):
					errors.append("emit condition: %s" % e)
		KIND_INFLUENCE:
			if res.get("type") != TYPE_VECTOR2:
				errors.append("an Influence must be Vector2-typed (it is a direction)")
			var gate: Logic = res.get("condition")
			if gate:
				for e: String in LogicValidator.validate_logic(gate):
					errors.append("gate condition: %s" % e)
		KIND_INFLUENCE_PROFILE:
			for cond: Logic in res.get("enter_conditions"):
				if cond:
					for e: String in LogicValidator.validate_logic(cond):
						errors.append("enter condition '%s': %s" % [cond.name, e])
			for cond: Logic in res.get("exit_conditions"):
				if cond:
					for e: String in LogicValidator.validate_logic(cond):
						errors.append("exit condition '%s': %s" % [cond.name, e])
			for infl in res.get("influences"):
				if not infl:
					continue
				if not infl is Influence:
					errors.append("'%s' is not an Influence" % str(infl.get("name")))
					continue
				for e: String in LogicValidator.validate_logic(infl):
					errors.append("influence '%s': %s" % [infl.name, e])
				var gate: Logic = infl.condition
				if gate:
					for e: String in LogicValidator.validate_logic(gate):
						errors.append("influence '%s' gate: %s" % [infl.name, e])
	return errors


## Lints every Logic expression against the SAME whitelist the validator
## enforces (LogicValidator.allowed_identifiers), so this audit can never
## drift from the real boundary again. Walks first-class Logic, pheromone
## emit conditions, influences (and their gates), and influence-profile
## enter/exit conditions — including ones embedded as subresources. Run from
## the debug menu (or a breakpoint) after any vocabulary change, and before
## deleting the deprecated node-returning methods from AntSenses.
func audit_expressions() -> void:
	var string_regex := RegEx.create_from_string("\"[^\"]*\"")
	var ident_regex := RegEx.create_from_string("(?<![.\\w])[A-Za-z_][A-Za-z0-9_]*")
	var issues := 0

	for entry: Entry in get_entries(KIND_LOGIC):
		issues += _audit_one(entry.resource, entry.path, string_regex, ident_regex)

	for entry: Entry in get_entries(KIND_PHEROMONE):
		var cond: Logic = entry.resource.get("condition")
		if cond:
			issues += _audit_one(cond, entry.path, string_regex, ident_regex)

	for entry: Entry in get_entries(KIND_INFLUENCE):
		issues += _audit_one(entry.resource, entry.path, string_regex, ident_regex)
		var gate: Logic = entry.resource.get("condition")
		if gate:
			issues += _audit_one(gate, entry.path, string_regex, ident_regex)

	for entry: Entry in get_entries(KIND_INFLUENCE_PROFILE):
		for cond: Logic in entry.resource.get("enter_conditions"):
			if cond:
				issues += _audit_one(cond, entry.path, string_regex, ident_regex)
		for cond: Logic in entry.resource.get("exit_conditions"):
			if cond:
				issues += _audit_one(cond, entry.path, string_regex, ident_regex)
		for infl in entry.resource.get("influences"):
			if infl is Logic:
				issues += _audit_one(infl, entry.path, string_regex, ident_regex)
			if infl is Influence and infl.condition:
				issues += _audit_one(infl.condition, entry.path, string_regex, ident_regex)

	logger.info("Expression audit complete: %d issue(s)" % issues)


func _audit_one(logic: Logic, path: String, string_regex: RegEx,
		ident_regex: RegEx) -> int:
	var allowed := LogicValidator.allowed_identifiers(logic.nested_expressions)
	var issues := 0
	var stripped := string_regex.sub(logic.expression_string, "", true)
	for m: RegExMatch in ident_regex.search_all(stripped):
		var ident := m.get_string()
		if not allowed.has(ident):
			logger.warn("audit: '%s' (%s) uses unknown identifier '%s'" % [
				logic.name, path, ident
			])
			issues += 1
	return issues


#region Internals
func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var full := dir_path.path_join(fname)
		if dir.current_is_dir():
			if not fname.begins_with("."):
				_scan_dir(full)
		elif fname.get_extension() == "tres":
			_register_file(full)
		fname = dir.get_next()
	dir.list_dir_end()


func _register_file(path: String) -> void:
	var res: Resource = ResourceLoader.load(path)
	if not res:
		logger.warn("Failed to load resource: %s" % path)
		return
	var kind := _kind_of(res)
	if kind.is_empty():
		return
	_catalog[kind].append(Entry.new(res, path))


## Classification by script type. Influence must be checked before Logic
## (it subclasses it).
func _kind_of(res: Resource) -> String:
	if res is AntProfile:
		return KIND_PROFILE
	if res is AntRule:
		return KIND_RULE
	if res is AntAction:
		return KIND_ACTION
	if res is Pheromone:
		return KIND_PHEROMONE
	if res is InfluenceProfile:
		return KIND_INFLUENCE_PROFILE
	if res is Influence:
		return KIND_INFLUENCE
	if res is Logic:
		return KIND_LOGIC
	return ""
#endregion
