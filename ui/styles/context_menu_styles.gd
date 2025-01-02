class_name ContextMenuStyles
extends RefCounted

#region Enums and Constants
## Defines different types of actions and their visual styles
enum ActionType {
	DEFAULT,
	DESTRUCTIVE,
	POSITIVE,
	INFO,
	WARNING
}

## Color configurations for different action types
const ACTION_COLORS: Dictionary = {
	ActionType.DEFAULT: {
		"normal": Color(0.2, 0.2, 0.2, 0.8),
		"hover": Color(0.3, 0.3, 0.3, 0.9)
	},
	ActionType.DESTRUCTIVE: {
		"normal": Color(0.5, 0.1, 0.1, 0.8),
		"hover": Color(0.6, 0.15, 0.15, 0.9)
	},
	ActionType.POSITIVE: {
		"normal": Color(0.1, 0.4, 0.1, 0.8),
		"hover": Color(0.15, 0.5, 0.15, 0.9)
	},
	ActionType.INFO: {
		"normal": Color(0.1, 0.3, 0.5, 0.8),
		"hover": Color(0.15, 0.4, 0.6, 0.9)
	},
	ActionType.WARNING: {
		"normal": Color(0.5, 0.4, 0.1, 0.8),
		"hover": Color(0.6, 0.5, 0.15, 0.9)
	}
}

## Menu geometry constants
const INNER_RADIUS: float = 60.0
const OUTER_RADIUS: float = 90.0
const SEGMENTS: int = 32  # Number of segments for smooth arcs
#endregion

## Returns the appropriate colors for a given action type
static func get_colors(action_type: ActionType) -> Dictionary:
	return ACTION_COLORS[action_type]

## Returns the geometry parameters for arc creation based on button index and total buttons
static func get_arc_parameters(index: int, total: int) -> Dictionary:
	var angle_per_button := TAU / total
	var start_angle := index * angle_per_button - PI/2  # Start from top
	var end_angle := start_angle + angle_per_button

	return {
		"inner_radius": INNER_RADIUS,
		"outer_radius": OUTER_RADIUS,
		"start_angle": start_angle,
		"end_angle": end_angle,
		"segments": SEGMENTS
	}
