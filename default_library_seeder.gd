class_name DefaultLibrarySeeder
extends RefCounted
## Generates the default behavior library (Logic conditions, AntActions,
## BehaviorChannels, AntBehaviors, BehaviorProfiles, AntProfiles, Pheromones,
## Influences) in code and saves it into user://behavior/ on first run. This
## replaces the built-in .tres files that used to ship under res://, making
## every resource user-editable through the runtime UI and freeing the
## project tree to be reorganized without breaking resource references.
##
## Seeding policy (all three matter):
##   1. NEVER overwrite an existing user file — user edits are sacred.
##   2. Deletions stick: a manifest records every id ever seeded, so a
##      default the user deleted is not resurrected on next launch.
##   3. New defaults added in later versions of this script are seeded on
##      upgrade (bump SEED_VERSION and add the definition; ids already in
##      the manifest are untouched).
##
## Save-order rule: leaves before parents. A parent saved while its nested
## Logic has no resource_path would embed a duplicate subresource instead of
## an ext_resource reference, silently forking the child. Every resource is
## therefore saved and take_over_path()'d before anything references it.
##
## v8 (Batch E2): rules and influence profiles are RETIRED — their tiers,
## helpers, directories, and manifest sections are gone, replaced by the
## channel/behavior/behavior-profile model. Influence expressions are
## normalized to pure directions; magnitudes moved into per-behavior
## InfluenceEntry weights. Pheromone emission is seeded as signaling-channel
## behaviors calling emit_pheromone. NOTE: v8 assumes DEV_WIPE_ON_LAUNCH or
## a fresh install — on a preserved install, never-clobber adoption keeps
## old baked-magnitude influence files and entry weights would double-apply.
##
## Called by ResourceLibrary._ready() before the first rescan(), so the
## catalog always includes freshly seeded defaults.

const SEED_VERSION: int = 8

const MANIFEST_PATH: String = "user://behavior/seed_manifest.cfg"

const LOGIC_DIR: String = "user://behavior/expressions"
const ACTION_DIR: String = "user://behavior/actions"
const PROFILE_DIR: String = "user://behavior/profiles"
const PHEROMONE_DIR: String = "user://behavior/pheromones"
const INFLUENCE_DIR: String = "user://behavior/influences"
const COLONY_DIR: String = "user://behavior/colonies"
const CHANNEL_DIR: String = "user://behavior/channels"
const BEHAVIOR_DIR: String = "user://behavior/behaviors"
const BEHAVIOR_PROFILE_DIR: String = "user://behavior/behavior_profiles"
## Retired kinds (E2): kept ONLY so the purge below can clear leftovers.
## ResourceLibrary drops its matching KIND_* constants in E3.
const RETIRED_RULE_DIR: String = "user://behavior/rules"
const RETIRED_INFLUENCE_PROFILE_DIR: String = "user://behavior/influence_profiles"
## Prototype graph library (pre-BBGraphLibrary). Lived at user:// root, so
## the behavior-directory wipe never touched it; removed on sight.
const RETIRED_PROTOTYPE_LIBRARY: String = "user://behavior_conditions.json"
## DEV ONLY: wipe user://behavior on every launch so the seeder's output is
## always fresh while the defaults are still churning. NOTE: while true,
## this defeats seeding policies 1 and 2 above — user edits and deletions do
## NOT survive a restart. Set false before real users touch the library.
const DEV_WIPE_ON_LAUNCH: bool = true


static func clear_directory(path: String) -> Error:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return DirAccess.get_open_error()

	dir.list_dir_begin()

	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break

		if name == "." or name == "..":
			continue

		var full_path: String = path.path_join(name)

		if dir.current_is_dir():
			var err: Error = clear_directory(full_path)
			if err != OK:
				return err

			err = DirAccess.remove_absolute(full_path)
			if err != OK:
				return err
		else:
			var err: Error = DirAccess.remove_absolute(full_path)
			if err != OK:
				return err

	dir.list_dir_end()

	return OK


## Entry point. Idempotent; cheap when nothing needs seeding.
static func seed() -> void:
	for dir: String in [LOGIC_DIR, ACTION_DIR, PROFILE_DIR, PHEROMONE_DIR,
			INFLUENCE_DIR, COLONY_DIR, CHANNEL_DIR, BEHAVIOR_DIR,
			BEHAVIOR_PROFILE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)
		if DEV_WIPE_ON_LAUNCH:
			var _err_wipe: Error = clear_directory(dir)

	if DEV_WIPE_ON_LAUNCH:
		# A dev wipe must simulate a TRUE first run. The manifest lives at
		# user://behavior/ root and survives the subdirectory wipe; if it is
		# left in place, _was_deleted() reads every wiped file as a
		# deliberate user deletion and silently skips ALL seeding — empty
		# catalog, null colony profile at spawn. Manifest goes with the files.
		var _err_manifest: Error = DirAccess.remove_absolute(MANIFEST_PATH)

	# Retired data (graph-editor integration): the prototype JSON library
	# predates the BBVocabulary clean break and fails validation anyway.
	# Not gated on DEV_WIPE — it is dead data on every install.
	if FileAccess.file_exists(RETIRED_PROTOTYPE_LIBRARY):
		var err_retired: Error = DirAccess.remove_absolute(RETIRED_PROTOTYPE_LIBRARY)
		if err_retired != OK:
			DebugLogger.warn(DebugLogger.Category.DATA,
				"Seeder: could not remove retired prototype library %s (%s)" % [
					RETIRED_PROTOTYPE_LIBRARY, error_string(err_retired)])
		else:
			DebugLogger.info(DebugLogger.Category.DATA,
				"Seeder: removed retired prototype library %s" % RETIRED_PROTOTYPE_LIBRARY)

	var manifest: ConfigFile = ConfigFile.new()
	var _err_load: Error = manifest.load(MANIFEST_PATH)  # missing file is fine — starts empty

	# Retired kinds (E2 clean break): rules and influence profiles are
	# replaced by behaviors / behavior profiles. Directory contents AND
	# their manifest sections go TOGETHER — like the retired prototype
	# library, NOT gated on DEV_WIPE: once the dev flag goes false, a stale
	# section would make _was_deleted() lie about kinds that no longer
	# exist (the wiped-manifest lesson, inverted).
	var _err_rules: Error = clear_directory(RETIRED_RULE_DIR)
	var _err_iprofiles: Error = clear_directory(RETIRED_INFLUENCE_PROFILE_DIR)
	if manifest.has_section("rule"):
		manifest.erase_section("rule")
	if manifest.has_section("influence_profile"):
		manifest.erase_section("influence_profile")

	# Resources available for referencing this run (existing or just created),
	# keyed "<kind>/<id>". A dependency deliberately deleted by the user makes
	# every parent that needs it unseedable — recorded and skipped, not
	# resurrected.
	var ctx: Dictionary = {}

	# ---- Tier 1a: Property leaves (typed direct sense reads) --------------
	# One PropertyLogic per atomic sense used by the boolean defaults, each
	# with its own eval policy. Where a leaf's id mirrors the sense name
	# (health_level, food_in_reach_count, …), the nested binding shadows the
	# raw sense inside parents — LogicState._detect_purity() knows this, so
	# the composites below still count as pure.
	_seed_property(manifest, ctx, "carrying food", "is_carrying_food",
		TYPE_BOOL, "Ant is carrying food")

	_seed_property(manifest, ctx, "at colony", "is_colony_in_range",
		TYPE_BOOL, "Home colony overlaps the reach area",
		Logic.EvalMode.TIMER, 250)

	_seed_property(manifest, ctx, "colony in sight", "is_colony_in_sight",
		TYPE_BOOL, "Home colony overlaps the sight area",
		Logic.EvalMode.TIMER, 250)

	_seed_property(manifest, ctx, "health level", "health_level",
		TYPE_FLOAT, "Current health, 0..max",
		Logic.EvalMode.TIMER, 500)

	_seed_property(manifest, ctx, "max health", "HEALTH_MAX",
		TYPE_FLOAT, "Maximum health (per-ant constant)",
		Logic.EvalMode.STICKY)

	_seed_property(manifest, ctx, "energy level", "energy_level",
		TYPE_FLOAT, "Current energy, 0..max",
		Logic.EvalMode.TIMER, 500)

	_seed_property(manifest, ctx, "max energy", "ENERGY_MAX",
		TYPE_FLOAT, "Maximum energy (per-ant constant)",
		Logic.EvalMode.STICKY)

	_seed_property(manifest, ctx, "food in reach count", "food_in_reach_count",
		TYPE_INT, "Available food items inside the reach area")

	_seed_property(manifest, ctx, "food in view count", "food_in_view_count",
		TYPE_INT, "Available food items inside the sight area",
		Logic.EvalMode.TIMER, 250)

	_seed_property(manifest, ctx, "enemies in view count", "enemies_in_view_count",
		TYPE_INT, "Foreign-colony ants inside the sight area",
		Logic.EvalMode.TIMER, 250)

	# ---- Tier 1b: Condition composites (pure over their leaves) -----------
	# Every world read above is a leaf, so these are pure composites:
	# EvaluationSystem re-executes them ONLY when a nested version changed.
	# FRAME is fine as their policy — the dependency gate does the real work.
	# NOTE (E2): "always" was referenced by the queen pheromone but had no
	# seed definition — the queen silently skipped as "dependency
	# unavailable". Seeded here (STICKY: a constant never re-evaluates).
	_seed_condition(manifest, ctx, "always",
		"true",
		"Constant true — for always-on gates",
		[], Logic.EvalMode.STICKY)

	_seed_condition(manifest, ctx, "not carrying food",
		"not carrying_food",
		"Ant is not carrying food",
		["carrying_food"])

	_seed_condition(manifest, ctx, "should rest",
		"health_level < 0.9 * max_health or energy_level < 0.9 * max_energy",
		"Health or energy below 90% of max",
		["health_level", "max_health", "energy_level", "max_energy"])

	_seed_condition(manifest, ctx, "should rest at colony",
		"at_colony and should_rest",
		"Inside colony radius and health/energy below rest threshold",
		["at_colony", "should_rest"])

	_seed_condition(manifest, ctx, "should store food",
		"at_colony and carrying_food",
		"Carrying food while inside colony radius",
		["at_colony", "carrying_food"])

	_seed_condition(manifest, ctx, "can harvest",
		"food_in_reach_count > 0 and not carrying_food",
		"Food within reach and mandibles free",
		["food_in_reach_count", "carrying_food"])

	_seed_condition(manifest, ctx, "enemies in view",
		"enemies_in_view_count > 0",
		"At least one foreign-colony ant is visible",
		["enemies_in_view_count"])

	_seed_condition(manifest, ctx, "sees food",
		"food_in_view_count > 0",
		"At least one food item is visible",
		["food_in_view_count"])

	_seed_condition(manifest, ctx, "should retreat",
		"(should_rest or enemies_in_view) and not sees_food",
		"Hurt, tired, or threatened, with no food in sight",
		["should_rest", "enemies_in_view", "sees_food"])

	# ---- Tier 1c: Impure conditions (string-arg senses stay direct) -------
	# pheromone_concentration takes an argument, so it can't be a
	# PropertyLogic leaf; these read the world directly and therefore re-run
	# whenever their TIMER expires (never version-gated — correctly so).
	_seed_condition(manifest, ctx, "senses food pheromone",
		"pheromone_concentration(\"food\") > 0.0",
		"Standing in a nonzero food-pheromone gradient", [],
		Logic.EvalMode.TIMER, 250)

	_seed_condition(manifest, ctx, "senses home pheromone",
		"pheromone_concentration(\"home\") > 0.0",
		"Standing in a nonzero home-pheromone gradient", [],
		Logic.EvalMode.TIMER, 250)

	# ---- Typed values (action parameters) ----------------------------------
	_seed_string_value(manifest, ctx, "food pheromone name", "food",
		"Constant: the food pheromone's heatmap key")

	_seed_string_value(manifest, ctx, "home pheromone name", "home",
		"Constant: the home pheromone's heatmap key")

	_seed_string_value(manifest, ctx, "danger pheromone name", "danger",
		"Constant: the danger pheromone's heatmap key")

	# ---- Actions (thin whitelisted verbs) ----------------------------------
	_seed_action(manifest, ctx, "harvest food", "harvest_food",
		"Pick up the nearest available food within reach")

	_seed_action(manifest, ctx, "store food", "store_food",
		"Deposit the carried food at the colony")

	_seed_action(manifest, ctx, "rest until full", "rest_until_full",
		"Rest at the colony until health and energy are full")

	_seed_param_action(manifest, ctx, "emit food pheromone", "emit_pheromone",
		["food_pheromone_name"], "Deposit food-trail heat this tick")

	_seed_param_action(manifest, ctx, "emit home pheromone", "emit_pheromone",
		["home_pheromone_name"], "Deposit home-trail heat this tick")

	_seed_param_action(manifest, ctx, "emit danger pheromone", "emit_pheromone",
		["danger_pheromone_name"], "Deposit danger heat this tick")

	# ---- Pheromones ---------------------------------------------------------
	# Emit conditions remain on the resources for reference/UI, but the
	# runtime emission path (signaling behaviors -> emit_pheromone) bypasses
	# them by design — the behavior trigger owns the decision.
	_seed_pheromone(manifest, ctx, "food", 0.25, 20.0, 4, 1.0,
		Color(0.0196078, 0.0156863, 1.0, 0.101961),
		Color(0.0, 0.0, 0.852083, 0.2),
		"carrying_food")

	_seed_pheromone(manifest, ctx, "home", 0.02, 5.0, 2, 1.0,
		Color(0.603612, 1.0, 0.573065, 0.0745098),
		Color(0.0, 0.560784, 0.0, 0.258824),
		"not_carrying_food")

	_seed_pheromone(manifest, ctx, "danger", 0.15, 15.0, 3, 1.0,
		Color(1.0, 0.15, 0.05, 0.12),
		Color(0.6, 0.0, 0.0, 0.28),
		"enemies_in_view")

	_seed_pheromone(manifest, ctx, "queen", 0.15, 15.0, 3, 1.0,
		Color.BURLYWOOD,
		Color.BROWN,
		"always")

	# ---- Influences (steering vectors, all whitelisted vocabulary) ---------
	# v8: expressions are PURE DIRECTIONS — the old baked magnitudes
	# (* 1.5 … * 3.0) moved into per-behavior InfluenceEntry weights below.
	_seed_influence(manifest, ctx, "forward influence",
		"Vector2(1, 0).rotated(global_rotation)",
		Color(0.745532, 0.0971564, 0.444001, 1.0), "",
		"Keep moving the way the ant is facing")

	_seed_influence(manifest, ctx, "random influence",
		"Vector2(1, 0).rotated(global_rotation + randf_range(-PI, PI))",
		Color(0.498039, 0.603922, 0.870588, 1.0), "",
		"Wander jitter")

	_seed_influence(manifest, ctx, "food influence",
		"(nearest_food_in_view_position - global_position).normalized()",
		Color(0.9, 0.75, 0.1, 1.0), "sees_food",
		"Steer toward the nearest visible food (gated on seeing any)")

	_seed_influence(manifest, ctx, "food pheromone influence",
		"pheromone_direction(\"food\").normalized()",
		Color(0.0, 0.0, 0.831373, 1.0), "senses_food_pheromone",
		"Follow the food-pheromone gradient")

	_seed_influence(manifest, ctx, "home pheromone influence",
		"pheromone_direction(\"home\").normalized()",
		Color(0.0, 0.0, 1.0, 1.0), "senses_home_pheromone",
		"Follow the home-pheromone gradient")

	_seed_influence(manifest, ctx, "colony in sight influence",
		"(colony_position - global_position).normalized()",
		Color(0.1, 0.8, 0.3, 1.0), "colony_in_sight",
		"Steer straight to the colony once it is visible")

	# ---- Channels (arbitration lanes) --------------------------------------
	_seed_channel(manifest, ctx, "movement",
		BehaviorChannel.Arbitration.EXCLUSIVE,
		"Steering authority: the winning behavior's influence entries drive movement")

	_seed_channel(manifest, ctx, "interaction",
		BehaviorChannel.Arbitration.EXCLUSIVE,
		"Physical manipulation (harvest, store, rest) — one at a time")

	_seed_channel(manifest, ctx, "signaling",
		BehaviorChannel.Arbitration.CONCURRENT,
		"Pheromone emission and other signals; every triggered behavior runs")

	_seed_channel(manifest, ctx, "background",
		BehaviorChannel.Arbitration.CONCURRENT,
		"Passive concurrent effects")

	# ---- Behaviors (trigger + channel + actions + weighted influences) -----
	_seed_behavior(manifest, ctx, "store food", "interaction",
		"should_store_food", "", ["store_food"], [],
		"Deposit carried food when inside colony radius")

	_seed_behavior(manifest, ctx, "harvest food", "interaction",
		"can_harvest", "", ["harvest_food"], [],
		"Grab food when it is in reach and mandibles are free")

	_seed_behavior(manifest, ctx, "rest", "interaction",
		"should_rest_at_colony", "", ["rest_until_full"], [],
		"Rest at the colony until health and energy are full")

	_seed_behavior(manifest, ctx, "return home", "movement",
		"carrying_food", "", [],
		[
			{ "id": "colony_in_sight_influence", "weight": 3.0 },
			{ "id": "home_pheromone_influence", "weight": 2.5 },
			{ "id": "forward_influence", "weight": 1.5 },
			{ "id": "random_influence", "weight": 1.0 },
		],
		"Head back to the colony while carrying food")

	_seed_behavior(manifest, ctx, "retreat home", "movement",
		"should_retreat", "at_colony", [],
		[
			{ "id": "colony_in_sight_influence", "weight": 3.0 },
			{ "id": "home_pheromone_influence", "weight": 2.5 },
			{ "id": "forward_influence", "weight": 1.5 },
			{ "id": "random_influence", "weight": 1.0 },
		],
		"Fall back to the colony when hurt, tired, or threatened; sticky until arrival")

	_seed_behavior(manifest, ctx, "look for food", "movement",
		"not_carrying_food", "", [],
		[
			{ "id": "food_influence", "weight": 2.0 },
			{ "id": "food_pheromone_influence", "weight": 2.5 },
			{ "id": "forward_influence", "weight": 1.5 },
			{ "id": "random_influence", "weight": 1.0 },
		],
		"Seek visible food and follow food-pheromone gradients")

	_seed_behavior(manifest, ctx, "wander", "movement",
		"", "", [],
		[
			{ "id": "forward_influence", "weight": 1.5 },
			{ "id": "random_influence", "weight": 1.0 },
		],
		"Null-trigger fallback: keep moving with jitter")

	_seed_behavior(manifest, ctx, "signal food trail", "signaling",
		"carrying_food", "", ["emit_food_pheromone"], [],
		"Lay food-trail pheromone while hauling")

	_seed_behavior(manifest, ctx, "signal home trail", "signaling",
		"not_carrying_food", "", ["emit_home_pheromone"], [],
		"Lay home-trail pheromone while unburdened")

	_seed_behavior(manifest, ctx, "signal danger", "signaling",
		"enemies_in_view", "", ["emit_danger_pheromone"], [],
		"Mark danger while an enemy is visible")

	# ---- Behavior profiles (the ant's full decision surface) ---------------
	# Priorities interleave freely across channels because channels arbitrate
	# independently: 100/90/80 compete only on interaction, 70/60/40/0 only
	# on movement; the signaling entries are concurrent (priority orders
	# execution, never suppresses). "return home" (70) outranking
	# "retreat home" (60) encodes "carrying food wins over retreating";
	# "and not sees_food" inside should_retreat encodes "retreat only when
	# no food is visible". Id "worker" deliberately mirrors the worker
	# AntProfile (different kind, different directory).
	_seed_behavior_profile(manifest, ctx, "worker",
		[
			{ "id": "store_food", "priority": 100 },
			{ "id": "harvest_food", "priority": 90 },
			{ "id": "rest", "priority": 80 },
			{ "id": "return_home", "priority": 70 },
			{ "id": "retreat_home", "priority": 60 },
			{ "id": "signal_danger", "priority": 55 },
			{ "id": "signal_food_trail", "priority": 50 },
			{ "id": "signal_home_trail", "priority": 45 },
			{ "id": "look_for_food", "priority": 40 },
			{ "id": "wander", "priority": 0 },
		],
		"Default worker: forage, haul, rest; retreat when hurt or threatened")

	# ---- Profiles -----------------------------------------------------------
	_seed_worker_profile(manifest, ctx)

	# ---- Colonies -----------------------------------------------------------
	_seed_standard_colony(manifest, ctx)

	manifest.set_value("meta", "version", SEED_VERSION)
	var _err_save: Error = manifest.save(MANIFEST_PATH)


#region Per-kind seeding
## PropertyLogic leaf: a typed direct read of ONE atomic sense
## (expression_string holds the AntSenses symbol name), skipping the
## Expression VM entirely. Leaves are where eval policies do their work —
## and what makes the composites above them pure (version-gateable).
static func _seed_property(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, sense: String, value_type: Variant.Type,
		description: String,
		mode: Logic.EvalMode = Logic.EvalMode.FRAME,
		interval_ms: int = 500) -> void:
	var logic: PropertyLogic = PropertyLogic.new()
	logic.expression_string = sense
	logic.type = value_type
	_finish_logic(manifest, ctx, logic, p_name, description, [],
		mode, interval_ms)


## ConditionLogic: a boolean expression (result coerced to bool) gating
## behaviors, pheromone emission, or influence entries. When every
## identifier is a nested id or pure built-in, it is a pure composite and
## gets dependency-version short-circuiting for free.
static func _seed_condition(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, expression: String, description: String,
		nested_ids: Array,
		mode: Logic.EvalMode = Logic.EvalMode.FRAME,
		interval_ms: int = 500) -> void:
	var logic: ConditionLogic = ConditionLogic.new()
	logic.expression_string = expression
	logic.type = TYPE_BOOL
	_finish_logic(manifest, ctx, logic, p_name, description, nested_ids,
		mode, interval_ms)


## A constant typed-string Logic (e.g. a pheromone name an emit action
## passes as a parameter). The literal is embedded in quotes so the
## Expression VM returns it verbatim; no identifiers, so the whitelist is
## trivially satisfied.
static func _seed_string_value(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, literal: String, description: String) -> void:
	var logic: ExpressionLogic = ExpressionLogic.new()
	logic.expression_string = "\"%s\"" % literal
	logic.type = TYPE_STRING
	_finish_logic(manifest, ctx, logic, p_name, description, [],
		Logic.EvalMode.STICKY, 500)


## Shared tail for all first-class Logic seeding: adopt/deleted checks,
## nested resolution (leaves-first), naming, eval policy, validation, save.
static func _finish_logic(manifest: ConfigFile, ctx: Dictionary, logic: Logic,
		p_name: String, description: String, nested_ids: Array,
		mode: Logic.EvalMode, interval_ms: int) -> void:
	var id: String = p_name.to_snake_case()
	var path: String = LOGIC_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "logic", id, path):
		return
	if _was_deleted(manifest, "logic", id):
		return

	var nested: Array[Logic] = []
	for nid: String in nested_ids:
		var dep: Logic = ctx.get("logic/%s" % nid)
		if not dep:
			DebugLogger.warn(DebugLogger.Category.DATA, "Seeder: skipping logic '%s' — dependency '%s' unavailable (deleted by user?)" % [id, nid])
			return
		nested.append(dep)

	logic.name = p_name
	logic.description = description
	logic.nested_expressions = nested
	logic.eval_mode = mode
	logic.eval_interval_ms = interval_ms

	var errors: Array = LogicValidator.validate_logic(logic)
	if not errors.is_empty():
		DebugLogger.error(DebugLogger.Category.DATA, "Seeder: default logic '%s' failed validation: %s" % [id, "; ".join(errors)])
		return

	_save_and_record(manifest, ctx, "logic", id, path, logic)


static func _seed_action(manifest: ConfigFile, ctx: Dictionary, p_name: String,
		method: String, description: String) -> void:
	var id: String = p_name.to_snake_case()
	var path: String = ACTION_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "action", id, path):
		return
	if _was_deleted(manifest, "action", id):
		return

	if method not in Ant.ACTION_API:
		DebugLogger.error(DebugLogger.Category.DATA, "Seeder: default action '%s' uses non-whitelisted method '%s'" % [id, method])
		return

	var action: AntAction = AntAction.new()
	action.name = p_name
	action.method = method
	action.description = description

	_save_and_record(manifest, ctx, "action", id, path, action)


## AntAction with Logic-evaluated parameters (the plain _seed_action stays
## for parameterless verbs). param_logic_ids resolve from ctx — leaves
## before parents as usual; a user-deleted param skips the action.
static func _seed_param_action(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, method: String, param_logic_ids: Array,
		description: String) -> void:
	var id: String = p_name.to_snake_case()
	var path: String = ACTION_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "action", id, path):
		return
	if _was_deleted(manifest, "action", id):
		return

	if method not in Ant.ACTION_API:
		DebugLogger.error(DebugLogger.Category.DATA,
			"Seeder: default action '%s' uses non-whitelisted method '%s'" % [id, method])
		return

	var params: Array[Logic] = []
	for pid: String in param_logic_ids:
		var param: Logic = ctx.get("logic/%s" % pid)
		if not param:
			DebugLogger.warn(DebugLogger.Category.DATA,
				"Seeder: skipping action '%s' — param '%s' unavailable (deleted by user?)" % [id, pid])
			return
		params.append(param)

	var action: AntAction = AntAction.new()
	action.name = p_name
	action.method = method
	action.params = params
	action.description = description

	_save_and_record(manifest, ctx, "action", id, path, action)


## Pheromone defaults. Emit conditions are cataloged Logic resources
## (referenced, not embedded). condition_id may be "" for an
## always-emitting pheromone.
static func _seed_pheromone(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, decay: float, generating: float, radius: int,
		diffusion: float, start_color: Color, end_color: Color,
		condition_id: String) -> void:
	var id: String = p_name.to_snake_case()
	var path: String = PHEROMONE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "pheromone", id, path):
		return
	if _was_deleted(manifest, "pheromone", id):
		return

	var condition: Logic = null
	if not condition_id.is_empty():
		condition = ctx.get("logic/%s" % condition_id)
		if not condition:
			DebugLogger.warn(DebugLogger.Category.DATA, "Seeder: skipping pheromone '%s' — emit condition '%s' unavailable (deleted by user?)" % [id, condition_id])
			return

	var pheromone: Pheromone = Pheromone.new()
	pheromone.name = p_name
	pheromone.decay_rate = decay
	pheromone.generating_rate = generating
	pheromone.heat_radius = radius
	pheromone.diffusion_rate = diffusion
	pheromone.start_color = start_color
	pheromone.end_color = end_color
	pheromone.condition = condition

	_save_and_record(manifest, ctx, "pheromone", id, path, pheromone)


## Influence defaults. Gate conditions are cataloged Logic (condition_id may
## be "" for an ungated influence). Validated like any Logic before save.
## v8: expressions are pure directions — weights live on InfluenceEntry.
static func _seed_influence(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, expression: String, color: Color,
		condition_id: String, description: String) -> void:
	var id: String = p_name.to_snake_case()
	var path: String = INFLUENCE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "influence", id, path):
		return
	if _was_deleted(manifest, "influence", id):
		return

	var condition: Logic = null
	if not condition_id.is_empty():
		condition = ctx.get("logic/%s" % condition_id)
		if not condition:
			DebugLogger.warn(DebugLogger.Category.DATA, "Seeder: skipping influence '%s' — gate condition '%s' unavailable (deleted by user?)" % [id, condition_id])
			return

	var influence: Influence = Influence.new()
	influence.name = p_name
	influence.expression_string = expression
	influence.description = description
	influence.color = color
	influence.condition = condition
	# _init already set type = TYPE_VECTOR2

	var errors: Array = LogicValidator.validate_logic(influence)
	if not errors.is_empty():
		DebugLogger.error(DebugLogger.Category.DATA, "Seeder: default influence '%s' failed validation: %s" % [id, "; ".join(errors)])
		return

	_save_and_record(manifest, ctx, "influence", id, path, influence)


## BehaviorChannel defaults: named arbitration lanes for behaviors.
static func _seed_channel(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, arbitration: BehaviorChannel.Arbitration,
		description: String) -> void:
	var id: String = p_name.to_snake_case()
	var path: String = CHANNEL_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "channel", id, path):
		return
	if _was_deleted(manifest, "channel", id):
		return

	var channel: BehaviorChannel = BehaviorChannel.new()
	channel.name = p_name
	channel.arbitration = arbitration
	channel.description = description

	_save_and_record(manifest, ctx, "channel", id, path, channel)


## AntBehavior defaults. trigger_id / release_id may be "" (null trigger =
## always eligible; null release = not sticky). influence_specs is an Array
## of Dictionaries: { "id": <influence id>, "weight": <float>,
## "gate": <logic id or absent> }. Entries are embedded wrappers; every
## resource they REFERENCE resolves from ctx (already saved — leaves before
## parents), and a user-deleted dependency makes the whole behavior
## unseedable: recorded and skipped, not resurrected.
static func _seed_behavior(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, channel_id: String, trigger_id: String,
		release_id: String, action_ids: Array, influence_specs: Array,
		description: String) -> void:
	var id: String = p_name.to_snake_case()
	var path: String = BEHAVIOR_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "behavior", id, path):
		return
	if _was_deleted(manifest, "behavior", id):
		return

	var channel: BehaviorChannel = ctx.get("channel/%s" % channel_id)
	if not channel:
		DebugLogger.warn(DebugLogger.Category.DATA,
			"Seeder: skipping behavior '%s' — channel '%s' unavailable (deleted by user?)" % [id, channel_id])
		return

	var trigger: Logic = null
	if not trigger_id.is_empty():
		trigger = ctx.get("logic/%s" % trigger_id)
		if not trigger:
			DebugLogger.warn(DebugLogger.Category.DATA,
				"Seeder: skipping behavior '%s' — trigger '%s' unavailable (deleted by user?)" % [id, trigger_id])
			return

	var release: Logic = null
	if not release_id.is_empty():
		release = ctx.get("logic/%s" % release_id)
		if not release:
			DebugLogger.warn(DebugLogger.Category.DATA,
				"Seeder: skipping behavior '%s' — release '%s' unavailable (deleted by user?)" % [id, release_id])
			return

	var actions: Array[AntAction] = []
	for aid: String in action_ids:
		var action: AntAction = ctx.get("action/%s" % aid)
		if not action:
			DebugLogger.warn(DebugLogger.Category.DATA,
				"Seeder: skipping behavior '%s' — action '%s' unavailable (deleted by user?)" % [id, aid])
			return
		actions.append(action)

	var entries: Array[InfluenceEntry] = []
	for spec: Dictionary in influence_specs:
		var influence_id: String = String(spec["id"])
		var influence: Influence = ctx.get("influence/%s" % influence_id)
		if not influence:
			DebugLogger.warn(DebugLogger.Category.DATA,
				"Seeder: skipping behavior '%s' — influence '%s' unavailable (deleted by user?)" % [id, influence_id])
			return
		var entry: InfluenceEntry = InfluenceEntry.new()
		entry.influence = influence
		entry.weight = float(spec.get("weight", 1.0))
		var gate_id: String = String(spec.get("gate", ""))
		if not gate_id.is_empty():
			var gate: Logic = ctx.get("logic/%s" % gate_id)
			if not gate:
				DebugLogger.warn(DebugLogger.Category.DATA,
					"Seeder: skipping behavior '%s' — gate '%s' unavailable (deleted by user?)" % [id, gate_id])
				return
			entry.gate = gate
		entries.append(entry)

	var behavior: AntBehavior = AntBehavior.new()
	behavior.name = p_name
	behavior.description = description
	behavior.trigger = trigger
	behavior.release = release
	behavior.channel = channel
	behavior.actions = actions
	behavior.influence_entries = entries

	_save_and_record(manifest, ctx, "behavior", id, path, behavior)


## BehaviorProfile defaults. entry_specs is an Array of Dictionaries:
## { "id": <behavior id>, "priority": <int>, "enabled": <bool, default
## true> }. A user-deleted behavior drops ITS entry only (the profile still
## seeds) — membership is composition, not a hard dependency.
static func _seed_behavior_profile(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, entry_specs: Array, description: String) -> void:
	var id: String = p_name.to_snake_case()
	var path: String = BEHAVIOR_PROFILE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "behavior_profile", id, path):
		return
	if _was_deleted(manifest, "behavior_profile", id):
		return

	var entries: Array[ProfileEntry] = []
	for spec: Dictionary in entry_specs:
		var behavior_id: String = String(spec["id"])
		var behavior: AntBehavior = ctx.get("behavior/%s" % behavior_id)
		if not behavior:
			DebugLogger.warn(DebugLogger.Category.DATA,
				"Seeder: behavior profile '%s' drops entry '%s' — behavior unavailable (deleted by user?)" % [id, behavior_id])
			continue
		var entry: ProfileEntry = ProfileEntry.new()
		entry.behavior = behavior
		entry.priority = int(spec.get("priority", 0))
		entry.enabled = bool(spec.get("enabled", true))
		entries.append(entry)

	var profile: BehaviorProfile = BehaviorProfile.new()
	profile.name = p_name
	profile.description = description
	profile.entries = entries

	_save_and_record(manifest, ctx, "behavior_profile", id, path, profile)


## Default "Worker" role so the profile catalog is never empty and colony
## creation always has a spawnable ant type.
static func _seed_worker_profile(manifest: ConfigFile, ctx: Dictionary) -> void:
	var id: String = "worker"
	var path: String = PROFILE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "profile", id, path):
		return
	if _was_deleted(manifest, "profile", id):
		return

	var profile: AntProfile = AntProfile.new()
	profile.name = "Worker"
	profile.role_type = "worker"
	profile.movement_rate = 25.0
	profile.vision_range = 100.0
	profile.size = 1.0
	profile.max_health = 100.0
	profile.is_combatant = false
	profile.attack_damage = 0.0
	profile.attack_cooldown = 0.8

	# No spawn_condition: identifiers like ant_count_by_role are not part of
	# the AntSenses vocabulary, so such a condition would be rejected by the
	# validator. Null means "placed only as initial ants".
	profile.spawn_condition = null

	# AntProfile.pheromones is deprecated (emission is behavior-authored;
	# heat layers register from the full catalog) — left empty on purpose.

	# The full decision surface: behaviors, priorities, channels.
	var worker_behavior: BehaviorProfile = ctx.get("behavior_profile/worker")
	if not worker_behavior:
		DebugLogger.warn(DebugLogger.Category.DATA,
			"Seeder: skipping profile 'worker' — behavior profile unavailable (deleted by user?)")
		return
	profile.behavior_profile = worker_behavior

	_save_and_record(manifest, ctx, "profile", id, path, profile)


## Default colony so colony creation never depends on a res:// .tres again
## (the old SettingsManager default pointed at
## res://entities/colony/resources/standard_colony_profile.tres, whose
## basic_worker chain dragged in every legacy res:// resource).
static func _seed_standard_colony(manifest: ConfigFile, ctx: Dictionary) -> void:
	var id: String = "standard_colony"
	var path: String = COLONY_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "colony", id, path):
		return
	if _was_deleted(manifest, "colony", id):
		return

	var worker: AntProfile = ctx.get("profile/worker")
	if not worker:
		DebugLogger.warn(DebugLogger.Category.DATA, "Seeder: skipping colony 'standard_colony' — worker profile unavailable (deleted by user?)")
		return

	var colony: ColonyProfile = ColonyProfile.new()
	colony.name = "Standard Colony"
	colony.radius = 60.0
	colony.max_ants = 25
	colony.spawn_rate = 10.0
	colony.dirt_color = Color(0.545098, 0.270588, 0.0745098, 0.8)
	colony.darker_dirt = Color(0.545098, 0.270588, 0.0745098, 0.9)
	colony.ant_profiles = [worker] as Array[AntProfile]
	colony.initial_ants = { "worker": 5 }

	_save_and_record(manifest, ctx, "colony", id, path, colony)
#endregion


#region Shared mechanics
## If a file with this id already exists (previously seeded, or user-authored
## under the same id), load it into ctx so later definitions can reference it,
## make sure the manifest knows about it, and report "handled".
static func _adopt_existing(manifest: ConfigFile, ctx: Dictionary,
		kind: String, id: String, path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var res: Resource = ResourceLoader.load(path)
	if res:
		ctx["%s/%s" % [kind, id]] = res
	if not manifest.has_section_key(kind, id):
		manifest.set_value(kind, id, SEED_VERSION)
	return true


## True when this id was seeded in the past but the file is gone — i.e. the
## user deleted it on purpose. Respect that.
static func _was_deleted(manifest: ConfigFile, kind: String, id: String) -> bool:
	return manifest.has_section_key(kind, id)


static func _save_and_record(manifest: ConfigFile, ctx: Dictionary,
		kind: String, id: String, path: String, res: Resource) -> void:
	_assert_leaves_first(kind, id, res)
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		DebugLogger.error(DebugLogger.Category.DATA, "Seeder: failed to save %s '%s' (%s)" % [kind, id, error_string(err)])
		return
	# Claim the on-disk path so anything saved later references this file as
	# an ext_resource instead of embedding a duplicate subresource.
	res.take_over_path(path)
	ctx["%s/%s" % [kind, id]] = res
	manifest.set_value(kind, id, SEED_VERSION)


## Save-order invariant (leaves before parents): every resource a parent is
## about to reference must already be on disk with its path claimed via
## take_over_path(), or ResourceSaver embeds a duplicate subresource —
## silently forking the child and bypassing the catalog's validation gates.
## Debug builds only; a violation stops at the assert with the parent and
## child named. Covers every kind the seeder writes, so a single call in
## _save_and_record() protects all current AND future seed definitions.
## Embedded wrappers (InfluenceEntry / ProfileEntry) are deliberately
## excluded from the path check — embedding them IS the design; only what
## they REFERENCE must be on disk.
static func _assert_leaves_first(kind: String, id: String, res: Resource) -> void:
	if not OS.is_debug_build():
		return
	var refs: Array = []
	match kind:
		"logic", "influence":
			refs.append_array(res.get("nested_expressions"))
			if kind == "influence":
				refs.append(res.get("condition"))
		"action":
			refs.append_array(res.get("params"))
		"pheromone":
			refs.append(res.get("condition"))
		"behavior":
			refs.append(res.get("trigger"))
			refs.append(res.get("release"))
			refs.append(res.get("channel"))
			refs.append_array(res.get("actions"))
			for entry: InfluenceEntry in res.get("influence_entries"):
				if entry == null:
					continue
				refs.append(entry.influence)
				refs.append(entry.gate)
				refs.append(entry.weight_expression)
		"behavior_profile":
			for entry: ProfileEntry in res.get("entries"):
				if entry == null:
					continue
				refs.append(entry.behavior)
		"profile":
			refs.append(res.get("spawn_condition"))
			refs.append_array(res.get("pheromones"))
			refs.append(res.get("behavior_profile"))
		"colony":
			refs.append_array(res.get("ant_profiles"))
	for child: Resource in refs:
		if child == null:
			continue
		assert(String(child.resource_path).begins_with("user://"),
			"Seeder save-order violation: %s '%s' references un-saved '%s' — leaves before parents!" % [
				kind, id, str(child.get("name"))])
#endregion
