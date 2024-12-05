class_name Path
extends Resource

## The complete path string that updates with path changes
@export var full: String:
	get:
		return full
	set(value):
		full = value
		notify_property_list_changed()
		emit_changed()

## Public accessor for parts that ensures synchronization
var parts: PackedStringArray:
	get:
		return full.to_lower().split(SEPARATOR)

## Static path separator
const SEPARATOR = "."

#region Construction and Parsing
func _init(path: Variant) -> void:
	if path is PackedStringArray:
		var normalized_parts: PackedStringArray = []
		for part in path:
			normalized_parts.append(part.to_lower())
		parts = normalized_parts
		full = SEPARATOR.join(parts) if not parts.is_empty() else "root"
	elif path is String:
		full = path
	else:
		push_error("Problem initializing path with argument %s" % str(path))

## Static constructor from full path string with validation
static func parse(full_path: String) -> Path:
	if not is_valid_path(full_path):
		push_error("Invalid path format: %s" % full_path)
		return Path.new([])

	if full_path.to_lower() == "root":
		return Path.new([])
	return Path.new(full_path.to_lower().split(SEPARATOR))
#endregion

#region Path Information
## Gets the root node name (first part)
func get_root_name() -> String:
	if is_root():
		return "root"
	return parts[0]

## Gets the property/node name (last part)
func get_property() -> String:
	if is_root():
		return "root"
	return parts[-1]

## Gets the depth of this path
func get_depth() -> int:
	return parts.size()
#endregion

#region Path Navigation
## Returns a new path with the given part appended
func append(part: String) -> Path:
	if not is_valid_path_component(part):
		push_error("Invalid path component: %s" % part)
		return self
	var new_parts = parts.duplicate()
	new_parts.append(part.to_lower())
	return Path.new(new_parts)

## Gets a child path by appending a property name
func get_child(property: String) -> Path:
	return append(property)

## Returns true if this path starts with the given pattern
func matches_pattern(pattern: String) -> bool:
	if pattern.is_empty():
		return false
	return full.match(pattern)
#endregion

#region Path Relationships
## Returns true if this path is a descendant of the given path
func is_descendant_of(ancestor: Variant) -> bool:
	var validated_path: Path = Path.validate(ancestor)
	if not validated_path:
		return false
	if validated_path.full.length() >= full.length():
		return false
	return full.begins_with(validated_path.full)

## Returns true if this path is an ancestor of the given path
func is_ancestor_of(descendant: Variant) -> bool:
	var validated_path: Path = Path.validate(descendant)
	if not validated_path:
		return false
	if full.length() >= validated_path.full.length():
		return false
	return validated_path.full.begins_with(full)

## Returns true if this path represents the same path as another
func equals(other_path: Variant) -> bool:
	var validated_path: Path = Path.validate(other_path)
	return full == validated_path.full

## Gets all ancestor paths including self, from root to leaf
static func get_ancestor_paths(path_str: String) -> Array[String]:
	var parts = path_str.split(SEPARATOR)
	var ancestors: Array[String] = []
	var current = ""

	for part in parts:
		if current.is_empty():
			current = part
		else:
			current += SEPARATOR + part
		ancestors.append(current)

	return ancestors
#endregion

#region Path Type Checks
## Returns true if this is a root path (no parts)
func is_root() -> bool:
	return parts.is_empty()

## Returns true if this path only contains a root node
func is_root_node() -> bool:
	return parts.size() == 1

## Utility method to check if a string is in path format
static func is_path_format(text: String) -> bool:
	return text.contains(SEPARATOR)

## Validates a single path component
static func is_valid_path_component(component: String) -> bool:
	return not component.is_empty() and component.is_valid_identifier()

## Validates path format and components
static func is_valid_path(text: String) -> bool:
	if text.is_empty() or text.begins_with(SEPARATOR) or text.ends_with(SEPARATOR):
		return false

	var parts = text.split(SEPARATOR)
	for part in parts:
		if part.is_empty() or not part.is_valid_identifier():
			return false
	return true

static func validate(path: Variant) -> Path:
	match typeof(path):
		TYPE_STRING:
			if path.is_empty():
				return null
			return Path.parse(path)
		TYPE_OBJECT:
			if path is Path:
				return path
			return null
		_:
			return null

func _to_string() -> String:
	return full
