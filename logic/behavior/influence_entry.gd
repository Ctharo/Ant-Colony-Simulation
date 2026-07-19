class_name InfluenceEntry
extends Resource
## Weighted membership of an [Influence] inside an [AntBehavior]: a
## reference to a cataloged influence plus the weight and optional gate this
## PARTICULAR behavior applies to it. The wrapper is what lets one library
## influence be reused across behaviors at different strengths without
## editing the influence itself — and what makes weight visible/editable in
## the UI instead of buried in an expression string.
##
## PERSISTENCE: entries are DELIBERATELY embedded subresources of their
## owning behavior — membership data, never cataloged, no id. Their
## references (influence / gate / weight_expression) must be saved external
## resources: leaves before parents applies exactly as it does for graph
## conditions; only this wrapper shell embeds.
##
## WEIGHT PRECEDENCE: when [member weight_expression] is set it overrides
## [member weight]; a constant weight should never require minting a Logic
## resource, while dynamic weighting ("home weight scales with injury")
## stays fully expressible and goes through EvaluationSystem, so eval
## policies and caching apply as usual.
##
## GATE SEMANTICS: AND, not replace. The influence's own intrinsic
## condition (Influence.condition) still applies; [member gate] adds
## behavior-specific gating on top. Both must pass for the entry to
## contribute.

#region Properties
## The cataloged steering vector this entry contributes.
@export var influence: Influence

## Constant multiplier applied to the influence's direction vector.
## Ignored when [member weight_expression] is set.
@export var weight: float = 1.0

## Optional dynamic weight: a scalar Logic evaluated per ant, overriding
## [member weight] when set. Non-numeric results contribute 0.
@export var weight_expression: Logic

## Optional behavior-specific gate, ANDed with the influence's own
## condition. Null = no extra gating.
@export var gate: Logic
#endregion


## The multiplier in effect for this ant right now.
func effective_weight(entity: Node2D) -> float:
	if weight_expression:
		var value: Variant = EvaluationSystem.get_value(weight_expression, entity)
		if value is float:
			return value
		if value is int:
			return float(value)
		return 0.0
	return weight


## True when both the entry gate and the influence's own condition pass.
## A null influence is inert (data failure — surfaced by the save gate and
## the validator, not logged here per log-once doctrine).
func is_active(entity: Node2D) -> bool:
	if not influence:
		return false
	if gate:
		var gate_value: Variant = EvaluationSystem.get_value(gate, entity)
		if not gate_value:
			return false
	return influence.is_valid(entity)


## The influence's direction scaled by the effective weight. Callers are
## expected to have checked [method is_active] first; an invalid vector
## contributes zero rather than poisoning the sum.
func weighted_vector(entity: Node2D) -> Vector2:
	if not influence:
		return Vector2.ZERO
	var raw: Variant = EvaluationSystem.get_value(influence, entity)
	if not raw is Vector2:
		return Vector2.ZERO
	var direction: Vector2 = raw
	return direction * effective_weight(entity)
