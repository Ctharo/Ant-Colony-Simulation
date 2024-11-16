class_name PropertyGroup
extends BaseRefCounted

#region Member Variables
## The node this property group belongs to (if any)
var entity: Node
var name: String
var metadata: Dictionary = {}
var description: String
var _root: NestedProperty
#endregion

func _init(p_name: String, p_entity: Node = null) -> void:
	entity = p_entity
	name = p_name.to_snake_case()
	log_from = name if not name.is_empty() else "property_group"
	log_category = DebugLogger.Category.PROPERTY
	
	_root = (Property.create(name)
		.as_container()
		.described_as("Property group for %s" % name)
		.build())
	_init_properties()

#region Property Management
## Virtual method that derived classes will implement to define their properties
func _init_properties() -> void:
	_warn("Property group %s did not initialize properties" % [name])

## Registers a new property or container at a path
func register_at_path(path: Path, property: NestedProperty) -> Result:
	# Skip intermediate registration messages
	if path.is_root():
		if not property:
			_error("Cannot register null property at root path")
			return Result.new(
				Result.ErrorType.TYPE_MISMATCH,
				"Cannot register null property"
			)
		_root.add_child(property)
		return Result.new()

	var parent_path = path.get_parent()
	if parent_path.is_root():
		_root.add_child(property)
		return Result.new()

	var parent = get_at_path(parent_path)
	if not parent or parent.type != NestedProperty.Type.CONTAINER:
		_error("Failed to register: parent path '%s' doesn't exist or isn't a container" % parent_path.full)
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Parent path '%s' doesn't exist or isn't a container" % parent_path.full
		)

	parent.add_child(property)
	return Result.new()

## Gets a property or group by path
func get_at_path(path: Path) -> NestedProperty:
	if path.is_root() or path.is_group_root():
		return _root
	var result = _root.get_child_by_string_path(path.get_subpath().full)
	if not result:
		_debug("No property found at path '%s'" % path.full)
	return result

## Gets children at a specific path
func get_children_at_path(path: Path) -> Array[NestedProperty]:
	var node = get_at_path(path)
	if node and node.type == NestedProperty.Type.CONTAINER:
		return node.children.values()
	_debug("No children found at path '%s' (not a container)" % path.full)
	return []

## Gets value if path points to a property
func get_value_at_path(path: Path) -> Variant:
	var node = get_at_path(path)
	if node and node.type == NestedProperty.Type.PROPERTY:
		return node.get_value()
	_debug("Cannot get value at path '%s' (not a property)" % path.full)
	return null

## Sets value if path points to a property
func set_value_at_path(path: Path, value: Variant) -> Result:
	var node = get_at_path(path)
	if not node:
		_error("Cannot set value: path '%s' doesn't exist" % path.full)
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Path '%s' doesn't exist" % path.full
		)
	if node.type != NestedProperty.Type.PROPERTY:
		_error("Cannot set value: path '%s' points to a container" % path.full)
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Path '%s' points to a container, not a property" % path.full
		)
	var result = node.set_value(value)
	if result.success():
		_debug("Successfully set value at path '%s'" % path.full)
	else:
		_error("Failed to set value at path '%s': %s" % [path.full, result.get_error()])
	return result

## Gets all properties in this group
func get_properties() -> Array[NestedProperty]:
	return _root.get_properties()

## Gets all leaf (value) properties under a path
func get_properties_at_path(path: Path) -> Array[NestedProperty]:
	var node = get_at_path(path)
	if not node:
		_debug("No properties found at path '%s' (path doesn't exist)" % path.full)
		return []
	return node.get_properties()

## Gets the root container
func get_root() -> NestedProperty:
	return _root
#endregion

#region Logging helpers
func _format_property_structure(prop: NestedProperty, indent: Array[String] = [], is_last: bool = true) -> String:
	var result = ""

	# Build the current line's prefix
	var prefix = ""
	for i in range(indent.size()):
		prefix += indent[i]

	# Add current line's branch
	if indent.size() > 0:
		prefix += "└──" if is_last else "├──"

	# Format the current node
	if prop.type == NestedProperty.Type.CONTAINER:
		result = "%s[Container] %s" % [prefix, prop.name]
		if prop.description:
			result += " (%s)" % prop.description

		# Process children
		var children = prop.children.values()
		if not children.is_empty():
			result += "\n"
			for i in range(children.size()):
				var child = children[i]
				var child_is_last = i == children.size() - 1

				# Build indentation for child
				var child_indent = indent.duplicate()
				child_indent.append("    " if is_last else "│   ")

				result += _format_property_structure(child, child_indent, child_is_last)
				if not child_is_last:
					result += "\n"
	else:
		result = "%s[Property] %s" % [prefix, prop.name]
		if prop.description:
			result += " (%s)" % prop.description
		result += " -> %s" % Property.type_to_string(prop.value_type)

	return result

func _log_structure(property: NestedProperty, message: String = "") -> void:
	if not message.is_empty():
		_debug(message)
	_debug("        %s" % _format_property_structure(property).replace("\n", "\n        "))

#endregion
