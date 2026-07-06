class_name Logic
extends Resource

#region Properties
## Name of the logic expression, used to generate ID
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

## The actual expression to evaluate
@export_multiline var expression_string: String

## Nested logic expressions used within this expression
@export var nested_expressions: Array[Logic]

## Description of what this logic does
@export var description: String

## Expected return type of the expression
@export var type: Variant.Type = TYPE_FLOAT

#region Re-evaluation Policy
## How EvaluationSystem caches this expression's result per entity.
enum EvalMode {
	FRAME,   ## Default: cached for one frame (16 ms) — legacy behavior
	ALWAYS,  ## Never cached: recomputed on every get_value() call
	TIMER,   ## Cached for eval_interval_ms, then recomputed on next use
	EVENT,   ## Cached until one of retrigger_signals fires on the entity
	STICKY,  ## Computed once per entity; cached until invalidated
}

@export_group("Re-evaluation")
## Caching policy applied by EvaluationSystem.
@export var eval_mode: EvalMode = EvalMode.FRAME

## TIMER mode: minimum milliseconds between recomputes.
@export_range(16, 60000, 1, "suffix:ms") var eval_interval_ms: int = 500

## EVENT mode: entity signals that invalidate the cached value. Only names in
## EvaluationSystem.TRIGGER_SIGNAL_WHITELIST are honored (same safety idea as
## Ant.ACTION_API — UI-authored data can't hook arbitrary signals).
@export var retrigger_signals: PackedStringArray = []
@export_group("")
#endregion

## Unique identifier for this logic expression
var id: String

@warning_ignore("unused_signal")
signal action_triggered(value: Variant, expression_id: String)
#endregion

## Get value with evaluation system
func get_value(entity: Node) -> Variant:
	return EvaluationSystem.get_value(self, entity)
