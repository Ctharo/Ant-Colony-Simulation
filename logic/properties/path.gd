class_name Path
extends Resource

## Private storage for the path string
var _path: String

## The editable path string in the inspector
@export var path: String:
	set(value):
		_path = value  
		if value.to_lower() == "root":
			_parts = []
		else:
			_parts = value.to_lower().split(SEPARATOR)
		notify_property_list_changed()
		emit_changed()
	get:
		return _path

## The complete path string that updates with path changes
@export var full: String:
	get:
		return get_full_path()
	set(value):  # Add setter to satisfy export, but it just updates path
		path = value  # This will trigger path's setter and update everything

## The parts of the path from root to leaf - now private
var _parts: Array[String]

## Public accessor for parts that ensures synchronization
var parts: Array[String]:
	set(value):
		var new_parts: Array[String] = []
		for part in value:
			new_parts.append(part.to_lower())
		_parts = new_parts
		path = SEPARATOR.join(_parts) if not _parts.is_empty() else "root"
		emit_changed()
	get:
		return _parts

## Subpath accessor
var sub: Path:
	get:
		return get_subpath()

## Static path separator
const SEPARATOR = "."

func _init(path_parts: Array[String] = []) -> void:
	var normalized_parts: Array[String] = []
	for part in path_parts:
		normalized_parts.append(part.to_lower())
	_parts = normalized_parts
	path = SEPARATOR.join(_parts) if not _parts.is_empty() else "root"

## Gets the full path as a string
func get_full_path() -> String:
	if is_root():
		return "root"
	if Path.is_path_format(path):
		return path
	return SEPARATOR.join(_parts)

## Gets the root node name (first part)
func get_root_name() -> String:
	if is_root():
		return "root"
	return _parts[0]

## Gets all parts after the root node as a new Path
func get_subpath() -> Path:
	if _parts.size() <= 1:
		return Path.new([])
	return Path.new(_parts.slice(1))

## Returns true if this is a root path (no parts)
func is_root() -> bool:
	return _parts.is_empty()

## Returns true if this path only contains a root node
func is_root_node() -> bool:
	return _parts.size() == 1

## Gets the parent path (all parts except the last)
func get_parent() -> Path:
	if is_root() or is_root_node():
		return Path.new([])
	return Path.new(_parts.slice(0, -1))

## Gets the property/node name (last part)
func get_property() -> String:
	if is_root():
		return "root"
	return _parts[-1]

## Returns true if this path is a descendant of the given path
func is_descendant_of(other: Path) -> bool:
	if other._parts.size() >= _parts.size():
		return false
	for i in range(other._parts.size()):
		if _parts[i] != other._parts[i]:
			return false
	return true

## Returns true if this path is an ancestor of the given path
func is_ancestor_of(other: Path) -> bool:
	return other.is_descendant_of(self)

## Returns true if this path starts with the given path parts
func starts_with(path_parts: Array[String]) -> bool:
	if path_parts.size() > _parts.size():
		return false
	for i in range(path_parts.size()):
		if _parts[i] != path_parts[i].to_lower():
			return false
	return true

## Returns a new path with the given part appended
func append(part: String) -> Path:
	var new_parts = _parts.duplicate()
	new_parts.append(part.to_lower())
	return Path.new(new_parts)

## Static constructor from full path string
static func parse(full_path: String) -> Path:
	if full_path.to_lower() == "root":
		return Path.new([])
	return Path.new(full_path.to_lower().split(SEPARATOR))

## Static constructor from root node and property
static func from_root_and_property(root: String, property: String) -> Path:
	return Path.new([root.to_lower(), property.to_lower()])

## Returns all ancestor paths including self, from root to leaf
static func get_ancestor_paths(path: Path) -> Array[Path]:
	var ancestors: Array[Path] = []
	var current_parts: Array[String] = []
	for part in path._parts:
		current_parts.append(part)
		ancestors.append(Path.new(current_parts.duplicate()))
	return ancestors

## Utility method to check if a string is in path format
static func is_path_format(text: String) -> bool:
	return text.contains(SEPARATOR)
