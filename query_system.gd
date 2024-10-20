class_name QuerySystem

enum FilterOperator {
	EQUALS,
	NOT_EQUALS,
	LESS_THAN,
	LESS_THAN_OR_EQUAL,
	GREATER_THAN,
	GREATER_THAN_OR_EQUAL,
	CONTAINS,
	NOT_CONTAINS
}

class Filter:
	var property: String
	var operator: FilterOperator
	var value: Variant

	func _init(p_property: String, p_operator: FilterOperator, p_value: Variant):
		property = p_property
		operator = p_operator
		value = p_value

class Query:
	var object_type: String
	var filters: Array[Filter]
	var cross_filters: Array[String]
	var selector: String
	var limit: int = -1  # -1 means no limit

	func _init(p_object_type: String):
		object_type = p_object_type
		filters = []
		cross_filters = []
		selector = ""

	func where(property: String, operator: FilterOperator, value: Variant) -> Query:
		filters.append(Filter.new(property, operator, value))
		return self

	func and_where(property: String, operator: FilterOperator, value: Variant) -> Query:
		return where(property, operator, value)

	func cross_match(other_query: String) -> Query:
		cross_filters.append(other_query)
		return self

	func select(selector_type: String, count: int = -1) -> Query:
		selector = selector_type
		limit = count
		return self

	func execute(simulation_state) -> Variant:
		var result = simulation_state.query(self)
		
		if limit > 0 and result is Array:
			result = result.slice(0, limit)
		
		match selector:
			"nearest":
				return simulation_state.get_nearest(result, limit)
			"furthest":
				return simulation_state.get_furthest(result, limit)
			"random":
				return simulation_state.get_random(result, limit)
			"count":
				return result.size()
			_:
				return result

static func create_query(object_type: String) -> Query:
	return Query.new(object_type)
