class_name AntAction
extends Resource
## Data-driven action definition. Binds a whitelisted Ant method to
## optional Logic-evaluated parameters so behavior can be authored in
## resource files (and eventually in the UI) instead of code.
##
## Security note: [member method] must appear in [constant Ant.ACTION_API].
## BehaviorManager refuses anything else, so arbitrary method names typed
## into a runtime UI cannot reach unintended code paths.

#region Properties
## Display name, used to generate ID (mirrors Logic naming convention)
@export var name: String:
	set(value):
		name = value
		id = name.to_snake_case()

## Name of the Ant method to call. Must be whitelisted in Ant.ACTION_API.
@export var method: String

## Optional parameters. Each Logic is evaluated against the acting ant and
## the results are passed positionally to [member method] via callv().
## Example: a "move to" action with a single Vector2-typed Logic param.
@export var params: Array[Logic] = []

## Description of what this action does (for UI tooltips)
@export var description: String

var id: String
#endregion
