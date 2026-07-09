class_name DefaultLibrarySeeder
extends RefCounted
## Generates the default behavior library (Logic conditions, AntActions,
## AntRules, AntProfiles) in code and saves it into user://behavior/ on first
## run. This replaces the built-in .tres files that used to ship under
## res://resources, making every resource user-editable through the runtime
## UI and freeing the project tree to be reorganized without breaking
## resource references.
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
## Called by ResourceLibrary._ready() before the first rescan(), so the
## catalog always includes freshly seeded defaults.

const SEED_VERSION := 2

const MANIFEST_PATH := "user://behavior/seed_manifest.cfg"

const LOGIC_DIR := "user://behavior/expressions"
const ACTION_DIR := "user://behavior/actions"
const RULE_DIR := "user://behavior/rules"
const PROFILE_DIR := "user://behavior/profiles"

## Pheromones and influence profiles are NOT migrated yet — they still live
## under res:// and have their own discovery dirs (see AntDesignerPanel).
## The default worker references them only if they exist, so a reorganized
## project degrades to a plain wanderer instead of failing to seed.
const WORKER_PHEROMONE_PATHS: Array[String] = [
	"res://entities/pheromone/resources/food_pheromone.tres",
	"res://entities/pheromone/resources/home_pheromone.tres",
]
const WORKER_INFLUENCE_PATHS: Array[String] = [
	"res://resources/influences/profiles/look_for_food.tres",
	"res://resources/influences/profiles/go_home.tres",
]


## Entry point. Idempotent; cheap when nothing needs seeding.
static func seed() -> void:
	for dir: String in [LOGIC_DIR, ACTION_DIR, RULE_DIR, PROFILE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)

	var manifest := ConfigFile.new()
	manifest.load(MANIFEST_PATH)  # missing file is fine — starts empty

	# Resources available for referencing this run (existing or just created),
	# keyed "<kind>/<id>". A dependency deliberately deleted by the user makes
	# every parent that needs it unseedable — recorded and skipped, not
	# resurrected.
	var ctx: Dictionary = {}

	# ---- Tier 1 Logic (leaves first) -------------------------------------
	_seed_logic(manifest, ctx, "should rest",
		"health_level < 0.9 * HEALTH_MAX or energy_level < 0.9 * ENERGY_MAX",
		"Health or energy below 90% of max", [])

	_seed_logic(manifest, ctx, "should rest at colony",
		"is_colony_in_range() and should_rest",
		"Inside colony radius and health/energy below rest threshold",
		["should_rest"])

	_seed_logic(manifest, ctx, "should store food",
		"is_colony_in_range() and is_carrying_food",
		"Carrying food while inside colony radius", [])

	_seed_logic(manifest, ctx, "can harvest",
		"food_in_reach_count > 0 and not is_carrying_food",
		"Food within reach and mandibles free", [])

	# ---- Actions (thin whitelisted verbs) --------------------------------
	_seed_action(manifest, ctx, "harvest food", "harvest_food",
		"Pick up the nearest available food within reach")

	_seed_action(manifest, ctx, "store food", "store_food",
		"Deposit the carried food at the colony")

	_seed_action(manifest, ctx, "rest until full", "rest_until_full",
		"Rest at the colony until health and energy are full")

	# ---- Rules (condition + action + priority) ---------------------------
	_seed_rule(manifest, ctx, "harvest rule", "can_harvest", "harvest_food", 30,
		"Grab food when it is in reach and mandibles are free")

	_seed_rule(manifest, ctx, "store rule", "should_store_food", "store_food", 20,
		"Deposit carried food when inside colony radius")

	_seed_rule(manifest, ctx, "rest rule", "should_rest_at_colony", "rest_until_full", 10,
		"Rest when at colony with health or energy below 90%")

	# ---- Profiles ---------------------------------------------------------
	_seed_worker_profile(manifest, ctx)

	manifest.set_value("meta", "version", SEED_VERSION)
	manifest.save(MANIFEST_PATH)


#region Per-kind seeding
static func _seed_logic(manifest: ConfigFile, ctx: Dictionary, p_name: String,
		expression: String, description: String, nested_ids: Array) -> void:
	var id := p_name.to_snake_case()
	var path := LOGIC_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "logic", id, path):
		return
	if _was_deleted(manifest, "logic", id):
		return

	var nested: Array[Logic] = []
	for nid: String in nested_ids:
		var dep: Logic = ctx.get("logic/%s" % nid)
		if not dep:
			push_warning("Seeder: skipping logic '%s' — dependency '%s' unavailable (deleted by user?)" % [id, nid])
			return
		nested.append(dep)

	var logic := Logic.new()
	logic.name = p_name
	logic.expression_string = expression
	logic.description = description
	logic.type = TYPE_BOOL
	logic.nested_expressions = nested

	var errors := LogicValidator.validate_logic(logic)
	if not errors.is_empty():
		push_error("Seeder: default logic '%s' failed validation: %s" % [id, "; ".join(errors)])
		return

	_save_and_record(manifest, ctx, "logic", id, path, logic)


static func _seed_action(manifest: ConfigFile, ctx: Dictionary, p_name: String,
		method: String, description: String) -> void:
	var id := p_name.to_snake_case()
	var path := ACTION_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "action", id, path):
		return
	if _was_deleted(manifest, "action", id):
		return

	if method not in Ant.ACTION_API:
		push_error("Seeder: default action '%s' uses non-whitelisted method '%s'" % [id, method])
		return

	var action := AntAction.new()
	action.name = p_name
	action.method = method
	action.description = description

	_save_and_record(manifest, ctx, "action", id, path, action)


static func _seed_rule(manifest: ConfigFile, ctx: Dictionary, p_name: String,
		condition_id: String, action_id: String, priority: int,
		description: String) -> void:
	var id := p_name.to_snake_case()
	var path := RULE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "rule", id, path):
		return
	if _was_deleted(manifest, "rule", id):
		return

	var condition: Logic = ctx.get("logic/%s" % condition_id)
	var action: AntAction = ctx.get("action/%s" % action_id)
	if not condition or not action:
		push_warning("Seeder: skipping rule '%s' — missing %s (deleted by user?)" % [
			id, "condition" if not condition else "action"])
		return

	var rule := AntRule.new()
	rule.name = p_name
	rule.condition = condition
	rule.action = action
	rule.priority = priority
	rule.enabled = true
	rule.description = description

	_save_and_record(manifest, ctx, "rule", id, path, rule)


## Default "Worker" role so the profile catalog is never empty and colony
## creation always has a spawnable ant type. Combat fields are assigned via
## set() so this compiles against AntProfile with or without the combat
## extension (set() on a missing property is a silent no-op).
static func _seed_worker_profile(manifest: ConfigFile, ctx: Dictionary) -> void:
	var id := "worker"
	var path := PROFILE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "profile", id, path):
		return
	if _was_deleted(manifest, "profile", id):
		return

	var profile := AntProfile.new()
	profile.name = "Worker"
	profile.movement_rate = 25.0
	profile.vision_range = 100.0
	profile.size = 1.0
	profile.set("role_type", "worker")
	profile.set("max_health", 100.0)
	profile.set("is_combatant", false)
	profile.set("attack_damage", 0.0)
	profile.set("attack_cooldown", 0.8)

	# No spawn_condition: identifiers like ant_count_by_role are not part of
	# the AntSenses vocabulary, so such a condition would be rejected by the
	# validator. Null means "placed only as initial ants".
	profile.spawn_condition = null

	# Empty rules = the ant falls back to Ant.DEFAULT_RULE_IDS.
	profile.behavior_rules = []

	var pheromones: Array[Pheromone] = []
	for p_path: String in WORKER_PHEROMONE_PATHS:
		if ResourceLoader.exists(p_path):
			pheromones.append(load(p_path))
	profile.pheromones = pheromones

	var influences: Array[InfluenceProfile] = []
	for i_path: String in WORKER_INFLUENCE_PATHS:
		if ResourceLoader.exists(i_path):
			influences.append(load(i_path))
	profile.movement_influences = influences

	_save_and_record(manifest, ctx, "profile", id, path, profile)
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
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Seeder: failed to save %s '%s' (%s)" % [kind, id, error_string(err)])
		return
	# Claim the on-disk path so anything saved later references this file as
	# an ext_resource instead of embedding a duplicate subresource.
	res.take_over_path(path)
	ctx["%s/%s" % [kind, id]] = res
	manifest.set_value(kind, id, SEED_VERSION)
#endregion
