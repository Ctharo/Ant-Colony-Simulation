class_name Storage
extends PropertyNode
## Component responsible for managing entity's storage capacity and contents

func _init(_entity: Node) -> void:
	# First create self as container
	super._init("storage", Type.CONTAINER, _entity)

	# Create the tree with the container name matching self
	var tree = PropertyNode.create_tree(_entity)\
		.container("storage", "Storage management")\
			.container("capacity", "Information about entity's storage capacity")\
				.value("max", Property.Type.FLOAT,
					Callable(self, "_get_max_capacity"),
					Callable(),
					["strength.base.level"],
					"Maximum weight the entity can store")\
				.value("current", Property.Type.FLOAT,
					Callable(self, "_get_current_capacity"),
					Callable(),
					[],
					"Current total mass of stored items")\
				.value("percentage", Property.Type.FLOAT,
					Callable(self, "_get_percentage_full"),
					Callable(),
					["storage.capacity.current", "storage.capacity.max"],
					"Current storage used as percentage of maximum")\
				.value("available", Property.Type.FLOAT,
					Callable(self, "_get_mass_available"),
					Callable(),
					["storage.capacity.max", "storage.capacity.current"],
					"Remaining storage capacity available")\
			.up()\
			.container("status", "Storage status information")\
				.value("is_carrying", Property.Type.BOOL,
					Callable(self, "_is_carrying"),
					Callable(),
					["storage.capacity.current"],
					"Whether the entity is currently carrying anything")\
				.value("is_full", Property.Type.BOOL,
					Callable(self, "_is_full"),
					Callable(),
					["storage.capacity.current", "storage.capacity.max"],
					"Whether storage is at maximum capacity")\
			.up()\
		.build()

	# Copy the container children from the built tree
	var built_storage = tree
	for child in built_storage.children.values():
		add_child(child)

	logger.trace("Storage property tree initialized")

#region Property Getters and Setters
func _get_max_capacity() -> float:
	var strength_level = entity.get_property_value(Path.parse("strength.base.level"))
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
