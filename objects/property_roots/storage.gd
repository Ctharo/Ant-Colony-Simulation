class_name Storage
extends PropertyNode
## Component responsible for managing entity's storage capacity and contents

@export var config: StorageResource


func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("storage", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = StorageResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Storage property tree initialized")
