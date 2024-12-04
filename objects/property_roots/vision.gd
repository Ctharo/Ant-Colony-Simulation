class_name Vision
extends PropertyNode
## Component responsible for managing entity's visual perception

#region Constants
const DEFAULT_RANGE := 50.0
#endregion


@export var config: VisionResource


func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("vision", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = VisionResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Vision property tree initialized")
