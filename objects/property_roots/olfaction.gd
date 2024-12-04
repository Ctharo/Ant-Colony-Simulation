class_name Olfaction
extends PropertyNode
## Component responsible for ant's sense of smell and pheromone detection

@export var config: OlfactionResource

func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("olfaction", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = OlfactionResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Olfaction property tree initialized")
