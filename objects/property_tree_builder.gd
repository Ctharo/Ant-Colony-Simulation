## Handles creation of PropertyNode trees from PropertyResources
class_name PropertyTreeBuilder

var logger: Logger

func _init() -> void:
	logger = Logger.new("property_tree_builder", DebugLogger.Category.PROPERTY)

## Create a complete property tree from a resource
func create_tree(resource: PropertyResource, entity: Node) -> PropertyNode:
	if not resource:
		logger.error("Cannot create tree from null resource")
		return null

	# Create the node for this level
	var node := PropertyNode.new(
		resource.path,
		resource.type,
		entity,
		resource,
		resource.value_type,
		resource.create_getter(entity),
		resource.create_setter(entity),
		resource.dependencies,
		resource.description
	)

	# Recursively create child nodes
	if resource.type == PropertyNode.Type.CONTAINER:
		for child_name in resource.children:
			var child_resource = resource.children[child_name]
			var child_node = create_tree(child_resource, entity)
			if child_node:
				node.add_child(child_node)

	return node

## Create multiple trees from a list of resources
func create_trees(resources: Array[PropertyResource], entity: Node) -> Array[PropertyNode]:
	var nodes: Array[PropertyNode] = []
	for resource in resources:
		var node = create_tree(resource, entity)
		if node:
			nodes.append(node)
	return nodes

## Helper method to create and validate a tree
static func build(resource: PropertyResource, entity: Node) -> PropertyNode:
	var builder = PropertyTreeBuilder.new()
	var node = builder.create_tree(resource, entity)

	if not node:
		builder.logger.error("Failed to create property tree from resource: %s" % resource.path)
		return null

	return node

## Validate a built tree structure
func validate_tree(node: PropertyNode) -> bool:
	if not node:
		return false

	# Validate node type consistency
	if node.type == PropertyNode.Type.CONTAINER and node.children.is_empty():
		logger.error("Container node has no children: %s" % node.path)
		return false

	if node.type == PropertyNode.Type.VALUE and not node.children.is_empty():
		logger.error("Value node has children: %s" % node.path)
		return false

	# Validate value nodes have proper accessors
	if node.type == PropertyNode.Type.VALUE and not node.has_valid_accessor():
		logger.error("Value node missing valid accessor: %s" % node.path)
		return false

	# Recursively validate children
	for child in node.children.values():
		if not validate_tree(child):
			return false

	return true

## Helper method to copy a tree structure
func copy_tree(source: PropertyNode, entity: Node = null) -> PropertyNode:
	if not source:
		return null

	var copy := PropertyNode.new(
		source.path,
		source.type,
		entity if entity else source.entity,
		source.config,
		source.value_type,
		source.getter,
		source.setter,
		source.dependencies,
		source.description
	)

	for child in source.children.values():
		var child_copy = copy_tree(child, entity)
		if child_copy:
			copy.add_child(child_copy)

	return copy
