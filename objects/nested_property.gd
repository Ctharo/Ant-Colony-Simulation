class_name NestedProperty
extends BaseRefCounted
## Responsible for tree structure and value handling
##
##

enum Type {
	PROPERTY,  # Leaf node with a value
	CONTAINER  # Branch node with children
}

#region Member Variables
var name: String
var type: Type
var path: Path : get = get_path
var value_type: Property.Type  # Only used if type is PROPERTY
var getter: Callable
var setter: Callable
var dependencies: Array[Path]
var description: String
var children: Dictionary  # name -> NestedProperty
var parent: NestedProperty
#endregion

func _init(
	p_name: String,
	p_type: Type,
	p_value_type: Property.Type,
	p_getter: Callable = Callable(),
	p_setter: Callable = Callable(),
	p_dependencies: Array[Path] = [],
	p_description: String = ""
) -> void:
	name = p_name
	type = p_type
	value_type = p_value_type
	getter = p_getter
	setter = p_setter
	dependencies = p_dependencies
	description = p_description
	children = {}

	log_category = DebugLogger.Category.PROPERTY
	log_from = "nested_property"

func add_child(child: NestedProperty) -> void:
	if type != Type.CONTAINER:
		_error("Cannot add child to non-container property")
		return
	child.parent = self
	children[child.name] = child

## Gets a child by name directly from this node's children
func get_child(child_name: String) -> NestedProperty:
	return children.get(child_name)

## Checks if this node has a child with the given name
func has_child(child_name: String) -> bool:
	return children.has(child_name)

func get_child_by_path(_path: Path) -> NestedProperty:
	if _path.parts.is_empty() or _path.parts[0] != name:
		return null

	if _path.parts.size() == 1:
		return self

	var child_name = _path.parts[1]
	if not children.has(child_name):
		return null

	if _path.parts.size() == 2:
		return children[child_name]

	var remaining_path = Path.new(_path.parts.slice(1))
	return children[child_name].get_child_by_path(remaining_path)

func get_child_by_string_path(path_string: String) -> NestedProperty:
	if path_string.is_empty():
		return null

	# Convert dot notation to path parts
	var parts = path_string.split(".")

	# Create a proper Path object
	var _path = Path.new(parts)

	return get_child_by_path(_path)

## Checks if a child exists at the given string path
func has_child_at_path(path_string: String) -> bool:
	return get_child_by_string_path(path_string) != null

## Gets child names at a specific path depth
## Returns empty array if path doesn't exist or has no children
func get_child_names_at_path(path_string: String) -> Array[String]:
	var property = get_child_by_string_path(path_string)
	if property and property.type == Type.CONTAINER:
		return property.children.keys()
	return []

func get_path() -> Path:
	var parts: Array[String] = []
	var current: NestedProperty = self

	while current != null:
		parts.push_front(current.name)
		current = current.parent

	return Path.new(parts)

func get_properties() -> Array[NestedProperty]:
	var properties: Array[NestedProperty] = []

	if type == Type.PROPERTY:
		properties.append(self)

	for child in children.values():
		properties.append_array(child.get_properties())

	return properties

func get_value() -> Variant:
	if type != Type.PROPERTY:
		_error("Cannot get value of container property")
		return null
	if not Property.is_valid_getter(getter):
		_error("Invalid getter for property")
		return null
	return getter.call()

func set_value(value: Variant) -> Result:
	if type != Type.PROPERTY:
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Cannot set value of container property"
		)
	if not Property.is_valid_type(value, value_type):
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Invalid value type"
		)
	if not Property.is_valid_setter(setter):
		return Result.new(
			Result.ErrorType.INVALID_SETTER,
			"Invalid setter for property"
		)
	setter.call(value)
	return Result.new()
