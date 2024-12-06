class_name PropertyExpression
extends LogicExpression

## Path to the property to access
@export var property_path: String

func _init() -> void:
	name = "Property Value"
	description = "Returns the value of a property"

func _evaluate() -> Variant:
	if current_context and use_current_item:
		if current_context.is_node_context:
			# If it's a Node, use get_property_value
			return current_context.current_item.get_property_value(property_path)
		else:
			# If it's a primitive type (like Vector2), return it directly
			return current_context.current_item
	else:
		# Use the entity as before
		return entity.get_property_value(property_path)
