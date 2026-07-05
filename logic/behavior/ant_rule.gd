class_name AntRule
extends Resource
## A single behavior rule: when [member condition] evaluates true for an ant,
## execute [member action]. Rules are evaluated in descending [member priority]
## order by BehaviorManager; the first rule that fires wins that tick
## (mirroring the early-return structure of the old hardcoded decision tree).

#region Properties
## Display name, used to generate ID
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

## Condition gating this rule. A null condition means "always true"
## (useful for lowest-priority fallback rules).
@export var condition: Logic

## Action executed when the condition passes
@export var action: AntAction

## Higher priority rules are checked first
@export var priority: int = 0

## Disabled rules are skipped entirely (togglable from UI at runtime)
@export var enabled: bool = true

## Description of the rule's intent (for UI tooltips)
@export var description: String

var id: String
#endregion
