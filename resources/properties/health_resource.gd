class_name HealthResource
extends PropertyResource
## Resource for managing health-related properties

#region Constants
const DEFAULT_MAX_HEALTH := 100.0
#endregion

#region Inner Classes
class MaxLevelResource extends PropertyResource:
	func _init() -> void:
		setup(
			"max",
			PropertyNode.Type.VALUE,
			"Maximum health level",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			var node = entity.get_property_value("health.capacity.max")
			return node.get_value() if node else DEFAULT_MAX_HEALTH
	
	func create_setter(entity: Node) -> Callable:
		return func(value): 
			var node = entity.get_property_value("health.capacity.max")
			if node:
				var result = node.set_value(value)
				if result.is_ok():
					# Ensure current health doesn't exceed new max
					var current_node = entity.get_property_value("health.capacity.current")
					if current_node and current_node.get_value() > value:
						current_node.set_value(value)

class CurrentLevelResource extends PropertyResource:
	func _init() -> void:
		setup(
			"current",
			PropertyNode.Type.VALUE,
			"Current health level",
			{},
			Property.Type.FLOAT
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			var node = entity.get_property_value("health.capacity.current")
			return node.get_value() if node else DEFAULT_MAX_HEALTH
	
	func create_setter(entity: Node) -> Callable:
		return func(value): 
			var node = entity.get_property_value("health.capacity.current")
			if node:
				var max_node = entity.get_property_value("health.capacity.max")
				var max_health = max_node.get_value() if max_node else DEFAULT_MAX_HEALTH
				value = min(value, max_health)  # Clamp to max health
				node.set_value(value)

class PercentageResource extends PropertyResource:
	func _init() -> void:
		setup(
			"percentage",
			PropertyNode.Type.VALUE,
			"Current health level as a percentage of max health",
			{},
			Property.Type.FLOAT,
			["health.capacity.current", "health.capacity.max"]
		)
	
	func create_getter(entity: Node) -> Callable:
		return func(): 
			var current_node = entity.get_property_value("health.capacity.current")
			var max_node = entity.get_property_value("health.capacity.max")
			
			var current = current_node.get_value() if current_node else 0.0
			var max_health = max_node.get_value() if max_node else DEFAULT_MAX_HEALTH
			
			return (current / max_health) * 100.0 if max_health > 0 else 0.0
#endregion

func _init() -> void:
	setup(
		"health",
		PropertyNode.Type.CONTAINER,
		"Health management",
		{
			"capacity": create_capacity_config()
		}
	)

func create_capacity_config() -> PropertyResource:
	return PropertyResource.create_container(
		"capacity",
		"Health capacity information",
		{
			"max": MaxLevelResource.new(),
			"current": CurrentLevelResource.new(),
			"percentage": PercentageResource.new()
		}
	)

#region Initialization Methods
## Initialize default values for the health property tree
func initialize_default_values(root_node: PropertyNode) -> void:
	var max_node = root_node.find_node_by_string("health.capacity.max")
	var current_node = root_node.find_node_by_string("health.capacity.current")
	
	if max_node:
		max_node.initialize_value(DEFAULT_MAX_HEALTH)
	if current_node:
		current_node.initialize_value(DEFAULT_MAX_HEALTH)
#endregion
