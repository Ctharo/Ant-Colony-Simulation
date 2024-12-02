class_name ActionConfig
extends Resource

## The type/name of the base action (Move, Harvest, etc)
@export var base_action: String
## Parameters specific to this action configuration
@export var params: Dictionary
## Description of the action
@export_multiline var description: String
