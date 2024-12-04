class_name Health
extends PropertyNode
## Component responsible for managing health state

#region Signals
## Emitted when health reaches zero
signal depleted
#endregion

#region Constants
const DEFAULT_MAX_HEALTH := 100.0
#endregion

@export var config: HealthResource

func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("health", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = HealthResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	


	logger.trace("Health property tree initialized")
