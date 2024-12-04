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
