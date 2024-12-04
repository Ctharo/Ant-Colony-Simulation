class_name Speed
extends PropertyNode
## Component responsible for managing entity movement and action rates

#region Constants
const DEFAULT_RATE := 1.0
#endregion

#region Member Variables
## Rate at which the entity can move (units/second)
var _movement_rate: float = DEFAULT_RATE

## Rate at which the entity can harvest resources (units/second)
var _harvesting_rate: float = DEFAULT_RATE

## Rate at which the entity can store resources (units/second)
var _storing_rate: float = DEFAULT_RATE

@export var config: SpeedResource
#endregion

func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("speed", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = SpeedResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Speed property tree initialized")
