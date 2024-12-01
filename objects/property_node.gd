class_name PropertyNode
extends RefCounted
## A node in the property tree that can be either a leaf (value) or branch (container)

enum Type {
	VALUE,     # Leaf node with a value
	CONTAINER  # Branch node with children
}

#region Member Variables
## Node name
var name: String

## Node type (Value or Container)
var type: Type

## Full path from root to this node
var path: Path : get = get_path

## Type of value (for Value nodes)
var value_type: Property.Type

## Value accessor functions (for Value nodes)
var getter: Callable
var setter: Callable

var logger: Logger

## Dependencies that affect this node's value
var dependencies: Array[Path]

## Description for documentation
var description: String

## Child nodes (for Container nodes)
var children: Dictionary = {}  # name -> PropertyNode

## Parent node (null for root)
var parent: PropertyNode

## Owner entity (for getting context in getters/setters)
var entity: Node
#endregion

func _init(
	p_name: String,
	p_type: Type,
	p_entity: Node = null,
	p_value_type: Property.Type = Property.Type.UNKNOWN,
	p_getter: Callable = Callable(),
	p_setter: Callable = Callable(),
	p_dependencies: Array[Path] = [],
	p_description: String = ""
) -> void:
	name = p_name
	type = p_type
	entity = p_entity
	value_type = p_value_type
	getter = p_getter
	setter = p_setter
	dependencies = p_dependencies
	description = p_description

	logger = Logger.new("property_node", DebugLogger.Category.PROPERTY)

## Create a property node from a resource configuration
static func from_resource(resource: PropertyResource, entity: Node) -> PropertyNode:
	var node := PropertyNode.new(
		resource.path.full,
		resource.type,
		entity,
		resource.value_type,
		resource.create_getter(entity),
		resource.create_setter(entity),
		resource.dependencies,
		resource.description
	)

	# Recursively create child nodes from child resources
	if resource.type == Type.CONTAINER:
		for child_resource in resource.children.values():
			var child_node := from_resource(child_resource, entity)
			node.add_child(child_node)

	return node

func copy_from(other: PropertyNode) -> void:
	name = other.name
	type = other.type
	entity = other.entity
	value_type = other.value_type
	getter = other.getter
	setter = other.setter
	dependencies = other.dependencies.duplicate()
	description = other.description

	# Copy children
	children.clear()
	for child in other.children.values():
		add_child(child)

#region Tree Navigation
func get_path() -> Path:
	var parts: Array[String] = []
	var current: PropertyNode = self

	while current != null:
		parts.push_front(current.name)
		current = current.parent

	return Path.new(parts)

func find_node(_path: Path) -> PropertyNode:
	if _path.parts[0] != name:
		return null # Often due to path.get_subpath

	if _path.parts.size() == 1:
		return self

	var child_name = _path.parts[1]
	if not children.has(child_name):
		return null

	return children[child_name].find_node(Path.new(_path.parts.slice(1)))

func find_node_by_string(path_string: String) -> PropertyNode:
	return find_node(Path.parse(path_string))
#endregion

#region Tree Modification
func add_child(child: PropertyNode) -> void:
	if not is_container_node():
		logger.error("Cannot add child to value node")
		return

	child.parent = self
	children[child.name] = child

func remove_child(child_name: String) -> void:
	if has_child(child_name):
		children[child_name].parent = null
		children.erase(child_name)
#endregion

#region Value Access
func get_value() -> Variant:
	if not is_value_node():
		logger.error("Cannot get value from container node")
		return null

	if not has_valid_accessor():
		logger.error("Invalid getter for property")
		return null

	return getter.call()

func set_value(value: Variant) -> Result:
	if not is_value_node():
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Cannot set value on container node"
		)

	if not Property.is_valid_type(value, value_type):
		return Result.new(
			Result.ErrorType.TYPE_MISMATCH,
			"Invalid value type"
		)

	if not has_valid_accessor(true):
		return Result.new(
			Result.ErrorType.INVALID_SETTER,
			"Invalid setter for property"
		)

	setter.call(value)
	return Result.new()
#endregion

#region Tree Traversal
func get_all_values() -> Array[PropertyNode]:
	var values: Array[PropertyNode] = []

	if type == Type.VALUE:
		values.append(self)

	for child in children.values():
		values.append_array(child.get_all_values())

	return values

func get_all_containers() -> Array[PropertyNode]:
	var containers: Array[PropertyNode] = []

	if type == Type.CONTAINER:
		containers.append(self)

	for child in children.values():
		containers.append_array(child.get_all_containers())

	return containers
#endregion

#region Node Validation
## Check if this node has a child with the given name
func has_child(child_name: String) -> bool:
	return children.has(child_name)

## Check if this is a value node
func is_value_node() -> bool:
	return type == Type.VALUE

## Check if this is a container node
func is_container_node() -> bool:
	return type == Type.CONTAINER

## Check if this node has valid getter/setter
func has_valid_accessor(check_setter: bool = false) -> bool:
	var has_valid = Property.is_valid_getter(getter)
	if check_setter:
		has_valid = has_valid and Property.is_valid_setter(setter)
	return has_valid
#endregion
