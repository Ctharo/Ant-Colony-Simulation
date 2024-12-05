class_name Proprioception
extends PropertyNode

## Create the proprioception property tree
func _init(entity: Node) -> void:
	# Initialize base node
	super._init(
		Path.new("proprioception"),
		Type.CONTAINER,
		entity,
		"Proprioception management"
	)

	# Create and add base container
	var base_container := PropertyNode.new(
		Path.new("proprioception.base"),
		Type.CONTAINER,
		entity,
		"Base position information"
	)
	add_child(base_container)

	# Add base position value
	var base_position := PropertyValue.new(
		Path.new("proprioception.base.position"),
		entity,
		Property.Type.VECTOR2,
		func(): return entity.global_position,
		Callable(),
		[],
		"Current global position of the entity"
	)
	base_container.add_child(base_position)

	# Add target position value
	var target_position := PropertyValue.new(
		Path.new("proprioception.base.target_position"),
		entity,
		Property.Type.VECTOR2,
		func(): return entity.target_position,
		func(value): entity.target_position = value,
		[],
		"Current target position for movement"
	)
	base_container.add_child(target_position)

	# Create and add colony container
	var colony_container := PropertyNode.new(
		Path.new("proprioception.colony"),
		Type.CONTAINER,
		entity,
		"Information about position relative to colony"
	)
	add_child(colony_container)

	# Add colony position value
	var colony_position := PropertyValue.new(
		Path.new("proprioception.colony.position"),
		entity,
		Property.Type.VECTOR2,
		func(): return entity.colony.global_position,
		Callable(),
		[],
		"Global position of the colony"
	)
	colony_container.add_child(colony_position)

	# Add colony direction value
	var colony_direction := PropertyValue.new(
		Path.new("proprioception.colony.direction"),
		entity,
		Property.Type.VECTOR2,
		func():
			var pos = entity.get_property_value("proprioception.base.position")
			var colony_pos = entity.get_property_value("proprioception.colony.position")
			return pos.direction_to(colony_pos) if colony_pos else Vector2.ZERO,
		Callable(),
		["proprioception.base.position", "proprioception.colony.position"],
		"Normalized vector pointing towards colony"
	)
	colony_container.add_child(colony_direction)

	# Add colony distance value
	var colony_distance := PropertyValue.new(
		Path.new("proprioception.colony.distance"),
		entity,
		Property.Type.FLOAT,
		func():
			var pos = entity.get_property_value("proprioception.base.position")
			var colony_pos = entity.get_property_value("proprioception.colony.position")
			return pos.distance_to(colony_pos) if colony_pos else 0.0,
		Callable(),
		["proprioception.base.position", "proprioception.colony.position"],
		"Distance from entity to colony in units"
	)
	colony_container.add_child(colony_distance)
