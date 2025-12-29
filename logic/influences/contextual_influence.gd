class_name ContextualInfluence
extends Influence

## Condition that modifies the strength of this influence
@export var strength_condition: Logic
## Factor to multiply strength by when condition is true
@export var strength_factor: float = 2.0

## Condition that modifies the direction of this influence
@export var direction_condition: Logic
## Angle to rotate direction by when condition is true (in radians)
@export var direction_angle: float = PI/2  # 90 degrees

## Condition that completely negates this influence
@export var negation_condition: Logic

## Get influence value with contextual modifications
func get_value(entity: Node) -> Vector2:
	# Check negation condition first
	if is_instance_valid(negation_condition) and negation_condition.get_value(entity):
		return Vector2.ZERO

	# Get base influence value
	var value = super.get_value(entity)

	# Apply strength modification if condition is met
	if is_instance_valid(strength_condition) and strength_condition.get_value(entity):
		value *= strength_factor

	# Apply direction modification if condition is met
	if is_instance_valid(direction_condition) and direction_condition.get_value(entity):
		value = value.rotated(direction_angle)

	return value
