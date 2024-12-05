class_name PropertyNode
extends Resource

## Type enumeration for node classification
enum Type { VALUE, CONTAINER }

## Name of the property
var name: String

## Type of the node (VALUE or CONTAINER)
var type: Type

## Path to this property
@export var path: Path

## Reference to parent node
var parent: PropertyNode

## Reference to the entity this property belongs to
var entity: Node

## Description of the property
var description: String

## Dictionary of child nodes
@export var children: Dictionary = {}

## Initialize the property node
func _init(
	p_path: Path,
	p_type: Type,
	p_entity: Node = null,
	p_description: String = ""
) -> void:
	path = p_path
	name = path.get_property()
	type = p_type
	entity = p_entity
	description = p_description

## Add a child node
func add_child(child: PropertyNode) -> void:
	if type != Type.CONTAINER:
		push_error("Cannot add child to value node: %s" % path.full)
		return
	if not child:
		push_error("Cannot add null child to node: %s" % path.full)
		return
	if children.has(child.name):
		push_error("Child already exists with name: %s" % child.name)
		return
	child.parent = self
	children[child.name] = child

## Remove a child node
func remove_child(child_name: String) -> void:
	if not children.has(child_name):
		push_error("No child found with name: %s" % child_name)
		return
	var child = children[child_name]
	child.parent = null
	children.erase(child_name)
