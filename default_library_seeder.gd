class_name DefaultLibrarySeeder
extends RefCounted
## Generates the default behavior library (Logic conditions, AntActions,
## AntRules, AntProfiles, Pheromones) in code and saves it into
## user://behavior/ on first run. This replaces the built-in .tres files that
## used to ship under res://, making every resource user-editable through the
## runtime UI and freeing the project tree to be reorganized without breaking
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

const SEED_VERSION := 3

const MANIFEST_PATH := "user://behavior/seed_manifest.cfg"

const LOGIC_DIR := "user://behavior/expressions"
const ACTION_DIR := "user://behavior/actions"
const RULE_DIR := "user://behavior/rules"
const PROFILE_DIR := "user://behavior/profiles"
const PHEROMONE_DIR := "user://behavior/pheromones"

## Influence profiles are NOT migrated yet — they still live under res:// and
## have their own discovery dirs (see AntDesignerPanel). The default worker
## references them only if they exist, so a reorganized project degrades to a
## plain wanderer instead of failing to seed.
const WORKER_INFLUENCE_PATHS: Array[String] = [
	"res://resources/influences/profiles/look_for_food.tres",
	"res://resources/influences/profiles/go_home.tres",
]


## Entry point. Idempotent; cheap when nothing needs seeding.
static func seed() -> void:
	for dir: String in [LOGIC_DIR, ACTION_DIR, RULE_DIR, PROFILE_DIR, PHEROMONE_DIR]:
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

	# Pheromone emit conditions (cataloged Logic, so they pass through the
	# editor/save/parse gates and can be reused by rules and influences).
	_seed_logic(manifest, ctx, "carrying food",
		"is_carrying_food",
		"Ant is carrying food", [])

	_seed_logic(manifest, ctx, "not carrying food",
		"not is_carrying_food",
		"Ant is not carrying food", [])

	# NOTE: the old res:// danger pheromone used `enemy_count_in_view`, which
	# is not in the AntSenses vocabulary — this is the corrected identifier.
	_seed_logic(manifest, ctx, "enemies in view",
		"enemies_in_view_count > 0",
		"At least one foreign-colony ant is visible", [])

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

	# ---- Pheromones -------------------------------------------------------
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

	# ---- Profiles ---------------------------------------------------------
	_seed_worker_profile(manifest, ctx)

	# ---- One-time migrations ----------------------------------------------
	_migrate_profile_pheromone_refs(manifest, ctx)

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


## Pheromone defaults. Emit conditions are cataloged Logic resources
## (referenced, not embedded), so they were saved leaves-first above and the
## .tres written here holds an ext_resource — never a forked subresource.
## condition_id may be "" for an always-emitting pheromone.
static func _seed_pheromone(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, decay: float, generating: float, radius: int,
		diffusion: float, start_color: Color, end_color: Color,
		condition_id: String) -> void:
	var id := p_name.to_snake_case()
	var path := PHEROMONE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "pheromone", id, path):
		return
	if _was_deleted(manifest, "pheromone", id):
		return

	var condition: Logic = null
	if not condition_id.is_empty():
		condition = ctx.get("logic/%s" % condition_id)
		if not condition:
			push_warning("Seeder: skipping pheromone '%s' — emit condition '%s' unavailable (deleted by user?)" % [id, condition_id])
			return

	var pheromone := Pheromone.new()
	pheromone.name = p_name
	pheromone.decay_rate = decay
	pheromone.generating_rate = generating
	pheromone.heat_radius = radius
	pheromone.diffusion_rate = diffusion
	pheromone.start_color = start_color
	pheromone.end_color = end_color
	pheromone.condition = condition

	_save_and_record(manifest, ctx, "pheromone", id, path, pheromone)


## Default "Worker" role so the profile catalog is never empty and colony
## creation always has a spawnable ant type.
static func _seed_worker_profile(manifest: ConfigFile, ctx: Dictionary) -> void:
	var id := "worker"
	var path := PROFILE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "profile", id, path):
		return
	if _was_deleted(manifest, "profile", id):
		return

	var profile := AntProfile.new()
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

	# Empty rules = the ant falls back to Ant.DEFAULT_RULE_IDS.
	profile.behavior_rules = []

	# Pheromones now come from the seeded catalog (leaves-first: they were
	# saved above, so these are ext_resource references).
	var pheromones: Array[Pheromone] = []
	for pid: String in ["food", "home"]:
		var ph: Pheromone = ctx.get("pheromone/%s" % pid)
		if ph:
			pheromones.append(ph)
	profile.pheromones = pheromones

	var influences: Array[InfluenceProfile] = []
	for i_path: String in WORKER_INFLUENCE_PATHS:
		if ResourceLoader.exists(i_path):
			influences.append(load(i_path))
	profile.movement_influences = influences

	_save_and_record(manifest, ctx, "profile", id, path, profile)
#endregion


#region One-time migrations
## Existing installs seeded at v2 have profiles whose pheromones point at the
## old res://entities/pheromone/resources .tres files. Swap those references
## to the freshly seeded user:// pheromones (matched by name) so the res://
## copies become deletable. Runs once; the manifest remembers.
##
## This is a pointer migration, not a content change — the user's profile
## keeps every stat and rule exactly as authored. A res:// reference whose
## name has no seeded counterpart (or whose counterpart the user deleted) is
## left alone.
static func _migrate_profile_pheromone_refs(manifest: ConfigFile, ctx: Dictionary) -> void:
	if manifest.get_value("meta", "pheromones_migrated", false):
		return

	var by_name := {}
	for key: String in ctx:
		if key.begins_with("pheromone/"):
			var ph: Pheromone = ctx[key]
			by_name[ph.name] = ph

	var dir := DirAccess.open(PROFILE_DIR)
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.get_extension() == "tres":
				_migrate_one_profile(PROFILE_DIR.path_join(fname), by_name)
			fname = dir.get_next()
		dir.list_dir_end()

	manifest.set_value("meta", "pheromones_migrated", true)


static func _migrate_one_profile(path: String, by_name: Dictionary) -> void:
	var profile: AntProfile = ResourceLoader.load(path) as AntProfile
	if not profile:
		return

	var changed := false
	var swapped: Array[Pheromone] = []
	for ph: Pheromone in profile.pheromones:
		if ph and ph.resource_path.begins_with("res://") and by_name.has(ph.name):
			swapped.append(by_name[ph.name])
			changed = true
		else:
			swapped.append(ph)

	if changed:
		profile.pheromones = swapped
		var err := ResourceSaver.save(profile, path)
		if err != OK:
			push_error("Seeder: pheromone-ref migration failed for %s (%s)" % [
				path, error_string(err)])
		else:
			print("Seeder: migrated pheromone references in %s" % path)
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
