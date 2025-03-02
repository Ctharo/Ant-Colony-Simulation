class_name InfluenceProfile
extends Resource

@export var name: String
## Conditions which define when this profile is valid
@export var enter_conditions: Array[Logic]
## Conditions which define when this profile should not be used
@export var exit_conditions: Array[Logic]
## Expression array to evaluate conditions
@export var influences: Array[Logic]
