class_name PropertyFactory
extends RefCounted

## Factory class for creating property resources and templates

#region Constants
const Constants = {
	MAX_HEALTH = 100.0,
	MAX_ENERGY = 100.0,
	STRENGTH_LEVEL = 10,
	VISION_RANGE = 50.0,
	STRENGTH_FACTOR = 20.0
}

## Standard templates for property creation
const Templates = {
	PERCENTAGE = "percentage",
	COUNT = "count",
	RANGE = "range",
	MASS = "mass",
	POSITION = "position",
	CAPACITY = "capacity",
	LIST = "list"
}
#endregion

#region Template Builder Class
## Template for common property structures with fluent interface
class PropertyTemplate:
	var name: String
	var type: PropertyNode.Type
	var value_type: Property.Type
	var description: String
	var dependencies: Array[String]
	var getter: Callable
	var setter: Callable

	func _init(name: String) -> void:
		self.name = name
		self.type = PropertyNode.Type.VALUE
		self.value_type = Property.Type.UNKNOWN
		self.description = ""
		self.dependencies = []

	## Fluent interface methods
	func with_type(p_type: PropertyNode.Type) -> PropertyTemplate:
		type = p_type
		return self

	func with_value_type(p_value_type: Property.Type) -> PropertyTemplate:
		value_type = p_value_type
		return self

	func with_description(p_description: String) -> PropertyTemplate:
		description = p_description
		return self

	func with_dependencies(p_dependencies: Array[String]) -> PropertyTemplate:
		dependencies = p_dependencies
		return self

	func with_getter(p_getter: Callable) -> PropertyTemplate:
		getter = p_getter
		return self

	func with_setter(p_setter: Callable) -> PropertyTemplate:
		setter = p_setter
		return self

	func build() -> PropertyResourceBuilder:
		var builder = PropertyResourceBuilder.new(Path.parse(name)).type(type)

		if description:
			builder.description(description)
		if value_type != Property.Type.UNKNOWN:
			builder.value_type(value_type)
		if dependencies:
			builder.add_dependencies(dependencies)
		if getter.is_valid():
			builder.getter(getter)
		if setter.is_valid():
			builder.setter(setter)

		return builder
#endregion

#region Template Factory Methods
static func create_mass_template(name: String, list_path: String) -> PropertyTemplate:
	return PropertyTemplate.new(name)\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Total mass of items")\
		.with_dependencies([list_path])\
		.with_getter(func(entity: Node):
			var items = entity.get_property_value(list_path)
			if not items:
				return 0.0
			return items.get_mass())

static func create_percentage_template(name: String, current_path: String, max_path: String) -> PropertyTemplate:
	return PropertyTemplate.new(name)\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Current value as percentage of maximum")\
		.with_dependencies([current_path, max_path])\
		.with_getter(func(entity: Node):
			var current = entity.get_property_value(current_path)
			var maximum = entity.get_property_value(max_path)
			return (current / maximum) * 100.0 if maximum > 0 else 0.0)

static func create_count_template(name: String, list_path: String) -> PropertyTemplate:
	return PropertyTemplate.new(name)\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.INT)\
		.with_description("Number of items in list")\
		.with_dependencies([list_path])\
		.with_getter(func(entity: Node):
			var items = entity.get_property_value(list_path)
			return items.size() if items else 0)

static func create_range_template(name: String, description: String = "") -> PropertyTemplate:
	return PropertyTemplate.new(name)\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description(description if description else "Maximum range")\
		.with_getter(func(entity: Node): return entity.get_property_value(name))\
		.with_setter(func(entity: Node, value: float): entity.set_property_value(name, value))

static func create_position_template(name: String, get_pos: Callable) -> PropertyTemplate:
	return PropertyTemplate.new(name)\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.VECTOR2)\
		.with_description("Position in global space")\
		.with_getter(get_pos)

static func create_derived_value(
	name: String,
	description: String,
	value_type: Property.Type,
	dependencies: Array[String],
	getter: Callable
) -> PropertyTemplate:
	return PropertyTemplate.new(name)\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(value_type)\
		.with_description(description)\
		.with_dependencies(dependencies)\
		.with_getter(getter)

static func create_list_container(
	name: String,
	description: String,
	list_template: PropertyTemplate,
	additional_children: Array[PropertyTemplate] = []
) -> PropertyResourceBuilder:
	var builder = PropertyResourceBuilder.container(name).description(description)

	# Add main list and count properties
	builder.add_child("list", list_template.build())
	builder.add_child("count", create_count_template("count", name + ".list").build())

	# Add any additional child properties
	for child in additional_children:
		builder.add_child(child.name, child.build())

	return builder

static func create_capacity_container(
	name: String,
	current_getter: Callable,
	max_getter: Callable,
	max_setter: Callable = Callable()
) -> PropertyResourceBuilder:
	var builder = PropertyResourceBuilder.container(name)\
		.description("Capacity information")

	# Add capacity properties
	builder.add_child("max", PropertyTemplate.new("max")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Maximum capacity")\
		.with_getter(max_getter)\
		.with_setter(max_setter)\
		.build()
	)

	builder.add_child("current", PropertyTemplate.new("current")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Current value")\
		.with_getter(current_getter)\
		.build()
	)

	builder.add_child("percentage",
		create_percentage_template("percentage", name + ".current", name + ".max").build()
	)

	return builder
#endregion

#region Factory Methods
static func create_health_resource() -> PropertyResource:
	return PropertyResourceBuilder.container("health")\
		.description("Health management")\
		.add_child("capacity", create_capacity_container(
			"health.capacity",
			func(entity: Node): return entity.current_health,
			func(entity: Node): return entity.max_health,
			func(entity: Node, value: float): entity.max_health = value
		))\
		.build()

static func create_vision_resource() -> PropertyResource:
	# Vision range template with fluent interface
	var vision_range_template = PropertyTemplate.new("range")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Maximum vision range")\
		.with_getter(func(entity: Node): return entity.vision_range)\
		.with_setter(func(entity: Node, value: float): entity.vision_range = value)

	# Foods list template
	var foods_list_template = PropertyTemplate.new("list")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FOODS)\
		.with_description("Food items within vision range")\
		.with_dependencies(["vision.base.range"])\
		.with_getter(func(entity: Node):
			var range = entity.get_property_value("vision.base.range")
			return Foods.in_range(entity.global_position, range, true))

	# Ants list template
	var ants_list_template = PropertyTemplate.new("list")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.ANTS)\
		.with_description("Ants within vision range")\
		.with_dependencies(["vision.base.range"])\
		.with_getter(func(entity: Node):
			var range = entity.get_property_value("vision.base.range")
			return Ants.in_range(entity, range))

	return PropertyResourceBuilder.container("vision")\
		.description("Vision management")\
		.add_child("base",
			PropertyResourceBuilder.container("base")\
				.description("Base vision attributes")\
				.add_child("range", vision_range_template.build())
		)\
		.add_child("ants", create_list_container(
			"vision.ants",
			"Ants in vision range",
			ants_list_template
		))\
		.add_child("foods", create_list_container(
			"vision.foods",
			"Food in vision range",
			foods_list_template
		))\
		.build()

static func create_strength_resource() -> PropertyResource:
	var level_template = PropertyTemplate.new("level")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.INT)\
		.with_description("Base strength level")\
		.with_getter(func(entity: Node): return entity.level)\
		.with_setter(func(entity: Node, value: int):
			if value > 0:
				entity.level = value)

	var carry_template = create_derived_value(
		"carry_factor",
		"Base carrying capacity factor",
		Property.Type.FLOAT,
		["strength.base.level"],
		func(entity: Node):
			var level = entity.get_property_value("strength.base.level")
			return float(level) * Constants.STRENGTH_FACTOR
	)

	return PropertyResourceBuilder.container("strength")\
		.description("Strength management")\
		.add_child("base",
			PropertyResourceBuilder.container("base")\
				.description("Base strength attributes")\
				.add_child("level", level_template.build())
		)\
		.add_child("derived",
			PropertyResourceBuilder.container("derived")\
				.description("Values derived from strength")\
				.add_child("carry_factor", carry_template.build())
		)\
		.build()

static func create_proprioception_resource() -> PropertyResource:
	# Base position templates
	var base_position = create_position_template(
		"position",
		func(entity: Node): return entity.global_position)

	var target_position = PropertyTemplate.new("target_position")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.VECTOR2)\
		.with_description("Current target position for movement")\
		.with_getter(func(entity: Node): return entity.target_position)\
		.with_setter(func(entity: Node, value): entity.target_position = value)

	var colony_position = create_position_template(
		"position",
		func(entity: Node): return entity.colony.global_position)

	# Colony relative position calculations
	var direction_template = create_derived_value(
		"direction",
		"Normalized vector pointing towards colony",
		Property.Type.VECTOR2,
		["proprioception.base.position", "proprioception.colony.position"],
		func(entity: Node):
			var pos = entity.get_property_value("proprioception.base.position")
			var colony_pos = entity.get_property_value("proprioception.colony.position")
			return pos.direction_to(colony_pos) if colony_pos else Vector2.ZERO)

	var distance_template = create_derived_value(
		"distance",
		"Distance from entity to colony in units",
		Property.Type.FLOAT,
		["proprioception.base.position", "proprioception.colony.position"],
		func(entity: Node):
			var pos = entity.get_property_value("proprioception.base.position")
			var colony_pos = entity.get_property_value("proprioception.colony.position")
			return pos.distance_to(colony_pos) if colony_pos else 0.0)

	return PropertyResourceBuilder.container("proprioception")\
		.description("Proprioception management")\
		.add_child("base",
			PropertyResourceBuilder.container("base")\
				.description("Base position information")\
				.add_child("position", base_position.build())\
				.add_child("target_position", target_position.build())
		)\
		.add_child("colony",
			PropertyResourceBuilder.container("colony")\
				.description("Information about position relative to colony")\
				.add_child("position", colony_position.build())\
				.add_child("direction", direction_template.build())\
				.add_child("distance", distance_template.build())
		)\
		.build()

static func create_energy_resource() -> PropertyResource:
	return PropertyResourceBuilder.container("energy")\
		.description("Energy management")\
		.add_child("capacity", create_capacity_container(
			"energy.capacity",
			func(entity: Node): return entity.current_energy,
			func(entity: Node): return entity.max_energy,
			func(entity: Node, value: float): entity.max_energy = value
		))\
		.build()

static func create_storage_resource() -> PropertyResource:
	var current_template = PropertyTemplate.new("current")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Current total mass of stored items")\
		.with_getter(func(entity: Node): return entity.foods.get_mass())

	var max_template = create_derived_value(
		"max",
		"Maximum weight the entity can store",
		Property.Type.FLOAT,
		["strength.derived.carry_factor"],
		func(entity: Node): return entity.get_property_value("strength.derived.carry_factor")
	)

	var available_template = create_derived_value(
		"available",
		"Remaining storage capacity available",
		Property.Type.FLOAT,
		["storage.capacity.max", "storage.capacity.current"],
		func(entity: Node):
			var maximum = entity.get_property_value("storage.capacity.max")
			var current = entity.get_property_value("storage.capacity.current")
			return maximum - current
	)

	return PropertyResourceBuilder.container("storage")\
		.description("Storage management")\
		.add_child("capacity",
			PropertyResourceBuilder.container("capacity")\
				.description("Information about entity's storage capacity")\
				.add_child("max", max_template.build())\
				.add_child("current", current_template.build())\
				.add_child("percentage", create_percentage_template(
					"percentage",
					"storage.capacity.current",
					"storage.capacity.max"
				).build())\
				.add_child("available", available_template.build())
		)\
		.build()

static func create_olfaction_resource() -> PropertyResource:
	var range_template = create_range_template("olfaction.base.range", "Maximum range at which to smell things")

	var all_pheromones = PropertyTemplate.new("list")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.PHEROMONES)\
		.with_description("All pheromones within olfactory range")\
		.with_dependencies(["olfaction.base.range"])\
		.with_getter(func(entity: Node): return entity._get_pheromones_in_range())

	var food_pheromones = PropertyTemplate.new("list")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.PHEROMONES)\
		.with_description("Food pheromones within range")\
		.with_dependencies(["olfaction.base.range"])\
		.with_getter(func(entity: Node): return entity._get_food_pheromones_in_range())

	var home_pheromones = PropertyTemplate.new("list")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.PHEROMONES)\
		.with_description("Home pheromones within range")\
		.with_dependencies(["olfaction.base.range"])\
		.with_getter(func(entity: Node): return entity._get_home_pheromones_in_range())

	return PropertyResourceBuilder.container("olfaction")\
		.description("Olfaction management")\
		.add_child("base",
			PropertyResourceBuilder.container("base")\
				.description("Base olfaction attributes")\
				.add_child("range", range_template.build())
		)\
		.add_child("pheromones",
			PropertyResourceBuilder.container("pheromones")\
				.description("Information about pheromones within range")\
				.add_child("list", all_pheromones.build())\
				.add_child("count", create_count_template("count", "olfaction.pheromones.list").build())\
				.add_child("food", create_list_container(
					"olfaction.pheromones.food",
					"Food-related pheromone information",
					food_pheromones
				))\
				.add_child("home", create_list_container(
					"olfaction.pheromones.home",
					"Home-related pheromone information",
					home_pheromones
				))
		)\
		.build()

static func create_speed_resource() -> PropertyResource:
	# Base rate templates
	var movement_rate = PropertyTemplate.new("rate")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Rate at which the entity can move (units/second)")\
		.with_getter(func(entity: Node): return entity.movement_rate)\
		.with_setter(func(entity: Node, value: float): entity.movement_rate = value)

	var harvesting_rate = PropertyTemplate.new("harvesting")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Rate at which the entity can harvest resources")\
		.with_getter(func(entity: Node): return entity.harvesting_rate)\
		.with_setter(func(entity: Node, value: float): entity.harvesting_rate = value)

	var storing_rate = PropertyTemplate.new("storing")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FLOAT)\
		.with_description("Rate at which the entity can store resources")\
		.with_getter(func(entity: Node): return entity.storing_rate)\
		.with_setter(func(entity: Node, value: float): entity.storing_rate = value)

	# Derived calculations
	var time_per_unit = create_derived_value(
		"time_per_unit",
		"Time required to move one unit of distance",
		Property.Type.FLOAT,
		["speed.base.rate"],
		func(entity: Node):
			var move_rate = entity.get_property_value("speed.base.rate")
			return 1.0 / move_rate if move_rate > 0 else INF
	)

	var harvesting_per_second = create_derived_value(
		"per_second",
		"Amount that can be harvested in one second",
		Property.Type.FLOAT,
		["speed.base.harvesting"],
		func(entity: Node):
			return entity.get_property_value("speed.base.harvesting")
	)

	return PropertyResourceBuilder.container("speed")\
		.description("Speed management")\
		.add_child("base",
			PropertyResourceBuilder.container("base")\
				.description("Base speed rates")\
				.add_child("rate", movement_rate.build())\
				.add_child("harvesting", harvesting_rate.build())\
				.add_child("storing", storing_rate.build())
		)\
		.add_child("derived",
			PropertyResourceBuilder.container("derived")\
				.description("Values derived from base speeds")\
				.add_child("movement",
					PropertyResourceBuilder.container("movement")\
						.description("Movement-related calculations")\
						.add_child("time_per_unit", time_per_unit.build())
				)\
				.add_child("harvesting",
					PropertyResourceBuilder.container("harvesting")\
						.description("Harvesting-related calculations")\
						.add_child("per_second", harvesting_per_second.build())
				)
		)\
		.build()

static func create_colony_resource() -> PropertyResource:
	var range_template = create_range_template(
		"reach.range",
		"Colony's interaction range"
	)

	return PropertyResourceBuilder.container("colony")\
		.description("Colony management")\
		.add_child("reach",
			PropertyResourceBuilder.container("reach")\
				.description("Colony reach properties")\
				.add_child("range", range_template.build())
		)\
		.build()

static func create_reach_resource() -> PropertyResource:
	var range_template = create_range_template(
		"reach.range",
		"Maximum distance the entity can reach"
	)

	var foods_list = PropertyTemplate.new("list")\
		.with_type(PropertyNode.Type.VALUE)\
		.with_value_type(Property.Type.FOODS)\
		.with_description("Food items within reach range")\
		.with_dependencies(["reach.range"])\
		.with_getter(func(entity: Node):
			return Foods.in_range(
				entity.global_position,
				entity.get_property_value("reach.range")))

	var foods_mass = create_mass_template(
		"mass",
		"reach.foods.list"
	)

	return PropertyResourceBuilder.container("reach")\
		.description("Reach management")\
		.add_child("range", range_template.build())\
		.add_child("foods", create_list_container(
			"reach.foods",
			"Properties related to food in reach range",
			foods_list,
			[foods_mass]
		))\
		.build()
