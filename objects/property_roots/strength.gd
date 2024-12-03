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

#region Property Getters and Setters
func _get_level() -> int:
	return _level

func _set_level(value: int) -> void:
	if value <= 0:
		logger.error("Attempted to set strength.base.level to non-positive value -> Action not allowed")
		return

	var old_value = _level
	_level = value

	if old_value != _level:
		logger.trace("Level updated: %d -> %d" % [old_value, _level])

func _get_carry_factor() -> float:
	return float(_level) * STRENGTH_FACTOR

func _get_is_overloaded() -> bool:
	if not entity:
		return false
	var load_percentage = entity.get_property_value(Path.parse("storage.capacity.percentage"))
	return load_percentage > OVERLOAD_THRESHOLD
#endregion

#region Public Methods
## Reset strength level to default value
func reset() -> void:
	_set_level(DEFAULT_LEVEL)
	logger.trace("Strength reset to default: %d" % DEFAULT_LEVEL)
#endregion
