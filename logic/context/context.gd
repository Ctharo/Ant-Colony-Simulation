class_name Context
extends RefCounted

## Defines how frequently different types of context information should be updated
enum UpdateFrequency {
	EVERY_TICK = 0,    # Update every frame (use sparingly!)
	FREQUENT = 1,      # Every 0.1 seconds
	NORMAL = 2,        # Every 0.5 seconds
	INFREQUENT = 3,    # Every 1.0 seconds
	RARE = 4           # Every 5.0 seconds
}

## Maps update frequencies to their time intervals
const UPDATE_INTERVALS = {
	UpdateFrequency.EVERY_TICK: 0.0,
	UpdateFrequency.FREQUENT: 0.1,
	UpdateFrequency.NORMAL: 0.5,
	UpdateFrequency.INFREQUENT: 1.0,
	UpdateFrequency.RARE: 5.0
}
