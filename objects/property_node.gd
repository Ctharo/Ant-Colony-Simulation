class_name PropertyNode
extends BaseRefCounted
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

	log_category = DebugLogger.Category.PROPERTY
	log_from = "property_node"

static func create(p_name: String, p_type: Type) -> PropertyNode:
	return PropertyNode.new(p_name, p_type)

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

func find_node(path: Path) -> PropertyNode:

	if path.parts[0] != name:
		return null # Often due to path.get_subpath

	if path.parts.size() == 1:
		return self

	var child_name = path.parts[1]
	if not children.has(child_name):
		return null

	return children[child_name].find_node(Path.new(path.parts.slice(1)))

func find_node_by_string(path_string: String) -> PropertyNode:
	return find_node(Path.parse(path_string))
#endregion

#region Tree Modification
func add_child(child: PropertyNode) -> void:
	if not is_container_node():
		_error("Cannot add child to value node")
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
		_error("Cannot get value from container node")
		return null

	if not has_valid_accessor():
		_error("Invalid getter for property")
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


static func create_tree(entity: Node) -> PropertyNode.Builder:
	return PropertyNode.Builder.new(entity)

class Builder:
	var _entity: Node
	var _current: PropertyNode
	var _root: PropertyNode

	func _init(entity: Node):
		_entity = entity

	func container(name: String, description: String = "") -> PropertyNode.Builder:
		var node = PropertyNode.new(
			name,
			Type.CONTAINER,
			_entity,
			Property.Type.UNKNOWN,
			Callable(),
			Callable(),
			[],
			description
		)

		if not _root:
			_root = node
			_current = node
		else:
			_current.add_child(node)
			_current = node

		return self

	func value(
		name: String,
		type: Property.Type,
		getter: Callable,
		setter: Callable = Callable(),
		dependencies: Array[String] = [],
		description: String = ""
	) -> PropertyNode.Builder:
		# Ensure we have a valid container to add values to
		if not _current:
			# Create an implicit root container if none exists
			container("root", "Implicit root container")

		var path_dependencies: Array[Path] = []
		for dep in dependencies:
			path_dependencies.append(Path.parse(dep))

		var node = PropertyNode.new(
			name,
			Type.VALUE,
			_entity,
			type,
			getter,
			setter,
			path_dependencies,
			description
		)
		_current.add_child(node)
		return self

	func up() -> PropertyNode.Builder:
		if _current.parent:
			_current = _current.parent
		return self

	func build() -> PropertyNode:
		return _root
#endregion
