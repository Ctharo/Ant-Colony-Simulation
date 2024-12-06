## Create the vision property tree
class_name Vision
extends PropertyNode

## Initialize the vision property tree
func _init(entity: Node) -> void:
	# Initialize base node
	super._init(
		Path.new("vision"),
		Type.CONTAINER,
		entity,
		"Vision management"
	)

	# Create and add base container
	var base_container := PropertyNode.new(
		Path.new("vision.base"),
		Type.CONTAINER,
		entity,
		"Base vision parameters"
	)
	add_child(base_container)

	# Add vision range value
	var vision_range := PropertyValue.new(
		Path.new("vision.base.range"),
		entity,
		Property.Type.FLOAT,
		func(): return entity.vision_range,
		func(value): entity.vision_range = value,
		[],
		"Maximum distance at which entity can detect objects"
	)
	base_container.add_child(vision_range)

	# Create and add objects container
	var food_container := PropertyNode.new(
		Path.new("vision.food"),
		Type.CONTAINER,
		entity,
		"Information about visible food objects"
	)
	add_child(food_container)

	# Add visible food list
	var visible_food := PropertyValue.new(
		Path.new("vision.food.list"),
		entity,
		Property.Type.ARRAY,
		func(): return Foods.in_range(entity.global_position, entity.vision_range),
		Callable(),
		["vision.base.range", "proprioception.base.position"],
		"List of food items within vision range"
	)
	food_container.add_child(visible_food)
