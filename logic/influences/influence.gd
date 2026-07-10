class_name Influence
extends Logic
## A steering vector: a Logic expression whose value is a Vector2 direction
## (with magnitude acting as weight), plus a debug color and an optional gate
## condition. InfluenceManager sums the vectors of all valid influences in
## the active InfluenceProfile to drive default movement.
##
## Cataloged by ResourceLibrary (KIND_INFLUENCE) under
## user://behavior/influences. Being a Logic subclass, an Influence passes
## through the same validator gates as any expression, with one extra
## constraint enforced at save: type must be TYPE_VECTOR2.
##
## NOTE: ContextualInfluence is retired. Its strength/direction/negation
## modifiers are all expressible directly in the expression string now
## (e.g. `pheromone_direction("food") * 2.5 * float(not is_carrying_food)`),
## and its get_value() override bypassed EvaluationSystem — no caching, no
## eval policies, no validation at parse. Delete contextual_influence.gd
## once nothing references it.

#region Properties
## Debug visualization color (arrow drawn by InfluenceManager).
@export var color: Color

## Optional gate: the influence only contributes while this is true.
## Evaluated through EvaluationSystem, so eval policies apply — give slow
## conditions a TIMER mode instead of gating in the expression itself.
@export var condition: Logic
#endregion


func _init() -> void:
	resource_name = "Influence"
	# An influence IS a direction expression; the save gate enforces this.
	type = TYPE_VECTOR2
	# Set default color if none provided
	if not color:
		color = Color(randf(), randf(), randf())


## Returns true if no condition or if condition evaluates to true.
func is_valid(entity: Node2D) -> bool:
	if not condition:
		return true
	return EvaluationSystem.get_value(condition, entity)
