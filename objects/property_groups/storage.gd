class_name Storage
extends PropertyNode
## Component responsible for managing entity's storage capacity and contents

func _init(p_entity: Node) -> void:
	# First create self as container
	super._init("storage", Type.CONTAINER, p_entity)

	# Then build and copy children
	var tree = PropertyNode.create_tree(p_entity)\
		.container("capacity", "Information about entity's storage capacity")\
			.value("maximum", Property.Type.FLOAT,
				Callable(self, "_get_max_capacity"),
				Callable(),
				["strength.level"],
				"Maximum weight the entity can store")\
			.value("current", Property.Type.FLOAT,
				Callable(self, "_get_current_capacity"),
				Callable(),
				[],
				"Current total mass of stored items")\
			.value("available", Property.Type.FLOAT,
				Callable(self, "_get_mass_available"),
				Callable(),
				["storage.capacity.maximum", "storage.capacity.current"],
				"Remaining storage capacity available")\
			.value("is_storing", Property.Type.BOOL,
				Callable(self, "_is_storing"),
				Callable(),
				["storage.capacity.current"],
				"Whether the entity is currently storing anything")\
		.build()

	# Copy children from built tree
	for child in tree.children.values():
		add_child(child)

	_trace("Storage property tree initialized")

#region Property Getters and Setters
func _get_max_capacity() -> float:
	var strength_level = entity.get_property_value("strength.level")
	return strength_level * 10.0 if strength_level else 0.0

func _get_current_capacity() -> float:
	if not entity:
		_error("Cannot get stored mass: entity reference is null")
		return 0.0
	return entity.foods.mass()

func _get_mass_available() -> float:
	return _get_max_capacity() - _get_current_capacity()

func _is_storing() -> bool:
	return _get_current_capacity() > 0
#endregion

#region Public Methods
## Check if the entity can store additional weight
func can_store(weight: float) -> bool:
	if weight < 0:
		_error("Cannot check negative weight")
		return false
	return weight <= _get_mass_available()
#endregion
