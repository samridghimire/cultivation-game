extends Node
## Owns the live game session: static data, the player, world flags and RNG.
##
## Player actions live here as thin wrappers: call a pure system in
## src/core/systems, post messages, advance time, emit EventBus signals.
## Keep rules out of this file; put them in the systems so they stay testable.

const BREAKTHROUGH_DAYS := 7

var data: GameData
var player: CharacterData
## Persistent world facts, e.g. {"villager_dead": true}.
var world_flags: Dictionary = {}
## Id of the region (data/regions.json) the player is in.
var current_region := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	data = GameData.load_from_dir()
	for err in data.load_errors:
		push_error("Data error: " + err)
	GameClock.days_advanced.connect(_on_days_advanced)


func has_session() -> bool:
	return player != null


func start_session(character: CharacterData) -> void:
	player = character
	world_flags = {}
	current_region = data.start_region
	GameClock.reset()
	EventBus.session_started.emit()
	EventBus.post("%s sets out on the path of cultivation." % player.name, "progress")
	EventBus.player_changed.emit()


func end_session() -> void:
	player = null
	world_flags = {}


# --- Actions -----------------------------------------------------------------

func cultivate(days: int, location_density: float = 1.0) -> void:
	if not _can_act():
		return
	if SpiritualRoots.cultivation_multiplier(player.spiritual_roots, data) <= 0.0:
		EventBus.post("Without a spiritual root, qi slips through you like water.", "warning")
		return
	if Cultivation.is_at_bottleneck(player, data):
		EventBus.post("You are at a bottleneck. More meditation will not help; attempt a breakthrough.", "warning")
		return
	var density := location_density * Exploration.qi_density(data, current_region) * Sects.cultivation_bonus(player, data)
	var result := Cultivation.cultivate(player, data, days, density)
	EventBus.post("You cultivate for %s and gather %d qi." % [Calendar.format_duration(days), int(result["qi_gained"])])
	if result["stages_gained"] > 0:
		EventBus.post("Your cultivation rises to %s!" % Cultivation.realm_label(player, data), "progress")
	if result["at_bottleneck"]:
		EventBus.post("You have reached a bottleneck. Attempt a breakthrough to advance.", "warning")
	_pass_time(days)


func attempt_breakthrough() -> void:
	if not _can_act():
		return
	if not Cultivation.can_attempt_breakthrough(player, data):
		EventBus.post("You are not ready to break through.", "warning")
		return
	var result := Cultivation.attempt_breakthrough(player, data, rng)
	if result["success"]:
		EventBus.post("Breakthrough! You have entered the %s realm." % result["realm_name"], "progress")
	else:
		EventBus.post("Your breakthrough to %s failed (%d%% chance). Your qi scatters." % [result["realm_name"], int(result["chance"] * 100)], "danger")
	EventBus.breakthrough_attempted.emit(result["success"], result["realm_name"])
	_pass_time(BREAKTHROUGH_DAYS)


func work_profession(prof_id: String, days: int) -> void:
	if not _can_act():
		return
	var result := Professions.work(player, data, prof_id, days)
	var def: ProfessionDef = data.professions[prof_id]
	EventBus.post("You work as a %s for %s: +%d xp, +%d spirit stones." % [def.name, Calendar.format_duration(days), int(result["xp"]), result["income"]])
	if result["ranks_gained"] > 0:
		EventBus.post("You are now a %s!" % Professions.rank_title(player, data, prof_id), "progress")
	if not player.is_rogue():
		var contribution := int(result["xp"] / (1.0 if Sects.is_favored_profession(player, data, prof_id) else 2.0))
		if Sects.add_contribution(player, data, contribution):
			EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")
	_pass_time(days)


func join_sect(sect_id: String) -> void:
	if not _can_act():
		return
	var result := Sects.join(player, data, sect_id)
	if result["ok"]:
		EventBus.post("You are accepted into the %s." % data.sects[sect_id].name, "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func leave_sect() -> void:
	if not _can_act():
		return
	var old_id := Sects.leave(player)
	if old_id != "":
		EventBus.post("You leave the %s and walk the path alone." % data.sects[old_id].name, "warning")
	EventBus.player_changed.emit()


func perform_deed(deed_id: String) -> void:
	if not _can_act():
		return
	var result := Deeds.perform(player, data, deed_id, world_flags)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	var deed: Dictionary = data.deeds[deed_id]
	EventBus.post("%s. (%s)" % [deed["name"], ", ".join(result["notes"])], "karma")
	_pass_time(result["days"])


func buy_item(item_id: String) -> void:
	if not _can_act():
		return
	var result := Items.buy(player, data, item_id)
	if result["ok"]:
		EventBus.post("You buy a %s." % data.items[item_id]["name"])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func use_item(item_id: String) -> void:
	if not _can_act():
		return
	var result := Items.use(player, data, item_id, world_flags)
	if result["ok"]:
		EventBus.post("You use a %s. (%s)" % [data.items[item_id]["name"], ", ".join(result["notes"])], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func travel(region_id: String) -> void:
	if not _can_act():
		return
	var check := Exploration.check_travel(player, data, current_region, region_id)
	if not check["ok"]:
		EventBus.post(check["reason"], "warning")
		return
	current_region = region_id
	EventBus.post("After %s on the road you arrive at %s." % [Calendar.format_duration(check["days"]), Exploration.region_name(data, region_id)], "progress")
	_pass_time(check["days"])
	EventBus.region_changed.emit(region_id)


## Explore a place tagged with `tags` (defaults to the region's encounter tags).
func explore(tags: Array = []) -> void:
	if not _can_act():
		return
	if tags.is_empty():
		tags = data.regions.get(current_region, {}).get("encounter_tags", [])
	var encounter := Exploration.roll_encounter(player, data, tags, world_flags, rng)
	if encounter.is_empty():
		EventBus.post("You search the area but find nothing.")
		_pass_time(1)
		return
	var result := Exploration.resolve(player, data, encounter, world_flags)
	var text: String = encounter.get("text", "")
	if not result["notes"].is_empty():
		text += " (%s)" % ", ".join(result["notes"])
	EventBus.post(text, "danger" if result["enemy"] != "" else "info")
	_pass_time(result["days"])
	if result["enemy"] == "" or not _can_act():
		return
	if Exploration.should_evade(player, data, result["enemy"]):
		EventBus.post("You sense overwhelming killing intent and slip away before the %s notices you." % data.enemies[result["enemy"]]["name"], "warning")
		return
	fight(result["enemy"])


func learn_technique(tech_id: String) -> void:
	if not _can_act():
		return
	var def: TechniqueDef = data.techniques.get(tech_id)
	if def != null and def.manual_item != "" and player.item_count(def.manual_item) > 0:
		use_item(def.manual_item)
		return
	EventBus.post("You have no manual for that technique.", "warning")


func practice_technique(tech_id: String, days: int) -> void:
	if not _can_act():
		return
	var result := Techniques.practice(player, data, tech_id, days)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	var def: TechniqueDef = data.techniques[tech_id]
	EventBus.post("You practice the %s for %s." % [def.name, Calendar.format_duration(days)])
	if result["levels_gained"] > 0:
		var mastered := " (mastered)" if Techniques.is_mastered(player, data, tech_id) else ""
		EventBus.post("Your %s reaches level %d%s!" % [def.name, Techniques.level(player, tech_id), mastered], "progress")
	_pass_time(days)


## Fight an enemy from data/enemies.json.
func fight(enemy_id: String) -> void:
	if not data.enemies.has(enemy_id):
		push_error("Unknown enemy '%s'" % enemy_id)
		return
	fight_enemy(data.enemies[enemy_id])


## Fight any enemy dictionary in the enemies.json format.
func fight_enemy(enemy: Dictionary) -> void:
	if not _can_act():
		return
	var result := Combat.resolve(player, data, enemy, rng)
	# The full blow-by-blow goes out with combat_finished; the log gets a summary.
	var lines: PackedStringArray = result["log"]
	EventBus.post(lines[0], "danger")
	EventBus.post("%s (%d rounds, %d/%d hp left)" % [lines[-1], result["rounds"], result["player_hp"], result["player_max_hp"]], "progress" if result["victory"] else "danger")
	var outcome := Combat.apply_outcome(player, data, enemy, result, world_flags)
	if not outcome["notes"].is_empty():
		EventBus.post("(%s)" % ", ".join(outcome["notes"]), "progress" if result["victory"] else "warning")
	EventBus.combat_finished.emit(enemy.get("name", "enemy"), result["victory"], result["log"])
	if outcome["died"]:
		_kill(outcome["cause"])
		EventBus.player_changed.emit()
		return
	_pass_time(outcome["days"])


# --- Save data ---------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"player": player.to_dict(),
		"world_flags": world_flags.duplicate(),
		"region": current_region,
		"clock": GameClock.to_dict(),
		# 64-bit ints do not survive JSON floats, so store them as strings.
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
	}


func load_save_dict(d: Dictionary) -> void:
	player = CharacterData.from_dict(d.get("player", {}))
	world_flags = d.get("world_flags", {})
	current_region = d.get("region", data.start_region)
	if not data.regions.has(current_region):
		current_region = data.start_region
	GameClock.from_dict(d.get("clock", {}))
	rng.seed = String(d.get("rng_seed", "0")).to_int()
	rng.state = String(d.get("rng_state", "0")).to_int()
	EventBus.session_started.emit()
	EventBus.player_changed.emit()


# --- Internals ---------------------------------------------------------------

func _can_act() -> bool:
	return player != null and player.alive


func _pass_time(days: int) -> void:
	GameClock.advance(days)
	EventBus.player_changed.emit()


func _on_days_advanced(days: int) -> void:
	if not _can_act():
		return
	player.age_days += days
	if player.age_years() >= Cultivation.lifespan_years(player, data):
		_kill("Your lifespan is exhausted. You die of old age at %d." % player.age_years())


func _kill(cause: String) -> void:
	player.alive = false
	player.cause_of_death = cause
	EventBus.post(cause, "danger")
	EventBus.player_died.emit(cause)
