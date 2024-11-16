class_name Storage
extends PropertyNode

func _init(p_entity: Node) -> void:
	super._init("storage", PropertyNode.Type.CONTAINER, p_entity)

func _init_properties() -> void:
	# Create carrying capacity container with nested properties
	var capacity_prop = (Property.create("capacity")
		.as_container()
		.described_as("Information about entity's storage capacity")
		.with_children([
			Property.create("maximum")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_max_capacity"))
				.with_dependency("strength.level")
				.described_as("Maximum weight the entity can store")
				.build(),
			Property.create("current")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_current_capacity"))
				.described_as("Current total mass of stored items")
				.build(),
			Property.create("available")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(self, "_get_mass_available"))
				.with_dependencies([
					"storage.capacity.maximum",
					"storage.capacity.current"
				])
				.described_as("Remaining storage capacity available")
				.build(),
			Property.create("is_storing")
				.as_property(Property.Type.BOOL)
				.with_getter(Callable(self, "_is_storing"))
				.with_dependency("storage.capacity.current")
				.described_as("Whether the entity is currently storing anything")
				.build()
		])
		.build())

	# Register properties
	register_at_path(Path.parse("storage"), capacity_prop)

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
