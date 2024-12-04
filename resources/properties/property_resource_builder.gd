class_name PropertyResourceBuilder
extends RefCounted
## Builder class for constructing PropertyResource trees

#region Constants
const DEFAULT_TYPE := PropertyNode.Type.VALUE
#endregion

#region Member Variables
var _path: String
var _type: PropertyNode.Type
var _description: String
var _value_type: Property.Type
var _dependencies: Array[String]
var _children: Dictionary
var _getter: Callable
var _setter: Callable
#endregion

#region Constructor
func _init(path: String) -> void:
	_path = path
	_type = DEFAULT_TYPE
	_description = ""
	_value_type = Property.Type.UNKNOWN
	_dependencies = []
	_children = {}
#endregion

#region Builder Methods
## Set the node type (Value or Container)
func type(type: PropertyNode.Type) -> PropertyResourceBuilder:
	_type = type
	return self

## Set the description
func description(desc: String) -> PropertyResourceBuilder:
	_description = desc
	return self

## Set the value type for leaf nodes
func value_type(type: Property.Type) -> PropertyResourceBuilder:
	_value_type = type
	return self

## Add a dependency path
func add_dependency(path: String) -> PropertyResourceBuilder:
	_dependencies.append(path)
	return self

## Add multiple dependency paths
func add_dependencies(paths: Array[String]) -> PropertyResourceBuilder:
	_dependencies.append_array(paths)
	return self

## Add a child resource builder
func add_child(name: String, child: PropertyResourceBuilder) -> PropertyResourceBuilder:
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
static func value(path: String) -> PropertyResourceBuilder:
	return PropertyResourceBuilder.new(path).type(PropertyNode.Type.VALUE)

## Create a new builder for a container node
static func container(path: String) -> PropertyResourceBuilder:
	return PropertyResourceBuilder.new(path).type(PropertyNode.Type.CONTAINER)
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
