class_name PropertyResource
extends Resource
## Base resource for managing property configurations and values

#region Configuration
## Property path for this resource
@export var path: Path

## Node type (Value or Container)
@export var type: PropertyNode.Type

## Description for documentation
@export_multiline var description: String

## Value type for leaf nodes
@export var value_type: Property.Type = Property.Type.UNKNOWN

## Dependencies that affect this node's value
@export var dependencies: Array[Path] = []

## Child resources (for container nodes)
@export var children: Dictionary = {}  # name -> PropertyResource

var logger: Logger
#endregion

## Create a getter function for this property
## Override in derived classes to provide specific getter logic
func create_getter(_entity: Node) -> Callable:
	if type != PropertyNode.Type.VALUE:
		return Callable()
	return Callable()

## Create a setter function for this property
## Override in derived classes to provide specific setter logic
func create_setter(_entity: Node) -> Callable:
	if type != PropertyNode.Type.VALUE:
		return Callable()
	return Callable()

## Static factory method for creating container resources
static func create_container(
	p_path: String,
	p_description: String,
	p_children: Dictionary = {}
) -> PropertyResource:
	var resource := PropertyResource.new()
	resource.setup(
		p_path,
		PropertyNode.Type.CONTAINER,
		p_description,
		p_children
	)
	return resource

## Static factory method for creating value resources
static func create_value(
	p_path: String,
	p_description: String,
	p_value_type: Property.Type,
	p_dependencies: Array[String] = []
) -> PropertyResource:
	var resource := PropertyResource.new()
	resource.setup(
		p_path,
		PropertyNode.Type.VALUE,
		p_description,
		{},
		p_value_type,
		p_dependencies
	)
	return resource

## Helper function to setup basic properties
func setup(
	p_path: String,
	p_type: PropertyNode.Type,
	p_description: String,
	p_children: Dictionary = {},
	p_value_type: Property.Type = Property.Type.UNKNOWN,
	p_dependencies: Array[String] = []
) -> PropertyResource:
	path = Path.parse(p_path)
	type = p_type
	description = p_description
	children = p_children
	value_type = p_value_type

	dependencies.clear()
	for dep in p_dependencies:
		dependencies.append(Path.parse(dep))

	return self
