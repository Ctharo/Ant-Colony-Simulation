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

#region Property Getters and Setters
func _get_max_capacity() -> float:
	var strength_level = entity.get_property_value("strength.base.level")
	return strength_level * 10.0 if strength_level else 0.0

func _get_current_capacity() -> float:
	if not entity:
		logger.error("Cannot get stored mass: entity reference is null")
		return 0.0
	return entity.foods.get_mass()

func _get_percentage_full() -> float:
	var maximum = _get_max_capacity()
	if maximum <= 0:
		return 0.0
	return (_get_current_capacity() / maximum) * 100.0

func _get_mass_available() -> float:
	return _get_max_capacity() - _get_current_capacity()

func _is_carrying() -> bool:
	return _get_current_capacity() > 0

func _is_full() -> bool:
	return is_equal_approx(_get_current_capacity(), _get_max_capacity())
#endregion

#region Public Methods
## Check if the entity can store additional weight
func can_store(weight: float) -> bool:
	if weight < 0:
		logger.error("Cannot check negative weight")
		return false
	return weight <= _get_mass_available()
#endregion
