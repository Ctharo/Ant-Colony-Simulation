class CollectFoodBehavior extends AntBehavior:
	func _init():
		name = "Collect Food"
		add_sub_behavior(WanderForFoodBehavior.new())
		add_sub_behavior(FollowPheromonesBehavior.new())
		add_sub_behavior(HarvestFoodBehavior.new())
		add_sub_behavior(ReturnHomeBehavior.new())
		add_sub_behavior(StoreFoodBehavior.new())

class WanderForFoodBehavior extends AntBehavior:
	func _init():
		name = "Wander for Food"
		conditions.append(NoFoodPheromoneNearbyCondition.new())
		actions.append(RandomMoveAction.new())

class FollowPheromonesBehavior extends AntBehavior:
	func _init():
		name = "Follow Pheromones"
		conditions.append(FoodPheromoneNearbyCondition.new())
		actions.append(FollowPheromoneAction.new())

class HarvestFoodBehavior extends AntBehavior:
	func _init():
		name = "Harvest Food"
		conditions.append(FoodInViewCondition.new())
		actions.append(MoveToFoodAction.new())
		actions.append(HarvestAction.new())

class ReturnHomeBehavior extends AntBehavior:
	func _init():
		name = "Return Home"
		conditions.append(CarryingFoodCondition.new())
		add_sub_behavior(FollowHomePheromonesBehavior.new())
		add_sub_behavior(WanderForHomeBehavior.new())

class StoreFoodBehavior extends AntBehavior:
	func _init():
		name = "Store Food"
		conditions.append(AtHomeCondition.new())
		conditions.append(CarryingFoodCondition.new())
		actions.append(StoreFoodAction.new())

