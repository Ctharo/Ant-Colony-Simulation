extends Node

class_name BehaviorConfig

enum ComparisonOperator {
	EQUAL,
	NOT_EQUAL,
	GREATER_THAN,
	LESS_THAN,
	GREATER_THAN_OR_EQUAL,
	LESS_THAN_OR_EQUAL
}

static var property_options = [
	"food.in_view",
	"food.in_reach",
	"energy.current",
	"energy.max",
	"carry_mass.current",
	"carry_mass.max",
	"home.in_reach",
	"home.in_view",
	"sight_range",
	"pheromone_sense_range"
]

static var action_options = [
	"move_to_nearest_food",
	"harvest_nearest_food",
	"return_home",
	"store_food"
]

static func get_operator_string(op: ComparisonOperator) -> String:
	return ComparisonOperator.keys()[op]

static func get_operator_from_string(op_string: String) -> ComparisonOperator:
	return ComparisonOperator[op_string]
