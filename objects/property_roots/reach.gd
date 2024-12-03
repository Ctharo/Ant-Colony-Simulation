class_name Reach
extends PropertyNode
## Component responsible for managing entity reach distance and food detection

#region Signals
## Could add signals here if needed, following Energy pattern
#endregion

#region Constants
const DEFAULT_RANGE := 15.0
#endregion

#region Member Variables
@export var config: ReachResource
## The maximum reach distance of the entity
var _range: float = DEFAULT_RANGE
#endregion

func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("reach", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = ReachResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Reach property tree initialized")
