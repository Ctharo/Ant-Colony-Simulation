@tool
class_name Pheromone
extends Resource

@export var name: String

## Rate at which it decays
@export var decay_rate: float :
	set(value):
		decay_rate = value
		generating_rate = decay_rate * GENERATING_DECAY_QUOTIENT
		emit_changed()
		
## Rate at which it is generated
@export var generating_rate: float :
	set(value):
		generating_rate = value
		decay_rate = generating_rate / GENERATING_DECAY_QUOTIENT
		emit_changed()

const GENERATING_DECAY_QUOTIENT: float = 100 # Places 100x quicker than it decays
