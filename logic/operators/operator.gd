#class_name Operator
#extends RefCounted
#
### Create a compound condition config using AND operator
### @param conditions Array of condition configs to combine
### @return Dictionary representing the AND condition
#static func and_condition(conditions: Array) -> Dictionary:
	#return {
		#"type": "Operator",
		#"operator_type": "and",
		#"operands": conditions
	#}
#
### Create a compound condition config using OR operator
### @param conditions Array of condition configs to combine
### @return Dictionary representing the OR condition
#static func or_condition(conditions: Array) -> Dictionary:
	#return {
		#"type": "Operator",
		#"operator_type": "or",
		#"operands": conditions
	#}
#
### Create a NOT condition config
### @param condition The condition config to negate
### @return Dictionary representing the NOT condition
#static func not_condition(condition: Dictionary) -> Dictionary:
	#return {
		#"type": "Operator",
		#"operator_type": "not",
		#"operands": [condition]
	#}
