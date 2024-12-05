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
func create_getter(_entity: Node) -> Callable:
	if type != PropertyNode.Type.VALUE:
		return Callable()
	return Callable()

## Create a setter function for this property
func create_setter(_entity: Node) -> Callable:
	if type != PropertyNode.Type.VALUE:
		return Callable()
	return Callable()

## Helper function to setup basic properties
func setup(
	p_path: Path,
	p_type: PropertyNode.Type,
	p_description: String,
	p_children: Dictionary = {},
	p_value_type: Property.Type = Property.Type.UNKNOWN,
	p_dependencies: Array[Path] = []
) -> PropertyResource:
	path = p_path
	type = p_type
	description = p_description
	children = p_children
	value_type = p_value_type
	dependencies = p_dependencies.duplicate()
	return self

#region Path Management
## Get the full path to a child property
func get_child_path(child_name: String) -> Path:
	return path.get_child(child_name)

## Check if this resource has a child at the given path
func has_child_at_path(child_path: Path) -> bool:
	if not child_path.is_descendant_of(path):
		return false

	var relative_path = child_path.parts.slice(path.get_depth())
	var current_children = children

	for part in relative_path:
		if not current_children.has(part):
			return false
		current_children = current_children[part].children

	return true

## Get a child resource at the given path
func get_child_at_path(child_path: Path) -> PropertyResource:
	if not child_path.is_descendant_of(path):
		return null

	if child_path.equals(path):
		return self

	var next_part = child_path.parts[path.get_depth()]
	if not children.has(next_part):
		return null

	return children[next_part].get_child_at_path(child_path)
#endregion
