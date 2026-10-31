extends Node
## Owns the live game session: static data, the player, world flags and RNG.
##
## Player actions live here as thin wrappers: call a pure system in
## src/core/systems, post messages, advance time, emit EventBus signals.
## Keep rules out of this file; put them in the systems so they stay testable.

const BREAKTHROUGH_DAYS := 7
## Dialogue id (data/dialogue/) for generated NPCs without their own file.
const GENERIC_DIALOGUE := "generic_cultivator"
## World flag set once the intro event (data/artifact.json intro_event) has played.
const INTRO_EVENT_FLAG := "intro_event_seen"

var data: GameData
var player: CharacterData
## Persistent world facts, e.g. {"villager_dead": true}.
var world_flags: Dictionary = {}
## The merchant whose shop is open (set by ShopScreen.open), for its own discounts.
var shop_name := ""
## Open auctions (Auctions): house_id -> {opening, lots}.
var auctions: Dictionary = {}
## The cultivator just beaten whose cultivation may still be devoured
## (Devouring, DEM-001); {} when none. Not saved: the chance passes with the
## combat report.
var devour_target: Dictionary = {}
## Why the last fight was lost (Combat.loss_advice), "" after a win; shown in the combat report.
var last_loss_advice: String = ""
## True when the last fight was a friendly spar (SPAR-001): the report reads like one.
var last_fight_friendly: bool = false
## Reward notes of the last won fight ("+8 Spirit Stone"...), shown in the combat report.
var last_fight_spoils: PackedStringArray = PackedStringArray()
var last_fight_companion: String = ""  ## WU-413: name of the friend who fought beside you in the last fight ("" = none).
## Last fight's playback data from Combat.resolve: trace, player_max_hp, enemy_max_hp (WU-036).
var last_fight_playback: Dictionary = {}
## Active world events (WorldEvents, LW-001): [{id, region, start_day, end_day}].
var world_events: Array = []
## Id of the region (data/regions.json) the player is in.
var current_region := ""
## True when the last travel reached a region for the first time (TRAV-002).
var last_arrival_first_visit: bool = false
## Id of the road encounter the last travel produced, "" if none (WU-080).
var last_travel_road_encounter: String = ""
## Live NPCs: id -> CharacterData (definitions in data/npcs.json).
var npcs: Dictionary = {}
## How much each NPC likes the player: id -> int.
var npc_favor: Dictionary = {}
## The conversation in progress ("" = none) and its current node.
var dialogue_npc := ""
var dialogue_node := ""
## Dialogue id of the story event (a dialogue without an NPC) in progress.
var dialogue_event := ""
## Story event a fresh character opens with (data/artifact.json intro_event),
## started by the HUD once it is ready (start_pending_event).
var pending_event := ""
## Encounter id waiting for the player's choice (W-004c, "" = none). Like a
## conversation it is not saved: loading a save drops it.
var pending_encounter := ""
## ENC-011: the people the pending encounter names ({villager: npc id, elder: npc id}); not saved, like the encounter.
var pending_cast: Dictionary = {}
## True when the last explore day used a region discovery (TRAV-005).
var last_explore_discovery := false
var last_explore_deep_path := false
## True while a bounty's foe is fought, so the hunt does not lapse mid-fight (BOUNTY-001).
var _bounty_fight := false
## A lethal foe sensed while exploring, awaiting face_threat() (transient, not saved).
var pending_threat := ""
## Set when the Creation Artifact just respawned the player (ART-005) until
## they pick where to awaken: {cause, anchor_id, lives_left, qi_lost}. Not saved.
var pending_respawn: Dictionary = {}
## Recap lines of the save that was just loaded (WU-025); the HUD shows them once on its arrival card and clears them.
var load_recap: PackedStringArray = []
## New sessions start beside this anchor place: the awakening dream ends "You wake on Meditation Rock".
const INTRO_SPAWN_ANCHOR := "qingshi_rock"
## Anchor the world should place the player at after the next region load ("" = region spawn).
var spawn_anchor := ""
var rng := RandomNumberGenerator.new()
## The player's clan (FAM-005), null until founded.
var clan: ClanData = null
## NPC clans (FAM-009, data/clans.json): clan id -> ClanData. See NpcClans.
var npc_clans: Dictionary = {}
## Player numbers before the current long action (TimeSkip.snapshot), for the
## time-skip summary. Set by _start_time_skip(), read by _pass_time().
var _skip_before: Dictionary = {}
## The last 5+ day action's digest {days, lines} (DAY-001); never saved, cleared when a new action starts.
var last_digest: Dictionary = {}
## Player hp at the end of the last fight_enemy() (carried between tournament bouts).
var last_fight_hp: int = -1


func _ready() -> void:
	data = GameData.load_from_dir()
	for err in data.load_errors:
		push_error("Data error: " + err)
	GameClock.days_advanced.connect(_on_days_advanced)
	GameClock.year_changed.connect(_on_year_changed)
	EventBus.player_changed.connect(check_milestones)
	EventBus.player_changed.connect(check_friendships)
	EventBus.player_changed.connect(_announce_tier)
	EventBus.player_changed.connect(check_unlock_notices)
	EventBus.player_changed.connect(Platform.refresh_presence)
	EventBus.region_changed.connect(func(_id: String) -> void: Platform.refresh_presence())


func has_session() -> bool:
	return player != null


func start_session(character: CharacterData) -> void:
	player = character
	_announced_tier = Alignment.tier_name(player.alignment, data)
	CreationArtifact.ensure(player, data)
	world_flags = {}
	auctions = {}
	devour_target = {}
	world_events = []
	current_region = data.start_region
	last_arrival_first_visit = false
	Exploration.visit(player, current_region)
	npcs = {}
	npc_favor = {}
	clan = null
	dialogue_npc = ""
	pending_encounter = ""
	pending_cast = {}
	pending_threat = ""
	pending_respawn = {}
	load_recap = []
	spawn_anchor = INTRO_SPAWN_ANCHOR  # the awakening ends on Meditation Rock (FH-011)
	dialogue_event = ""
	pending_event = String(data.artifact.get("intro_event", ""))
	Npcs.ensure_all(npcs, data, rng)
	Npcs.ensure_eligible(npcs, data, rng, Children.descendants(player, npcs))
	npc_clans = {}
	NpcClans.ensure(npc_clans, npcs, data, rng)
	Rivals.spawn(player, npcs, data, rng, data.start_region)
	world_flags["notice_rival"] = true  # a rival from the start is not news (GUIDE-008)
	for notice in Guidance.unlock_notices(player, data, world_flags, npcs, clan):
		world_flags["notice_" + String(notice["id"])] = true  # roads already open are not news
	GameClock.reset()
	_store_year_snapshot()
	_announced_tier = Alignment.tier_name(player.alignment, data)
	EventBus.clear_history()
	EventBus.session_started.emit()
	EventBus.post("%s sets out on the path of cultivation." % player.name, "progress")
	EventBus.player_changed.emit()


func end_session() -> void:
	Platform.set_rich_presence("")
	EventBus.topic = ""
	player = null
	world_flags = {}
	auctions = {}
	devour_target = {}
	world_events = []
	npcs = {}
	npc_favor = {}
	clan = null
	npc_clans = {}
	dialogue_npc = ""
	pending_encounter = ""
	pending_cast = {}
	pending_threat = ""
	pending_respawn = {}
	load_recap = []
	spawn_anchor = ""
	dialogue_event = ""
	pending_event = ""


# --- Actions -----------------------------------------------------------------

## `skip_title` heads the time-skip overlay ("In seclusion" at an abode).
func cultivate(days: int, location_density: float = 1.0, skip_title: String = "Meditating") -> void:
	EventBus.topic = "cultivation"
	pending_threat = ""
	if not _can_act():
		return
	if SpiritualRoots.cultivation_multiplier(player.spiritual_roots, data) <= 0.0:
		EventBus.post("Without a spiritual root, qi slips through you like water.", "warning")
		return
	if Cultivation.is_at_bottleneck(player, data):
		EventBus.post("You are at a bottleneck. More meditation will not help; attempt a breakthrough.", "warning")
		return
	# Weather is averaged over the days spent (RV-016); the span and the days to the bottleneck depend on each
	# other, so settle them in a few passes.
	var density := _cultivation_density(location_density, days)
	var needed := Cultivation.days_to_bottleneck(player, data, density)
	var asked := days
	for _pass in 6:
		if needed <= 0 or needed == days or (needed > days and days >= asked):
			break
		days = mini(needed, asked)
		density = _cultivation_density(location_density, days)
		needed = Cultivation.days_to_bottleneck(player, data, density)
	if needed > days and days < asked: # the passes kept flipping between two spans: take the longer, it reaches the bottleneck
		days = mini(needed, asked)
	var ends_early := days < asked
	player.last_meditated_day = GameClock.total_days + days
	_start_time_skip()
	var result := Cultivation.cultivate(player, data, days, density)
	EventBus.post("You cultivate for %s and gather %d qi (%s)." % [Calendar.format_duration(days), int(result["qi_gained"]), Cultivation.progress_text(player, data)])
	if result["stages_gained"] > 0:
		EventBus.post("Your cultivation rises to %s!" % Cultivation.realm_label(player, data), "progress")
	if result["at_bottleneck"]:
		EventBus.post("You have reached a bottleneck. Attempt a breakthrough to advance.", "warning")
	if ends_early:
		EventBus.post("Your qi reaches a bottleneck after %s; you end your seclusion." % Calendar.format_duration(days))
	if skip_title == "In seclusion":
		LifeStats.add(player, "days_in_seclusion", days)
	_pass_time(days, skip_title)


## Claim a cave abode in the current region for spirit stones. Its anchor is
## bound right away if the artifact has a free anchor slot.
func claim_abode(abode_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Abodes.claim(player, data, abode_id, current_region)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	if result["previous"] != "":
		EventBus.post("You leave %s behind." % Abodes.abode_name(data, result["previous"]))
	if result["array_returned"] != "":
		EventBus.post("You pack up your %s." % data.items.get(result["array_returned"], {}).get("name", result["array_returned"]))
	EventBus.post("You pay %d spirit stones and claim %s as your abode." % [result["cost"], Abodes.abode_name(data, abode_id)], "progress")
	if Clans.move_seat(clan, abode_id, data):
		EventBus.post("The %s moves its seat to %s." % [clan.name, Abodes.abode_name(data, abode_id)], "progress")
	var anchor_id := String(result["anchor_id"])
	if anchor_id != "" and not player.anchors.has(anchor_id) and player.anchors.size() < CreationArtifact.anchor_slots(player, data):
		bind_anchor(anchor_id)
	EventBus.player_changed.emit()


## Cultivate in seclusion at the player's abode (must be in its region).
func cultivate_in_seclusion(days: int) -> void:
	EventBus.topic = "cultivation"
	pending_threat = ""
	if not _can_act():
		return
	var density := Abodes.seclusion_density(player, data, current_region)
	if density <= 0.0:
		EventBus.post("You have no abode here to seclude yourself in.", "warning")
		return
	cultivate(days, density * ClanEstate.seat_qi_multiplier(clan, data, player.abode), "In seclusion")


## Set up an array (items.json `array`) at the player's abode; takes a day.
func place_abode_array(item_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Abodes.place_array(player, data, current_region, item_id)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	if result["replaced"] != "":
		EventBus.post("You pack up the %s." % data.items.get(result["replaced"], {}).get("name", result["replaced"]))
	EventBus.post("You plant the %s around %s; qi density there rises by %d%%." % [data.items[item_id].get("name", item_id), Abodes.abode_name(data, player.abode), roundi(Abodes.array_bonus(player, data) * 100.0)], "progress")
	_pass_time(1)


## Pack up the array at the player's abode into the inventory.
func remove_abode_array() -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Abodes.remove_array(player, data, current_region)
	if result["ok"]:
		EventBus.post("You pack up the %s." % data.items.get(result["item"], {}).get("name", result["item"]))
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func store_in_abode(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Abodes.store(player, data, current_region, item_id, quantity)
	if result["ok"]:
		EventBus.post("You put %d %s in your abode's chest." % [quantity, Items.item_plural(data, item_id, quantity)])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func retrieve_from_abode(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Abodes.retrieve(player, data, current_region, item_id, quantity)
	if result["ok"]:
		EventBus.post("You take %d %s from your abode's chest." % [quantity, Items.item_plural(data, item_id, quantity)])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## HEART-001: the heart vision due before the next major breakthrough ({} = none). No time passes.
func heart_vision() -> Dictionary:
	return HeartVision.vision(player, data, npcs)


## Faces choice `index` of heart_vision(): posts what happens and the change to the odds.
func face_heart_vision(index: int) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := HeartVision.choose(player, data, index, rng)
	if result.is_empty():
		return
	var bonus := float(result["bonus"])
	var note := "no change to your odds"
	if bonus > 0.0:
		note = "+%d%% to break through" % roundi(bonus * 100)
	elif bonus < 0.0:
		note = "%d%% to break through" % roundi(bonus * 100)
	EventBus.post("%s (%s)." % [result["text"], note], "cultivation")
	EventBus.player_changed.emit()


func attempt_breakthrough() -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	if not Cultivation.can_attempt_breakthrough(player, data):
		EventBus.post("You are not ready to break through.", "warning")
		return
	# Only a surpassing this attempt causes reaches the realm card, not one the monthly check made.
	last_surpassed_rival = ""
	var old_realm_index := player.realm_index
	var lifespan_before := Cultivation.lifespan_years(player, data)
	var qi_rate_before := Cultivation.qi_per_day(player, data)
	var result := Cultivation.attempt_breakthrough(player, data, rng)
	_report_tribulation(result)
	if result["died"]:
		EventBus.breakthrough_attempted.emit(false, result["realm_name"])
		_die_violently("The final bolt of the %s tribulation tears through you. Your body turns to ash." % result["realm_name"])
		return
	LifeStats.add(player, "breakthroughs" if result["success"] else "breakthroughs_failed")
	if result["success"]:
		EventBus.post("Breakthrough! You have entered the %s realm." % result["realm_name"], "progress")
		var lifespan_gain := Cultivation.lifespan_years(player, data) - lifespan_before
		if lifespan_gain > 0:
			EventBus.post("Your lifespan grows to %d years (+%d)." % [Cultivation.lifespan_years(player, data), lifespan_gain], "progress")
			EventBus.breakthrough_details.emit("Lifespan +%d years" % lifespan_gain)
		var qi_ratio := Cultivation.qi_per_day(player, data) / maxf(qi_rate_before, 0.0001)
		if qi_ratio >= 1.5:
			EventBus.post("Your qi gathers %s times faster." % String.num(qi_ratio, 1), "progress")
		var told := Family.breakthrough_news(player, data, npcs, npc_favor)
		if not told.is_empty():
			EventBus.post("Word of your %s breakthrough spreads: %d %s who know you think better of you." % [result["realm_name"], told.size(), "person" if told.size() == 1 else "people"], "progress")
		if Bloodlines.update(player, data):
			EventBus.post("Your blood boils and sings: your %s awakens!" % Bloodlines.bloodline_name(data, player.bloodline), "progress")
		_check_rival_surpassed()
		_check_rival_caught_up(old_realm_index)
	else:
		if result["tribulation"].is_empty():
			EventBus.post("Your breakthrough to %s failed (%d%% chance). Your qi scatters." % [result["realm_name"], int(result["chance"] * 100)], "danger")
		else:
			EventBus.post("Your breakthrough to %s fails in the tribulation. Your qi scatters." % result["realm_name"], "danger")
		if result["injury"] != "":
			EventBus.post("You suffer %s." % Injuries.injury_name(data, result["injury"]), "danger")
			EventBus.post(Guidance.injury_news(player, data, result["injury"], current_region, world_flags), "danger")
		var lesson := _failure_lesson_line()
		if lesson != "":
			EventBus.post(lesson, "info")
		var tip := Guidance.pill_source_hint(player, data)
		EventBus.post(tip if tip != "" else "Fortune, Dao insights and pills raise your odds.", "info")
	EventBus.breakthrough_attempted.emit(result["success"], result["realm_name"])
	_pass_time(BREAKTHROUGH_DAYS)
	if result["success"]:
		SaveManager.autosave()


## What a failed attempt taught, from the same terms as Cultivation.chance_breakdown.
func _failure_lesson_line() -> String:
	if data.failure_bonus <= 0.0:
		return ""
	var earned := data.failure_bonus * player.breakthrough_failures
	var shown := minf(earned, data.failure_bonus_max)
	if earned - data.failure_bonus >= data.failure_bonus_max:
		return "The lessons stay with you: your lessons are already worth all they can teach (+%d percent)." % roundi(shown * 100.0)
	return "The lessons stay with you: +%d percent on your next attempt." % roundi(shown * 100.0)


## Name of the rival surpassed by the latest breakthrough; the HUD's realm card takes it (WU-148).
var last_surpassed_rival: String = ""


## Marks the rival as surpassed (once) after a breakthrough past their realm.
func _check_rival_surpassed() -> void:
	if not world_flags.get(Rivals.FIRST_MEETING_FLAG, false) or world_flags.get(Rivals.SURPASSED_FLAG, false):
		return
	var rival := Rivals.rival_of(player, npcs)
	if Rivals.surpassed(player, rival):
		world_flags[Rivals.SURPASSED_FLAG] = true
		Rivals.spur(rival, data)
		last_surpassed_rival = rival.name
		EventBus.post("You have surpassed %s. Whatever they once said of you, no one repeats it now." % rival.name, "progress")
		check_milestones()


## RIVAL-020: news the day a breakthrough brings you level with a rival who was ahead; once per realm.
func _check_rival_caught_up(old_realm_index: int) -> void:
	if not world_flags.get(Rivals.FIRST_MEETING_FLAG, false):
		return
	if int(world_flags.get("rival_caught_up_realm", -1)) == player.realm_index:
		return
	var rival := Rivals.rival_of(player, npcs)
	if Rivals.caught_up(player, rival, old_realm_index):
		world_flags["rival_caught_up_realm"] = player.realm_index
		EventBus.post(Rivals.caught_up_line(rival), "progress")


## Expected tribulation for breaking into the next realm (Tribulation.preview),
## for a "prepare" warning before attempting a breakthrough.
func tribulation_preview() -> Dictionary:
	return Tribulation.preview(player, data, player.realm_index + 1)


func _report_tribulation(result: Dictionary) -> void:
	var trib: Dictionary = result["tribulation"]
	if trib.is_empty():
		return
	EventBus.tribulation_endured.emit(result["realm_name"], trib)
	EventBus.post("Heaven answers your breakthrough: tribulation clouds gather over the %s threshold!" % result["realm_name"], "danger")
	if not trib["talismans_used"].is_empty():
		EventBus.post("You burn %s to shield yourself." % ", ".join(trib["talismans_used"]), "info")
	for i in trib["waves"].size():
		var wave: Dictionary = trib["waves"][i]
		var what := "Your heart demon rises" if wave["kind"] == "heart_demon" else "Lightning wave %d strikes" % (i + 1)
		EventBus.post("%s: %d damage (%d/%d left)." % [what, wave["damage"], wave["hp_left"], trib["max_hp"]], "danger")
	if trib["survived"]:
		LifeStats.add(player, "tribulations_survived")
		EventBus.post("You endure the tribulation and are reforged by its lightning.", "progress")
	elif not trib["died"]:
		EventBus.post("You are struck down before the tribulation ends.", "danger")


func work_profession(prof_id: String, days: int) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	_start_time_skip()
	var result := Professions.work(player, data, prof_id, days)
	var def: ProfessionDef = data.professions[prof_id]
	EventBus.post("You work as %s for %s: +%d xp, +%d spirit stones." % [Text.a(def.name), Calendar.format_duration(days), int(result["xp"]), result["income"]])
	if result["ranks_gained"] > 0:
		_post_rank_up(prof_id, int(result["ranks_gained"]))
	if not player.is_rogue():
		var contribution := int(result["xp"] / (1.0 if Sects.is_favored_profession(player, data, prof_id) else 2.0))
		if Sects.add_contribution(player, data, contribution):
			EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")
	_pass_time(days, "Working as %s" % Text.a(def.name))


## A newcomer's first craft also brings their first order (PROF-007), so they need
## not wait for the month end; open orders are capped per profession. `only_prof`
## limits that early roll to the new craft (no early orders for the others).
func _commissions_month(only_prof: String = "") -> void:
	EventBus.topic = "trade"
	for order in Commissions.roll(player, data, rng, GameClock.total_days, only_prof, current_region):
		var days := Commissions.days_left(order, GameClock.total_days)
		EventBus.post("A buyer at the workshop orders %d %s for %d spirit stones (%d days)." % [
			int(order["count"]), Items.item_plural(data, String(order["item"]), int(order["count"])), int(order["reward"]), days], "progress")
	EventBus.topic = "world"


## Fills open crafting order `index` (PROF-001). Takes no time.
func deliver_commission(index: int) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var result := Commissions.deliver(player, data, index)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var item_name := Items.item_plural(data, String(result["item"]), int(result["count"]))
	EventBus.post("You deliver %d %s: +%d spirit stones, +%d xp." % [int(result["count"]), item_name, int(result["stones"]), int(result["xp"])], "progress")
	var prof_id: String = result["profession"]
	if result["ranks_gained"] > 0:
		_post_rank_up(prof_id, int(result["ranks_gained"]))
	if not player.is_rogue():
		var contribution := int(result["xp"] / (1.0 if Sects.is_favored_profession(player, data, prof_id) else 2.0))
		if Sects.add_contribution(player, data, contribution):
			EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")
	_gain_renown("commission")
	EventBus.player_changed.emit()


func join_sect(sect_id: String) -> void:
	EventBus.topic = "sect"
	if not _can_act():
		return
	var result := Sects.join(player, data, sect_id)
	if result["ok"]:
		EventBus.post("You are accepted into the %s." % data.sects[sect_id].name, "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func leave_sect() -> void:
	EventBus.topic = "sect"
	if not _can_act():
		return
	var old_id := Sects.leave(player)
	if old_id != "":
		var rep := Reputation.on_leave(player, data, old_id)
		var suffix := " (reputation %+d)" % rep if rep != 0 else ""
		EventBus.post("You leave the %s and walk the path alone.%s" % [data.sects[old_id].name, suffix], "warning")
	EventBus.player_changed.emit()


func perform_deed(deed_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var deed: Dictionary = data.deeds.get(deed_id, {})
	var reason := Deeds.check(player, data, deed, world_flags, GameClock.total_days) if not deed.is_empty() else "Unknown deed."
	if reason != "":
		EventBus.post(reason, "warning")
		return
	var enemy_id := String(deed.get("enemy", ""))
	if enemy_id != "":
		EventBus.post("%s: first you must fight." % deed["name"], "danger")
		if not fight_enemy(data.enemies[enemy_id]):
			if _can_act():
				EventBus.post("Beaten, you abandon the attempt.", "warning")
				_pass_time(int(deed.get("days", 0)))
			return
	var result := Deeds.perform(player, data, deed_id, world_flags, GameClock.total_days)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	LifeStats.add(player, "deeds_done")
	if float((deed.get("effects", {}) as Dictionary).get("alignment", 0)) > 0.0:
		_gain_renown("righteous_deed")
	EventBus.post("%s. (%s)" % [deed["name"], ", ".join(result["notes"])], "karma")
	_pass_time(result["days"])


## Buys one item; `faction` is the sect the merchant belongs to (prices follow reputation).
func buy_item(item_id: String, faction: String = "", quantity: int = 1) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var result := Items.buy(player, data, item_id, quantity, faction, buy_multiplier(item_id), price_season())
	if result["ok"]:
		var item_name: String = data.items[item_id]["name"]
		var what := Text.a(item_name) if quantity == 1 else "%d %s" % [quantity, item_name]
		EventBus.post("You buy %s for %d spirit stones." % [what, result["stones"]])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func use_item(item_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	if Equipment.is_equipment(data, item_id):
		equip_item(item_id)
		return
	var result := Items.use(player, data, item_id, world_flags)
	if result["ok"]:
		EventBus.post("You use %s. (%s)" % [Text.a(String(data.items[item_id]["name"])), ", ".join(result["notes"])], "progress")
		var burned := int(data.items[item_id].get("effects", {}).get("burn_lifespan", 0))
		if burned > 0:
			EventBus.post("You feel %d years of life drain away. %d years remain." % [burned, Cultivation.years_left(player, data)], "danger")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Equip a weapon/armor from the inventory (takes no time).
func equip_item(item_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var reason := Equipment.check_equip(player, data, item_id)
	if reason != "":
		EventBus.post(reason, "warning")
	else:
		var previous := Equipment.equip(player, data, item_id)
		var text := "You equip the %s (%s)." % [data.items[item_id]["name"], Equipment.describe_stats(data, item_id)]
		if previous != "":
			text += " The %s goes back into your pack." % data.items[previous]["name"]
		EventBus.post(text, "progress")
		var shift := Equipment.bind_artifact(player, data, item_id)
		if shift != 0:
			EventBus.post("The %s drinks a drop of your blood and binds itself to you. Your heart shifts: alignment %+d (%s)." % [data.items[item_id]["name"], shift, Alignment.tier_name(player.alignment, data)], "karma")
		if Equipment.item_drain(data, item_id) > 0:
			EventBus.post("It thirsts for your life. %d years remain to you." % Cultivation.years_left(player, data), "danger")
	EventBus.player_changed.emit()


func unequip(slot: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var item_id := Equipment.unequip(player, slot)
	if item_id != "":
		EventBus.post("You put away the %s." % data.items[item_id]["name"], "info")
	EventBus.player_changed.emit()


## The days a journey along `route` ({"days": base days}) spends now: the character's
## travel speed plus the snow day (WU-403). `travel` and both travel labels use this.
func journey_days(route: Dictionary) -> int:
	return Exploration.travel_days(player, data, int(route.get("days", 1))) + Weather.travel_extra_days(data, current_region, GameClock.total_days)


func travel(region_id: String) -> void:
	EventBus.topic = "world"
	pending_threat = ""
	if not _can_act():
		return
	var check := Exploration.check_travel(player, data, current_region, region_id)
	if not check["ok"]:
		EventBus.post(check["reason"], "warning")
		return
	_start_time_skip()
	last_travel_road_encounter = ""
	var snow_days := Weather.travel_extra_days(data, current_region, GameClock.total_days)
	if snow_days > 0:
		check["days"] = journey_days({"days": check["base_days"]})
		EventBus.post("Snow slows the road: +%d %s." % [snow_days, "day" if snow_days == 1 else "days"], "info")
	current_region = region_id
	last_arrival_first_visit = Exploration.visit(player, region_id)
	world_flags["notice_road_" + region_id] = true  # you are already here (TRAV-001)
	var how := Exploration.travel_how(player, data)
	EventBus.post("After %s %s you arrive at %s." % [Calendar.format_duration(check["days"]), how if how != "" else "on the road", Exploration.region_name(data, region_id)], "progress")
	var first_sight: String = String(data.regions.get(region_id, {}).get("first_visit", ""))
	if last_arrival_first_visit and first_sight != "":
		EventBus.post(first_sight, "info")
	_pass_time(check["days"], "Travelling to %s" % Exploration.region_name(data, region_id))
	if not _road_ambush() and _can_act():
		var road := Exploration.road_encounter(player, data, int(check["days"]), world_flags, rng, Calendar.season_of(GameClock.total_days), GameClock.total_days)
		if not road.is_empty():
			last_travel_road_encounter = String(road.get("id", ""))
			# Not an exploration find: the encounter window must not title it a discovery.
			last_explore_discovery = false
			last_explore_deep_path = false
			_meet_encounter(road, "On the road: ")
	EventBus.region_changed.emit(region_id)
	SaveManager.autosave()


## After a journey, an NPC with a strong grudge may ambush the player, and a
## grateful one may come to help (Karma, RIV-003).
func _road_ambush() -> bool:
	if not _can_act():
		return false
	var hunter_id := Karma.roll_hunter(player, npcs, data, rng, 1.0 - ClanEstate.ward(clan, data, current_region))
	if hunter_id == "":
		return false
	var hunter: CharacterData = npcs[hunter_id]
	EventBus.post("%s has hunted you down on the road. Your old grudge (%s) will be settled with blood!" % [hunter.name, Karma.grudge_word(Karma.grudge(player, hunter_id), data)], "danger")
	var ally_id := Karma.roll_ally(player, npcs, data, rng, hunter_id)
	if ally_id != "":
		EventBus.post("%s, who owes you a debt, rushes to fight at your side!" % npcs[ally_id].name, "progress")
	var won := fight_enemy(Karma.npc_enemy(hunter, data))
	Karma.after_hunt(player, data, hunter_id, won)
	if ally_id != "":
		player.buffs.erase("ally_aid")
	return true


## Explore a place tagged with `tags` (defaults to the region's encounter tags).
func explore(tags: Array = []) -> void:
	_explore_once(tags, false)


## Explore for up to `max_days` days (1..30), one day at a time, stopping as
## soon as anything happens that needs the player (an encounter, a choice, a
## sensed threat, a fight, death). Returns the days spent. Quiet days are
## summed up in one line at the end (FH-025).
func explore_many(max_days: int, tags: Array = []) -> int:
	EventBus.topic = "world"
	var limit := clampi(max_days, 1, 30)
	var days := 0
	var quiet_days := 0
	while days < limit and _can_act():
		var result := _explore_once(tags, true)
		days += 1
		if result["event"] != "nothing":
			break
		quiet_days += 1
	if quiet_days > 0 and _can_act():
		EventBus.post(("You explore for %s and find nothing of note. %s" % [Calendar.format_duration(quiet_days), Exploration.quiet_line(data, current_region, GameClock.total_days)]).strip_edges())
	return days


## What exploring here (or a place with `tags`) might bring, as one line.
func explore_outlook(tags: Array = []) -> String:
	if tags.is_empty():
		tags = data.regions.get(current_region, {}).get("encounter_tags", [])
	tags = tags + WorldEvents.encounter_tags(data, world_events, current_region)
	var line := Guidance.outlook_text(Exploration.outlook(player, data, tags, world_flags, Calendar.season_of(GameClock.total_days), current_region, GameClock.total_days))
	if Exploration.mastered(player, data, current_region, world_flags):
		line = (line + " You know every path here.").strip_edges()
	return line


## Once per region (world flag mastered_<region>): notes that the current region is now mastered.
func _check_mastery() -> void:
	var flag := "mastered_" + current_region
	if current_region == "" or world_flags.get(flag, false) or not Exploration.mastered(player, data, current_region, world_flags):
		return
	world_flags[flag] = true
	LifeStats.add(player, "regions_mastered")
	EventBus.post("You know %s like the lines of your own palm." % Exploration.region_name(data, current_region), "progress")
	EventBus.region_mastered.emit(current_region)


## One day of exploring. Returns {event: "nothing"|"fight"|"choice"|"threat"|"story"}.
## `quiet` skips the per-day "find nothing" line (explore_many sums it up).
func _explore_once(tags: Array, quiet: bool) -> Dictionary:
	var result := _explore_day(tags, quiet)
	_check_mastery()
	return result


func _explore_day(tags: Array, quiet: bool) -> Dictionary:
	EventBus.topic = "world"
	if not _can_act():
		return {"event": "nothing"}
	if tags.is_empty():
		tags = data.regions.get(current_region, {}).get("encounter_tags", [])
	tags = tags + WorldEvents.encounter_tags(data, world_events, current_region)
	if Weather.of(data, current_region, GameClock.total_days) == "storm":
		if not quiet:  # explore_many would repeat it every storm day
			EventBus.post("A storm rolls over the sky; lightning walks the horizon.", "warning")
		_storm_strike()
	var encounter := Exploration.discovery_for(player, data, current_region, world_flags)
	Exploration.add_explore_day(player, current_region)
	last_explore_discovery = not encounter.is_empty()
	last_explore_deep_path = false
	if encounter.is_empty():
		encounter = Exploration.deep_path_for(player, data, current_region, world_flags)
		last_explore_deep_path = not encounter.is_empty()
	if encounter.is_empty():
		var hunted := Bounties.hunt_roll(player, data, current_region, GameClock.total_days, rng)
		if hunted != "":
			return _hunt_bounty_foe(hunted)
		encounter = Exploration.roll_encounter(player, data, tags, world_flags, rng, _rival_for_roll(), 1.0 - ClanEstate.ward(clan, data, current_region), Calendar.season_of(GameClock.total_days), current_region, int(npc_favor.get(player.rival, 0)), func(e: Dictionary) -> bool: return Folk.available(e, npcs, data, player, current_region), GameClock.total_days)
		if String(encounter.get("rival", "")) != "" or encounter.has("rival_attitude"):
			Rivals.note_encounter(data, world_flags, GameClock.total_days)
	else:
		# Only the discovery itself marks the region discovered; a deeper path must not
		# use up a discovery the player has not met yet.
		if last_explore_discovery:
			world_flags["discovered_" + current_region] = true
			LifeStats.sync_discoveries(player, world_flags)
		_gain_renown("discovery" if last_explore_discovery else "deep_path")
	if encounter.is_empty():
		if not quiet:
			EventBus.post(("You search the area but find nothing. %s" % Exploration.quiet_line(data, current_region, GameClock.total_days)).strip_edges())
		_pass_time(1)
		return {"event": "nothing"}
	return _meet_encounter(encounter, explore_prefix(encounter, last_explore_discovery, last_explore_deep_path))


## WEATHER-005: what a day of exploring in a storm may bring (lightning, or a lightning-struck branch).
func _storm_strike() -> void:
	var r := Weather.storm_explore(data, "storm", player, rng)
	match String(r["event"]):
		"lightning":
			if String(r["dao"]) != "":
				Dao.add_progress(player, data, String(r["dao"]), float(data.dao.get("seclusion_mult", 2.0)) * Weather.dao_mult(data, "storm", String(r["dao"])), rng)
				EventBus.post("Lightning finds you, and you find something in it.", "progress")
			elif String(r["injury"]) != "" and Injuries.inflict(player, data, String(r["injury"])):
				EventBus.post("Lightning finds you: you are left with %s." % Injuries.injury_name(data, String(r["injury"])), "danger")
			else:
				EventBus.post("Lightning cracks down beside you and leaves your hair standing on end.", "warning")
		"thunderwood":
			player.add_item("lightning_struck_wood", 1)
			EventBus.post("A bolt splits an old tree nearby; you pick up a piece of Lightning-struck Wood.", "info")


## The rival an encounter roll may use: none while the rival is keeping quiet (RIVAL-021).
func _rival_for_roll() -> CharacterData:
	if not Rivals.encounter_ready(data, world_flags, GameClock.total_days):
		return null
	return Rivals.rival_of(player, npcs)


## Message prefix for an encounter met while exploring.
static func explore_prefix(encounter: Dictionary, discovery: bool, deep_path: bool) -> String:
	if discovery:
		return "A discovery: "
	if deep_path:
		return "A hidden path: "
	if encounter.has("min_renown"):
		return "Your name is known here: "
	return ""


## Play out an encounter that happened (exploring or on the road): effects,
## time, rival consequences, then a choice or a fight. `prefix` heads the text.
func _meet_encounter(encounter: Dictionary, prefix: String = "") -> Dictionary:
	LifeStats.add(player, "encounters")
	Exploration.note_met(player, encounter, GameClock.total_days)
	pending_cast = Folk.pick(encounter, npcs, data, player, current_region, npc_favor, rng)
	var renown_before := Renown.value(player, current_region)
	var result := Exploration.resolve(player, data, encounter, world_flags, current_region)
	_effect_renown_banner(renown_before)
	result["notes"].append_array(_folk_favor(encounter.get("effects", {})))
	var text := rival_text(String(encounter.get("text", "")))
	if not result["notes"].is_empty():
		text += " (%s)" % ", ".join(result["notes"])
	text = prefix + text
	EventBus.post(text, "danger" if result["enemy"] != "" else "info")
	pending_encounter = ""
	pending_threat = ""
	_pass_time(result["days"])
	if not _can_act():
		return {"event": "story"}
	_rival_consequences(encounter)
	if not _can_act():
		return {"event": "story"}
	if encounter.has("choices"):
		pending_encounter = String(encounter["id"])
		EventBus.encounter_choice_requested.emit(pending_encounter)
		return {"event": "choice"}
	if result["enemy"] == "":
		return {"event": "story"}
	_resolve_explore_enemy(result["enemy"])
	return {"event": "threat" if pending_threat != "" else "fight"}


## The trail of the bounty's foe turns up while exploring (BOUNTY-001): a chosen fight, so a Dangerous foe is
## fought directly; a Deadly one is out of reach and the bounty stays open.
func _hunt_bounty_foe(enemy_id: String) -> Dictionary:
	var enemy_name := String(data.enemies[enemy_id].get("name", enemy_id))
	EventBus.post("You pick up the trail of the %s from your bounty." % enemy_name, "danger")
	pending_encounter = ""
	pending_threat = ""
	# The day passes after the hunt and the hunted bounty is paid even if it lapsed during the
	# fight, so a trail found on the bounty's last day can still be claimed.
	if Exploration.should_evade(player, data, enemy_id):
		EventBus.post("The %s is far beyond you. You lose the trail." % enemy_name, "warning")
		_pass_time(1)
		return {"event": "nothing"}
	var bounty_id := String(player.bounty.get("id", ""))
	_bounty_fight = true
	var won := fight(enemy_id)
	_bounty_fight = false
	if won and _can_act():
		var paid := Bounties.complete(player, data, GameClock.total_days, bounty_id)
		var stones := int(paid["stones"])
		var bonus_line := " Your name earned you %d more." % int(paid["bonus"]) if int(paid["bonus"]) > 0 else ""
		EventBus.post("Bounty claimed: %d spirit stones.%s" % [stones, bonus_line], "progress")
		EventBus.bounty_claimed.emit(enemy_name, stones)
		_gain_renown("bounty")
		EventBus.player_changed.emit()
	if _can_act():
		_pass_time(1)
	return {"event": "fight"}


## Take a bounty from a board. Takes no time.
func take_bounty(bounty_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var reason := Bounties.check_take(player, data, bounty_id, GameClock.total_days)
	if reason != "":
		EventBus.post(reason, "warning")
	else:
		Bounties.take(player, data, bounty_id, GameClock.total_days)
		var b := Bounties.def_of(data, bounty_id)
		EventBus.post("You take the bounty: %s (%d days)" % [b["text"], int(b["days"])], "info")
	EventBus.player_changed.emit()


func abandon_bounty() -> void:
	EventBus.topic = "world"
	if not _can_act() or player.bounty.is_empty():
		return
	Bounties.abandon(player, data, GameClock.total_days)
	EventBus.post("You give up the hunt.", "info")
	EventBus.player_changed.emit()


## A foe met while exploring: Deadly lethal foes are evaded, Dangerous lethal
## foes are sensed first and the player chooses (face_threat), the rest fight.
func _resolve_explore_enemy(enemy_id: String) -> void:
	var enemy: Dictionary = data.enemies[enemy_id]
	if Exploration.should_evade(player, data, enemy_id):
		EventBus.post("You sense overwhelming killing intent and slip away before the %s notices you." % enemy["name"], "warning")
		return
	if Exploration.should_offer_flee(player, data, enemy_id):
		pending_threat = enemy_id
		var intent := "hungry for a kill" if bool(enemy.get("lethal", false)) else "far stronger than you"
		EventBus.post("You sense a %s nearby, %s (%s, %d%% to win)." % [enemy["name"], intent, Combat.danger_label(player, data, enemy), roundi(Combat.win_chance(player, data, enemy) * 100.0)], "danger")
		EventBus.threat_sensed.emit(enemy_id)
		return
	fight(enemy_id)


## Answer a sensed threat: fight it, or slip away (one day).
func face_threat(fight_it: bool) -> void:
	if pending_threat == "" or not _can_act():
		push_warning("face_threat called with no pending threat")
		return
	var enemy_id := pending_threat
	pending_threat = ""
	if fight_it:
		fight(enemy_id)
		return
	LifeStats.add(player, "threats_fled")
	EventBus.post("You slip away before it finds you.")
	_pass_time(1)


## Delve one floor deeper into an open secret realm in the current region
## (data/secret_realms.json): pay the entry cost once per opening, beat the
## floor's guardian, then claim one of its treasures. Losing drives you out,
## and so does a realm that closes before the floor is done (W-005d). Clearing
## the last floor grants the realm's inheritance once per life.
func enter_secret_realm(realm_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var today: int = GameClock.total_days
	var reason := SecretRealms.check_enter(player, data, realm_id, current_region, today)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var def := SecretRealms.realm(data, realm_id)
	var cost := SecretRealms.pay_entry(player, def, today)
	if cost > 0:
		EventBus.post("You pour %d spirit stones into the barrier of the %s and slip inside." % [cost, def["name"]], "info")
	var floor_def := SecretRealms.next_floor(player, def, today)
	EventBus.post("%s: %s" % [floor_def.get("name", ""), floor_def.get("text", "")], "info")
	if SecretRealms.closes_mid_floor(player, def, today):
		var expelled := SecretRealms.expel(player, data, def, today)
		var hurt := " (%s)" % Injuries.injury_name(data, expelled["injury"]) if expelled["injury"] != "" else ""
		EventBus.post("The %s shudders and begins to close. Its barrier hurls you out before you can claim the %s.%s" % [def["name"], floor_def.get("name", ""), hurt], "danger")
		_pass_time(expelled["days"])
		return
	if SecretRealms.roll_rival(data, rng) and not _contest_realm_rival(def):
		return
	var guardian := String(floor_def.get("guardian", ""))
	if guardian != "" and not fight_enemy(data.enemies[guardian]):
		if _can_act():
			EventBus.post("You are driven out of the %s." % def["name"], "warning")
		return
	var result := SecretRealms.claim_floor(player, data, realm_id, today, world_flags, rng)
	var notes: PackedStringArray = result["notes"]
	EventBus.post("You claim the treasure of the %s. (%s)" % [result["floor_name"], ", ".join(notes)], "progress")
	if result["last"]:
		EventBus.post("You have plundered every floor of the %s." % def["name"], "progress")
		_receive_inheritance(realm_id)
	_pass_time(result["days"])


## A rival cultivator contests the floor (W-005f): beat them and spare them
## (gratitude; rob or kill them later from their menu), or lose the floor.
## Returns true if the delve goes on.
func _contest_realm_rival(def: Dictionary) -> bool:
	var rival := SecretRealms.spawn_rival(npcs, data, def, rng)
	EventBus.post("%s, a %s cultivator, is here for the same treasure and attacks!" % [rival.name, Cultivation.realm_label(rival, data)], "danger")
	if not fight_enemy(Karma.npc_enemy(rival, data)):
		if _can_act():
			EventBus.post("%s claims the floor's treasure and leaves you in the dust." % rival.name, "warning")
		return false
	var gratitude := int(data.secret_realm_rivals.get("spare_gratitude", 0))
	if gratitude > 0:
		Karma.add_gratitude(player, data, rival.id, gratitude)
	EventBus.post("You let the beaten %s go. They will remember your mercy, and you may meet again in %s." % [rival.name, Exploration.region_name(data, String(def.get("region", "")))], "karma")
	return _can_act()


func _receive_inheritance(realm_id: String) -> void:
	var legacy: Dictionary = SecretRealms.realm(data, realm_id).get("inheritance", {})
	if legacy.is_empty() or SecretRealms.has_inherited(player, realm_id):
		return
	var reason := SecretRealms.check_inheritance(player, data, realm_id, world_flags)
	if reason != "":
		EventBus.post(reason, "warning")
		return
	var notes := SecretRealms.claim_inheritance(player, data, realm_id, world_flags)
	EventBus.post("%s: %s (%s)" % [legacy.get("name", ""), legacy.get("text", ""), ", ".join(notes)], "progress")


## Attempt the next trial of an inheritance ground in the current region
## (data/inheritances.json): realm/attribute/alignment tests pass at once if
## met, fight trials must be won (losing is never lethal). Passing the last
## trial claims the inheritance; no one else can claim it after you.
func attempt_inheritance(inheritance_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var reason := Inheritances.check_attempt(player, data, inheritance_id, current_region, GameClock.total_days, world_flags)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var def := Inheritances.inheritance(data, inheritance_id)
	var stage := Inheritances.next_stage(player, def)
	EventBus.post("%s: %s" % [stage.get("name", ""), stage.get("text", "")], "info")
	var enemy := Inheritances.stage_enemy(data, stage)
	if not enemy.is_empty() and not fight_enemy(enemy):
		if _can_act():
			EventBus.post("You fail the trial of the %s. You may try again." % def["name"], "warning")
		return
	var result := Inheritances.pass_stage(player, data, inheritance_id, world_flags)
	if result["last"]:
		EventBus.post("You claim the %s! (%s)" % [def["name"], ", ".join(result["notes"])], "progress")
	else:
		EventBus.post("You pass the %s." % Inheritances.stage_title(String(result["stage_name"])), "progress")
	_pass_time(result["days"])


## The pending encounter's choices for the UI: [{index, label, disabled, reason, chance, lethal}]
## ([] when no encounter is waiting).
func encounter_choices() -> Array[Dictionary]:
	if pending_encounter == "" or not _can_act():
		return []
	return Exploration.choices(player, data, data.encounters.get(pending_encounter, {}), world_flags, npcs)


## Pick choice `index` of the pending encounter: applies its outcome, passes
## its days and starts its fight, if any (a chosen fight is never evaded).
func choose_encounter(index: int) -> void:
	EventBus.topic = "world"
	if pending_encounter == "" or not _can_act():
		return
	var encounter: Dictionary = data.encounters.get(pending_encounter, {})
	var renown_before := Renown.value(player, current_region)
	var result := Exploration.resolve_choice(player, data, encounter, index, world_flags, current_region, rng, GameClock.total_days)
	_effect_renown_banner(renown_before)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	pending_encounter = ""
	pending_threat = ""
	var picked: Dictionary = encounter["choices"][index]
	if result["failed"]:
		picked = picked["on_fail"]
	result["notes"].append_array(_folk_favor(picked.get("effects", {})))
	var text := rival_text(String(result["text"]))
	if not result["notes"].is_empty():
		text += " (%s)" % ", ".join(result["notes"])
	if String(result.get("verdict", "")) != "":
		text = (String(result["verdict"]) + " " + text).strip_edges()
	if text != "":
		EventBus.post(text, "danger" if result["enemy"] != "" else "karma" if result["karma"] else "info")
	EventBus.encounter_choice_resolved.emit()
	_check_mastery()
	_pass_time(result["days"])
	var choice: Dictionary = encounter["choices"][index]
	if result["failed"]:
		choice = choice["on_fail"]
	if _can_act():
		_rival_consequences(choice)
	if result["enemy"] != "" and _can_act():
		if fight(result["enemy"]):
			_grateful_npc(choice)
			_add_renown(int(choice.get("renown", 0)))
	elif _can_act():
		_grateful_npc(choice)
		_add_renown(int(choice.get("renown", 0)))


## RIV-001f: a choice with grateful_npc spawns the person it helped in the
## current region, owing the player that much gratitude (after a won fight
## when the choice has one).
func _grateful_npc(choice: Dictionary) -> void:
	var def: Dictionary = choice.get("grateful_npc", {})
	if def.is_empty():
		return
	var ages: Array = def.get("age_years", [18, 40])
	var opts := {"region": current_region, "age_years": rng.randi_range(int(ages[0]), int(ages[1])), "realm": String(def.get("realm", "mortal"))}
	if def.has("gender"):
		opts["gender"] = String(def["gender"])
	var npc := Npcs.spawn(npcs, data, rng, opts)
	npc_favor[npc.id] = int(def.get("favor", 0))
	Karma.add_gratitude(player, data, npc.id, int(def.get("amount", 0)))
	EventBus.post("%s will not forget what you did. (They owe you a debt.)" % npc.name, "karma")


## Encounter text with the rival's name and realm filled in (Rivals.fill).
func rival_text(text: String) -> String:
	return Folk.fill(Rivals.fill(text, Rivals.rival_of(player, npcs), data), pending_cast, npcs)


## ENC-011: applies the villager_favor / elder_favor of `effects` to the people the encounter named; the notes say whom.
func _folk_favor(effects: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = []
	var changes := Folk.favor_changes(effects, pending_cast)
	for npc_id: String in changes:
		var npc: CharacterData = npcs.get(npc_id)
		if npc == null:
			continue
		var delta := int(changes[npc_id])
		npc_favor[npc_id] = clampi(int(npc_favor.get(npc_id, 0)) + delta, -100, 100)
		notes.append("%s thinks %s of you" % [npc.name, "better" if delta > 0 else "worse"])
	return notes


## RIVAL-013: the living, met rival's attitude toward the player; "" without one.
func _rival_attitude() -> String:
	var rival := Rivals.rival_of(player, npcs)
	if rival == null or not world_flags.get(Rivals.FIRST_MEETING_FLAG, false):
		return ""
	return Rivals.attitude(player, rival, int(npc_favor.get(rival.id, 0)), data)


## RIVAL-013: posts the line for an attitude move since `before` (see _rival_attitude).
func _post_attitude_change(before: String) -> void:
	var rival := Rivals.rival_of(player, npcs)
	if rival == null:
		return
	var line := Rivals.attitude_change_line(rival.name, before, _rival_attitude())
	if line != "":
		EventBus.post(line, "world")


## Applies an encounter's (or choice's) rival fields: rival_grudge and
## rival_favor change the rival's ledger and favor, fight_rival starts a
## non-lethal fight with the rival (RIV-002).
func _rival_consequences(entry: Dictionary) -> void:
	var rival := Rivals.rival_of(player, npcs)
	if rival == null:
		return
	var before := _rival_attitude()
	var grudge := int(entry.get("rival_grudge", 0))
	if grudge > 0:
		Karma.add_grudge(player, data, rival.id, grudge)
	var favor := int(entry.get("rival_favor", 0))
	if favor != 0:
		npc_favor[rival.id] = clampi(int(npc_favor.get(rival.id, 0)) + favor, -100, 100)
	_post_attitude_change(before)
	if bool(entry.get("fight_rival", false)):
		# RIVAL-022: a friendly invitation is a spar (no stones lost, no death), not a duel.
		if bool(entry.get("spar", false)):
			# RIVAL-023: the same cooldown the NPC menu's spar sets, so the loss advice is true.
			player.npc_action_days["spar:" + rival.id] = GameClock.total_days
			fight_enemy(Mentorship.spar_enemy(rival, data))
		else:
			fight_enemy(Karma.npc_enemy(rival, data))


## Leave the pending encounter without choosing (the UI offers this only when
## every choice is locked).
func dismiss_encounter() -> void:
	EventBus.topic = "world"
	if pending_encounter == "":
		return
	pending_encounter = ""
	pending_threat = ""
	EventBus.post("You leave the matter be and walk away.")
	EventBus.encounter_choice_resolved.emit()
	EventBus.player_changed.emit()


## Gather materials from a place's gathering table (see Exploration.gather).
func gather(table: Array, days: int) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var season := Calendar.season_of(GameClock.total_days)
	var rolled: Array = []
	var base := Exploration.gather_table_for(player, data, table, season)
	var found := Exploration.gather(player, HerbLore.skill_table(data.herb_lore, base, player.gather_xp), rng, rolled)
	HerbLore.bonus_units(data.herb_lore, found, player.gather_xp, rng)
	Exploration.note_seasonal_gather(player, rolled, season)
	var kind_today := Weather.of(data, current_region, GameClock.total_days)
	var stormed := Weather.herb_penalty(data, kind_today, found)
	var thrived: Array[String] = Weather.herb_bonus(data, kind_today, found, rng)
	for item_id in thrived:
		found[item_id] = int(found[item_id]) + 1
	var tipped := Folk.tip_bonus(data, world_flags, GameClock.total_days, current_region, Exploration.gather_table_for(player, data, table, season))
	for item_id in tipped:
		found[item_id] = int(found.get(item_id, 0)) + int(tipped[item_id])
	var notes: PackedStringArray = []
	for item_id in found:
		player.add_item(item_id, found[item_id])
		notes.append("+%d %s" % [found[item_id], Items.item_plural(data, item_id, found[item_id])])
	var first_finds: PackedStringArray = []
	for item_id in found:
		if data.items.get(item_id, {}).get("tags", []).has("herb") and HerbLore.record_find(player, item_id, int(found[item_id])):
			first_finds.append(String(data.items[item_id]["name"]))
	var old_rank := HerbLore.rank_name(data.herb_lore, player.gather_xp)
	player.gather_xp += HerbLore.xp_gain(data.herb_lore, base, found) + HerbLore.FIRST_FIND_XP * first_finds.size()
	if HerbLore.rank_name(data.herb_lore, player.gather_xp) != old_rank:
		EventBus.post("Your herb lore has improved: %s." % HerbLore.rank_name(data.herb_lore, player.gather_xp), "progress")
	if notes.is_empty():
		EventBus.post("You search for %s but find nothing worth taking." % Calendar.format_duration(days))
	else:
		EventBus.post("You gather for %s. (%s)" % [Calendar.format_duration(days), ", ".join(notes)], "progress")
	for herb_name in first_finds:
		EventBus.post("First find: %s!" % herb_name, "progress")
	for item_id in tipped:
		var tip: Dictionary = Folk.active_tip(world_flags, GameClock.total_days)
		var friend: CharacterData = npcs.get(String(tip.get("npc_id", "")))
		EventBus.post("%s's tip was good: +%d %s." % [friend.name if friend != null else "Your friend", tipped[item_id], Items.item_plural(data, item_id, tipped[item_id])], "info")
	if not stormed.is_empty():
		EventBus.post("The storm batters the herbs: each stack yields less.", "info")
	for item_id in thrived:
		EventBus.post("The rain has the herbs thriving: +1 %s." % Items.item_plural(data, item_id, 1), "info")
	if Exploration.locked_gather_count(player, data, table) > 0:
		EventBus.post("You sense rarer treasures here, but your cultivation is too shallow to find them.")
	_pass_time(days)


## The friend's tip in force, for the UI: "" or "Tip: Spirit Grass in Misty Forest (4 days left)".
func active_tip_text() -> String:
	var tip := Folk.active_tip(world_flags, GameClock.total_days)
	if tip.is_empty():
		return ""
	var left := int(tip["until"]) - GameClock.total_days
	return "Tip: %s in %s (%s left)" % [data.items.get(String(tip["item"]), {}).get("name", tip["item"]), data.regions.get(String(tip["region"]), {}).get("name", tip["region"]), Calendar.format_duration(left + 1)]


## Fish a pond's catch table (FISH-001): like gather, but the weather moves the chance of a catch.
## `quality` (0..1, FISH-003) is how well the cast went; 0.5 is an ordinary one.
func fish(table: Array, days: int, place_name: String = "", quality: float = 0.5) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var season := Calendar.season_of(GameClock.total_days)
	var mult := Weather.fishing_multiplier(data, Weather.of(data, current_region, GameClock.total_days))
	var base := Exploration.gather_table_for(player, data, table, season)
	var usable := Weather.scale_catch(Fishing.skill_table(base, quality, player.fishing_xp), mult)
	var found: Dictionary = {}
	if Fishing.got_away(quality, rng):
		EventBus.post("A fish takes the bait, then it got away.")
	else:
		found = Exploration.gather(player, usable, rng)
		var trophy := Fishing.trophy_in(base, found)
		if trophy != "" and not Fishing.trophy_allowed(quality, player.fishing_xp):
			found = {}
			if quality >= 0.5:
				EventBus.post("Something huge takes the bait and snaps the line.")
	base = Fishing.filter_trophy(base, quality, player.fishing_xp)
	var old_rank := Fishing.rank_name(player.fishing_xp)
	player.fishing_xp += Fishing.xp_gain(base, found)
	var notes: PackedStringArray = []
	var first_catches: PackedStringArray = []
	var trophy_caught := ""
	for item_id in found:
		player.add_item(item_id, found[item_id])
		notes.append("+%d %s" % [found[item_id], Items.item_plural(data, item_id, found[item_id])])
		if data.items.get(item_id, {}).get("tags", []).has("fish") and Fishing.record_catch(player, item_id, int(found[item_id])):
			first_catches.append(String(data.items[item_id]["name"]))
			player.fishing_xp += Fishing.FIRST_CATCH_XP
			if Fishing.trophy_in(base, {item_id: 1}) != "":
				trophy_caught = String(data.items[item_id]["name"])
	var where := " at the %s" % place_name if place_name != "" else ""
	if notes.is_empty():
		EventBus.post("You fish for %s%s but nothing bites." % [Calendar.format_duration(days), where])
	else:
		EventBus.post("You fish for %s%s: %s." % [Calendar.format_duration(days), where, ", ".join(notes)], "progress")
	for fish_name in first_catches:
		EventBus.post("First catch: %s!" % fish_name, "progress")
	if trophy_caught != "":
		EventBus.post("Pond legend: you landed the %s!" % trophy_caught, "progress")
	# After the first-catch bonus, so a rank reached through it is announced too.
	if Fishing.rank_name(player.fishing_xp) != old_rank:
		EventBus.post("Your fishing has improved: %s." % Fishing.rank_name(player.fishing_xp), "progress")
	_pass_time(days)


## FISH-002: cook a home meal (data/recipes.json home_meals) from ingredients in the pack.
func cook_meal(meal_id: String) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var result := Cooking.cook(player, data, meal_id)
	if not result["ok"]:
		EventBus.post(String(result["reason"]), "warning")
		return
	EventBus.post("You cook %s: +%d %s." % [Cooking.meal(data, meal_id)["name"], result["count"], Items.item_plural(data, String(result["item"]), int(result["count"]))], "progress")
	EventBus.player_changed.emit()
	_pass_time(int(result["days"]))


func sell_item(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var result := Items.sell(player, data, item_id, quantity, price_season())
	if result["ok"]:
		EventBus.post("You sell %d %s for %d spirit stones." % [quantity, Items.item_plural(data, item_id, quantity), result["stones"]])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Sells every full stack in `ids` (see Items.bulk_sell_ids) with one message.
## Returns the stones earned.
func sell_all(ids: Array) -> int:
	EventBus.topic = "trade"
	if not _can_act():
		return 0
	var sold := 0
	var stones := 0
	for id in ids:
		var count := player.item_count(id)
		var result := Items.sell(player, data, id, count, price_season())
		if result["ok"]:
			sold += count
			stones += int(result["stones"])
	if sold > 0:
		EventBus.post("You sell %d %s for %d spirit stones." % [sold, "item" if sold == 1 else "items", stones])
	else:
		EventBus.post("You have nothing to sell.", "warning")
	EventBus.player_changed.emit()
	return stones


# --- Dialogue ----------------------------------------------------------------
# A dialogue window (or the NPC's own menu) calls start_dialogue, renders
# dialogue_view() and calls choose_dialogue until dialogue_ended fires.

func start_dialogue(npc_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var dialogue := _npc_dialogue(npc_id)
	var npc: CharacterData = npcs.get(npc_id)
	if dialogue.is_empty() or npc == null or not npc.alive:
		return
	var node := Dialogue.entry_node(dialogue, _dialogue_ctx(npc_id))
	if node == "":
		return
	dialogue_npc = npc_id
	dialogue_event = ""
	dialogue_node = node
	_greet_renowned(npc_id)
	EventBus.dialogue_requested.emit(npc_id)


## Start a story event: a dialogue file (data/dialogue/) not bound to an NPC.
## `once_flag` (optional) is a world flag set when it starts; an event whose
## flag is already set does not start. Returns true if it started.
func start_event(dialogue_id: String, once_flag: String = "") -> bool:
	EventBus.topic = "world"
	if not _can_act() or in_dialogue() or not data.dialogues.has(dialogue_id):
		return false
	if once_flag != "" and world_flags.get(once_flag, false):
		return false
	var node := Dialogue.entry_node(data.dialogues[dialogue_id], _dialogue_ctx(""))
	if node == "":
		return false
	if once_flag != "":
		world_flags[once_flag] = true
	dialogue_npc = ""
	dialogue_event = dialogue_id
	dialogue_node = node
	EventBus.dialogue_requested.emit("")
	return true


## Starts the pending intro event of a fresh character, once (world flag
## INTRO_EVENT_FLAG). Called by the HUD when it is ready to show it.
func start_pending_event() -> void:
	var event_id := pending_event
	pending_event = ""
	if event_id != "":
		start_event(event_id, INTRO_EVENT_FLAG)


## True while a conversation or story event is in progress.
func in_dialogue() -> bool:
	return dialogue_npc != "" or dialogue_event != ""


## The current node: {id, speaker, text, choices: [{index, label, disabled,
## reason}]}, or {} when no conversation is in progress.
func dialogue_view() -> Dictionary:
	if not in_dialogue():
		return {}
	return Dialogue.view(_current_dialogue(), dialogue_node, _dialogue_ctx(dialogue_npc))


## Picks choice `index` (from dialogue_view) of the current node. Emits
## dialogue_ended once effects and time are applied if the conversation is over.
func choose_dialogue(index: int) -> void:
	EventBus.topic = "world"
	if not in_dialogue() or not _can_act():
		return
	var npc_id := dialogue_npc
	var result := Dialogue.choose(_current_dialogue(), dialogue_node, index, _dialogue_ctx(npc_id))
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	if result["favor"] != 0 and npc_id != "":
		var before := _rival_attitude()
		npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + result["favor"]
		_post_attitude_change(before)
	if not result["notes"].is_empty():
		EventBus.post("(%s)" % ", ".join(result["notes"]), "karma")
	dialogue_node = result["next"]
	_pass_time(result["days"])
	if dialogue_node == "" or not _can_act():
		end_dialogue()
	else:
		EventBus.player_changed.emit()


func end_dialogue() -> void:
	var npc_id := dialogue_npc
	dialogue_npc = ""
	dialogue_node = ""
	dialogue_event = ""
	EventBus.dialogue_ended.emit(npc_id)
	EventBus.player_changed.emit()


## True if talking to `npc_id` would open a conversation file.
func has_dialogue(npc_id: String) -> bool:
	return not _npc_dialogue(npc_id).is_empty()


## A named NPC's own dialogue file; generated adults (no def) fall back to
## GENERIC_DIALOGUE, children have nothing to say.
func _npc_dialogue(npc_id: String) -> Dictionary:
	if data.npcs.has(npc_id):
		return data.dialogues.get(data.npcs[npc_id].get("dialogue", ""), {})
	var npc: CharacterData = npcs.get(npc_id)
	if npc == null or npc.age_years() < int(data.family.get("adult_age", 16)):
		return {}
	return data.dialogues.get(GENERIC_DIALOGUE, {})


## The dialogue file in progress: the story event's, else the NPC's.
func _current_dialogue() -> Dictionary:
	if dialogue_event != "":
		return data.dialogues.get(dialogue_event, {})
	return _npc_dialogue(dialogue_npc)


func _dialogue_ctx(npc_id: String) -> Dictionary:
	return {"player": player, "npc": npcs.get(npc_id), "data": data, "flags": world_flags, "favor": int(npc_favor.get(npc_id, 0)), "rival": Rivals.rival_of(player, npcs)}


## Spend time courting an NPC (needs some favor first); raises their favor.
func court(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := Family.court(player, npcs.get(npc_id), int(npc_favor.get(npc_id, 0)), data, npcs)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var courted := NpcClans.scaled_favor(npc_clans, data, npc_id, int(result["favor"]), int(result["favor"]))
	var before := _rival_attitude()
	npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + courted
	EventBus.post("You spend days in %s's company. They warm to you. (%s)" % [npcs[npc_id].name, Family.favor_progress(int(npc_favor[npc_id]), data)], "progress")
	_post_attitude_change(before)
	_pass_time(result["days"])


## WORLD-003: what a neighbour says in passing today given your favor with them ("" if nothing).
func greeting_for(npc_id: String) -> String:
	var npc: CharacterData = npcs.get(npc_id)
	if npc == null:
		return ""
	var line := Folk.greeting(npc, int(npc_favor.get(npc_id, 0)), GameClock.total_days, data, world_flags, Weather.of(data, current_region, GameClock.total_days)).replace("{player}", player.name)
	if line.contains("{partner}"):
		line = line.replace("{partner}", String(npcs[npc.spouses.back()].name) if not npc.spouses.is_empty() and npcs.has(npc.spouses.back()) else "my beloved")
	if line.contains("{child}"):
		line = line.replace("{child}", String(npcs[npc.children.back()].name) if not npc.children.is_empty() and npcs.has(npc.children.back()) else "the little one")
	return line


## WORLD-007: the generated villager dropping by today ("" = nobody). The world places them and the Look line reports it.
func visitor_today() -> String:
	if player == null:
		return ""
	var region: Dictionary = data.regions.get(current_region, {})
	if Npcs.visit_place_of(region, FamilyHome.has_home(player, npcs, data, current_region)).is_empty():
		return ""
	var weather := Weather.of(data, current_region, GameClock.total_days)
	return Folk.visitor(npcs, npc_favor, data, player, current_region, GameClock.total_days, weather, player.folk_visit_day)


## WORLD-007: where today's visitor stands ({} for anyone else).
func visit_place_for(npc_id: String) -> Dictionary:
	if npc_id == "" or npc_id != visitor_today():
		return {}
	return Npcs.visit_place_of(data.regions.get(current_region, {}), FamilyHome.has_home(player, npcs, data, current_region))


## FOLK-006: where villagers made friends by your mediation stand today (npc id -> place; empty when no mark).
func together_places() -> Dictionary:
	if player == null:
		return {}
	var day := GameClock.total_days
	return Folk.together_places(npcs, world_flags, current_region, data.regions.get(current_region, {}), day, Weather.of(data, current_region, day))


## WORLD-007: why you cannot share tea with `npc_id` now ("" when you can).
func check_tea(npc_id: String) -> String:
	if npc_id == "" or npc_id != visitor_today():
		return "There is nobody here to share tea with."
	if int(player.folk_visit_day.get(npc_id, -1)) == GameClock.total_days:
		return "You have already shared tea today."
	return ""


## WORLD-007: share tea with today's visitor: favor (ignoring the chat cap) and maybe a gathering tip.
func share_tea(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var reason := check_tea(npc_id)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var rules := Folk.visit_rules(data)
	var npc: CharacterData = npcs[npc_id]
	npc_favor[npc_id] = mini(100, int(npc_favor.get(npc_id, 0)) + int(rules["tea_favor"]))
	player.folk_visit_day[npc_id] = GameClock.total_days
	var neighbours: Array = []
	for route: Dictionary in data.regions.get(current_region, {}).get("routes", []):
		neighbours.append(String(route.get("to", "")))
	var season := Calendar.season_of(GameClock.total_days)
	var tip := Folk.roll_tip(player, data, world_flags, current_region, neighbours, int(npc_favor[npc_id]), npc_id, GameClock.total_days, season, rng, float(rules.get("tip_chance", 0.0)))
	EventBus.post(Folk.tea_line(data, String(npc.name), Family.favor_progress(int(npc_favor[npc_id]), data), GameClock.total_days, season, not tip.is_empty()), "progress")
	if not tip.is_empty():
		EventBus.post(Folk.tip_line(data, tip, String(npc.name), GameClock.total_days, Weather.of(data, current_region, GameClock.total_days)), "info")
	EventBus.player_changed.emit()


## FOLK-005: why `npc_id` cannot be asked to come exploring ("" when they can).
func check_companion(npc_id: String) -> String:
	return Folk.check_invite(player, npcs.get(npc_id), int(npc_favor.get(npc_id, 0)), data, current_region, GameClock.total_days)


## FOLK-005: ask a friend to join today's fight (no time passes).
func invite_companion(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var reason := check_companion(npc_id)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	Folk.invite(player, npc_id, GameClock.total_days)
	EventBus.post("%s agrees to come exploring with you today." % npcs[npc_id].name, "progress")
	EventBus.player_changed.emit()


## FOLK-004: why the quarrel `npc_id` is part of cannot be settled now ("" when it can).
func check_quarrel(npc_id: String) -> String:
	return Folk.check_settle(npcs, data, world_flags, current_region, npc_id, GameClock.total_days)


## FOLK-004: the open quarrel `npc_id` is in ({} when none).
func quarrel_of(npc_id: String) -> Dictionary:
	if player == null:
		return {}
	var q := Folk.open_quarrel(world_flags, current_region, GameClock.total_days)
	return q if Folk.quarrel_other(q, npc_id) != "" else {}


## FOLK-004: settle the open quarrel of this region with `choice` (Folk.QUARREL_CHOICES): favor with both, maybe
## alignment and stones. Clears the quarrel. `npc_id` is the villager you came through.
func settle_quarrel(npc_id: String, choice: String) -> Dictionary:
	EventBus.topic = "family"
	if not _can_act():
		return {}
	var reason := check_quarrel(npc_id)
	if reason != "" or not Folk.QUARREL_CHOICES.has(choice):
		EventBus.post(reason if reason != "" else "You cannot settle it that way.", "warning")
		EventBus.player_changed.emit()
		return {}
	var q := Folk.open_quarrel(world_flags, current_region, GameClock.total_days)
	var result := Folk.settle(player, data, q, choice, rng)
	var notes: PackedStringArray = []
	for id: String in result["favor"]:
		var delta := int(result["favor"][id])
		npc_favor[id] = clampi(int(npc_favor.get(id, 0)) + delta, -100, 100)
		if delta != 0:
			notes.append("%s %s" % [npcs[id].name, "%+d" % delta])
	if int(result["alignment"]) != 0:
		Alignment.shift(player, data, int(result["alignment"]))
	if int(result["stones"]) > 0:
		player.add_item("spirit_stone", int(result["stones"]))
		notes.append("+%d spirit stones" % int(result["stones"]))
	world_flags.erase(Folk.quarrel_flag(current_region))
	if bool(result["ok"]):
		Folk.record_mark(data, world_flags, current_region, q, choice, GameClock.total_days)
	var a: String = npcs[q["a"]].name
	var b: String = npcs[q["b"]].name
	var line := ""
	match choice:
		"mediate":
			line = "You hear out both sides and %s." % ("find a settlement they can both live with" if result["ok"] else "only make both of them sulk")
		"side_a":
			line = "You take %s's side against %s." % [a, b]
		"side_b":
			line = "You take %s's side against %s." % [b, a]
		_:
			line = "You offer to keep quiet about the matter, for a price."
	EventBus.post("%s (%s)" % [line, ", ".join(notes)], "progress")
	EventBus.player_changed.emit()
	return result


## WORLD-005: why `npc_id`'s wedding cannot be attended now ("" when it can).
func check_celebration(npc_id: String) -> String:
	if not npcs.has(npc_id):
		return "There is no wedding to attend."
	return Folk.check_attend(world_flags, npc_id, GameClock.total_days)


## WORLD-005: attend the wedding of `npc_id` and their spouse: favor with both, a nudge of alignment, a day.
func attend_celebration(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var reason := check_celebration(npc_id)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var npc: CharacterData = npcs[npc_id]
	var partner_id := ""
	if Folk.celebration_kind(world_flags, npc_id) == Folk.WEDDING:
		for spouse_id in npc.spouses:
			if npcs.has(spouse_id):
				partner_id = String(spouse_id)
				break
	var result := Folk.attend(world_flags, npc_id, partner_id, GameClock.total_days, data)
	var cap := int(data.family.get("acquaintance", {}).get("gift_max_favor", 100))
	var names: Array[String] = []
	for id: String in [npc_id, partner_id]:
		if id == "":
			continue
		var favor := int(npc_favor.get(id, 0))
		npc_favor[id] = favor + clampi(int(result["favor"]), 0, maxi(0, cap - favor))
		names.append(npcs[id].name)
	Alignment.shift(player, data, int(result["alignment"]))
	EventBus.post(String(result["text"]).replace("{names}", " and ".join(names)), "progress")
	_pass_time(int(result["days"]))

## FOLK-002: a friendly villager hands over a small gift when you are greeted (once per cooldown).
## The world calls this once per greeting; `greeting_for` itself has no side effects.
func receive_greeting_gift(npc_id: String) -> void:
	var npc: CharacterData = npcs.get(npc_id)
	if npc == null:
		return
	var gift := Folk.gift(player, npc, int(npc_favor.get(npc.id, 0)), GameClock.total_days, data)
	if gift.is_empty():
		return
	player.add_item(String(gift["item"]), int(gift["count"]))
	player.folk_gift_day[npc.id] = GameClock.total_days
	EventBus.post(String(gift["text"]), "progress")


## WORLD-005/006: the celebration a family event in the current region opens: {kind, ids}, kind "" for none.
## A wedding opens for the pair, a birth (full-month feast) for the mother and her spouses, a death
## (funeral) for the dead one's relatives who live here. The player's own family has its own flow.
func _celebration_for(event: Dictionary) -> Dictionary:
	var none := {"kind": "", "ids": []}
	var id := String(event.get("npc_id", ""))
	if not npcs.has(id):
		return none
	var npc: CharacterData = npcs[id]
	if Npcs.region_of(npc, data) != current_region:
		return none
	match String(event.get("kind", "")):
		"marriage":
			return {"kind": Folk.WEDDING, "ids": [id, event["other_id"]]}
		"birth":
			if player.children.has(id) or player.spouses.has(id):
				return none
			var ids: Array = [id]
			for spouse_id in npc.spouses:
				if npcs.has(spouse_id) and npcs[spouse_id].alive and not player.spouses.has(spouse_id):
					ids.append(String(spouse_id))
			return {"kind": "full_month", "ids": ids}
		"death":
			var mourners := Folk.mourners(npcs, data, npc, current_region, player)
			if not mourners.is_empty():
				return {"kind": "funeral", "ids": mourners}
	return none


## Pass a few days chatting with an NPC who has no dialogue file; raises favor
## up to data/family.json acquaintance.chat_max_favor (enough to court).
func chat(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var favor := int(npc_favor.get(npc_id, 0))
	var result := Family.chat(player, npcs.get(npc_id), favor, data)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var cap := int(data.family.get("acquaintance", {}).get("chat_max_favor", 0))
	var festival := WorldEvents.favor_multiplier(data, world_events, current_region) > 1.0
	var base := NpcClans.scaled_favor(npc_clans, data, npc_id, WorldEvents.scaled_favor(data, world_events, current_region, int(result["favor"])), cap - favor)
	var gain: int = base + Karma.favor_bonus(player, data, npc_id, base, cap - favor - base)
	var before := _rival_attitude()
	npc_favor[npc_id] = favor + gain
	EventBus.post("You pass some time talking with %s. (%s)" % [npcs[npc_id].name, Family.favor_progress(int(npc_favor[npc_id]), data)] + (" The festival warms the mood." if festival else ""))
	_post_attitude_change(before)
	_greet_renowned(npc_id)
	var hint := Family.taste_hint(data, npc_id)
	if hint != "" and int(npc_favor[npc_id]) >= Family.taste_hint_favor(data) and not world_flags.has("taste_told_" + npc_id):
		world_flags["taste_told_" + npc_id] = true
		EventBus.post(hint, "info")
	var visit := Letters.take_visit_bonus(npc_id, data, world_flags)
	if visit > 0:
		npc_favor[npc_id] = mini(100, int(npc_favor[npc_id]) + visit)
		EventBus.post("%s is glad you came when invited. (%s)" % [npcs[npc_id].name, Family.favor_progress(int(npc_favor[npc_id]), data)], "progress")
	if not data.npcs.has(npc_id) and not (player.parents.has(npc_id) or player.children.has(npc_id) or player.spouses.has(npc_id)):
		var neighbours: Array = []
		for route: Dictionary in data.regions.get(current_region, {}).get("routes", []):
			neighbours.append(String(route.get("to", "")))
		var tip := Folk.roll_tip(player, data, world_flags, current_region, neighbours, int(npc_favor[npc_id]), npc_id, GameClock.total_days, Calendar.season_of(GameClock.total_days), rng)
		if not tip.is_empty():
			EventBus.post(Folk.tip_line(data, tip, String(npcs[npc_id].name), GameClock.total_days, Weather.of(data, current_region, GameClock.total_days)), "info")
	_pass_time(result["days"])


## NEWS-002: a renowned player is greeted by name, at most once per NPC per 30 days. Family never.
func _greet_renowned(npc_id: String) -> void:
	if player.parents.has(npc_id) or player.children.has(npc_id) or player.spouses.has(npc_id):
		return
	var key := "greeted_" + npc_id
	if world_flags.has(key) and GameClock.total_days - int(world_flags[key]) < 30:
		return
	var line := Renown.greeting(player, data, current_region, String(npcs[npc_id].name), GameClock.total_days)
	if line == "":
		return
	world_flags[key] = GameClock.total_days
	EventBus.post(line, "progress")


## Ask a stronger NPC for pointers on one of your techniques (MENTOR-001).
func check_pointers(npc_id: String) -> String:
	return Mentorship.check_pointers(player, npcs.get(npc_id), int(npc_favor.get(npc_id, 0)), data, GameClock.total_days, current_region, world_flags)


func ask_pointers(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := Mentorship.give_pointers(player, npcs.get(npc_id), int(npc_favor.get(npc_id, 0)), data, GameClock.total_days)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var text := Mentorship.pointer_line(data, npcs[npc_id].name, result["tech_name"], GameClock.total_days)
	if result["shared"]:
		text += " You both know this art; the advice cuts deep."
	if int(result["levels_gained"]) > 0:
		text += " %s reaches level %d." % [result["tech_name"], Techniques.level(player, result["tech_id"])]
	EventBus.post(text, "progress")
	_pass_time(result["days"])


## A friendly spar with an NPC within a realm of you (SPAR-001): no stones lost,
## no injury, practice for your combat techniques; a win earns a little favor.
func check_spar(npc_id: String) -> String:
	return Mentorship.check_spar(player, npcs.get(npc_id), int(npc_favor.get(npc_id, 0)), data, GameClock.total_days)


func spar_with(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var reason := check_spar(npc_id)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var npc: CharacterData = npcs[npc_id]
	var won := fight_enemy(Mentorship.spar_enemy(npc, data))
	if not _can_act():
		return
	var result := Mentorship.after_spar(player, npc, data, won, GameClock.total_days)
	var before := _rival_attitude()
	if int(result["favor"]) > 0:
		npc_favor[npc_id] = mini(100, int(npc_favor.get(npc_id, 0)) + int(result["favor"]))
	var opening := "%s accepts your challenge." if npc_id == player.rival else "You spar with %s."
	var text := "%s %s" % [opening % npc.name, "You win the bout." if won else "They win the bout."]
	if not (result["practiced"] as PackedStringArray).is_empty():
		text += " Your %s grow sharper." % " and ".join(result["practiced"])
	for line in result["levels"]:
		text += " %s." % line
	EventBus.post(text, "progress")
	if npc_id == player.rival:
		var key := "rival_bouts_won" if won else "rival_bouts_lost"
		LifeStats.add(player, key)
		world_flags[key] = int(world_flags.get(key, 0)) + 1
		if won and int(world_flags[key]) == 1:
			EventBus.post("You best %s in a bout for the first time." % npc.name, "progress")
	_post_attitude_change(before)
	# The bout itself took a day; the spar rule's `days` is the whole visit.
	_pass_time(maxi(0, int(result["days"]) - 1))
	EventBus.player_changed.emit()


## Give one item to an NPC; favor scales with its price, up to
## data/family.json acquaintance.gift_max_favor.
func give_gift(npc_id: String, item_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var favor := int(npc_favor.get(npc_id, 0))
	var result := Family.give_gift(player, npcs.get(npc_id), favor, item_id, data)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var cap := int(data.family.get("acquaintance", {}).get("gift_max_favor", 0))
	var festival := WorldEvents.favor_multiplier(data, world_events, current_region) > 1.0
	var taste := int(result["taste"])
	var gain := int(result["favor"])
	if taste >= 0:
		gain *= Folk.gift_multiplier(world_flags, npc_id, GameClock.total_days, data, true)
		var base := NpcClans.scaled_favor(npc_clans, data, npc_id, WorldEvents.scaled_favor(data, world_events, current_region, gain), cap - favor)
		gain = base + Karma.favor_bonus(player, data, npc_id, base, cap - favor - base)
	var before := _rival_attitude()
	npc_favor[npc_id] = clampi(favor + gain, 0, 100)
	if taste >= 0:
		Karma.on_kindness(player, data, npc_id, "gift")
	var item_name: String = data.items[item_id].get("name", item_id)
	EventBus.post("%s accepts your %s. (%s)" % [npcs[npc_id].name, item_name, Family.favor_progress(int(npc_favor[npc_id]), data)] + (" The festival warms the mood." if festival and taste >= 0 else ""))
	if taste != 0:
		world_flags["taste_%s_%s" % [npc_id, item_id]] = taste
		EventBus.post("%s is delighted." % npcs[npc_id].name if taste > 0 else "%s frowns at the %s." % [npcs[npc_id].name, item_name.to_lower()], "progress" if taste > 0 else "warning")
	_post_attitude_change(before)
	if taste >= 0:
		_clan_deed(npc_id, "gift")  # a disliked gift (taken even at the favor cap) earns no clan kindness
	_pass_time(result["days"])


## Pick the player's gender once, for old saves where it is unknown ("").
func choose_gender(gender: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var reason := Names.check_choose_gender(player, data, gender)
	if reason != "":
		EventBus.post(reason, "warning")
		return
	player.gender = gender
	EventBus.post("You are %s." % gender, "info")
	EventBus.player_changed.emit()


## Propose marriage to an NPC, offering spousal `rank` (data/family.json).
func propose(npc_id: String, rank: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := Family.propose(player, npcs.get(npc_id), int(npc_favor.get(npc_id, 0)), rank, data, npcs)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("%s accepts your proposal and becomes your %s." % [npcs[npc_id].name, Family.rank_name(data, player.gender, rank).to_lower()], "progress")
	_pass_time(result["days"])


## Commit a hostile act (data/karma.json: humiliate, rob, kill) against an NPC.
## Acts with "fight" make you beat them first. The victim and their kin hold a grudge.
func hostile_act(npc_id: String, act_id: String) -> void:
	EventBus.topic = "combat"
	if not _can_act():
		return
	var npc: CharacterData = npcs.get(npc_id)
	var reason := Karma.check_act(player, npc, act_id, data)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var act := Karma.act(data, act_id)
	var won := true
	if bool(act.get("fight", false)):
		EventBus.post("You turn on %s." % npc.name, "danger")
		won = fight_enemy(Karma.npc_enemy(npc, data))
		if not _can_act():
			return
	var before := _rival_attitude()
	var result := Karma.commit(player, npc, act_id, won, npcs, data, rng)
	npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + int(result["favor"])
	var notes: PackedStringArray = result["notes"]
	var suffix := " (%s)" % ", ".join(notes) if not notes.is_empty() else ""
	if not won:
		EventBus.post("%s drives you off.%s" % [npc.name, suffix], "warning")
	else:
		EventBus.post(Karma.act_sentence(npc, act_id, result, data) + suffix, "danger" if not npc.alive else "warning")
	_post_attitude_change(before)
	_clan_deed(npc_id, act_id)
	_pass_time(result["days"])


## FAM-009b: a deed toward an NPC clan member (a karma act or a kindness)
## shifts the clan's relation to the player; a blood feud sets its members
## hunting the player.
func _clan_deed(npc_id: String, deed: String) -> void:
	var result := NpcClans.on_deed(npc_clans, npcs, data, player, npc_id, deed)
	if result.is_empty():
		return
	var clan_name: String = (npc_clans[result["clan_id"]] as ClanData).name
	var change := int(result["change"])
	var standing := NpcClans.standing_name(data, int(result["value"]))
	if change < 0:
		EventBus.post("The %s will remember this. (Relations %+d: %s)" % [clan_name, change, standing], "karma")
	elif change > 0 and result["standing_changed"]:
		EventBus.post("Your kindness to its members warms the %s toward you. (Now %s)" % [clan_name, standing], "karma")
	if int(result["feud"]) > 0:
		EventBus.post("The %s swears a blood feud against you! Its members will hunt you." % clan_name, "danger")


## Posts "Your path has shifted" once when the alignment tier differs from the
## last one announced (the first call only remembers the tier).
var _announced_tier: String = ""

func _announce_tier() -> void:
	if player == null:
		return
	var tier := Alignment.tier_name(player.alignment, data)
	if _announced_tier != "" and tier != _announced_tier:
		EventBus.post("Your path has shifted: you are now %s." % tier, "karma")
	_announced_tier = tier


## Pay spirit stones to clear an NPC's grudge against you (Karma.amends_cost).
func make_amends(npc_id: String) -> void:
	EventBus.topic = "combat"
	if not _can_act():
		return
	var result := Karma.make_amends(player, npcs.get(npc_id), data)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
	else:
		EventBus.post("You offer %s %d spirit stones and an apology. The grudge is settled." % [npcs[npc_id].name, result["cost"]], "progress")
	EventBus.player_changed.emit()


## Cultivate together with a spouse who is in the current region: both gain
## qi with the dual cultivation bonus (data/family.json) and favor rises.
func dual_cultivate(spouse_id: String, days: int, location_density: float = 1.0) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var spouse: CharacterData = npcs.get(spouse_id)
	if spouse != null and spouse.alive and Npcs.region_of(spouse, data) != current_region:
		EventBus.post("%s is not here." % spouse.name, "warning")
		EventBus.player_changed.emit()
		return
	var density := _cultivation_density(location_density, days)
	_start_time_skip()
	var result := Family.dual_cultivate(player, spouse, data, days, density)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	player.last_meditated_day = GameClock.total_days + days
	npc_favor[spouse_id] = Family.add_spouse_favor(data, int(npc_favor.get(spouse_id, 0)), result["favor"])
	EventBus.post("You and %s cultivate together for %s. You gather %d qi; they gather %d." % [spouse.name, Calendar.format_duration(days), int(result["qi_gained"]), int(result["spouse_qi"])])
	if result["stages_gained"] > 0:
		EventBus.post("Your cultivation rises to %s!" % Cultivation.realm_label(player, data), "progress")
	if result["spouse_stages"] > 0:
		EventBus.post("%s rises to %s." % [spouse.name, Cultivation.realm_label(spouse, data)], "progress")
	if result["at_bottleneck"]:
		EventBus.post("You have reached a bottleneck. Attempt a breakthrough to advance.", "warning")
	_pass_time(days, "Cultivating with %s" % spouse.name)


## Spend time with a spouse in the current region trying for a child
## (data/family.json "children"). On conception the carrier's pregnancy begins;
## the birth happens as time passes (see _advance_pregnancies).
func try_for_child(spouse_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var spouse: CharacterData = npcs.get(spouse_id)
	if spouse != null and spouse.alive and Npcs.region_of(spouse, data) != current_region:
		EventBus.post("%s is not here." % spouse.name, "warning")
		EventBus.player_changed.emit()
		return
	var result := Children.try_conceive(player, spouse, data, rng)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	if result["conceived"]:
		var carrier := "You are" if Children.is_pregnant(player) else spouse.name + " is"
		EventBus.post("Heaven smiles on your union: %s with child!" % carrier, "progress")
	else:
		EventBus.post("You and %s spend %s together, but no child is conceived yet." % [spouse.name, Calendar.format_duration(result["days"])])
	_pass_time(result["days"])


## Found the player's clan (data/family.json "clan"): the player becomes its
## Patriarch/Matriarch and their spouses and descendants join.
func found_clan() -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := Clans.found(player, clan, npcs, data, GameClock.total_days)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	clan = result["clan"]
	EventBus.post("You found the %s and become its %s. %d members gather under your banner." % [clan.name, Clans.rank_name(data, Clans.head_rank(data), player.gender), clan.members.size()], "progress")
	if clan.seat != "":
		EventBus.post("%s becomes the seat of the %s." % [Clans.seat_name(clan, data), clan.name])
	_pass_time(result["days"])


## Recruit an NPC in the current region as a clan retainer.
func recruit_to_clan(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var npc: CharacterData = npcs.get(npc_id)
	if npc != null and npc.alive and Npcs.region_of(npc, data) != current_region:
		EventBus.post("%s is not here." % npc.name, "warning")
		EventBus.player_changed.emit()
		return
	var result := Clans.recruit(player, clan, npc, int(npc_favor.get(npc_id, 0)), data)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("%s swears allegiance to the %s." % [npc.name, clan.name], "progress")
	_pass_time(result["days"])


## Give a clan member a rank (data/family.json clan.ranks). Takes no time.
func set_clan_rank(member_id: String, rank_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var member: CharacterData = npcs.get(member_id)
	var result := Clans.promote(clan, member, rank_id, data)
	if result["ok"]:
		EventBus.post("%s is now %s of the %s." % [member.name, Text.a(Clans.rank_name(data, rank_id, member.gender)), clan.name], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Start building (or upgrading) a clan estate building (data/clan_buildings.json),
## paid from the clan treasury. The builders work while the world moves on;
## giving the order takes no time.
func build_clan_building(building_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := ClanEstate.start_build(player, clan, building_id, data)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
	else:
		var what := ClanEstate.building_name(data, building_id)
		if int(result["level"]) > 1:
			what += " (level %d)" % int(result["level"])
		EventBus.post("The %s spends %d spirit stones to raise the %s. It will take %s." % [clan.name, result["cost"], what, Calendar.format_duration(result["days"])], "progress")
	EventBus.player_changed.emit()


## Clan estate over `days` days / `months` month boundaries: construction
## progress, then monthly income, reputation and herb harvests.
func _advance_estate(days: int, months: int) -> void:
	var built := ClanEstate.advance_construction(clan, days)
	if not built.is_empty():
		EventBus.post("The %s's %s is complete (level %d)." % [clan.name, ClanEstate.building_name(data, built["building"]), built["level"]], "progress")
	var yields := ClanEstate.apply_months(clan, player, data, months)
	var herbs: Dictionary = yields["herbs"]
	if not herbs.is_empty():
		var parts: PackedStringArray = []
		for item_id in herbs:
			parts.append("%d %s" % [herbs[item_id], Items.item_plural(data, item_id, herbs[item_id])])
		EventBus.post("Your clan's spirit fields send you %s." % ", ".join(parts))


## Spend time at the Family Home in the current region (FAM-011): the family
## living here grows fonder of the player.
func visit_family_home() -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := FamilyHome.visit(player, npcs, npc_favor, data, current_region)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var names: PackedStringArray = []
	for id in result["gains"]:
		names.append(npcs[id].name)
	EventBus.post("You spend %s at home with %s. The house is warm with laughter." % [Calendar.format_duration(result["days"]), Text.join_and(names)], "progress")
	_pass_time(result["days"], "At home with your family")


## Bring the player's spouses and minor children to live at the Family Home in
## the current region (FAM-011).
func move_household_here() -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := FamilyHome.move_household(player, npcs, data, current_region)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var names: PackedStringArray = []
	for id in result["moved"]:
		names.append(npcs[id].name)
	EventBus.post("%s %s to the family home in %s." % [Text.join_and(names), "moves" if names.size() == 1 else "move", Exploration.region_name(data, current_region)], "progress")
	_pass_time(result["days"])


## Send one of the player's children to a sect as a disciple (FAM-009c).
func send_child_to_sect(child_id: String, sect_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var child: CharacterData = npcs.get(child_id)
	var result := Sects.send_child(player, child, data, sect_id)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("You escort %s to the %s. %s is now %s." % [child.name, (data.sects[sect_id] as SectDef).name, child.name, Sects.member_text(child, data)], "progress")
	_pass_time(result["days"])


## Call one of the player's children home from their sect. Takes no time.
func recall_child_from_sect(child_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var child: CharacterData = npcs.get(child_id)
	if child == null or not player.children.has(child_id) or child.is_rogue():
		EventBus.post("They are not in a sect.", "warning")
		EventBus.player_changed.emit()
		return
	var sect_name := (data.sects[child.sect["id"]] as SectDef).name if data.sects.has(String(child.sect["id"])) else "sect"
	Sects.leave(child)
	EventBus.post("%s leaves the %s and returns home." % [child.name, sect_name])
	EventBus.player_changed.emit()


## Name one of the player's descendants in the clan as its heir (Young
## Master/Mistress). Takes no time.
func designate_heir(person_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var person: CharacterData = npcs.get(person_id)
	var result := Clans.designate_heir(player, clan, person, npcs)
	if result["ok"]:
		EventBus.post("You name %s heir of the %s, its %s." % [person.name, clan.name, Clans.heir_title(data, person.gender)], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Move spirit stones into the clan treasury. Takes no time.
func deposit_to_clan(amount: int) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := Clans.deposit(player, clan, amount)
	if result["ok"]:
		EventBus.post("You deposit %d spirit stones. The %s treasury holds %d." % [amount, clan.name, clan.treasury])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Adopt an orphaned child NPC in the current region (data/family.json "adoption").
func adopt(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var child: CharacterData = npcs.get(npc_id)
	if child != null and child.alive and Npcs.region_of(child, data) != current_region:
		EventBus.post("%s is not here." % child.name, "warning")
		EventBus.player_changed.emit()
		return
	var result := Adoption.adopt(player, child, npcs, data)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	_welcome_adopted(child, result)


## Adopt a foundling from an orphanage or temple in the current region, for a
## donation (Adoption.foundling_donation).
func adopt_foundling() -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var result := Adoption.adopt_foundling(player, npcs, data, rng, current_region)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("You donate %d spirit stones to the caretakers." % result["donation"])
	_welcome_adopted(result["child"], result)


func _welcome_adopted(child: CharacterData, result: Dictionary) -> void:
	npc_favor[child.id] = maxi(int(npc_favor.get(child.id, 0)), int(result["favor"]))
	EventBus.post("You take in %s, a %d-year-old %s with %s, as your own." % [child.name, child.age_years(), "boy" if child.gender == "male" else "girl", SpiritualRoots.describe(child.spiritual_roots, data)], "progress")
	_pass_time(result["days"])


## Give one of your children a monthly training assignment (data/family.json
## "training"), paid in spirit stones each month. Takes no time.
func assign_training(child_id: String, assignment_id: String, profession: String = "") -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var child: CharacterData = npcs.get(child_id)
	var result := Training.assign(player, child, assignment_id, profession, data)
	if result["ok"]:
		var what := Training.assignment_name(data, assignment_id)
		if profession != "" and child.training.has("profession"):
			what += " (%s)" % data.professions[profession].name
		EventBus.post("%s will train: %s, %d spirit stones a month." % [child.name, what, Training.monthly_cost(data, assignment_id)])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Stop paying for a child's training. Takes no time.
func clear_training(child_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var child: CharacterData = npcs.get(child_id)
	var reason := Training.check_child(player, child)
	if reason != "":
		EventBus.post(reason, "warning")
	elif Training.current(child) != "":
		Training.clear(child)
		EventBus.post("%s's training is stopped." % child.name)
	EventBus.player_changed.emit()


## Teach a child in the current region a technique you know.
func teach_technique(child_id: String, tech_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var child: CharacterData = npcs.get(child_id)
	if not _child_is_here(child):
		return
	var result := Training.teach(player, child, tech_id, data)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("You teach %s the %s." % [child.name, data.techniques[tech_id].name], "progress")
	_pass_time(result["days"])


## Give a child in the current region a pill (any usable item) to take at once. Takes no time.
func give_to_child(child_id: String, item_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var child: CharacterData = npcs.get(child_id)
	if not _child_is_here(child):
		return
	var result := Training.give(player, child, item_id, data, world_flags)
	if result["ok"]:
		EventBus.post("%s takes the %s. (%s)" % [child.name, data.items[item_id]["name"], ", ".join(result["notes"])], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func learn_technique(tech_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var def: TechniqueDef = data.techniques.get(tech_id)
	if def != null and def.manual_item != "" and player.item_count(def.manual_item) > 0:
		use_item(def.manual_item)
		return
	EventBus.post("You have no manual for that technique.", "warning")


func practice_technique(tech_id: String, days: int) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	_start_time_skip()
	var result := Techniques.practice(player, data, tech_id, days)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	var def: TechniqueDef = data.techniques[tech_id]
	EventBus.post("You practice the %s for %s." % [def.name, Calendar.format_duration(days)])
	if result["levels_gained"] > 0:
		var mastered := " (mastered)" if Techniques.is_mastered(player, data, tech_id) else ""
		EventBus.post("Your %s reaches level %d%s!" % [def.name, Techniques.level(player, tech_id), mastered], "progress")
	var insights := Dao.on_practice(player, data, tech_id, days, rng)
	for insight_id in insights:
		EventBus.post("Practicing the %s, you comprehend the %s more deeply (level %d)!" % [def.name, Dao.def_of(data, insight_id)["name"], Dao.level(player, insight_id)], "progress")
	_pass_time(days, "Practicing the %s" % def.name)


## Contemplate a Dao insight you have already glimpsed, in seclusion, for `days`.
func contemplate_dao(insight_id: String, days: int) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	_start_time_skip()
	var result := Dao.contemplate(player, data, insight_id, days, rng, Weather.mean_dao_mult(data, current_region, insight_id, GameClock.total_days, days))
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	var insight := Dao.def_of(data, insight_id)
	EventBus.post("You sit in seclusion for %s, contemplating the %s." % [Calendar.format_duration(days), insight["name"]])
	if result["levels"] > 0:
		EventBus.post("Enlightenment! Your %s reaches level %d." % [insight["name"], Dao.level(player, insight_id)], "progress")
	_pass_time(days, "Contemplating the %s" % insight["name"])


## Temper your body to its next stage (BodyTempering): consumes the stage's
## items and days, and may injure you.
func temper_body() -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := BodyTempering.temper(player, data, rng)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("You spend %s tempering your body. You attain %s! (%s)" % [Calendar.format_duration(result["days"]), result["name"], BodyTempering.describe_bonuses(player, data)], "progress")
	if result["injury"] != "":
		EventBus.post("The tempering leaves you with %s." % Injuries.injury_name(data, result["injury"]), "danger")
		EventBus.post(Guidance.injury_news(player, data, result["injury"], current_region, world_flags), "danger")
	_pass_time(result["days"])


## Make a known cultivation method your main method. Re-circulating your qi takes
## techniques.json method_switch_days.
func set_main_method(tech_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Techniques.set_main_method(player, data, tech_id)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	var def: TechniqueDef = data.techniques[tech_id]
	EventBus.post("You spend %s re-circulating your qi along the paths of the %s: %s." % [Calendar.format_duration(result["days"]), def.name, Techniques.describe_method(player, data, tech_id)], "progress")
	if result["days"] > 0:
		_pass_time(result["days"])
	else:
		EventBus.player_changed.emit()


## Activate a secret art: burn its lifespan cost for a temporary combat buff. Takes no time.
func activate_technique(tech_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Techniques.activate(player, data, tech_id)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	var def: TechniqueDef = data.techniques[tech_id]
	var cost := " Your life burns: -%d years of lifespan." % result["years"] if result["years"] > 0 else ""
	EventBus.post("You ignite the %s for %s!%s" % [def.name, Calendar.format_duration(result["days"]), cost], "danger")
	EventBus.player_changed.emit()


## Treat one of your own injuries with your Doctor skill.
func treat_own_injury(injury_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Medicine.treat_self(player, data, injury_id)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	var injury_name := Injuries.injury_name(data, injury_id)
	if result["healed"]:
		EventBus.post("You treat your %s. It is fully healed." % injury_name, "progress")
	else:
		EventBus.post("You treat your %s: %d days of healing. (%s left)" % [injury_name, result["days_healed"], Calendar.format_duration(player.injuries[injury_id])])
	if result["ranks_gained"] > 0:
		_post_rank_up(Medicine.DOCTOR, int(result["ranks_gained"]))
	_pass_time(result["days"])


## Pay a clinic to heal an injury fully.
func visit_clinic(injury_id: String) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var result := Medicine.visit_clinic(player, data, injury_id)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("The doctor heals your %s for %d spirit stones." % [Injuries.injury_name(data, injury_id), result["cost"]], "progress")
	_pass_time(result["days"])


## Treat an injured NPC's worst injury: Doctor xp, alignment and their favor.
func treat_npc(npc_id: String) -> void:
	EventBus.topic = "family"
	if not _can_act():
		return
	var patient: CharacterData = npcs.get(npc_id)
	var result := Medicine.treat_npc(player, patient, data)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var treated := NpcClans.scaled_favor(npc_clans, data, npc_id, int(result["favor"]), int(result["favor"]))
	var before := _rival_attitude()
	npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + treated
	_post_attitude_change(before)
	var injury_name := Injuries.injury_name(data, result["injury"])
	var outcome := "it is fully healed" if result["healed"] else "%s left" % Calendar.format_duration(patient.injuries[result["injury"]])
	var owed := Karma.on_kindness(player, data, npc_id, "treat_npc")
	var debt := ", they owe you" if owed > 0 else ""
	EventBus.post("You treat %s's %s: %s. (+%d favor, alignment %+d, now %s%s)" % [patient.name, injury_name, outcome, treated, result["alignment"], Alignment.tier_name(player.alignment, data), debt], "karma")
	_clan_deed(npc_id, "treat_npc")
	if result["ranks_gained"] > 0:
		_post_rank_up(Medicine.DOCTOR, int(result["ranks_gained"]))
	_pass_time(result["days"])


## Work as a doctor: treat village patients for income, Doctor xp and alignment.
func treat_patients(days: int) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	_start_time_skip()
	var result := Medicine.treat_patients(player, data, days)
	EventBus.post("You treat patients for %s: +%d xp, +%d spirit stones, alignment %+d, now %s." % [Calendar.format_duration(days), int(result["xp"]), result["income"], result["alignment"], Alignment.tier_name(player.alignment, data)], "karma")
	if result["ranks_gained"] > 0:
		_post_rank_up(Medicine.DOCTOR, int(result["ranks_gained"]))
	_gain_renown("patients")
	_pass_time(days, "Treating patients")


## Crafting messages per profession (GameState.refine).
const CRAFT_FLAVOR := {
	"alchemist": {"verb": "refine", "great": "Pill fragrance fills the room!", "fail": "The cauldron cracks and your herbs turn to ash."},
	"blacksmith": {"verb": "forge", "great": "The blade sings as it leaves the forge!", "fail": "The metal cracks under the hammer and the ore is ruined."},
	"talisman_master": {"verb": "inscribe", "great": "The runes blaze with golden light!", "fail": "Your brush slips; the talisman flares and burns to ash."},
	"array_master": {"verb": "refine", "great": "The array flags hum in perfect resonance!", "fail": "A rune line breaks and the array materials crumble to dust."},
	"beast_tamer": {"verb": "mix", "great": "The feed smells so rich that every beast in the street turns its head!", "fail": "The mixture curdles into a reeking mess no beast will touch."},
}


## Refine one batch of a recipe from data/recipes.json. Failure burns the ingredients.
func refine(recipe_id: String) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var prof_id: String = data.recipes[recipe_id]["profession"]
	var had_profession := player.professions.has(prof_id)
	var result := Alchemy.refine(player, data, recipe_id, rng)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var recipe_name: String = data.recipes[recipe_id].get("name", recipe_id)
	if result["success"]:
		LifeStats.add(player, "items_crafted", int(result["count"]))
	var flavor: Dictionary = CRAFT_FLAVOR.get(prof_id, CRAFT_FLAVOR["alchemist"])
	if result["great"]:
		EventBus.post("%s A great success: %s yields +%d %s, +%d xp." % [flavor["great"], recipe_name, result["count"], Items.item_plural(data, String(result["item"]), int(result["count"])), int(result["xp"])], "progress")
	elif result["success"]:
		EventBus.post("You %s %s: +%d %s, +%d xp." % [flavor["verb"], recipe_name, result["count"], Items.item_plural(data, String(result["item"]), int(result["count"])), int(result["xp"])], "progress")
	else:
		EventBus.post("%s %s failed (+%d xp)." % [flavor["fail"], recipe_name, int(result["xp"])], "warning")
	if result["ranks_gained"] > 0:
		_post_rank_up(prof_id, int(result["ranks_gained"]))
	if not player.is_rogue():
		var contribution := int(result["xp"] / (1.0 if Sects.is_favored_profession(player, data, prof_id) else 2.0))
		if Sects.add_contribution(player, data, contribution):
			EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")
	if not had_profession and player.professions.has(prof_id):
		_commissions_month(prof_id)
	_pass_time(result["days"])


## Craft `times` batches in a row, stopping when one is no longer possible
## (missing ingredients, rank) or the character dies.
func refine_batch(recipe_id: String, times: int) -> void:
	EventBus.topic = "trade"
	for i in times:
		if not _can_act() or Alchemy.check(player, data, recipe_id) != "":
			break
		refine(recipe_id)


## Take a sect mission (data/sect_missions.json): beat its enemy if it has
## one (losing fails the mission), then hand in items, earn contribution and
## rewards, and spend the mission's days.
func take_mission(mission_id: String) -> void:
	EventBus.topic = "sect"
	if not _can_act():
		return
	var reason := Sects.check_mission(player, data, mission_id, world_flags)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var mission: Dictionary = data.sect_missions[mission_id]
	var enemy_id := String(mission.get("enemy", ""))
	if enemy_id != "":
		if not fight_enemy(data.enemies[enemy_id], -1, "Sect mission: %s. " % mission["name"]):
			Sects.fail_mission(player, data, mission_id)
			var days := data.sect_mission_loss_cooldown_days
			var tail := " The sect will not send you again for %d days." % days if days > 0 else ""
			if _can_act():
				EventBus.post("You fail the mission: %s.%s" % [mission["name"], tail], "warning")
			return
	_start_time_skip()
	var result := Sects.complete_mission(player, data, mission_id, world_flags)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	LifeStats.add(player, "missions_done")
	var notes: PackedStringArray = result["notes"]
	notes.insert(0, "+%d contribution" % result["contribution"])
	EventBus.post("Mission complete: %s. (%s)" % [mission["name"], ", ".join(notes)], "progress")
	if result["promoted"]:
		EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")
	_pass_time(result["days"], "On a sect mission")


## Fight your sect's promotion trial (sects.json rank `trial`) for the next
## rank. A sparring match: losing can injure you but never kills or robs you.
func attempt_promotion_trial() -> void:
	EventBus.topic = "sect"
	if not _can_act():
		return
	var reason := Sects.check_promotion(player, data)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var sect: SectDef = data.sects[player.sect["id"]]
	var rank_name := sect.rank_name(Sects.next_rank(player, data))
	var enemy := Sects.trial_opponent(data, Sects.trial_enemy(player, data))
	EventBus.post("You step into the trial arena to earn the rank of %s." % rank_name)
	if fight_enemy(enemy):
		Sects.pass_trial(player, data)
		EventBus.post("You pass the trial. Your sect promotes you to %s." % Sects.describe(player, data), "progress")
		EventBus.player_changed.emit()
	elif _can_act():
		EventBus.post("You fail the trial for %s. You may try again." % rank_name, "warning")


## Buy an item from your sect's contribution shop (sects.json `shop`).
## Spending contribution never lowers your rank. Takes no time.
func buy_with_contribution(item_id: String) -> void:
	EventBus.topic = "sect"
	if not _can_act():
		return
	var result := Sects.buy_with_contribution(player, data, item_id)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
	else:
		EventBus.post("The sect treasury grants you %s for %d contribution. (%d contribution left)" % [data.items[item_id].get("name", item_id), result["cost"], Sects.contribution_balance(player)], "progress")
	EventBus.player_changed.emit()


## Attend the sect elder's monthly lecture (sects.json `lecture`): qi, maybe a Dao glimpse.
func attend_lecture() -> void:
	EventBus.topic = "sect"
	if not _can_act():
		return
	var reason := Sects.check_lecture(player, data, GameClock.total_days)
	if reason != "":
		EventBus.post(reason, "warning")
		return
	_start_time_skip()
	var result := Sects.attend_lecture(player, data, rng, GameClock.total_days, _cultivation_density(1.0))
	var scene: String = result["line"] if result["line"] != "" else "You attend %s." % result["name"]
	if int(result["qi"]) == 0:
		EventBus.post("%s Your qi is at a bottleneck; the words settle in your mind instead." % scene, "progress")
	else:
		EventBus.post("%s (+%d qi)" % [scene, int(result["qi"])], "progress")
	if result["insight_id"] != "":
		var insight: Dictionary = Dao.def_of(data, result["insight_id"])
		EventBus.post("A line of the lecture clicks: you glimpse the %s." % insight.get("name", "Dao"), "progress")
	_pass_time(int(result["days"]), "Attending a lecture")
	EventBus.player_changed.emit()


## The lots of `house_id`'s open auction ([] when none is being held).
func auction_lots(house_id: String) -> Array:
	return Auctions.current_lots(auctions, data, house_id, GameClock.total_days, rng.seed)


## Why a bid of `amount` on lot `lot_index` would be refused ("" = allowed).
func check_bid(house_id: String, lot_index: int, amount: int) -> String:
	if not _can_act():
		return "You cannot act."
	return Auctions.check_bid(player, data, auctions, house_id, lot_index, amount, current_region, GameClock.total_days, rng.seed)


## Place one sealed bid on an auction lot (data/auctions.json). Beating the
## hidden NPC maximum wins the lot; otherwise a rival takes it. Takes no time.
func bid(house_id: String, lot_index: int, amount: int) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var result := Auctions.bid(player, data, auctions, house_id, lot_index, amount, current_region, GameClock.total_days, rng.seed)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
	else:
		var item_name: String = data.items[result["item"]].get("name", result["item"])
		var lot_name := item_name if result["count"] == 1 else "%d %s" % [result["count"], item_name]
		if result["won"]:
			EventBus.post("The hammer falls: you win %s for %d spirit stones." % [lot_name, result["price"]], "progress")
		else:
			EventBus.post("A rival bidder outbids you and takes %s for %d spirit stones." % [lot_name, result["price"]], "warning")
	EventBus.player_changed.emit()


## The density cultivate() and dual_cultivate() use at a spot of `location_density`.
func _cultivation_density(location_density: float, days: int = 1) -> float:
	return location_density * region_qi_density(days) * Sects.cultivation_bonus(player, data)


## Days of meditation at a spot of `location_density` until the next stage (-1 = at the bottleneck).
func days_to_next_stage(location_density: float = 1.0) -> int:
	return Cultivation.days_to_next_stage(player, data, _cultivation_density(location_density))


## Preview line for cultivating `days` at a spot of `location_density` (same density as cultivate()).
func meditation_preview(days: int, location_density: float = 1.0) -> String:
	return Guidance.meditation_preview(player, data, days, _cultivation_density(location_density))


## Qi density where the player stands, with the sect cultivation bonus (for hints and the journal).
func hint_density() -> float:
	return region_qi_density() * Sects.cultivation_bonus(player, data)


## Journal entries for the current session (Guidance.journal); no side effects.
func journal_entries() -> Array[Dictionary]:
	return Guidance.journal(player, data, world_flags, GameClock.total_days, current_region, hint_density(), npcs, world_events, clan, npc_favor)


## Qi density of the current region, including active world events (LW-001) and today's weather for the player's root (WEATHER-003).
## With `days` > 1 the weather factor is the mean over those days (RV-016).
func region_qi_density(days: int = 1) -> float:
	return Exploration.qi_density(data, current_region, world_flags) * WorldEvents.qi_multiplier(data, world_events, current_region) * Weather.mean_qi_mult(data, current_region, player, GameClock.total_days, days)


## Merchant price multiplier of the current region's active world events.
## The season shop prices follow (MARKET-001).
func price_season() -> String:
	return Calendar.season_of(GameClock.total_days).to_lower()


func market_multiplier() -> float:
	return WorldEvents.price_multiplier(data, world_events, current_region)


## Buy-side multiplier: world events, local renown and a friend's price. Sell prices use market_multiplier() only.
## With `item_id`, the open shop's own discount for that item applies too (ShopDiscounts, WEATHER-006).
func buy_multiplier(item_id: String = "") -> float:
	var mult := market_multiplier() * Renown.buy_multiplier(player, data, current_region) * Letters.deal_multiplier(player, current_region, GameClock.total_days)
	if item_id != "":
		mult *= ShopDiscounts.discount_mult(data, current_region, shop_name, item_id, world_flags, GameClock.total_days)
	return mult


## Local renown for a source (RENOWN-001); announces a new title.
func _gain_renown(source: String) -> void:
	_announce_renown(Renown.gain(player, data, current_region, source))


## Local renown by amount (RENOWN-004, encounter choices).
func _add_renown(amount: int) -> void:
	_announce_renown(Renown.add(player, data, current_region, amount), false)


## ENC-006: an encounter's `renown` effect is applied in Effects (core), which cannot emit signals;
## raise the title banner here when it crossed a tier.
func _effect_renown_banner(before: int) -> void:
	var title := String(Renown.tier(data, Renown.value(player, current_region)).get("title", ""))
	if title != "" and title != String(Renown.tier(data, before).get("title", "")):
		EventBus.renown_tier_reached.emit(current_region, title)


## `quiet_gain` false also says so when a gain crosses no tier (RENOWN-005).
func _announce_renown(result: Dictionary, quiet_gain: bool = true) -> void:
	if int(result["gained"]) <= 0:
		return
	player.life_stats["best_renown"] = maxi(LifeStats.get_stat(player, "best_renown"), Renown.best(player))
	if String(result["new_tier"]) != "":
		if bool(result.get("first_title", false)):
			LifeStats.add(player, "renown_titles")
		EventBus.post("Your name is %s in %s now." % [String(result["new_tier"]).to_lower(), data.regions[current_region].get("name", current_region)], "progress")
		EventBus.renown_tier_reached.emit(current_region, String(result["new_tier"]))
	elif not quiet_gain:
		EventBus.post("Word of it spreads through %s (renown +%d)." % [data.regions[current_region].get("name", current_region), int(result["gained"])], "progress")


## Hear the market gossip: world events under way and when the next auction
## opens (LW-001b). Takes no time. Posts the lines and returns them (WU-111).
func hear_rumors() -> PackedStringArray:
	EventBus.topic = "world"
	if not _can_act():
		return PackedStringArray()
	var extra := auction_rumors()
	extra.append_array(SectFactions.rumors(data, npcs))
	for text in Guidance.discovery_rumors(player, data, world_flags, current_region):
		if not (data.regions[current_region].get("discovery_rumor", "") == text):
			extra.append(text)
			break
	extra.append_array(Rumors.lines(player, data, world_flags, current_region, GameClock.total_days))
	var lines: PackedStringArray = []
	for line in WorldEvents.rumors(data, world_events, extra, GameClock.total_days):
		EventBus.post(line)
		lines.append(line)
	return lines


## "The Fallen Star Auction House holds its next auction in 3 weeks." per house.
func auction_rumors() -> PackedStringArray:
	var lines: PackedStringArray = []
	for def: Dictionary in data.auction_houses.values():
		if Auctions.is_open(def, GameClock.total_days):
			lines.append("The %s is holding an auction right now." % def.get("name", def["id"]))
		else:
			lines.append("The %s holds its next auction in %s." % [def.get("name", def["id"]), Calendar.format_duration(Auctions.days_until_open(def, GameClock.total_days))])
	return lines


## NPC sects recruit rogue NPCs at a month boundary (LW-002). The player's
## spouses and descendants are never recruited; news only about people the
## player knows.
func _sect_factions_month() -> void:
	var reserved := {}
	for id in player.spouses + Children.descendants(player, npcs):
		reserved[id] = true
	for event in SectFactions.recruit(data, npcs, rng, reserved):
		if Npcs.is_newsworthy(String(event["npc_id"]), player, npc_favor):
			EventBus.post(event["text"], event["category"])
	var fallen := false
	for event in SectFactions.clash(data, npcs, rng):
		fallen = fallen or not event["dead_ids"].is_empty()
		var own_sect := "" if player.is_rogue() else String(player.sect["id"])
		if own_sect != "" and (own_sect == event["winner"] or own_sect == event["loser"]):
			EventBus.post(event["text"], event["category"])
			var call_line := SectFactions.start_call(data, player, world_flags, own_sect, GameClock.total_days)
			if call_line != "":
				EventBus.post(call_line, "warning")
			continue
		for npc_id: String in event["dead_ids"]:
			if Npcs.is_newsworthy(npc_id, player, npc_favor):
				EventBus.post("News arrives: %s %s." % [npcs[npc_id].name, npcs[npc_id].cause_of_death], "info")
	if fallen:
		Npcs.ensure_eligible(npcs, data, rng, Children.descendants(player, npcs))  # a fallen candidate is replaced


## Sects strongest first as {id, name, strength, members} (LW-002).
func sect_standings() -> Array[Dictionary]:
	return SectFactions.standings(data, npcs)


## Festival goods the merchants of the current region sell right now (FEST-002).
## `stock_tags` is the merchant's (null = every festival good in the region, FEST-004).
func festival_stock(stock_tags: Variant = null) -> Array:
	return WorldEvents.shop_items(data, world_events, current_region, stock_tags)


## Expire and roll world events at a month boundary, posting the news.
func _world_events_month() -> void:
	_expire_world_events()
	for started in WorldEvents.roll(data, world_events, GameClock.total_days, rng):
		if Exploration.is_nearby(data, current_region, String(started.get("region", ""))):
			EventBus.post(WorldEvents.news(data, started, true), "warning")
		if String(started.get("region", "")) == current_region and WorldEvents.is_festival(data, String(started["id"])):
			EventBus.festival_started.emit(WorldEvents.event_name(data, String(started["id"])), WorldEvents.news(data, started, true))


## Expire world events whose end_day has passed (checked every day, so an ended event
## can't be joined until the month rolls over), posting the news.
func _expire_world_events() -> void:
	## News of far-off events is dropped; "Hear rumors" still lists active ones.
	for ended in WorldEvents.expire(world_events, GameClock.total_days):
		if Exploration.is_nearby(data, current_region, String(ended.get("region", ""))):
			EventBus.post(WorldEvents.news(data, ended, false), "info")
	_expire_sect_calls()


## Sect calls (LW-002b) lapse; tells the player when their own sect's call is answered by others.
func _expire_sect_calls() -> void:
	var lapsed := SectFactions.expire_calls(world_flags, GameClock.total_days)
	if not player.is_rogue() and lapsed.has(String(player.sect["id"])):
		EventBus.post("The sect's call has been answered by others.", "info", "sect")


## Enter the bracket of the tournament under way here (LW-003): `rounds` spars in
## a row against generated cultivators of your own realm and stage, with no healing between bouts. Losing one ends your run;
## winning all pays the prize. Once per event.
func enter_tournament(event_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var reason := WorldEvents.check_join(data, world_events, player, event_id, "tournament", current_region)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	WorldEvents.instance_in(world_events, event_id, current_region)["done"] = true
	var rounds := int(WorldEvents.def_of(data, event_id)["tournament"]["rounds"])
	EventBus.post("You sign your name on the tournament roll. %d bouts stand between you and the prize." % rounds)
	var hp := -1  # no healing between bouts: each starts with what the last left
	for round_index in rounds:
		var rival := WorldEvents.opponent(data, event_id, "tournament", player, round_index, rng)
		EventBus.post("Bout %d of %d: %s steps into the ring." % [round_index + 1, rounds, rival["name"]])
		var won := fight_enemy(rival, hp)
		hp = last_fight_hp
		if not won:
			if _can_act():
				EventBus.post("You are knocked out of the tournament in bout %d." % (round_index + 1), "warning")
			return
	for note in WorldEvents.pay_prize(data, player, event_id, world_flags, rng):
		EventBus.post(note, "progress")
	LifeStats.add(player, "tournaments_won")
	EventBus.post("You win the tournament! The sects applaud the new champion.", "progress")
	EventBus.player_changed.emit()


## Beat a raider of the incursion under way here (LW-003) for the event's
## `defence` effects. Once per event.
func defend_against_incursion(event_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var reason := WorldEvents.check_join(data, world_events, player, event_id, "defence", current_region)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	WorldEvents.instance_in(world_events, event_id, current_region)["done"] = true
	var raider := WorldEvents.opponent(data, event_id, "defence", player, 0, rng)
	EventBus.post("You rush to the defence against %s." % raider["name"])
	if fight_enemy(raider):
		LifeStats.add(player, "incursions_repelled")
		for note in Effects.apply(player, data, WorldEvents.def_of(data, event_id)["defence"]["effects"], world_flags):
			EventBus.post(note, "progress")
		EventBus.post("The raiders fall back. The people of %s thank you." % Exploration.region_name(data, current_region), "progress")
		EventBus.player_changed.emit()
	elif _can_act():
		EventBus.post("The raider drives you off.", "warning")


## The active event in this region that has an activity, or "" (first in data order).
## `stock_tags` of the asking merchant limit it to festivals whose stalls it fits (FEST-005); [] = any.
func festival_activity_here(stock_tags: Array = []) -> String:
	for def: Dictionary in data.world_events.values():
		var event_id := String(def["id"])
		if not WorldEvents.sold_by(data, event_id, stock_tags):
			continue
		if def.has("activity") and not WorldEvents.instance_in(world_events, event_id, current_region).is_empty():
			return event_id
	return ""


func check_festival_activity(event_id: String) -> String:
	return WorldEvents.check_activity(data, world_events, player, event_id, current_region)


## Take part in a festival's activity (FEST-003): open to anyone, once per festival.
func festival_activity(event_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var result := WorldEvents.do_activity(data, world_events, player, event_id, current_region, world_flags)
	if not bool(result["ok"]):
		EventBus.post(String(result["reason"]), "warning")
		EventBus.player_changed.emit()
		return
	var notes := PackedStringArray(result["notes"])
	EventBus.post(String(result["text"]) + ((" (%s)" % ", ".join(notes)) if not notes.is_empty() else ""), "progress")
	if int(result["days"]) > 0:
		_pass_time(int(result["days"]))
	LifeStats.add(player, "festival_activities")
	EventBus.player_changed.emit()


## Fight an enemy from data/enemies.json.
func fight(enemy_id: String) -> bool:
	EventBus.topic = "combat"
	if not data.enemies.has(enemy_id):
		push_error("Unknown enemy '%s'" % enemy_id)
		return false
	return fight_enemy(data.enemies[enemy_id])


## Ready a combat talisman so it is burned automatically in the next fights.
func ready_talisman(item_id: String) -> void:
	EventBus.topic = "combat"
	if not _can_act():
		return
	var reason := CombatTalismans.ready_talisman(player, data, item_id)
	if reason != "":
		EventBus.post(reason, "warning")
	else:
		EventBus.post("You tuck %s into your sleeve, ready for battle." % Text.a(String(data.items[item_id].get("name", item_id))))
	EventBus.player_changed.emit()


func unready_talisman(item_id: String) -> void:
	EventBus.topic = "combat"
	if not _can_act():
		return
	if CombatTalismans.unready_talisman(player, item_id):
		EventBus.post("You put the %s away." % data.items.get(item_id, {}).get("name", item_id))
	EventBus.player_changed.emit()


## Fight any enemy dictionary in the enemies.json format. Returns true if the
## player won and is still alive.
func fight_enemy(enemy: Dictionary, start_hp: int = -1, prefix: String = "") -> bool:
	EventBus.topic = "combat"
	if not _can_act():
		return false
	devour_target = {}
	last_fight_spoils = PackedStringArray()
	last_fight_companion = ""
	var allies: Array = []
	var companion_id := ""
	if not enemy.get("spar", false):
		var ally_id := Karma.strike_ally(player, npcs, data, current_region, String(enemy.get("id", "")))
		if ally_id != "":
			allies.append(Karma.ally_strike(player, npcs, data, ally_id))
		companion_id = Folk.companion_today(player, GameClock.total_days)
		if companion_id != "" and npcs.has(companion_id) and npcs[companion_id].alive:
			allies.append(Folk.companion_strike(npcs, data, companion_id))
			last_fight_companion = npcs[companion_id].name
			EventBus.post("%s joins the fight at your side." % npcs[companion_id].name, "progress")
		else:
			companion_id = ""
	# win_chance rates a full-HP fight without allies; a wounded bout or an ally
	# strike makes that figure wrong, so the respawn lesson leaves it out then.
	var pre_odds := Combat.win_chance(player, data, enemy) if start_hp < 0 and allies.is_empty() else -1.0
	EventBus.combat_started.emit(enemy)
	var result := Combat.resolve(player, data, enemy, rng, allies, start_hp)
	last_fight_hp = int(result["player_hp"])
	last_fight_playback = {"trace": result["trace"], "player_max": result["player_max_hp"], "enemy_max": result["enemy_max_hp"]}
	# The full blow-by-blow goes out with combat_finished; the log gets a summary.
	var lines: PackedStringArray = result["log"]
	EventBus.post(prefix + lines[0], "danger")
	var outcome := Combat.apply_outcome(player, data, enemy, result, world_flags, rng)
	if companion_id != "":
		var delta := Folk.finish_companion(player, npcs, npc_favor, data, rng, companion_id, bool(result["victory"]))
		EventBus.post("%s %s. (favor %+d)" % [npcs[companion_id].name, "is glad of the fight you won together" if delta >= 0 else "is hurt in the fight you lost", delta], "info")
	var rounds := int(result["rounds"])
	var summary := "%d/%d hp left" % [result["player_hp"], result["player_max_hp"]]
	if rounds == 0:
		summary = "defeated before it could strike, " + summary
	else:
		summary = "%d %s, %s" % [rounds, "round" if rounds == 1 else "rounds", summary]
	if not outcome["notes"].is_empty():
		summary += "; " + ", ".join(outcome["notes"])
	EventBus.post("%s (%s)" % [lines[-1], summary], "progress" if result["victory"] else "danger")
	if result["victory"]:
		var worth := {}
		for item_id in enemy.get("rewards", {}).get("items", {}):
			var price := Items.sell_price(data, String(item_id), price_season())
			if price > 0 and int(enemy["rewards"]["items"][item_id]) > 0:
				var count := int(enemy["rewards"]["items"][item_id])
				worth["+%d %s" % [count, data.items.get(item_id, {}).get("name", item_id)]] = {"price": price, "count": count}
		for note in outcome["notes"]:
			if not String(note).begins_with("Burned:"):
				if worth.has(String(note)):
					last_fight_spoils.append("%s (sells for %d%s)" % [note, worth[note]["price"], " each" if int(worth[note]["count"]) > 1 else ""])
				else:
					last_fight_spoils.append(note)
	var advice := Combat.loss_advice(player, data, enemy, result)
	if advice != "" and not result["victory"] and not bool(enemy.get("friendly", false)):
		advice += Guidance.fairer_fight_note(Guidance.fair_fights(player, data, world_flags, GameClock.total_days, current_region, npcs, npc_favor), String(enemy.get("name", "")))
	last_fight_friendly = bool(enemy.get("friendly", false))
	if last_fight_friendly:
		var days := int(data.family.get("mentorship", {}).get("spar", {}).get("cooldown_days", 0))
		advice = "" if result["victory"] else "No harm done. You can spar again in %d %s." % [days, "day" if days == 1 else "days"]
		last_fight_spoils = PackedStringArray()
	last_loss_advice = advice
	if advice != "" and not outcome["died"]:
		EventBus.post(advice, "danger")
	if result["victory"] and not outcome["died"] and Devouring.is_devourable(data, enemy):
		devour_target = enemy
	if not enemy.get("spar", false):
		LifeStats.add(player, "fights_won" if result["victory"] else "fights_lost")
		if result["victory"] and not bool(enemy.get("friendly", false)) and String(enemy.get("realm", "")) != "":
			world_flags[Guidance.beat_realm_flag(String(enemy["realm"]))] = true
	EventBus.combat_finished.emit(enemy.get("name", "enemy"), result["victory"], result["log"])
	var drained := 0 if outcome["died"] or bool(enemy.get("friendly", false)) else Equipment.drain_after_fight(player, data)
	if drained > 0:
		EventBus.post("Your weapon drinks %d %s of your life. %d years remain." % [drained, "year" if drained == 1 else "years", Cultivation.years_left(player, data)], "danger")
		if player.age_years() >= Cultivation.lifespan_years(player, data):
			_kill("Your weapon drinks the last of your years. You wither and die of old age at %d." % player.age_years())
			EventBus.player_changed.emit()
			return false
	if outcome["died"]:
		var fight_info := {"enemy_id": String(enemy.get("id", "")), "enemy_name": String(enemy.get("name", "enemy"))}
		if pre_odds >= 0.0:
			fight_info["win_chance"] = pre_odds
		_die_violently(outcome["cause"], fight_info)
		return false
	if result["victory"]:
		_try_tame(String(enemy.get("id", "")))
	_pass_time(outcome["days"])
	return bool(result["victory"]) and _can_act()


## Devour the cultivation of the cultivator just beaten (devour_target):
## qi, a big alignment drop and a chance of a heart demon (Devouring).
func devour() -> void:
	EventBus.topic = "combat"
	if not _can_act() or devour_target.is_empty():
		return
	var enemy := devour_target
	devour_target = {}
	var result := Devouring.devour(player, data, enemy, rng)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("You press your palm to the fallen %s's dantian and drink their cultivation dry: +%d qi. (Alignment %+d, now %s)" % [enemy.get("name", "cultivator"), result["qi"], result["alignment"], Alignment.tier_name(player.alignment, data)], "karma")
	if result["stages"] > 0:
		EventBus.post("Your cultivation rises to %s!" % Cultivation.realm_label(player, data), "progress")
	if result["injury"] != "":
		EventBus.post("Their dying will takes root in your heart: you suffer %s." % Injuries.injury_name(data, result["injury"]), "danger")
	_pass_time(result["days"])


## A Beast Tamer who defeats a tameable beast tries to tame it (Beasts.try_tame).
func _try_tame(enemy_id: String) -> void:
	var tame := Beasts.try_tame(player, data, enemy_id, rng)
	if not tame["attempted"]:
		return
	var beast_name := Beasts.beast_name(data, tame["beast"])
	if tame["tamed"]:
		EventBus.post("The beaten %s lowers its head and accepts you as its master. It follows you now." % beast_name, "progress")
	else:
		EventBus.post("You try to tame the %s, but it tears free and flees." % beast_name)
	if tame["ranks_gained"] > 0:
		_post_rank_up(Beasts.PROFESSION, int(tame["ranks_gained"]))
	EventBus.player_changed.emit()


## Feed companion `beast_id` the best beast food you carry (BEAST-001d). Takes no time.
func feed_companion(beast_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var item_id := Beasts.best_food(player, data)
	var result := Beasts.feed(player, data, beast_id, item_id) if item_id != "" else {"ok": false, "reason": "You carry nothing your %s would eat." % Beasts.beast_name(data, beast_id)}
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
	else:
		EventBus.post("Your %s gobbles down %s. (+%d growth)" % [Beasts.beast_name(data, beast_id), Text.a(String(data.items[item_id].get("name", item_id))), result["xp"]])
		if result["levels"] > 0:
			EventBus.post("Your %s grows stronger: level %d!" % [Beasts.beast_name(data, beast_id), Beasts.level(player, data, beast_id)], "progress")
	EventBus.player_changed.emit()


## Release spirit beast companion `index` back to the wild.
func release_companion(index: int) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var released := Beasts.release(player, data, index)
	if released == "":
		EventBus.post("You have no such companion.", "warning")
	else:
		EventBus.post("You set your %s free. It looks back once before vanishing into the wild." % released)
	EventBus.player_changed.emit()


## Bind the Creation Artifact to an anchor place (data/regions.json "anchor_id").
func bind_anchor(anchor_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := CreationArtifact.bind_anchor(player, data, anchor_id)
	if result["ok"]:
		EventBus.post("The Creation Artifact hums as you bind its anchor to %s. You will return here if you fall." % CreationArtifact.anchor_name(data, anchor_id), "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func unbind_anchor(anchor_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	if CreationArtifact.unbind_anchor(player, anchor_id):
		EventBus.post("You release the anchor at %s." % CreationArtifact.anchor_name(data, anchor_id))
	EventBus.player_changed.emit()


## Feed spirit stones to the Creation Artifact for one more life.
func recharge_artifact() -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := CreationArtifact.recharge(player, data)
	if result["ok"]:
		EventBus.post("The artifact drinks %d spirit stones. Lives: %d." % [result["cost"], player.artifact_lives], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Cultivate inside the artifact's Inner World for `days` of world time: the
## dilated inner days count for cultivation and age the body (InnerWorld).
func enter_inner_world(days: int) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	_start_time_skip()
	var result := InnerWorld.cultivate(player, data, days, Sects.cultivation_bonus(player, data))
	if not result["ok"]:
		_skip_before = {}
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	player.last_meditated_day = GameClock.total_days + days
	EventBus.post("You spend %s in the inner world while %s pass outside, and gather %d qi." % [Calendar.format_duration(result["inner_days"]), Calendar.format_duration(days), int(result["qi_gained"])], "progress")
	if result["stages_gained"] > 0:
		EventBus.post("Your cultivation rises to %s!" % Cultivation.realm_label(player, data), "progress")
	if result["at_bottleneck"]:
		EventBus.post("You have reached a bottleneck. Attempt a breakthrough to advance.", "warning")
	_pass_time(days, "In the inner world")


## Plant one carried herb in the artifact's spirit garden (ART-004). Takes no time.
func plant_in_garden(item_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := SpiritGarden.plant(player, data, item_id)
	if result["ok"]:
		EventBus.post("You plant %s in the spirit garden." % Text.a(String(data.items[item_id].get("name", item_id))))
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Harvest every ready plot of the spirit garden. Takes no time.
func harvest_garden() -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var gained := SpiritGarden.harvest(player, data, rng)
	if gained.is_empty():
		EventBus.post("Nothing in the spirit garden is ready yet.", "warning")
	else:
		var parts: PackedStringArray = []
		for item_id in gained:
			parts.append("%d %s" % [gained[item_id], Items.item_plural(data, item_id, gained[item_id])])
		EventBus.post("You harvest the spirit garden: %s." % ", ".join(parts), "progress")
	EventBus.player_changed.emit()


## Rent the region's field plot (FARM-001). Takes no time.
func rent_field() -> void:
	EventBus.topic = "trade"
	var place := FieldPlots.place_def(data, current_region)
	if not _can_act() or place.is_empty():
		return
	var result := FieldPlots.rent(player, current_region, place, GameClock.total_days)
	if result["ok"]:
		EventBus.post("You rent %s for %s (%d spirit stones)." % [place["display_name"], Calendar.format_duration(int(place["rent_days"])), int(place["rent"])], "trade")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Plant one carried herb in the region's rented field. Takes no time.
func plant_field(item_id: String) -> void:
	EventBus.topic = "trade"
	var place := FieldPlots.place_def(data, current_region)
	if not _can_act() or place.is_empty():
		return
	var result := FieldPlots.plant(player, data, place, FieldPlots.key(current_region, place), item_id, GameClock.total_days)
	if result["ok"]:
		EventBus.post("You plant %s in %s." % [Text.a(String(data.items[item_id].get("name", item_id))), place["display_name"]], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Water the region's field by hand (FARM-002): tomorrow counts as a rain day for its crops. Takes no time.
func water_field() -> void:
	EventBus.topic = "trade"
	var place := FieldPlots.place_def(data, current_region)
	if not _can_act() or place.is_empty():
		return
	var weather := Weather.of(data, current_region, GameClock.total_days)
	var result := FieldPlots.water(player, place, FieldPlots.key(current_region, place), GameClock.total_days, weather)
	EventBus.post("You carry water to %s." % place["display_name"] if result["ok"] else result["reason"], "progress" if result["ok"] else "warning")
	EventBus.player_changed.emit()


## Press qi into the region's field (FARM-004): its crops grow 2 days at once. Takes no time.
func nourish_field() -> void:
	EventBus.topic = "trade"
	var place := FieldPlots.place_def(data, current_region)
	if not _can_act() or place.is_empty():
		return
	var result := FieldPlots.nourish(player, place, FieldPlots.key(current_region, place), GameClock.total_days)
	if result["ok"]:
		var name: String = data.items.get(result["item"], {}).get("name", result["item"])
		var left := int(result["days_left"])
		EventBus.post("You press qi into the soil; the %s stirs (%s)." % [name, "ready now" if left <= 0 else "ready in %s" % Calendar.format_duration(left)], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Pay to enlarge the region's field once (FARM-002). Takes no time.
func expand_field() -> void:
	EventBus.topic = "trade"
	var place := FieldPlots.place_def(data, current_region)
	if not _can_act() or place.is_empty():
		return
	var result := FieldPlots.expand(player, place, FieldPlots.key(current_region, place), GameClock.total_days)
	if result["ok"]:
		EventBus.post("You pay %d spirit stones to clear more ground: %s now has %d plots." % [int(place["expand_cost"]), place["display_name"], int(place["max_plots"])], "trade")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Harvest every ripe crop in the region's field. Takes no time.
func harvest_field() -> void:
	EventBus.topic = "trade"
	var place := FieldPlots.place_def(data, current_region)
	if not _can_act() or place.is_empty():
		return
	var result := FieldPlots.harvest(player, place, FieldPlots.key(current_region, place), rng)
	if result["ok"]:
		var parts: PackedStringArray = []
		for item_id in result["items"]:
			var tended_note := ", well tended, +%d" % int(place.get("tended_bonus", FieldPlots.DEFAULT_TENDED_BONUS)) if (result["tended"] as Dictionary).has(item_id) else ""
			parts.append("%d %s%s" % [result["items"][item_id], Items.item_plural(data, item_id, result["items"][item_id]), tended_note])
		EventBus.post("You harvest %s: %s." % [place["display_name"], ", ".join(parts)], "progress")
		if not (result["orphaned"] as Array).is_empty():
			EventBus.post("Some of the crop was an odd, forgotten strain; you salvage a single herb of it.", "info")
	else:
		EventBus.post("Nothing in the field is ready yet.", "warning")
	EventBus.player_changed.emit()


## Feed items (spirit stones, treasures) to the Creation Artifact for energy.
func feed_artifact(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := ArtifactFunctions.feed(player, data, item_id, quantity)
	if result["ok"]:
		EventBus.post("The artifact devours %d %s. (+%d energy, %d total)" % [quantity, Items.item_plural(data, item_id, quantity), result["energy"], player.artifact_energy], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Spend artifact energy to unseal a function (data/artifact.json "functions").
func unlock_artifact_function(function_id: String) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := ArtifactFunctions.unlock(player, data, function_id, world_flags)
	if result["ok"]:
		var def := ArtifactFunctions.get_def(data, function_id)
		EventBus.post("A seal on the Creation Artifact shatters: %s. %s" % [def.get("name", function_id), def.get("description", "")], "progress")
		if String(def.get("flavor", "")) != "":
			EventBus.post(String(def["flavor"]))
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Move items into the artifact's storage space (kept even through death).
func store_in_artifact(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := ArtifactFunctions.store(player, data, item_id, quantity)
	if result["ok"]:
		EventBus.post("You tuck %d %s away inside the artifact." % [quantity, Items.item_plural(data, item_id, quantity)])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Take items back out of the artifact's storage space.
func retrieve_from_artifact(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := ArtifactFunctions.retrieve(player, item_id, quantity)
	if result["ok"]:
		EventBus.post("You draw %d %s out of the artifact." % [quantity, Items.item_plural(data, item_id, quantity)])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


# --- Save data ---------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"player": player.to_dict(),
		"world_flags": world_flags.duplicate(),
		"auctions": auctions.duplicate(true),
		"world_events": world_events.duplicate(true),
		"region": current_region,
		"npcs": Npcs.to_dict(npcs),
		"npc_favor": npc_favor.duplicate(),
		"clan": clan.to_dict() if clan != null else {},
		"npc_clans": NpcClans.to_dict(npc_clans),
		"clock": GameClock.to_dict(),
		# 64-bit ints do not survive JSON floats, so store them as strings.
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
	}


func load_save_dict(d: Dictionary) -> void:
	player = CharacterData.from_dict(d.get("player", {}))
	_announced_tier = Alignment.tier_name(player.alignment, data)
	if not d.get("player", {}).has("known_recipes"):
		Alchemy.grant_rank_recipes(player, data)  # saves from before recipe learning
	CreationArtifact.ensure(player, data)
	world_flags = d.get("world_flags", {})
	auctions = d.get("auctions", {})
	world_events = []
	for instance in d.get("world_events", []):
		if instance is Dictionary and data.world_events.has(String(instance.get("id", ""))):
			world_events.append({"id": String(instance["id"]), "region": String(instance.get("region", "")), "start_day": int(instance.get("start_day", 0)), "end_day": int(instance.get("end_day", 0)), "done": bool(instance.get("done", false)), "activity_done": bool(instance.get("activity_done", false))})
	current_region = d.get("region", data.start_region)
	last_arrival_first_visit = false
	npcs = Npcs.from_dict(d.get("npcs", {}))
	Npcs.ensure_all(npcs, data, rng)
	Npcs.ensure_eligible(npcs, data, rng, Children.descendants(player, npcs))
	npc_favor = {}
	for npc_id in d.get("npc_favor", {}):
		npc_favor[npc_id] = int(d["npc_favor"][npc_id])
	var saved_clan: Dictionary = d.get("clan", {})
	clan = ClanData.from_dict(saved_clan) if not saved_clan.is_empty() else null
	if clan != null and clan.seat == "":
		Clans.move_seat(clan, player.abode, data)
	npc_clans = NpcClans.from_dict(d.get("npc_clans", {}))
	if player.visited_regions.is_empty():
		Exploration.visit(player, current_region)  # older saves (TRAV-001)
		Exploration.backfill_visited(player, data, npcs)  # and their other haunts (TRAV-003)
	# A save from before GUIDE-008 has no notice flags: mark what it already
	# qualifies for as seen, quietly, so loading never floods the log (RV-010).
	if not world_flags.keys().any(func(k: Variant) -> bool: return String(k).begins_with("notice_")):
		for notice in Guidance.unlock_notices(player, data, world_flags, npcs, clan):
			world_flags["notice_" + String(notice["id"])] = true
	NpcClans.ensure(npc_clans, npcs, data, rng)  # older saves gain the clans
	if player.rival == "" or not npcs.has(player.rival):
		Rivals.spawn(player, npcs, data, rng, data.start_region)  # older saves gain a rival
	dialogue_npc = ""
	dialogue_node = ""
	dialogue_event = ""
	pending_event = ""  # a loaded game never replays the intro event
	pending_encounter = ""
	pending_cast = {}
	pending_threat = ""
	if not data.regions.has(current_region):
		current_region = data.start_region
	GameClock.from_dict(d.get("clock", {}))
	EventBus.clear_history()
	load_recap = Guidance.recap(player, data, world_flags, GameClock.total_days, current_region, hint_density(), npcs, world_events, clan)
	for line in load_recap:
		EventBus.post(line, "info")
	rng.seed = String(d.get("rng_seed", "0")).to_int()
	rng.state = String(d.get("rng_state", "0")).to_int()
	# Milestones reached before this save (or before GOAL-001) are awarded silently, so
	# loading never re-announces them; every earned one is re-synced to Steam (idempotent).
	LifeStats.backfill(player, data, world_flags)
	Milestones.award(player, data, world_flags, clan)
	for id in player.milestones:
		Platform.unlock_achievement(String(id))
	EventBus.session_started.emit()
	EventBus.player_changed.emit()


# --- Internals ---------------------------------------------------------------

func letter_request(npc_id: String) -> Dictionary:
	return Letters.open_request(player, npc_id, GameClock.total_days)


func check_letter_request(npc_id: String) -> String:
	var npc: CharacterData = npcs.get(npc_id)
	if npc == null or not npc.alive:
		return "They are gone."
	var npc_region := Npcs.region_of(npc, data)
	if npc_region != current_region:
		return "They are in %s; give it to them in person." % String(data.regions.get(npc_region, {}).get("name", npc_region))
	return Letters.check_answer(player, data, npc_id, GameClock.total_days)


## Gives a letter's asked-for items to the NPC in person (LETTER-003). Takes no time.
func answer_letter_request(npc_id: String) -> void:
	if not _can_act() or check_letter_request(npc_id) != "":
		return
	var req := letter_request(npc_id)
	var item_name := Letters._item_name(data, String(req["item"]))
	var result := Letters.answer(player, data, npc_id, GameClock.total_days, world_flags)
	if not result["ok"]:
		return
	var before := _rival_attitude()
	npc_favor[npc_id] = clampi(int(npc_favor.get(npc_id, 0)) + int(result["favor"]), 0, 100)
	_post_attitude_change(before)
	var notes: PackedStringArray = [Family.favor_progress(int(npc_favor[npc_id]), data)]
	notes.append_array(result["notes"])
	if String(req.get("source", "letter")) == "folk":
		EventBus.post("You give %s %d %s. (%s)" % [npcs[npc_id].name, int(req["count"]), Items.item_plural(data, String(req["item"]), int(req["count"])), ", ".join(notes)], "progress")
	else:
		EventBus.post("You give %s the %s they asked for. (%s)" % [npcs[npc_id].name, item_name, ", ".join(notes)], "progress")
	EventBus.player_changed.emit()


func _can_act() -> bool:
	return player != null and player.alive


## Advance the clock. A non-empty `skip_title` (e.g. "Meditating") also emits
## EventBus.time_skipped with a summary against _start_time_skip()'s snapshot.
func _pass_time(days: int, skip_title: String = "") -> void:
	var posted_before := EventBus.posted_count
	var age_before := player.age_days if player != null else 0
	last_digest = {}
	GameClock.advance(days)
	_record_digest(days, EventBus.posted_count - posted_before)
	if player != null and _month_of(player.age_days) > _month_of(age_before):
		SaveManager.autosave()
	if skip_title != "" and _can_act() and not _skip_before.is_empty():
		var summary := TimeSkip.summarize(skip_title, days, _skip_before, TimeSkip.snapshot(player),
				Cultivation.realm_label(player, data), EventBus.posted_count - posted_before)
		EventBus.time_skipped.emit(days, summary)
	_skip_before = {}
	EventBus.player_changed.emit()


## Folds the posts made during a 5+ day action into last_digest (DAY-001).
func _record_digest(days: int, posted: int) -> void:
	if days < DayDigest.MIN_DAYS or posted <= 0:
		return
	var entries: Array[Dictionary] = []
	var hist := EventBus.history
	for i in range(maxi(0, hist.size() - posted), hist.size()):
		entries.append({"text": hist[i]["text"], "category": hist[i]["category"]})
	var lines := DayDigest.summarize(entries, days)
	if not lines.is_empty():
		last_digest = {"days": days, "lines": lines}


@warning_ignore("integer_division")
static func _month_of(age_days: int) -> int:
	return age_days / Calendar.DAYS_PER_MONTH


## Posts the rank-up line, then what the new rank opens (PROF-008). `ranks_gained` is how many
## ranks the action just added, so a jump over a rank names the recipes of every rank it passed (PROF-010).
func _post_rank_up(prof_id: String, ranks_gained: int = 1) -> void:
	EventBus.post("You are now %s!" % Text.a(Professions.rank_title(player, data, prof_id)), "progress")
	var extra := Professions.rank_up_line(player, data, prof_id, Professions.rank_of(player, prof_id) - ranks_gained)
	if extra != "":
		EventBus.post(extra, "progress")


## Remember the player's numbers before a long action (see _pass_time).
func _start_time_skip() -> void:
	_skip_before = TimeSkip.snapshot(player)


## Awards and announces any newly reached milestones (GOAL-001). Runs on player_changed.
func check_milestones() -> void:
	if player == null:
		return
	for def in Milestones.award(player, data, world_flags, clan):
		EventBus.post("Milestone: %s. %s" % [def["name"], def.get("description", "")], "progress")
		Platform.unlock_achievement(String(def["id"]))
		EventBus.milestone_reached.emit(String(def["id"]), String(def["name"]))


## FOLK-007: the generated villagers whose favor you track, minus your family.
func _friend_ids() -> Array:
	var ids: Array = []
	for id: String in npc_favor:
		var c: CharacterData = npcs.get(id)
		if c == null or data.npcs.has(id) or player.spouses.has(id) or player.children.has(id) or player.parents.has(id):
			continue
		ids.append(id)
	ids.sort()
	return ids


## FOLK-007: a one-time line and small gift the first time a villager's favor reaches each friendship tier.
func check_friendships() -> void:
	if player == null or data.family.get("folk_tiers", []).is_empty():
		return
	var ids := _friend_ids()
	if not player.folk_tiers_seeded:
		# Old save (or first check): record current tiers silently so nothing bursts out.
		for id: String in ids:
			player.folk_tier_seen[id] = maxi(int(player.folk_tier_seen.get(id, -1)), Folk.tier_index(data, int(npc_favor.get(id, 0))))
		player.folk_tiers_seeded = true
		return
	for hit in Folk.new_tiers(data, player.folk_tier_seen, npc_favor, ids):
		var tier: Dictionary = data.family["folk_tiers"][int(hit["tier"])]
		var npc: CharacterData = npcs[hit["id"]]
		player.folk_tier_seen[hit["id"]] = int(hit["tier"])
		if tier.has("line"):
			EventBus.post(String(tier["line"]).replace("{name}", npc.name), "social")
		if tier.has("gift"):
			player.add_item(String(tier["gift"]["item"]), int(tier["gift"]["count"]))


## FOLK-007: "Friend", "Close friend"... for the UI; "" when below the first tier.
func friendship_label(npc_id: String) -> String:
	return Folk.tier_name(data, int(npc_favor.get(npc_id, 0)))


## Announces each newly available feature once (GUIDE-008). Runs on player_changed.
func check_unlock_notices() -> void:
	if player == null:
		return
	for notice in Guidance.unlock_notices(player, data, world_flags, npcs, clan):
		world_flags["notice_" + String(notice["id"])] = true
		EventBus.post(String(notice["text"]), "progress")
		EventBus.last_notice_id = String(notice["id"])
		EventBus.feature_unlocked.emit(String(notice["text"]))
		EventBus.last_notice_id = ""


func _store_year_snapshot() -> void:
	player.year_start_stats = player.life_stats.duplicate()
	player.year_start_realm = Cultivation.realm_label(player, data)
	player.year_start_year = Calendar.year_of(GameClock.total_days)


## Sums up the year that just ended (YEAR-001). A save from before the snapshot
## existed only stores one.
func _on_year_changed(year: int) -> void:
	if not _can_act():
		return
	if player.year_start_realm != "":
		var lines := LifeStats.year_summary(player.year_start_stats, player.life_stats, player.year_start_realm, Cultivation.realm_label(player, data))
		var rival_line := Rivals.year_line(player, Rivals.rival_of(player, npcs), world_flags)
		if rival_line != "":
			lines.append(rival_line)  # last, so it never pushes out the realm line
		for line in lines:
			EventBus.post(line, "progress", "life")
		EventBus.year_reviewed.emit(year, lines, player.year_start_year)
	_store_year_snapshot()


func _on_days_advanced(days: int) -> void:
	if not _can_act():
		return
	var action_topic := EventBus.topic
	EventBus.topic = "cultivation"
	var age_before := player.age_days
	player.age_days += days
	var spouse_favor := Family.spouse_favor_gain(data, age_before, player.age_days)
	if spouse_favor > 0:
		for spouse_id in player.spouses:
			var spouse: CharacterData = npcs.get(spouse_id)
			if spouse != null and spouse.alive:
				npc_favor[spouse_id] = Family.add_spouse_favor(data, int(npc_favor.get(spouse_id, 0)), spouse_favor)
	Karma.decay(player, data, Karma.decay_amount(data, age_before, player.age_days))
	var drift := Bloodlines.drift_amount(player, data, age_before, player.age_days)
	if drift != 0:
		Alignment.shift(player, data, drift)
		EventBus.post("The %s in your veins stirs; your heart shifts (alignment %+d)." % [Bloodlines.bloodline_name(data, player.bloodline), drift], "karma")
	for injury_id in Injuries.pass_days(player, days):
		EventBus.post("Your %s has healed." % Injuries.injury_name(data, injury_id), "progress")
	var lapsed_bounty := "" if _bounty_fight else Bounties.expire(player, data, GameClock.total_days)
	if lapsed_bounty != "":
		var lapsed_enemy: String = Bounties.def_of(data, lapsed_bounty).get("enemy", "")
		EventBus.post("Your bounty on the %s has lapsed." % data.enemies.get(lapsed_enemy, {}).get("name", lapsed_enemy), "info")
	for buff_name in Buffs.pass_days(player, days):
		EventBus.post("The power of your %s fades." % buff_name)
	var weather_of := func(region_id: String, day: int) -> String: return Weather.of(data, region_id, day)
	for ready in FieldPlots.advance(player, data, days, GameClock.total_days, weather_of):
		var ready_region := ready.get_slice(":", 0)
		var ready_item := ready.substr(ready_region.length() + 1)
		EventBus.post("Your %s in %s is ready." % [data.items.get(ready_item, {}).get("name", ready_item), FieldPlots.place_def(data, ready_region).get("display_name", "the field")], "progress")
	for item_id in SpiritGarden.advance(player, data, days):
		EventBus.post("The %s in your spirit garden is ready to harvest." % data.items.get(item_id, {}).get("name", item_id), "progress")
	var season_line := Exploration.season_news(player, data, GameClock.total_days - days, GameClock.total_days)
	if season_line != "":
		EventBus.post(season_line, "info")
	EventBus.topic = "family"
	# NPCs the player knows (favor) or married never marry off-screen.
	var reserved := npc_favor.duplicate()
	for spouse_id in player.spouses:
		reserved[spouse_id] = true
	for event in Npcs.simulate(npcs, data, days, rng, reserved, world_flags):
		var party := _celebration_for(event)
		if party["kind"] != "":
			Folk.start_celebration(world_flags, party["ids"], GameClock.total_days, data, party["kind"])
			var news := Folk.celebration_news(data, party["kind"], GameClock.total_days)
			EventBus.post(news.replace("{region}", data.regions.get(current_region, {}).get("name", current_region)).replace("{text}", event["text"]), "info")
			continue
		# News about generated strangers is noise; only report people the player knows.
		if not Npcs.is_newsworthy(String(event["npc_id"]), player, npc_favor):
			continue
		EventBus.post(event["text"], event["category"])
	_rival_news()
	# Marriages, deaths and moves all thin the pool, so top it up every pass (a load tops it up too).
	Npcs.ensure_eligible(npcs, data, rng, Children.descendants(player, npcs))
	for event in NpcClans.simulate(npc_clans, npcs, data):
		EventBus.post(event["text"], event["category"])
	for event in NpcClans.sync_alliances(npc_clans, npcs, data, player, clan):
		EventBus.post(event["text"], "progress" if event["ally"] == NpcClans.PLAYER else "info", "family")
	@warning_ignore("integer_division")
	if player.age_years() > age_before / Calendar.DAYS_PER_YEAR:
		_prune_dead_npcs()
	_advance_pregnancies(days)
	for legacy: Dictionary in data.inheritances.values():
		if Inheritances.lost_between(legacy, GameClock.total_days - days, GameClock.total_days, world_flags):
			if Inheritances.player_knew(player, legacy):
				LifeStats.add(player, "inheritances_lost")
			EventBus.post(String(legacy.get("rival_news", "Word spreads that someone has claimed the %s." % legacy["name"])), "info")
	@warning_ignore("integer_division")
	var months := player.age_days / Calendar.DAYS_PER_MONTH - age_before / Calendar.DAYS_PER_MONTH
	if months > 0:
		Folk.expire_celebrations(world_flags, GameClock.total_days)
	for i in months:
		EventBus.topic = "sect"
		_sect_month_end()
		EventBus.topic = "world"
		_world_events_month()
		_sect_factions_month()
		_commissions_month()
	EventBus.topic = "world"
	_expire_world_events()
	if not player.commissions.is_empty():
		EventBus.topic = "trade"
		for warning in Commissions.lapse_warnings(player, data, GameClock.total_days - days, GameClock.total_days):
			EventBus.post(warning, "info")
		for lapsed in Commissions.expire(player, GameClock.total_days):
			EventBus.post(Commissions.lapse_text(player, data, lapsed), "info")
			LifeStats.add(player, "commissions_lapsed")
		EventBus.topic = "world"
	if months > 0 or Calendar.DAYS_PER_MONTH - age_before % Calendar.DAYS_PER_MONTH > Sects.DUTY_REMINDER_DAYS:
		if Sects.duty_days_left(player) <= Sects.DUTY_REMINDER_DAYS:
			var reminder := Sects.duty_reminder(player, data)
			if reminder != "":
				EventBus.post(reminder, "warning", "sect")
	EventBus.topic = "family"
	for event in Training.advance(player, npcs, data, months, ClanEstate.training_multiplier(clan, data), world_flags):
		EventBus.post(event["text"], event["category"])
	for repaid in Karma.repay_debts(player, npcs, data, months, rng, world_flags):
		EventBus.post("%s repays a debt of gratitude. (%s)" % [npcs[repaid["npc_id"]].name, ", ".join(repaid["notes"])], "progress")
	for i in months:
		var letter := Letters.monthly(player, npcs, npc_favor, data, rng, world_flags, GameClock.total_days, current_region)
		if not letter.is_empty():
			var line := "A letter from %s: %s" % [npcs[letter["npc_id"]].name, letter["text"]]
			Letters.remember(player, data, line, GameClock.total_days)
			EventBus.letter_arrived.emit(npcs[letter["npc_id"]].name)
			EventBus.post(line + (" (%s)" % ", ".join(letter["notes"]) if not letter["notes"].is_empty() else "") + (" They hope you will bring it when you pass." if letter["request"] else ""), "progress")
	EventBus.topic = "world"
	for i in months:
		var asked := Folk.monthly_request(player, npcs, data, rng, current_region, npc_favor, GameClock.total_days)
		if not asked.is_empty():
			EventBus.post(String(asked["text"]) + " (Give it to them in person within %d days.)" % int(Folk.request_rules(data).get("days", 20)), "info")
		var quarrel := Folk.monthly_quarrel(player, npcs, data, rng, current_region, GameClock.total_days, world_flags)
		if not quarrel.is_empty():
			EventBus.post(Folk.quarrel_text(quarrel, npcs, data) + " (Either of them would welcome a word from you.)", "info")
	for req in player.letter_requests.duplicate():
		var asker: CharacterData = npcs.get(req["npc_id"])
		if asker == null or not asker.alive:
			player.letter_requests.erase(req)
	Letters.expire_deals(player, GameClock.total_days)
	EventBus.topic = "family"
	for gone in Letters.expire_requests(player, GameClock.total_days):
		if String(gone.get("source", "letter")) != "folk":
			EventBus.post("%s no longer waits for your answer." % npcs[gone["npc_id"]].name, "normal")
	if clan != null:
		_advance_estate(days, months)
		for joined in Clans.sync_family(player, clan, npcs, data):
			EventBus.post("%s joins the %s." % [joined, clan.name], "progress")
	EventBus.topic = "world"
	for line in SecretRealms.opening_news(player, data, current_region, GameClock.total_days - days, GameClock.total_days):
		EventBus.post(line, "progress")
	for line in SecretRealms.notice_news(player, data, GameClock.total_days - days, GameClock.total_days):
		EventBus.post(line, "progress")
	for notice_id in SecretRealms.notice_realms(player, data, GameClock.total_days - days, GameClock.total_days):
		EventBus.secret_realm_notice.emit(notice_id)
	for def: Dictionary in data.secret_realms.values():
		if SecretRealms.closed_between(def, GameClock.total_days - days, GameClock.total_days):
			var cleared := SecretRealms.cleared_last_opening(player, def, GameClock.total_days)
			if SecretRealms.rival_claims_inheritance(player, data, String(def["id"]), cleared, world_flags, rng):
				EventBus.post("Word spreads that a rival emerged from the %s carrying the %s. That legacy is gone for good." % [def["name"], def["inheritance"].get("name", "inheritance")], "warning")
	EventBus.topic = action_topic
	_maybe_rival_meeting()
	if player.age_years() >= Cultivation.lifespan_years(player, data):
		_kill("Your lifespan is exhausted. You die of old age at %d." % player.age_years())


## RIVAL-005: word of the rival's breakthroughs once you have met them.
func _rival_news() -> void:
	if player.alive and Rivals.successor_due(world_flags, GameClock.total_days):
		var heir := Rivals.spawn(player, npcs, data, rng, current_region if current_region != "" else data.start_region)
		for flag in [Rivals.SUCCESSOR_DAY_FLAG, Rivals.FIRST_MEETING_FLAG, Rivals.SEEN_REALM_FLAG, Rivals.SURPASSED_FLAG, "rival_death_news", Rivals.BOUTS_WON_FLAG, Rivals.BOUTS_LOST_FLAG]:
			world_flags.erase(flag)
		world_flags[Rivals.MEETING_FROM_FLAG] = GameClock.total_days
		EventBus.post(Rivals.successor_line(heir, String(world_flags.get("rival_predecessor", "your old rival"))), "world")
		world_flags.erase("rival_predecessor")
	if not world_flags.get(Rivals.FIRST_MEETING_FLAG, false):
		return
	if not world_flags.get("rival_death_news", false):
		var dead: CharacterData = npcs.get(player.rival)
		if dead != null and not dead.alive:
			var death_line := Rivals.death_news(player, dead)
			if death_line != "":
				EventBus.post(death_line, "info")
				if Rivals.successor_delay(data) > 0:
					world_flags[Rivals.SUCCESSOR_DAY_FLAG] = GameClock.total_days + Rivals.successor_delay(data)
					world_flags["rival_predecessor"] = dead.name
			world_flags["rival_death_news"] = true
	var rival := Rivals.rival_of(player, npcs)
	if rival == null:
		return
	if not world_flags.has(Rivals.SEEN_REALM_FLAG):
		world_flags[Rivals.SEEN_REALM_FLAG] = rival.realm_index
	else:
		var line := Rivals.news(player, rival, int(world_flags[Rivals.SEEN_REALM_FLAG]), data)
		if line != "":
			EventBus.post(line, "info")
			world_flags[Rivals.SEEN_REALM_FLAG] = rival.realm_index
	if world_flags.get(Rivals.SURPASSED_FLAG, false) and Rivals.overtook(player, rival):
		world_flags.erase(Rivals.SURPASSED_FLAG)
		EventBus.post("%s has overtaken you again." % rival.name, "warning")
	_check_rival_surpassed()


## RIVAL-003: the rival's first meeting plays once around day 10, never over
## another dialogue, a fight, a pending choice or a respawn (the check simply runs
## again at the next day advance). A time-skip summary being prepared (_skip_before)
## also waits: the dialogue would close that overlay.
func _maybe_rival_meeting() -> void:
	if not _can_act() or in_dialogue() or not _skip_before.is_empty() or pending_encounter != "" or pending_threat != "" or not pending_respawn.is_empty():
		return
	if Rivals.first_meeting_due(player, npcs, data, world_flags, GameClock.total_days):
		var rival := Rivals.rival_of(player, npcs)
		if rival != null:
			world_flags[Rivals.SEEN_REALM_FLAG] = rival.realm_index
		start_event(Rivals.FIRST_MEETING_EVENT, Rivals.FIRST_MEETING_FLAG)


## Forgets generated NPCs long dead whom the player has no tie to, so saves
## do not grow forever (FAM-013b, family.json npc_families.prune_dead_years).
func _prune_dead_npcs() -> void:
	var years := int(NpcFamilies.rules(data).get("prune_dead_years", 0))
	if years <= 0:
		return
	var keep := npc_favor.duplicate()
	for id in player.parents + player.children + player.spouses:
		keep[id] = true
	for id in player.grudges.keys() + player.gratitude.keys():
		keep[id] = true
	keep[player.rival] = true
	if clan != null:
		keep[clan.heir] = true
		for id in clan.members:
			keep[id] = true
	for id in Children.descendants(player, npcs):
		keep[id] = true
	Npcs.prune(npcs, keep, years * Calendar.DAYS_PER_YEAR)


## Pays the sect stipend for the month that just ended (if the duty was met).
func _sect_month_end() -> void:
	var duty := Sects.monthly_duty(player, data)
	var earned := Sects.duty_progress(player)
	var result := Sects.month_end(player, data)
	if result["paid"]:
		var parts: PackedStringArray = []
		if result["stones"] > 0:
			parts.append("%d spirit stones" % result["stones"])
		for item_id in result["items"]:
			parts.append("%d %s" % [result["items"][item_id], Items.item_plural(data, item_id, result["items"][item_id])])
		EventBus.post("Your sect pays your monthly stipend: %s." % ", ".join(parts), "progress")
	elif result["skipped"]:
		EventBus.post("You fell short of your sect duty (%d/%d contribution), so this month's stipend is withheld." % [earned, duty], "warning")
	if result["promoted"]:
		EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")


## Pregnancies of the player and of spouses carrying the player's child
## progress; due ones give birth. A spouse carrying an NPC's child (e.g. a
## widow's late husband's) is left to NpcFamilies, which already advances it.
func _advance_pregnancies(days: int) -> void:
	var expecting: Array[CharacterData] = [player]
	for spouse_id in player.spouses:
		var spouse: CharacterData = npcs.get(spouse_id)
		if spouse != null and spouse.alive and String(spouse.pregnancy.get("partner", "")) == player.id:
			expecting.append(spouse)
	for mother in expecting:
		if not Children.advance_pregnancy(mother, days):
			continue
		var father_id := String(mother.pregnancy.get("partner", ""))
		var father: CharacterData = player if father_id == player.id else npcs.get(father_id)
		if father == null:
			mother.pregnancy = {}
			continue
		var region := current_region if mother == player else Npcs.region_of(mother, data)
		var child := Children.give_birth(mother, father, npcs, data, rng, region)
		var mother_name := "you" if mother == player else mother.name
		EventBus.post("A child is born to %s: %s, a %s with %s." % [mother_name, child.name, "son" if child.gender == "male" else "daughter", SpiritualRoots.describe(child.spiritual_roots, data)], "progress")


## Whether `child` (a living NPC) is in the current region; posts a warning if not.
func _child_is_here(child: CharacterData) -> bool:
	if child != null and child.alive and Npcs.region_of(child, data) != current_region:
		EventBus.post("%s is not here." % child.name, "warning")
		EventBus.player_changed.emit()
		return false
	return true


## A death by violence: the Creation Artifact respawns the player if it has a
## life left; otherwise death is final. (Old age always goes straight to _kill.)
func _die_violently(cause: String, fight: Dictionary = {}) -> void:
	if not CreationArtifact.can_respawn(player):
		_kill(cause + " The Creation Artifact has no lives left to pull your soul back.")
		EventBus.player_changed.emit()
		return
	var result := CreationArtifact.respawn(player, data)
	EventBus.post(cause, "danger")
	var place := CreationArtifact.anchor_name(data, result["anchor_id"]) if result["anchor_id"] != "" else Exploration.region_name(data, result["region"])
	EventBus.post("The Creation Artifact pulls your soul back. You awaken at %s, %d qi lost. (%d lives left)" % [place, int(result["qi_lost"]), result["lives_left"]], "warning")
	var moved: bool = result["region"] != current_region
	current_region = result["region"]
	last_arrival_first_visit = false
	pending_respawn = {"cause": cause, "anchor_id": result["anchor_id"], "lives_left": result["lives_left"], "qi_lost": result["qi_lost"]}
	pending_respawn.merge(fight)
	if moved:
		spawn_anchor = result["anchor_id"]
	LifeStats.add(player, "respawns")
	EventBus.player_respawned.emit(result["anchor_id"], result["lives_left"])
	_pass_time(result["days"])
	if moved:
		EventBus.region_changed.emit(current_region)


## After a respawn, awaken at `anchor_id` (any bound anchor, or "" for the
## start region when none are bound) instead of the default respawn point.
## Reloads the region so the player stands at the chosen anchor.
func choose_respawn_anchor(anchor_id: String) -> void:
	EventBus.topic = "cultivation"
	if pending_respawn.is_empty() or not _can_act():
		return
	var valid := CreationArtifact.respawn_choices(player, data).any(func(choice: Dictionary) -> bool: return choice["anchor_id"] == anchor_id)
	if not valid:
		push_error("Not a respawn choice: '%s'" % anchor_id)
		return
	if anchor_id != String(pending_respawn["anchor_id"]):
		var place := CreationArtifact.anchor_name(data, anchor_id) if anchor_id != "" else Exploration.region_name(data, data.start_region)
		EventBus.post("You let the artifact carry your soul to %s instead." % place, "warning")
	pending_respawn = {}
	current_region = CreationArtifact.anchor_region(data, anchor_id)
	last_arrival_first_visit = false
	spawn_anchor = anchor_id
	EventBus.player_changed.emit()
	EventBus.region_changed.emit(current_region)


func _kill(cause: String) -> void:
	player.alive = false
	player.cause_of_death = cause
	EventBus.post(cause, "danger")
	EventBus.player_died.emit(cause)
	SaveManager.record_final_death()
