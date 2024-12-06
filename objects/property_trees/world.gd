class_name World
extends PropertyNode

## Create the proprioception property tree
func _init(entity: Node) -> void:
	# Initialize base node
	super._init(
		Path.new("world"),
		Type.CONTAINER,
		entity,
		"World management"
	)

	# Create and add base container
	var food_container := PropertyNode.new(
		Path.new("world.food"),
		Type.CONTAINER,
		entity,
		"Food information"
	)
	add_child(food_container)

	# Add base position value
	var food_list := PropertyValue.new(
		Path.new("world.food.list"),
		entity,
		Property.Type.ARRAY,
		func(): return Foods.all(),
		Callable(),
		[],
		"Global list of all foods"
	)
	food_container.add_child(food_list)
