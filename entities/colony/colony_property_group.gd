class_name ColonyPropertyGroup
extends PropertyGroup

## Reference to the parent colony node
var colony: Colony

func _init(p_colony: Colony) -> void:
	colony = p_colony
	log_from = "colony"
	log_category = DebugLogger.Category.ENTITY
	name = log_from
	_root = (Property.create(name)
		.as_container()
		.described_as("Property group for %s" % name)
		.build())
	_init_properties()

func _init_properties() -> void:
	_debug("Initializing colony properties...")

	# Create base properties container
	var base_prop = (Property.create("base")
		.as_container()
		.described_as("Basic colony properties")
		.with_children([
			Property.create("position")
				.as_property(Property.Type.VECTOR2)
				.with_getter(Callable(colony, "_get_position"))
				.described_as("Location of the colony in global coordinates")
				.build(),

			Property.create("radius")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(colony, "_get_radius"))
				.with_setter(Callable(colony, "_set_radius"))
				.described_as("Size of the colony radius in units")
				.build()
		])
		.build())

	# Create metrics container with computed properties
	var metrics_prop = (Property.create("metrics")
		.as_container()
		.described_as("Colony size metrics")
		.with_children([
			Property.create("area")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(colony, "_get_area"))
				.with_dependency("colony.base.radius")
				.described_as("Size of the colony area in units squared")
				.build(),

			Property.create("perimeter")
				.as_property(Property.Type.FLOAT)
				.with_getter(Callable(colony, "_get_perimeter"))
				.with_dependency("colony.base.radius")
				.described_as("Length of colony perimeter in units")
				.build()
		])
		.build())

	# Create resources container with nested groups
	var resources_prop = (Property.create("resources")
		.as_container()
		.described_as("Colony resource information")
		.with_children([
			# Foods group
			(Property.create("foods")
				.as_container()
				.described_as("Properties related to colony food storage")
				.with_children([
					Property.create("items")
						.as_property(Property.Type.FOODS)
						.with_getter(Callable(colony, "_get_foods"))
						.described_as("All food items in colony storage")
						.build(),
					Property.create("count")
						.as_property(Property.Type.INT)
						.with_getter(Callable(colony, "_get_food_count"))
						.with_dependency("colony.resources.foods.items")
						.described_as("Number of food items in colony storage")
						.build(),
					Property.create("mass")
						.as_property(Property.Type.FLOAT)
						.with_getter(Callable(colony, "_get_total_food_mass"))
						.with_dependency("colony.resources.foods.items")
						.described_as("Total mass of stored food")
						.build()
				])
				.build()),
			
			# Ants group
			(Property.create("ants")
				.as_container()
				.described_as("Properties related to colony ants")
				.with_children([
					Property.create("members")
						.as_property(Property.Type.ANTS)
						.with_getter(Callable(colony, "_get_ants"))
						.described_as("All ants belonging to the colony")
						.build(),
					Property.create("count")
						.as_property(Property.Type.INT)
						.with_getter(Callable(colony, "_get_ant_count"))
						.with_dependency("colony.resources.ants.members")
						.described_as("Number of ants in the colony")
						.build(),
					Property.create("average_energy")
						.as_property(Property.Type.FLOAT)
						.with_getter(Callable(colony, "_get_average_ant_energy"))
						.with_dependency("colony.resources.ants.members")
						.described_as("Average energy level of colony ants")
						.build()
				])
				.build())
		])
		.build())

	# Register all properties
	var result = register_at_path(Path.parse("colony"), base_prop)
	if not result.success():
		_error("Failed to register colony.base properties: %s" % result.get_error())
		
	result = register_at_path(Path.parse("colony"), metrics_prop)
	if not result.success():
		_error("Failed to register colony.metrics properties: %s" % result.get_error())
		
	result = register_at_path(Path.parse("colony"), resources_prop)
	if not result.success():
		_error("Failed to register colony.resources properties: %s" % result.get_error())

	_trace("Successfully initialized colony properties with structure:")
	_log_structure(_root)
