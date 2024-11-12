class_name Path
extends RefCounted

## The parts of the path from root to leaf
var parts: Array[String]

## The complete path string
var full: String : get = get_full_path

## Static path separator
const SEPARATOR = "."

func _init(path_parts: Array[String]) -> void:
	var a: Array[String]
	for part in path_parts:
		a.append(part.to_lower())  # Ensure all parts are lowercase
	parts = a

## Gets the full path as a string, handling special cases
func get_full_path() -> String:
	if is_root():
		return "root"
	if is_group_root():
		return parts[0]
	return SEPARATOR.join(parts)

## Gets the group name (first part) of the path
func get_group_name() -> String:
	if is_root():
		return "root"
	return parts[0]

## Gets all parts after the group name as a new Path
func get_subpath() -> Path:
	if parts.size() <= 1:
		return Path.new([])
	return Path.new(parts.slice(1))

## Returns true if this is a root path (no parts)
func is_root() -> bool:
	return parts.is_empty()

## Returns true if this path only contains a group name
func is_group_root() -> bool:
	return parts.size() == 1

## Gets the parent path (all parts except the last)
func get_parent() -> Path:
	if is_root() or is_group_root():
		return Path.new([])
	return Path.new(parts.slice(0, -1))

## Gets the property name (last part) of the path
func get_property() -> String:
	if is_root():
		return "root"
	return parts[-1]

## Returns true if this path is a descendant of the given path
func is_descendant_of(other: Path) -> bool:
	if other.parts.size() >= parts.size():
		return false
	for i in range(other.parts.size()):
		if parts[i] != other.parts[i]:
			return false
	return true

## Returns true if this path is an ancestor of the given path
func is_ancestor_of(other: Path) -> bool:
	return other.is_descendant_of(self)

## Returns true if this path starts with the given path parts
func starts_with(path_parts: Array[String]) -> bool:
	if path_parts.size() > parts.size():
		return false
	for i in range(path_parts.size()):
		if parts[i] != path_parts[i].to_lower():
			return false
	return true

## Returns a new path with the given part appended
func append(part: String) -> Path:
	var new_parts = parts.duplicate()
	new_parts.append(part.to_lower())  # Ensure appended part is lowercase
	return Path.new(new_parts)

## Static constructor from full path string
static func parse(full_path: String) -> Path:
	if full_path.to_lower() == "root":
		return Path.new([])
	return Path.new(full_path.to_lower().split(SEPARATOR))

## Static constructor from branch and property
static func from_branch_and_property(branch: String, property: String) -> Path:
	return Path.new([branch.to_lower(), property.to_lower()])

## Returns all ancestor paths including self, from root to leaf
static func get_ancestor_paths(path: Path) -> Array[Path]:
	var ancestors: Array[Path] = []
	var current_parts: Array[String] = []
	for part in path.parts:
		current_parts.append(part)
		ancestors.append(Path.new(current_parts.duplicate()))
	return ancestors

## Utility method to check if a string is in path format
static func is_path_format(text: String) -> bool:
	return text.contains(SEPARATOR)
