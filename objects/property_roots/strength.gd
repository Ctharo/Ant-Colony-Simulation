class_name Strength
extends PropertyNode
## Component responsible for managing entity's base strength attributes

#region Constants
## Factor used to calculate maximum carry weight from strength level
const STRENGTH_FACTOR: float = 20.0
## Default starting strength level
const DEFAULT_LEVEL := 10
## Threshold percentage for overloaded status
const OVERLOAD_THRESHOLD := 90.0
#endregion

#region Member Variables
## Base strength level of the entity
var _level: int = DEFAULT_LEVEL
#endregion
@export var config: StrengthResource


func _init(_entity: Node) -> void:
	## Initialize the proprioception component
	super._init("strength", Type.CONTAINER, _entity)
	
	# Initialize configuration
	if not config:
		config = StrengthResource.new()
	
	# Create the complete property tree from the resource
	var node := PropertyNode.from_resource(config, _entity)
	
	# Copy the configured tree into this instance
	copy_from(node)
	

	logger.trace("Strength property tree initialized")
