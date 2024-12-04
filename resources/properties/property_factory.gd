class_name PropertyFactory
extends RefCounted
## Factory for creating common property resource structures

#region Constants
const DEFAULT_MAX_HEALTH := 100.0
const DEFAULT_MAX_ENERGY := 100.0
const DEFAULT_STRENGTH_LEVEL := 10
const DEFAULT_VISION_RANGE := 50.0
const STRENGTH_FACTOR := 20.0
#endregion

#region Health Factory
static func create_health_resource() -> PropertyResource:
	return (
		PropertyResourceBuilder.container("health")
			.description("Health management")
			.add_child("capacity", _create_health_capacity_builder())
			.build()
	)

static func _create_health_capacity_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("capacity")
			.description("Health capacity information")
			.add_child("max", (
				PropertyResourceBuilder.value("max")
					.description("Maximum health level")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							var node = entity.get_property_value("health.capacity.max")
							return node.get_value() if node else DEFAULT_MAX_HEALTH)
					.setter(
						func(entity: Node, value: float):
							var node = entity.get_property_value("health.capacity.max")
							if node:
								var result = node.set_value(value)
								if result.is_ok():
									var current_node = entity.get_property_value("health.capacity.current")
									if current_node and current_node.get_value() > value:
										current_node.set_value(value))
			))
			.add_child("current", (
				PropertyResourceBuilder.value("current")
					.description("Current health level")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							var node = entity.get_property_value("health.capacity.current")
							return node.get_value() if node else DEFAULT_MAX_HEALTH)
					.setter(
						func(entity: Node, value: float):
							var node = entity.get_property_value("health.capacity.current")
							if node:
								var max_node = entity.get_property_value("health.capacity.max")
								var max_health = max_node.get_value() if max_node else DEFAULT_MAX_HEALTH
								value = min(value, max_health)
								node.set_value(value))
			))
			.add_child("percentage", (
				PropertyResourceBuilder.value("percentage")
					.description("Current health level as a percentage of max health")
					.value_type(Property.Type.FLOAT)
					.add_dependencies(["health.capacity.current", "health.capacity.max"])
					.getter(
						func(entity: Node):
							var current_node = entity.get_property_value("health.capacity.current")
							var max_node = entity.get_property_value("health.capacity.max")
							
							var current = current_node.get_value() if current_node else 0.0
							var max_health = max_node.get_value() if max_node else DEFAULT_MAX_HEALTH
							
							return (current / max_health) * 100.0 if max_health > 0 else 0.0)
			))
	)
#endregion

#region Energy Factory
static func create_energy_resource() -> PropertyResource:
	return (PropertyResourceBuilder.container("energy")
		.description("Energy management")
		.add_child("capacity", _create_energy_capacity_builder())
		.add_child("status", _create_energy_status_builder())
		.build())

static func _create_energy_capacity_builder() -> PropertyResourceBuilder:
	return (PropertyResourceBuilder.container("capacity")
		.description("Energy capacity information")
		.add_child("max", (PropertyResourceBuilder.value("max")
			.description("Maximum energy level")
			.value_type(Property.Type.FLOAT)
			.getter(func(entity: Node): return entity.max_level)
			.setter(func(entity: Node, value: float): 
				if not is_zero_approx(value):
					entity.set_property_value("energy.capacity.current", value)
					)))
		.add_child("current", (PropertyResourceBuilder.value("current")
			.description("Current energy level")
			.value_type(Property.Type.FLOAT)
			.getter(func(entity: Node): return entity.current_level)
			.setter(func(entity: Node, value: float):
				var max_level = entity.get_property_value("energy.capacity.max")
				entity.set_property_value("energy.capacity.max", clamp(value, 0.0, max_level)))))
		.add_child("percentage", (PropertyResourceBuilder.value("percentage")
			.description("Current energy level as percentage")
			.value_type(Property.Type.FLOAT)
			.add_dependencies(["energy.capacity.current", "energy.capacity.max"])
			.getter(func(entity: Node):
				var current = entity.get_property_value("energy.capacity.current")
				var max_level = entity.get_property_value("energy.capacity.max")
				return (current / max_level) * 100.0 if max_level > 0 else 0.0)
				)))

static func _create_energy_status_builder() -> PropertyResourceBuilder:
	return (PropertyResourceBuilder.container("status")
		.description("Energy status information")
		.add_child("replenishable", (PropertyResourceBuilder.value("replenishable")
			.description("Amount of energy that can be replenished")
			.value_type(Property.Type.FLOAT)
			.add_dependencies(["energy.capacity.current", "energy.capacity.max"])
			.getter(func(entity: Node):
				var current = entity.get_property_value("energy.capacity.current")
				var max_level = entity.get_property_value("energy.capacity.max")
				return max_level - current)
				)))
#endregion

#region Strength Factory
static func create_strength_resource() -> PropertyResource:
	return (PropertyResourceBuilder.container("strength")
		.description("Strength management")
		.add_child("base", _create_strength_base_builder())
		.add_child("derived", _create_strength_derived_builder())
		.build())

static func _create_strength_base_builder() -> PropertyResourceBuilder:
	return (PropertyResourceBuilder.container("base")
		.description("Base strength attributes")
		.add_child("level", (PropertyResourceBuilder.value("level")
			.description("Base strength level")
			.value_type(Property.Type.INT)
			.getter(func(entity: Node): return entity.level)
			.setter(func(entity: Node, value: int): 
				if value > 0:
					entity.level = value)
			)))

static func _create_strength_derived_builder() -> PropertyResourceBuilder:
	return (PropertyResourceBuilder.container("derived")
		.description("Values derived from strength")
		.add_child("carry_factor", (PropertyResourceBuilder.value("carry_factor")
			.description("Base carrying capacity factor")
			.value_type(Property.Type.FLOAT)
			.add_dependencies(["strength.base.level"])
			.getter(func(entity: Node):
				var level = entity.get_property_value("strength.base.level")
				return float(level) * STRENGTH_FACTOR)
				)))
#endregion
#region Vision Factory
static func create_vision_resource() -> PropertyResource:
	return (
		PropertyResourceBuilder.container("vision")
			.description("Vision management")
			.add_child("base", _create_vision_base_builder())
			.add_child("ants", _create_vision_ants_builder())
			.add_child("foods", _create_vision_foods_builder())
			.build()
	)

static func _create_vision_base_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("base")
			.description("Base vision attributes")
			.add_child("range", (
				PropertyResourceBuilder.value("range")
					.description("Maximum range at which the entity can see")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node): 
							return entity.get_property_value("vision.base.range"))
					.setter(
						func(entity: Node, value: float): 
							entity.set_property_value("vision.base.range", value))
			))
	)

static func _create_vision_ants_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("ants")
			.description("Properties related to ants in vision range")
			.add_child("list", (
				PropertyResourceBuilder.value("list")
					.description("Ants within vision range")
					.value_type(Property.Type.ANTS)
					.add_dependencies(["vision.base.range"])
					.getter(
						func(entity: Node):
							var range = entity.get_property_value("vision.base.range")
							return Ants.in_range(entity, range))
			))
			.add_child("count", (
				PropertyResourceBuilder.value("count")
					.description("Number of ants within vision range")
					.value_type(Property.Type.INT)
					.add_dependencies(["vision.ants.list"])
					.getter(
						func(entity: Node):
							var ants = entity.get_property_value("vision.ants.list")
							return ants.size() if ants else 0)
			))
	)

static func _create_vision_foods_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("foods")
			.description("Properties related to food in vision range")
			.add_child("list", (
				PropertyResourceBuilder.value("list")
					.description("Food items within vision range")
					.value_type(Property.Type.FOODS)
					.add_dependencies(["vision.base.range"])
					.getter(
						func(entity: Node):
							var range = entity.get_property_value("vision.base.range")
							return Foods.in_range(entity.global_position, range, true))
			))
			.add_child("nearest", (
				PropertyResourceBuilder.container("nearest")
					.description("Nearest food item to entity")
					.add_child("object", (
						PropertyResourceBuilder.value("object")
							.description("Nearest visible food item")
							.value_type(Property.Type.FOOD)
							.add_dependencies(["vision.base.range"])
							.getter(
								func(entity: Node):
									var range = entity.get_property_value("vision.base.range")
									return Foods.nearest_food(entity.global_position, range, true))
					))
					.add_child("position", (
						PropertyResourceBuilder.value("position")
							.description("Nearest visible food item position")
							.value_type(Property.Type.VECTOR2)
							.add_dependencies(["vision.foods.nearest.object"])
							.getter(
								func(entity: Node):
									var food = entity.get_property_value("vision.foods.nearest.object")
									return food.global_position if food else Vector2.ZERO))
					))
			)
			.add_child("count", (
				PropertyResourceBuilder.value("count")
					.description("Number of food items within vision range")
					.value_type(Property.Type.INT)
					.add_dependencies(["vision.foods.list"])
					.getter(
						func(entity: Node):
							var foods = entity.get_property_value("vision.foods.list")
							return foods.size() if foods else 0)
				))
			.add_child("mass", (
				PropertyResourceBuilder.value("mass")
					.description("Total mass of food within vision range")
					.value_type(Property.Type.FLOAT)
					.add_dependencies(["vision.foods.list"])
					.getter(
						func(entity: Node):
							var foods = entity.get_property_value("vision.foods.list")
							return foods.get_mass() if foods else 0.0)
			))
	)
#endregion

#region Reach Factory
static func create_reach_resource() -> PropertyResource:
	return (
		PropertyResourceBuilder.container("reach")
			.description("Reach management")
			.add_child("range", (
				PropertyResourceBuilder.value("range")
					.description("Maximum distance the entity can reach")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							return entity.get_property_value("reach.base.range"))
					.setter(
						func(entity: Node, value: float):
							if value <= 0:
								return
							entity.range = value)
			))
			.add_child("foods", _create_reach_foods_builder())
			.build()
	)

static func _create_reach_foods_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("foods")
			.description("Properties related to food in reach range")
			.add_child("list", (
				PropertyResourceBuilder.value("list")
					.description("Food items within reach range")
					.value_type(Property.Type.FOODS)
					.add_dependencies(["reach.base.range"])
					.getter(
						func(entity: Node):
							return Foods.in_range(entity.global_position, entity.get_property_value("reach.range")))
			))
			.add_child("count", (
				PropertyResourceBuilder.value("count")
					.description("Number of food items within reach range")
					.value_type(Property.Type.INT)
					.add_dependencies(["reach.foods.list"])
					.getter(
						func(entity: Node):
							var foods = entity.get_property_value("reach.foods.list")
							return foods.size() if foods else 0)
			))
			.add_child("mass", (
				PropertyResourceBuilder.value("mass")
					.description("Total mass of food within reach range")
					.value_type(Property.Type.FLOAT)
					.add_dependencies(["reach.foods.list"])
					.getter(
						func(entity: Node):
							var foods = entity.get_property_value("reach.foods.list")
							if not foods:
								return 0.0
							var total_mass: float = 0.0
							for food in foods:
								total_mass += food.mass
							return total_mass)
			))
	)
#endregion
#region Storage Factory
static func create_storage_resource() -> PropertyResource:
	return (
		PropertyResourceBuilder.container("storage")
			.description("Storage management")
			.add_child("capacity", _create_storage_capacity_builder())
			.build()
	)

static func _create_storage_capacity_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("capacity")
			.description("Information about entity's storage capacity")
			.add_child("max", (
				PropertyResourceBuilder.value("max")
					.description("Maximum weight the entity can store")
					.value_type(Property.Type.FLOAT)
					.add_dependencies(["strength.derived.carry_factor"])
					.getter(
						func(entity: Node):
							return entity.get_property_value("strength.derived.carry_factor"))
			))
			.add_child("current", (
				PropertyResourceBuilder.value("current")
					.description("Current total mass of stored items")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							return entity.foods.get_mass())
			))
			.add_child("percentage", (
				PropertyResourceBuilder.value("percentage")
					.description("Current storage used as percentage of maximum")
					.value_type(Property.Type.FLOAT)
					.add_dependencies(["storage.capacity.current", "storage.capacity.max"])
					.getter(
						func(entity: Node):
							var maximum = entity.get_property_value("storage.capacity.max")
							if maximum <= 0:
								return 0.0
							var current = entity.get_property_value("storage.capacity.current")
							return (current / maximum) * 100.0)
			))
			.add_child("available", (
				PropertyResourceBuilder.value("available")
					.description("Remaining storage capacity available")
					.value_type(Property.Type.FLOAT)
					.add_dependencies(["storage.capacity.max", "storage.capacity.current"])
					.getter(
						func(entity: Node):
							var maximum = entity.get_property_value("storage.capacity.max")
							var current = entity.get_property_value("storage.capacity.current")
							return maximum - current)
			))
	)
#endregion

#region Proprioception Factory
static func create_proprioception_resource() -> PropertyResource:
	return (
		PropertyResourceBuilder.container("proprioception")
			.description("Proprioception management")
			.add_child("base", _create_proprioception_base_builder())
			.add_child("colony", _create_proprioception_colony_builder())
			.build()
	)

static func _create_proprioception_base_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("base")
			.description("Base position information")
			.add_child("position", (
				PropertyResourceBuilder.value("position")
					.description("Current global position of the entity")
					.value_type(Property.Type.VECTOR2)
					.getter(
						func(entity: Node):
							return entity.global_position)
			))
			.add_child("target_position", (
				PropertyResourceBuilder.value("target_position")
					.description("Current target position for movement")
					.value_type(Property.Type.VECTOR2)
					.getter(
						func(entity: Node):
							return entity.target_position)
					.setter(
						func(entity: Node, value):
							entity.target_position = value)
			))
	)

static func _create_proprioception_colony_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("colony")
			.description("Information about position relative to colony")
			.add_child("position", (
				PropertyResourceBuilder.value("position")
					.description("Global position of the colony")
					.value_type(Property.Type.VECTOR2)
					.getter(
						func(entity: Node):
							return entity.colony.global_position)
			))
			.add_child("direction", (
				PropertyResourceBuilder.value("direction")
					.description("Normalized vector pointing towards colony")
					.value_type(Property.Type.VECTOR2)
					.add_dependencies(["proprioception.base.position", "proprioception.colony.position"])
					.getter(
						func(entity: Node):
							var pos = entity.get_property_value("proprioception.base.position")
							var colony_pos = entity.get_property_value("proprioception.colony.position")
							return pos.direction_to(colony_pos) if colony_pos else Vector2.ZERO)
			))
			.add_child("distance", (
				PropertyResourceBuilder.value("distance")
					.description("Distance from entity to colony in units")
					.value_type(Property.Type.FLOAT)
					.add_dependencies(["proprioception.base.position", "proprioception.colony.position"])
					.getter(
						func(entity: Node):
							var pos = entity.get_property_value("proprioception.base.position")
							var colony_pos = entity.get_property_value("proprioception.colony.position")
							return pos.distance_to(colony_pos) if colony_pos else 0.0)
			))
	)
#endregion

#region Olfaction Factory
static func create_olfaction_resource() -> PropertyResource:
	return (
		PropertyResourceBuilder.container("olfaction")
			.description("Olfaction management")
			.add_child("base", _create_olfaction_base_builder())
			.add_child("pheromones", _create_olfaction_pheromones_builder())
			.build()
	)

static func _create_olfaction_base_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("base")
			.description("Base olfaction attributes")
			.add_child("range", (
				PropertyResourceBuilder.value("range")
					.description("Maximum range at which to smell things")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							return entity.get_property_value("olfaction.base.range"))
					.setter(
						func(entity: Node, value):
							entity.get_property("olfaction").range = value)
			))
	)

static func _create_olfaction_pheromones_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("pheromones")
			.description("Information about pheromones within range")
			.add_child("list", (
				PropertyResourceBuilder.value("list")
					.description("All pheromones within olfactory range")
					.value_type(Property.Type.PHEROMONES)
					.add_dependencies(["olfaction.base.range"])
					.getter(
						func(entity: Node):
							return entity._get_pheromones_in_range())
			))
			.add_child("count", (
				PropertyResourceBuilder.value("count")
					.description("Count of all pheromones within range")
					.value_type(Property.Type.INT)
					.add_dependencies(["olfaction.pheromones.list"])
					.getter(
						func(entity: Node):
							var pheromones = entity.get_property_value("olfaction.pheromones.list")
							return pheromones.size() if pheromones else 0)
			))
			.add_child("food", _create_olfaction_food_builder())
			.add_child("home", _create_olfaction_home_builder())
	)

static func _create_olfaction_food_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("food")
			.description("Food-related pheromone information")
			.add_child("list", (
				PropertyResourceBuilder.value("list")
					.description("Food pheromones within range")
					.value_type(Property.Type.PHEROMONES)
					.add_dependencies(["olfaction.base.range"])
					.getter(
						func(entity: Node):
							return entity._get_food_pheromones_in_range())
			))
			.add_child("count", (
				PropertyResourceBuilder.value("count")
					.description("Count of food pheromones within range")
					.value_type(Property.Type.INT)
					.add_dependencies(["olfaction.pheromones.food.list"])
					.getter(
						func(entity: Node):
							var pheromones = entity.get_property_value("olfaction.pheromones.food.list")
							return pheromones.size() if pheromones else 0)
			))
	)

static func _create_olfaction_home_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("home")
			.description("Home-related pheromone information")
			.add_child("list", (
				PropertyResourceBuilder.value("list")
					.description("Home pheromones within range")
					.value_type(Property.Type.PHEROMONES)
					.add_dependencies(["olfaction.base.range"])
					.getter(
						func(entity: Node):
							return entity._get_home_pheromones_in_range())
			))
			.add_child("count", (
				PropertyResourceBuilder.value("count")
					.description("Count of home pheromones within range")
					.value_type(Property.Type.INT)
					.add_dependencies(["olfaction.pheromones.home.list"])
					.getter(
						func(entity: Node):
							var pheromones = entity.get_property_value("olfaction.pheromones.home.list")
							return pheromones.size() if pheromones else 0)
			))
	)
#endregion
#region Speed Factory
static func create_speed_resource() -> PropertyResource:
	return (
		PropertyResourceBuilder.container("speed")
			.description("Speed management")
			.add_child("base", _create_speed_base_builder())
			.add_child("derived", _create_speed_derived_builder())
			.build()
	)

static func _create_speed_base_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("base")
			.description("Base speed rates")
			.add_child("rate", (
				PropertyResourceBuilder.value("rate")
					.description("Rate at which the entity can move (units/second)")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							return entity.movement_rate)
					.setter(
						func(entity: Node, value: float):
							entity.movement_rate = value)
			))
			.add_child("harvesting", (
				PropertyResourceBuilder.value("harvesting")
					.description("Rate at which the entity can harvest resources (units/second)")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							return entity.harvesting_rate)
					.setter(
						func(entity: Node, value: float):
							entity.harvesting_rate = value)
			))
			.add_child("storing", (
				PropertyResourceBuilder.value("storing")
					.description("Rate at which the entity can store resources (units/second)")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							return entity.storing_rate)
					.setter(
						func(entity: Node, value: float):
							entity.storing_rate = value)
			))
	)

static func _create_speed_derived_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("derived")
			.description("Values derived from base speeds")
			.add_child("movement", (
				PropertyResourceBuilder.container("movement")
					.description("Movement-related calculations")
					.add_child("time_per_unit", (
						PropertyResourceBuilder.value("time_per_unit")
							.description("Time required to move one unit of distance")
							.value_type(Property.Type.FLOAT)
							.add_dependencies(["speed.base.rate"])
							.getter(
								func(entity: Node):
									var movement_rate = entity.get_property_value("speed.base.rate")
									return 1.0 / movement_rate if movement_rate > 0 else INF)
					))
			))
			.add_child("harvesting", (
				PropertyResourceBuilder.container("harvesting")
					.description("Harvesting-related calculations")
					.add_child("per_second", (
						PropertyResourceBuilder.value("per_second")
							.description("Amount that can be harvested in one second")
							.value_type(Property.Type.FLOAT)
							.add_dependencies(["speed.base.harvesting"])
							.getter(
								func(entity: Node):
									return entity.get_property_value("speed.base.harvesting"))
					))
			))
	)
#endregion
#region Colony resource
static func create_colony_resource() -> PropertyResource:
	return (
		PropertyResourceBuilder.container("colony")
			.description("Colony management")
			.add_child("reach", _create_colony_reach_builder())
			.build()
	)

static func _create_colony_reach_builder() -> PropertyResourceBuilder:
	return (
		PropertyResourceBuilder.container("reach")
			.description("Colony reach properties")
			.add_child("range", (
				PropertyResourceBuilder.value("range")
					.description("Colony's interaction range")
					.value_type(Property.Type.FLOAT)
					.getter(
						func(entity: Node):
							return entity.get_property_value("reach.range"))
					.setter(
						func(entity: Node, value: float):
							entity.set_property_value("reach.range", value))
			))
	)
#endregion
