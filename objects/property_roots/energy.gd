class_name Energy
extends PropertyNode
## Component responsible for managing energy state

#region Signals
## Emitted when energy is completely depleted
signal depleted
#endregion

#region Constants
const DEFAULT_MAX_ENERGY := 100.0
#endregion

@export var config: EnergyResource

func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("energy", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = EnergyResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	
	logger.trace("Energy property tree initialized")
