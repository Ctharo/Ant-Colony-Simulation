class_name PropertyGroup
extends BaseRefCounted

#region Member Variables
var ant: Ant
var name: String
var metadata: Dictionary = {}
var description: String
var _root: NestedProperty
#endregion

func _init(p_name: String, p_ant: Ant = null) -> void:
	log_from = "property_group"
	log_category = DebugLogger.Category.PROPERTY

	name = p_name.to_snake_case()
	ant = p_ant
	_root = (Property.create(name)
		.as_container()
		.described_as("Property group for %s" % name)
		.build())
	_trace("Property group initialized: %s" % name)
	_init_properties()

#region Property Management
## Virtual method that derived classes will implement to define their properties
func _init_properties() -> void:
	_warn("Property group %s did not initialize properties" % [name])

## Gets a property or group by path
## Can return either a container (group) or leaf (property)
func get_at_path(path: Path) -> NestedProperty:
	if path.is_root() or path.is_group_root():
		return _root
	return _root.get_child_by_string_path(path.get_subpath().full)

## Gets children at a specific path
## Returns empty array if path doesn't exist or points to a leaf
func get_children_at_path(path: Path) -> Array[NestedProperty]:
	var node = get_at_path(path)
	if node and node.type == NestedProperty.Type.CONTAINER:
		return node.children.values()
	return []

## Gets value if path points to a property
func get_value_at_path(path: Path) -> Variant:
	var node = get_at_path(path)
	if node and node.type == NestedProperty.Type.PROPERTY:
		return node.get_value()
	return null

## Sets value if path points to a property
func set_value_at_path(path: Path, value: Variant) -> Result:
	var node = get_at_path(path)
	if not node:
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Path '%s' doesn't exist" % path.full
		)
	if node.type != NestedProperty.Type.PROPERTY:
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Path '%s' points to a container, not a property" % path.full
		)
	return node.set_value(value)

## Gets all properties in this group
func get_properties() -> Array[NestedProperty]:
	return _root.get_properties()

## Gets all leaf (value) properties under a path
func get_properties_at_path(path: Path) -> Array[NestedProperty]:
	var node = get_at_path(path)
	if not node:
		return []
	return node.get_properties()

## Gets the root container
func get_root() -> NestedProperty:
	return _root

## Registers a new property or container at a path
func register_at_path(path: Path, property: NestedProperty) -> Result:
	if path.is_root():
		if not property:
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
		return Result.new(
			Result.ErrorType.NOT_FOUND,
			"Parent path '%s' doesn't exist or isn't a container" % parent_path.full
		)
	parent.add_child(property)
	return Result.new()
#endregion
