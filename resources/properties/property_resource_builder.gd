class_name PropertyResourceBuilder
extends RefCounted
## Builder class for constructing PropertyResource trees

#region Constants
const DEFAULT_TYPE := PropertyNode.Type.VALUE
#endregion

#region Member Variables
var _path: Path
var _type: PropertyNode.Type
var _description: String
var _value_type: Property.Type
var _dependencies: Array[Path]
var _children: Dictionary
var _getter: Callable
var _setter: Callable
#endregion

#region Constructor
func _init(initial_path: Path) -> void:
	_path = initial_path
	_type = DEFAULT_TYPE
	_description = ""
	_value_type = Property.Type.UNKNOWN
	_dependencies = []
	_children = {}
#endregion

#region Builder Methods
## Set the node type (Value or Container)
func type(node_type: PropertyNode.Type) -> PropertyResourceBuilder:
	_type = node_type
	return self

## Set the description
func description(desc: String) -> PropertyResourceBuilder:
	_description = desc
	return self

## Set the value type for leaf nodes
func value_type(val_type: Property.Type) -> PropertyResourceBuilder:
	_value_type = val_type
	return self

## Add a dependency path
func add_dependency(dependency_path: Variant) -> PropertyResourceBuilder:
	if dependency_path is String:
		_dependencies.append(Path.parse(dependency_path))
	elif dependency_path is Path:
		_dependencies.append(dependency_path)
	return self

## Add multiple dependency paths
func add_dependencies(paths: Array) -> PropertyResourceBuilder:
	for path in paths:
		add_dependency(path)
	return self

## Add a child resource builder
func add_child(name: String, child: PropertyResourceBuilder) -> PropertyResourceBuilder:
	# Update child's path to be relative to this builder's path
	child._path = _path.get_child(name)
	_children[name] = child
	return self

## Set custom getter function
func getter(func_ref: Callable) -> PropertyResourceBuilder:
	_getter = func_ref
	return self

## Set custom setter function
func setter(func_ref: Callable) -> PropertyResourceBuilder:
	_setter = func_ref
	return self

## Build and return the final PropertyResource
func build() -> PropertyResource:
	var resource := CustomPropertyResource.new()

	# Build children first if any
	var built_children := {}
	for child_name in _children:
		built_children[child_name] = _children[child_name].build()

	# Setup the resource
	resource.setup(
		_path,
		_type,
		_description,
		built_children,
		_value_type,
		_dependencies
	)

	# Set custom getter/setter if provided
	if _getter.is_valid():
		resource.custom_getter = _getter
	if _setter.is_valid():
		resource.custom_setter = _setter

	return resource
#endregion

#region Static Factory Methods
## Create a new builder for a value node
static func value(path_str: String) -> PropertyResourceBuilder:
	return PropertyResourceBuilder.new(Path.parse(path_str)).type(PropertyNode.Type.VALUE)

## Create a new builder for a container node
static func container(path_str: String) -> PropertyResourceBuilder:
	return PropertyResourceBuilder.new(Path.parse(path_str)).type(PropertyNode.Type.CONTAINER)

## Create a builder from an existing path
static func from_path(path: Path, node_type: PropertyNode.Type = DEFAULT_TYPE) -> PropertyResourceBuilder:
	return PropertyResourceBuilder.new(path).type(node_type)
#endregion

## Custom PropertyResource that can use provided getter/setter
class CustomPropertyResource extends PropertyResource:
	var custom_getter: Callable
	var custom_setter: Callable

	func create_getter(entity: Node) -> Callable:
		if custom_getter.is_valid():
			return custom_getter.bind(entity)
		return super.create_getter(entity)

	func create_setter(entity: Node) -> Callable:
		if custom_setter.is_valid():
			return custom_setter.bind(entity)
		return super.create_setter(entity)

#region Helper Methods
## Create a builder with common value node settings
static func create_value_node(
	path: Variant,
	value_type: Property.Type,
	description: String,
	getter: Callable,
	setter: Callable = Callable(),
	dependencies: Array = []
) -> PropertyResourceBuilder:
	var builder = (
		PropertyResourceBuilder.value(path if path is String else path.full)
		.value_type(value_type)
		.description(description)
		.getter(getter)
	)

	if setter.is_valid():
		builder.setter(setter)

	if not dependencies.is_empty():
		builder.add_dependencies(dependencies)

	return builder

## Create a builder with common container node settings
static func create_container_node(
	path: Variant,
	description: String,
	children: Array = []
) -> PropertyResourceBuilder:
	var builder = (
		PropertyResourceBuilder.container(path if path is String else path.full)
		.description(description)
	)

	for child in children:
		builder.add_child(child.path.get_property(), child)

	return builder
#endregion
