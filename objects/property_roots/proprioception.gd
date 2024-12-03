@tool
class_name Proprioception
extends PropertyNode
## The component responsible for sense of direction and position

@export var config: ProprioceptionResource

func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("proprioception", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = ProprioceptionResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Proprioception property tree initialized")

#region Public Methods
## Helper method to get value from a child node
func get_node_value(path: String) -> Variant:
	var node := find_node_by_string(path)
	if not node:
		logger.error("Could not find node at path: %s" % path)
		return null
	return node.get_value()
#endregion
