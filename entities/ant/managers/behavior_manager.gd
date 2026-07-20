class_name BehaviorManager
extends Node
## Arbitrates a BehaviorProfile across channels each physics tick — the E2
## replacement for BOTH the AntRule first-match-wins loop that lived here
## and the InfluenceProfile selection that lived in InfluenceManager. One
## decision point: behaviors own their steering, so the action layer and
## the movement layer can never disagree.
##
## PER-TICK ALGORITHM (process_tick):
##  1. Hold maintenance: sticky claims on exclusive channels are dropped
##     when the holder left the profile, was disabled, or its release
##     condition fired.
##  2. One descending-priority walk of the profile entries:
##     - CONCURRENT channel + triggered → actions run. No claims, no
##       suppression.
##     - EXCLUSIVE channel: the first entry that is either triggered OR the
##       channel's current holder claims the channel; everything below it
##       on that channel is suppressed this tick. Descending order is what
##       implements preemption for free: a strictly higher-priority
##       triggered behavior reaches the channel first, claims it, and the
##       displaced holder's hold is CANCELLED (not suspended) — it must
##       re-trigger to run again. A holder reached with nothing above it
##       claimed keeps the channel even with its trigger false (sticky
##       hysteresis — see AntBehavior docs).
##  3. The movement channel's winner hands its influence entries to
##     InfluenceManager. No winner = EMPTY entries = deliberate idle (the
##     integrator returns zero; there is no forward-drift fallback in the
##     new model — standing still is now an authorable outcome).
##
## DOING_TASK INTERIM: while entity.doing_task is true (blocking task
## coroutines like rest_until_full), exclusive channels are suppressed
## entirely — no claims, empty movement entries, ant holds position —
## while CONCURRENT channels keep running (an ant can emit pheromones while
## resting). Holds still evaluate their releases so a sticky claim can
## expire during a task. This preserves the old "rule fired = ant does
## nothing else" freeze until the current_task state machine replaces the
## await-based tasks (see horizon notes); at that point this gate becomes a
## data-authored priority decision and this block shrinks to nothing.
##
## Conditions (trigger / release) are evaluated through EvaluationSystem —
## same pipeline as everything else, so per-condition eval policies control
## the real per-tick cost. The ACTION_API whitelist boundary is unchanged:
## _execute refuses any method not listed on Ant.
##
## Local per-ant disables are keyed by ProfileEntry (membership, not
## behavior identity — the same behavior at two priorities in two profiles
## is two entries). They subtract only for this ant and never mutate the
## shared resource.

signal behavior_fired(behavior: AntBehavior)
## Emitted when the movement channel's winner changes; null = no winner.
signal movement_behavior_changed(behavior: AntBehavior)
signal profile_changed

#region Properties
## The ant this manager acts on.
var entity: Ant

## The assigned decision surface (shared resource — never mutated here).
var profile: BehaviorProfile

## Descending-priority cache of the profile's entries. Rebuilt on
## set_profile() / resort(), never per tick.
var _entries: Array[ProfileEntry] = []

## Per-ant overrides. Keys are ProfileEntry, value true = locally disabled.
var _local_disabled: Dictionary = {}

## Sticky claims: channel id -> the ProfileEntry holding that exclusive
## channel. Only behaviors with a release condition are ever recorded.
var _holds: Dictionary = {}

## Last tick's movement winner (for change detection on the signal).
var _movement_winner: ProfileEntry = null

## Log-once keys for data failures surfaced during arbitration.
var _warned: Dictionary = {}

var logger: iLogger
#endregion


func _init() -> void:
	name = "behavior_manager"
	logger = iLogger.new(name, DebugLogger.Category.LOGIC)


func initialize(p_entity: Ant) -> void:
	if not p_entity:
		push_error("Cannot initialize BehaviorManager with null entity")
		return
	entity = p_entity


#region Profile management
## Assigns (or replaces) the profile. Local disables for entries that
## survive the swap are preserved; holds do not (a new decision surface
## starts clean).
func set_profile(p_profile: BehaviorProfile) -> void:
	profile = p_profile
	_holds.clear()
	_rebuild_entries()
	for entry: ProfileEntry in _local_disabled.keys().duplicate():
		if entry not in _entries:
			_local_disabled.erase(entry)
	profile_changed.emit()


## Public re-sort hook for runtime priority editing (E3 designer pane).
func resort() -> void:
	_rebuild_entries()
	profile_changed.emit()


func _rebuild_entries() -> void:
	if profile:
		_entries = profile.sorted_entries()
	else:
		_entries = []


func set_entry_enabled_local(entry: ProfileEntry, enabled: bool) -> void:
	if enabled:
		_local_disabled.erase(entry)
	else:
		_local_disabled[entry] = true


func is_entry_enabled_local(entry: ProfileEntry) -> bool:
	return not _local_disabled.get(entry, false)
#endregion


#region Arbitration
## The per-tick entry point (called from Ant._physics_process).
func process_tick() -> void:
	if not is_instance_valid(entity) or entity.is_dead:
		return

	_maintain_holds()

	var task_busy: bool = entity.doing_task
	var claimed: Dictionary = {}
	var movement: ProfileEntry = null

	for entry: ProfileEntry in _entries:
		if not _entry_live(entry):
			continue
		var behavior: AntBehavior = entry.behavior
		var channel: BehaviorChannel = behavior.channel
		if not channel:
			_warn_once("no_channel:%s" % behavior.id,
				"Behavior '%s' has no channel — skipped" % behavior.id)
			continue

		if channel.is_exclusive():
			if task_busy:
				continue
			var cid: String = channel.id
			if claimed.has(cid):
				continue
			var is_holder: bool = _holds.get(cid) == entry
			if not is_holder and not _is_triggered(behavior):
				continue
			claimed[cid] = entry
			# Preemption: a lower-priority holder displaced by this claim
			# loses its hold outright — cancelled, not suspended.
			var previous: ProfileEntry = _holds.get(cid)
			if previous != null and previous != entry:
				_holds.erase(cid)
			if behavior.is_sticky():
				_holds[cid] = entry
			if cid == BehaviorChannel.MOVEMENT_ID:
				movement = entry
			_run_actions(behavior)
		else:
			if _is_triggered(behavior):
				_run_actions(behavior)

	_publish_movement(movement)


## Drops holds whose entry left the profile, was disabled, or released.
func _maintain_holds() -> void:
	var stale: Array[String] = []
	for channel_id: String in _holds:
		var holder: ProfileEntry = _holds[channel_id]
		if holder == null or holder not in _entries or not _entry_live(holder):
			stale.append(channel_id)
			continue
		if _release_fired(holder.behavior):
			stale.append(channel_id)
	for channel_id: String in stale:
		_holds.erase(channel_id)


func _publish_movement(winner: ProfileEntry) -> void:
	if winner != _movement_winner:
		_movement_winner = winner
		var winning_behavior: AntBehavior = null
		if winner != null:
			winning_behavior = winner.behavior
		movement_behavior_changed.emit(winning_behavior)

	var movement_entries: Array[InfluenceEntry] = []
	if winner != null:
		movement_entries = winner.behavior.influence_entries
	entity.influence_manager.set_entries(movement_entries)


func _entry_live(entry: ProfileEntry) -> bool:
	return entry != null \
		and entry.enabled \
		and not _local_disabled.get(entry, false) \
		and entry.behavior != null


## Null trigger = always eligible (fallbacks like wander).
func _is_triggered(behavior: AntBehavior) -> bool:
	if not behavior.trigger:
		return true
	var result: Variant = EvaluationSystem.get_value(behavior.trigger, entity)
	return true if result else false


func _release_fired(behavior: AntBehavior) -> bool:
	if not behavior.release:
		return false
	var result: Variant = EvaluationSystem.get_value(behavior.release, entity)
	return true if result else false
#endregion


#region Action execution
## Runs a behavior's actions in order. behavior_fired is emitted once per
## behavior per tick when at least one action actually executed.
func _run_actions(behavior: AntBehavior) -> void:
	var any_executed: bool = false
	for action: AntAction in behavior.actions:
		if action == null:
			continue
		if _execute(action):
			any_executed = true
	if any_executed:
		behavior_fired.emit(behavior)


## Executes an action against the entity. Returns false if the action was
## rejected (not whitelisted / missing method) so a bad action doesn't
## masquerade as activity.
func _execute(action: AntAction) -> bool:
	if action.method.is_empty():
		logger.error("Action '%s' has no method set" % action.name)
		return false

	if action.method not in Ant.ACTION_API:
		logger.error("Action '%s' uses non-whitelisted method '%s'" % [
			action.name, action.method
		])
		return false

	if not entity.has_method(action.method):
		logger.error("Entity is missing action method '%s'" % action.method)
		return false

	var args: Array = []
	for param: Logic in action.params:
		args.append(EvaluationSystem.get_value(param, entity))

	entity.callv(action.method, args)
	return true
#endregion


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	logger.warn(message)
