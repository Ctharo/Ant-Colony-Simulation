class_name LogicState
extends RefCounted

## Immutable reference back to the asset
var logic: Logic

## Entity this state belongs to
var entity: Node

## Cached value (if this logic type supports caching)
var cached_value: Variant

## Incremented whenever this logic's VALUE changes
var version: int = 0

## Child versions from the last successful evaluation.
## child_logic_id -> version
var dependency_versions: Dictionary = {}

## Last calculated value. Used to determine whether the version should increment.
var has_value := false

## Expression parser (only Expression/Condition/Decision use this)
var expression: Expression

## True once parsed
var is_parsed := false

## Statistics
var evaluations := 0
var cache_hits := 0
var total_time_us := 0.0
var last_time_us := 0.0


func _init(p_logic: Logic, p_entity: Node):
	logic = p_logic
	entity = p_entity

	if logic is ExpressionLogic \
	or logic is ConditionLogic \
	or logic is DecisionLogic:
		expression = Expression.new()

func cache(value: Variant):
	if !has_value or cached_value != value:
		version += 1

	cached_value = value
	has_value = true

func dependency_changed(child: Logic, version: int) -> bool:
	return dependency_versions.get(child.id, -1) != version

func remember_dependency(child: Logic, child_version: int):
	dependency_versions[child.id] = child_version
