class_name DefaultLibrarySeeder
extends RefCounted
## Generates the default behavior library (Logic conditions, AntActions,
## AntRules, AntProfiles, Pheromones, Influences, InfluenceProfiles) in code
## and saves it into user://behavior/ on first run. This replaces the
## built-in .tres files that used to ship under res://, making every
## resource user-editable through the runtime UI and freeing the project
## tree to be reorganized without breaking resource references.
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
## v4 (influence migration) notes — the seeded influences are REWRITES of
## the old res://resources/influences .tres files:
##   - get_pheromone_direction("x")  →  pheromone_direction("x")
##     (the deprecated node-era call; last blocker for deleting
##     AntSenses.DEPRECATED — run audit_expressions() after first launch)
##   - go_home's "die" enter condition calling suicide() is dropped: a
##     side-effecting action inside a condition is exactly what the
##     validator exists to reject.
##   - go_home's null exit_conditions becomes a real exit ("not carrying
##     food"), which the sticky selection in InfluenceManager now honors.
##
## v5 (colony migration) notes:
##   - ColonyProfiles are cataloged (KIND_COLONY) and a "Standard Colony"
##     default referencing the seeded worker replaces the res://
##     standard_colony_profile.tres → basic_worker.tres chain that kept the
##     legacy res:// resources load-bearing.
##   - The legacy runtime save (user://colony_profile.tres) is imported, and
##     res:// ant-profile references / initial_ants keys are renamed through
##     LEGACY_PROFILE_ALIASES (basic_worker → worker).
##
## Called by ResourceLibrary._ready() before the first rescan(), so the
## catalog always includes freshly seeded defaults.

const SEED_VERSION := 5

const MANIFEST_PATH := "user://behavior/seed_manifest.cfg"

const LOGIC_DIR := "user://behavior/expressions"
const ACTION_DIR := "user://behavior/actions"
const RULE_DIR := "user://behavior/rules"
const PROFILE_DIR := "user://behavior/profiles"
const PHEROMONE_DIR := "user://behavior/pheromones"
const INFLUENCE_DIR := "user://behavior/influences"
const INFLUENCE_PROFILE_DIR := "user://behavior/influence_profiles"
const COLONY_DIR := "user://behavior/colonies"

## Legacy ant-profile ids renamed by the seeder migrations. Colony profiles
## authored against the old res:// basic_worker map onto the seeded worker.
const LEGACY_PROFILE_ALIASES: Dictionary = {
	"basic_worker": "worker",
}

static func clear_directory(path: String) -> Error:
	var dir := DirAccess.open(path)
	if dir == null:
		return DirAccess.get_open_error()

	dir.list_dir_begin()

	while true:
		var name := dir.get_next()
		if name.is_empty():
			break

		if name == "." or name == "..":
			continue

		var full_path := path.path_join(name)

		if dir.current_is_dir():
			var err := clear_directory(full_path)
			if err != OK:
				return err

			err = DirAccess.remove_absolute(full_path)
			if err != OK:
				return err
		else:
			var err := DirAccess.remove_absolute(full_path)
			if err != OK:
				return err

	dir.list_dir_end()

	return OK

## Entry point. Idempotent; cheap when nothing needs seeding.
static func seed() -> void:
	for dir: String in [LOGIC_DIR, ACTION_DIR, RULE_DIR, PROFILE_DIR,
			PHEROMONE_DIR, INFLUENCE_DIR, INFLUENCE_PROFILE_DIR, COLONY_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)
		clear_directory(dir)

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

	_seed_logic(manifest, ctx, "enemies in view",
		"enemies_in_view_count > 0",
		"At least one foreign-colony ant is visible", [])

	# Influence gate conditions.
	_seed_logic(manifest, ctx, "sees food",
		"food_in_view_count > 0",
		"At least one food item is visible", [])

	_seed_logic(manifest, ctx, "senses food pheromone",
		"pheromone_concentration(\"food\") > 0.0",
		"Standing in a nonzero food-pheromone gradient", [])

	_seed_logic(manifest, ctx, "senses home pheromone",
		"pheromone_concentration(\"home\") > 0.0",
		"Standing in a nonzero home-pheromone gradient", [])

	_seed_logic(manifest, ctx, "colony in sight",
		"has_colony and global_position.distance_to(colony_position) < vision_range",
		"Own colony center is within vision range", [])

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

	# ---- Influences (steering vectors, all whitelisted vocabulary) --------
	_seed_influence(manifest, ctx, "forward influence",
		"Vector2(1, 0).rotated(global_rotation) * 1.5",
		Color(0.745532, 0.0971564, 0.444001, 1.0), "",
		"Keep moving the way the ant is facing")

	_seed_influence(manifest, ctx, "random influence",
		"Vector2(1, 0).rotated(global_rotation + randf_range(-PI, PI))",
		Color(0.498039, 0.603922, 0.870588, 1.0), "",
		"Wander jitter")

	_seed_influence(manifest, ctx, "food influence",
		"(nearest_food_in_view_position - global_position).normalized() * 2.0",
		Color(0.9, 0.75, 0.1, 1.0), "sees_food",
		"Steer toward the nearest visible food (gated on seeing any)")

	_seed_influence(manifest, ctx, "food pheromone influence",
		"pheromone_direction(\"food\").normalized() * 2.5",
		Color(0.0, 0.0, 0.831373, 1.0), "senses_food_pheromone",
		"Follow the food-pheromone gradient")

	_seed_influence(manifest, ctx, "home pheromone influence",
		"pheromone_direction(\"home\").normalized() * 2.5",
		Color(0.0, 0.0, 1.0, 1.0), "senses_home_pheromone",
		"Follow the home-pheromone gradient")

	_seed_influence(manifest, ctx, "colony in sight influence",
		"(colony_position - global_position).normalized() * 3.0",
		Color(0.1, 0.8, 0.3, 1.0), "colony_in_sight",
		"Steer straight to the colony once it is visible")

	# ---- Influence profiles (steering states) ------------------------------
	_seed_influence_profile(manifest, ctx, "wander",
		[], [],
		["forward_influence", "random_influence"],
		)

	_seed_influence_profile(manifest, ctx, "look for food",
		["not_carrying_food"], ["carrying_food"],
		["food_influence", "food_pheromone_influence",
		 "forward_influence", "random_influence"],
		)

	_seed_influence_profile(manifest, ctx, "go home",
		["carrying_food"], ["not_carrying_food"],
		["colony_in_sight_influence", "home_pheromone_influence",
		 "forward_influence", "random_influence"],
		)

	# ---- Profiles ---------------------------------------------------------
	_seed_worker_profile(manifest, ctx)

	# ---- Colonies ---------------------------------------------------------
	_seed_standard_colony(manifest, ctx)


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
## (referenced, not embedded). condition_id may be "" for an
## always-emitting pheromone.
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


## Influence defaults. Gate conditions are cataloged Logic (condition_id may
## be "" for an ungated influence). Validated like any Logic before save.
static func _seed_influence(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, expression: String, color: Color,
		condition_id: String, description: String) -> void:
	var id := p_name.to_snake_case()
	var path := INFLUENCE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "influence", id, path):
		return
	if _was_deleted(manifest, "influence", id):
		return

	var condition: Logic = null
	if not condition_id.is_empty():
		condition = ctx.get("logic/%s" % condition_id)
		if not condition:
			push_warning("Seeder: skipping influence '%s' — gate condition '%s' unavailable (deleted by user?)" % [id, condition_id])
			return

	var influence := Influence.new()
	influence.name = p_name
	influence.expression_string = expression
	influence.description = description
	influence.color = color
	influence.condition = condition
	# _init already set type = TYPE_VECTOR2

	var errors := LogicValidator.validate_logic(influence)
	if not errors.is_empty():
		push_error("Seeder: default influence '%s' failed validation: %s" % [id, "; ".join(errors)])
		return

	_save_and_record(manifest, ctx, "influence", id, path, influence)


## Influence-profile defaults. Everything referenced must already be in ctx
## (leaves-first). A missing dependency (user-deleted) skips the profile.
static func _seed_influence_profile(manifest: ConfigFile, ctx: Dictionary,
		p_name: String, enter_ids: Array, exit_ids: Array,
		influence_ids: Array) -> void:
	var id := p_name.to_snake_case()
	var path := INFLUENCE_PROFILE_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "influence_profile", id, path):
		return
	if _was_deleted(manifest, "influence_profile", id):
		return

	var enter: Array[Logic] = []
	for cid: String in enter_ids:
		var c: Logic = ctx.get("logic/%s" % cid)
		if not c:
			push_warning("Seeder: skipping influence profile '%s' — enter condition '%s' unavailable" % [id, cid])
			return
		enter.append(c)

	var exit: Array[Logic] = []
	for cid: String in exit_ids:
		var c: Logic = ctx.get("logic/%s" % cid)
		if not c:
			push_warning("Seeder: skipping influence profile '%s' — exit condition '%s' unavailable" % [id, cid])
			return
		exit.append(c)

	var influences: Array[Logic] = []
	for iid: String in influence_ids:
		var infl: Influence = ctx.get("influence/%s" % iid)
		if not infl:
			push_warning("Seeder: skipping influence profile '%s' — influence '%s' unavailable" % [id, iid])
			return
		influences.append(infl)

	var profile := InfluenceProfile.new()
	profile.name = p_name
	profile.enter_conditions = enter
	profile.exit_conditions = exit
	profile.influences = influences

	_save_and_record(manifest, ctx, "influence_profile", id, path, profile)


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

	# All composition now comes from the seeded catalog (leaves-first: these
	# were saved above, so the .tres holds ext_resource references).
	var pheromones: Array[Pheromone] = []
	for pid: String in ["food", "home"]:
		var ph: Pheromone = ctx.get("pheromone/%s" % pid)
		if ph:
			pheromones.append(ph)
	profile.pheromones = pheromones

	# Order matters: InfluenceManager picks the FIRST eligible profile, so
	# the always-eligible wander fallback goes last.
	var influences: Array[InfluenceProfile] = []
	for iid: String in ["look_for_food", "go_home", "wander"]:
		var ip: InfluenceProfile = ctx.get("influence_profile/%s" % iid)
		if ip:
			influences.append(ip)
	profile.movement_influences = influences

	_save_and_record(manifest, ctx, "profile", id, path, profile)
#endregion


## Default colony so colony creation never depends on a res:// .tres again
## (the old SettingsManager default pointed at
## res://entities/colony/resources/standard_colony_profile.tres, whose
## basic_worker chain dragged in every legacy res:// resource).
static func _seed_standard_colony(manifest: ConfigFile, ctx: Dictionary) -> void:
	var id := "standard_colony"
	var path := COLONY_DIR.path_join("%s.tres" % id)

	if _adopt_existing(manifest, ctx, "colony", id, path):
		return
	if _was_deleted(manifest, "colony", id):
		return

	var worker: AntProfile = ctx.get("profile/worker")
	if not worker:
		push_warning("Seeder: skipping colony 'standard_colony' — worker profile unavailable (deleted by user?)")
		return

	var colony := ColonyProfile.new()
	colony.name = "Standard Colony"
	colony.radius = 60.0
	colony.max_ants = 25
	colony.spawn_rate = 10.0
	colony.dirt_color = Color(0.545098, 0.270588, 0.0745098, 0.8)
	colony.darker_dirt = Color(0.545098, 0.270588, 0.0745098, 0.9)
	colony.ant_profiles = [worker] as Array[AntProfile]
	colony.initial_ants = { "worker": 5 }

	_save_and_record(manifest, ctx, "colony", id, path, colony)


#region One-time migrations
## Existing installs have profiles whose pheromones point at the old
## res://entities/pheromone/resources .tres files. Swap those references to
## the seeded user:// pheromones (matched by name). Runs once.
static func _migrate_profile_pheromone_refs(manifest: ConfigFile, ctx: Dictionary) -> void:
	if manifest.get_value("meta", "pheromones_migrated", false):
		return

	var by_name := {}
	for key: String in ctx:
		if key.begins_with("pheromone/"):
			var ph: Pheromone = ctx[key]
			by_name[ph.name] = ph

	_for_each_profile(func(profile: AntProfile, path: String) -> void:
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
			_resave_profile(profile, path, "pheromone")
	)

	manifest.set_value("meta", "pheromones_migrated", true)


## Same pointer migration for movement_influences: res:// InfluenceProfile
## references are swapped to the seeded user:// equivalents. Matching is by
## name, falling back to the file's basename because some legacy files
## (look_for_food.tres) never had their name property set.
static func _migrate_profile_influence_refs(manifest: ConfigFile, ctx: Dictionary) -> void:
	if manifest.get_value("meta", "influences_migrated", false):
		return

	var by_id := {}
	for key: String in ctx:
		if key.begins_with("influence_profile/"):
			var ip: InfluenceProfile = ctx[key]
			by_id[ip.id] = ip

	_for_each_profile(func(profile: AntProfile, path: String) -> void:
		var changed := false
		var swapped: Array[InfluenceProfile] = []
		for ip: InfluenceProfile in profile.movement_influences:
			if ip and ip.resource_path.begins_with("res://"):
				var key: String = ip.name.to_snake_case() if not ip.name.is_empty() \
					else ip.resource_path.get_file().get_basename().to_snake_case()
				if by_id.has(key):
					swapped.append(by_id[key])
					changed = true
					continue
			swapped.append(ip)
		if changed:
			profile.movement_influences = swapped
			_resave_profile(profile, path, "influence")
	)

	manifest.set_value("meta", "influences_migrated", true)


## Rescues colony profiles from the res:// era. Runs once:
##  1. Imports the legacy SettingsManager runtime save
##     (user://colony_profile.tres) into the colony catalog dir. User data
##     wins: if its id collides with a freshly seeded default, it overwrites.
##  2. For every colony .tres in the catalog dir: res:// AntProfile
##     references are swapped to cataloged profiles matched by id (with the
##     LEGACY_PROFILE_ALIASES rename map, so basic_worker → worker), and
##     initial_ants keys are renamed through the same aliases.
static func _migrate_colony_profiles(manifest: ConfigFile, ctx: Dictionary) -> void:
	if manifest.get_value("meta", "colonies_migrated", false):
		return

	# 1. Import the legacy runtime save, if any.
	const LEGACY_PATH := "user://colony_profile.tres"
	if FileAccess.file_exists(LEGACY_PATH):
		var legacy: ColonyProfile = ResourceLoader.load(LEGACY_PATH) as ColonyProfile
		if legacy:
			var lid: String = legacy.id if not legacy.id.is_empty() else "imported_colony"
			var dest := COLONY_DIR.path_join("%s.tres" % lid)
			var err := ResourceSaver.save(legacy, dest)
			if err == OK:
				legacy.take_over_path(dest)
				ctx["colony/%s" % lid] = legacy
				manifest.set_value("colony", lid, SEED_VERSION)
				print("Seeder: imported legacy colony profile -> %s" % dest)
			else:
				push_error("Seeder: failed to import legacy colony profile (%s)" % error_string(err))

	# 2. Fix references in every cataloged colony profile.
	var profiles_by_id := {}
	for key: String in ctx:
		if key.begins_with("profile/"):
			profiles_by_id[key.trim_prefix("profile/")] = ctx[key]

	var dir := DirAccess.open(COLONY_DIR)
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.get_extension() == "tres":
				_migrate_one_colony(COLONY_DIR.path_join(fname), profiles_by_id)
			fname = dir.get_next()
		dir.list_dir_end()

	manifest.set_value("meta", "colonies_migrated", true)


static func _migrate_one_colony(path: String, profiles_by_id: Dictionary) -> void:
	var colony: ColonyProfile = ResourceLoader.load(path) as ColonyProfile
	if not colony:
		return

	var changed := false

	# Swap res:// ant-profile references to cataloged ones (id + aliases).
	var swapped: Array[AntProfile] = []
	for ap: AntProfile in colony.ant_profiles:
		if ap and ap.resource_path.begins_with("res://"):
			var target_id: String = LEGACY_PROFILE_ALIASES.get(ap.id, ap.id)
			if profiles_by_id.has(target_id):
				swapped.append(profiles_by_id[target_id])
				changed = true
				continue
		swapped.append(ap)

	# Rename initial_ants keys through the same alias map.
	var renamed := {}
	for key: String in colony.initial_ants:
		var new_key: String = LEGACY_PROFILE_ALIASES.get(key, key)
		if new_key != key:
			changed = true
		renamed[new_key] = colony.initial_ants[key]

	if changed:
		colony.ant_profiles = swapped
		colony.initial_ants = renamed
		var err := ResourceSaver.save(colony, path)
		if err != OK:
			push_error("Seeder: colony migration failed for %s (%s)" % [path, error_string(err)])
		else:
			print("Seeder: migrated colony profile %s" % path)


static func _for_each_profile(fn: Callable) -> void:
	var dir := DirAccess.open(PROFILE_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.get_extension() == "tres":
			var path := PROFILE_DIR.path_join(fname)
			var profile: AntProfile = ResourceLoader.load(path) as AntProfile
			if profile:
				fn.call(profile, path)
		fname = dir.get_next()
	dir.list_dir_end()


static func _resave_profile(profile: AntProfile, path: String, what: String) -> void:
	var err := ResourceSaver.save(profile, path)
	if err != OK:
		push_error("Seeder: %s-ref migration failed for %s (%s)" % [
			what, path, error_string(err)])
	else:
		print("Seeder: migrated %s references in %s" % [what, path])
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
