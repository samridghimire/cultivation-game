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
## Open auctions (Auctions): house_id -> {opening, lots}.
var auctions: Dictionary = {}
## The cultivator just beaten whose cultivation may still be devoured
## (Devouring, DEM-001); {} when none. Not saved: the chance passes with the
## combat report.
var devour_target: Dictionary = {}
## Active world events (WorldEvents, LW-001): [{id, region, start_day, end_day}].
var world_events: Array = []
## Id of the region (data/regions.json) the player is in.
var current_region := ""
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
## Set when the Creation Artifact just respawned the player (ART-005) until
## they pick where to awaken: {cause, anchor_id, lives_left, qi_lost}. Not saved.
var pending_respawn: Dictionary = {}
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


func _ready() -> void:
	data = GameData.load_from_dir()
	for err in data.load_errors:
		push_error("Data error: " + err)
	GameClock.days_advanced.connect(_on_days_advanced)


func has_session() -> bool:
	return player != null


func start_session(character: CharacterData) -> void:
	player = character
	CreationArtifact.ensure(player, data)
	world_flags = {}
	auctions = {}
	devour_target = {}
	world_events = []
	current_region = data.start_region
	npcs = {}
	npc_favor = {}
	clan = null
	dialogue_npc = ""
	pending_encounter = ""
	pending_respawn = {}
	spawn_anchor = ""
	dialogue_event = ""
	pending_event = String(data.artifact.get("intro_event", ""))
	Npcs.ensure_all(npcs, data, rng)
	Npcs.ensure_eligible(npcs, data, rng, Children.descendants(player, npcs))
	npc_clans = {}
	NpcClans.ensure(npc_clans, npcs, data, rng)
	Rivals.spawn(player, npcs, data, rng, data.start_region)
	GameClock.reset()
	EventBus.clear_history()
	EventBus.session_started.emit()
	EventBus.post("%s sets out on the path of cultivation." % player.name, "progress")
	EventBus.player_changed.emit()


func end_session() -> void:
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
	pending_respawn = {}
	spawn_anchor = ""
	dialogue_event = ""
	pending_event = ""


# --- Actions -----------------------------------------------------------------

## `skip_title` heads the time-skip overlay ("In seclusion" at an abode).
func cultivate(days: int, location_density: float = 1.0, skip_title: String = "Meditating") -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	if SpiritualRoots.cultivation_multiplier(player.spiritual_roots, data) <= 0.0:
		EventBus.post("Without a spiritual root, qi slips through you like water.", "warning")
		return
	if Cultivation.is_at_bottleneck(player, data):
		EventBus.post("You are at a bottleneck. More meditation will not help; attempt a breakthrough.", "warning")
		return
	var density := location_density * region_qi_density() * Sects.cultivation_bonus(player, data)
	_start_time_skip()
	var result := Cultivation.cultivate(player, data, days, density)
	EventBus.post("You cultivate for %s and gather %d qi." % [Calendar.format_duration(days), int(result["qi_gained"])])
	if result["stages_gained"] > 0:
		EventBus.post("Your cultivation rises to %s!" % Cultivation.realm_label(player, data), "progress")
	if result["at_bottleneck"]:
		EventBus.post("You have reached a bottleneck. Attempt a breakthrough to advance.", "warning")
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
		EventBus.post("You put %d %s in your abode's chest." % [quantity, data.items.get(item_id, {}).get("name", item_id)])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func retrieve_from_abode(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := Abodes.retrieve(player, data, current_region, item_id, quantity)
	if result["ok"]:
		EventBus.post("You take %d %s from your abode's chest." % [quantity, data.items.get(item_id, {}).get("name", item_id)])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func attempt_breakthrough() -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	if not Cultivation.can_attempt_breakthrough(player, data):
		EventBus.post("You are not ready to break through.", "warning")
		return
	var result := Cultivation.attempt_breakthrough(player, data, rng)
	_report_tribulation(result)
	if result["died"]:
		EventBus.breakthrough_attempted.emit(false, result["realm_name"])
		_die_violently("The final bolt of the %s tribulation tears through you. Your body turns to ash." % result["realm_name"])
		return
	if result["success"]:
		EventBus.post("Breakthrough! You have entered the %s realm." % result["realm_name"], "progress")
		if Bloodlines.update(player, data):
			EventBus.post("Your blood boils and sings: your %s awakens!" % Bloodlines.bloodline_name(data, player.bloodline), "progress")
	else:
		if result["tribulation"].is_empty():
			EventBus.post("Your breakthrough to %s failed (%d%% chance). Your qi scatters." % [result["realm_name"], int(result["chance"] * 100)], "danger")
		else:
			EventBus.post("Your breakthrough to %s fails in the tribulation. Your qi scatters." % result["realm_name"], "danger")
		if result["injury"] != "":
			EventBus.post("You suffer %s." % Injuries.injury_name(data, result["injury"]), "danger")
	EventBus.breakthrough_attempted.emit(result["success"], result["realm_name"])
	_pass_time(BREAKTHROUGH_DAYS)


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
		EventBus.post("You are now %s!" % Text.a(Professions.rank_title(player, data, prof_id)), "progress")
	if not player.is_rogue():
		var contribution := int(result["xp"] / (1.0 if Sects.is_favored_profession(player, data, prof_id) else 2.0))
		if Sects.add_contribution(player, data, contribution):
			EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")
	_pass_time(days, "Working as %s" % Text.a(def.name))


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
	var reason := Deeds.check(player, data, deed, world_flags) if not deed.is_empty() else "Unknown deed."
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
	var result := Deeds.perform(player, data, deed_id, world_flags)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	EventBus.post("%s. (%s)" % [deed["name"], ", ".join(result["notes"])], "karma")
	_pass_time(result["days"])


## Buys one item; `faction` is the sect the merchant belongs to (prices follow reputation).
func buy_item(item_id: String, faction: String = "", quantity: int = 1) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var result := Items.buy(player, data, item_id, quantity, faction, market_multiplier())
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


func travel(region_id: String) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var check := Exploration.check_travel(player, data, current_region, region_id)
	if not check["ok"]:
		EventBus.post(check["reason"], "warning")
		return
	_start_time_skip()
	current_region = region_id
	EventBus.post("After %s on the road you arrive at %s." % [Calendar.format_duration(check["days"]), Exploration.region_name(data, region_id)], "progress")
	_pass_time(check["days"], "Travelling to %s" % Exploration.region_name(data, region_id))
	_road_ambush()
	EventBus.region_changed.emit(region_id)


## After a journey, an NPC with a strong grudge may ambush the player, and a
## grateful one may come to help (Karma, RIV-003).
func _road_ambush() -> void:
	if not _can_act():
		return
	var hunter_id := Karma.roll_hunter(player, npcs, data, rng, 1.0 - ClanEstate.ward(clan, data, current_region))
	if hunter_id == "":
		return
	var hunter: CharacterData = npcs[hunter_id]
	EventBus.post("%s has hunted you down on the road. Your old grudge (%d) will be settled with blood!" % [hunter.name, Karma.grudge(player, hunter_id)], "danger")
	var ally_id := Karma.roll_ally(player, npcs, data, rng, hunter_id)
	if ally_id != "":
		EventBus.post("%s, who owes you a debt, rushes to fight at your side!" % npcs[ally_id].name, "progress")
	var won := fight_enemy(Karma.npc_enemy(hunter, data))
	Karma.after_hunt(player, data, hunter_id, won)
	if ally_id != "":
		player.buffs.erase("ally_aid")


## Explore a place tagged with `tags` (defaults to the region's encounter tags).
func explore(tags: Array = []) -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	if tags.is_empty():
		tags = data.regions.get(current_region, {}).get("encounter_tags", [])
	tags = tags + WorldEvents.encounter_tags(data, world_events, current_region)
	var encounter := Exploration.roll_encounter(player, data, tags, world_flags, rng, Rivals.rival_of(player, npcs), 1.0 - ClanEstate.ward(clan, data, current_region))
	if encounter.is_empty():
		EventBus.post("You search the area but find nothing.")
		_pass_time(1)
		return
	var result := Exploration.resolve(player, data, encounter, world_flags)
	var text := rival_text(String(encounter.get("text", "")))
	if not result["notes"].is_empty():
		text += " (%s)" % ", ".join(result["notes"])
	EventBus.post(text, "danger" if result["enemy"] != "" else "info")
	pending_encounter = ""
	_pass_time(result["days"])
	if not _can_act():
		return
	_rival_consequences(encounter)
	if not _can_act():
		return
	if encounter.has("choices"):
		pending_encounter = String(encounter["id"])
		EventBus.encounter_choice_requested.emit(pending_encounter)
		return
	if result["enemy"] == "":
		return
	if Exploration.should_evade(player, data, result["enemy"]):
		EventBus.post("You sense overwhelming killing intent and slip away before the %s notices you." % data.enemies[result["enemy"]]["name"], "warning")
		return
	fight(result["enemy"])


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
		EventBus.post("You pass the %s." % result["stage_name"], "progress")
	_pass_time(result["days"])


## The pending encounter's choices for the UI: [{index, label, disabled, reason}]
## ([] when no encounter is waiting).
func encounter_choices() -> Array[Dictionary]:
	if pending_encounter == "" or not _can_act():
		return []
	return Exploration.choices(player, data, data.encounters.get(pending_encounter, {}), world_flags)


## Pick choice `index` of the pending encounter: applies its outcome, passes
## its days and starts its fight, if any (a chosen fight is never evaded).
func choose_encounter(index: int) -> void:
	EventBus.topic = "world"
	if pending_encounter == "" or not _can_act():
		return
	var encounter: Dictionary = data.encounters.get(pending_encounter, {})
	var result := Exploration.resolve_choice(player, data, encounter, index, world_flags)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	pending_encounter = ""
	var text := rival_text(String(result["text"]))
	if not result["notes"].is_empty():
		text += " (%s)" % ", ".join(result["notes"])
	if text != "":
		EventBus.post(text, "danger" if result["enemy"] != "" else "karma" if result["karma"] else "info")
	EventBus.encounter_choice_resolved.emit()
	_pass_time(result["days"])
	var choice: Dictionary = encounter["choices"][index]
	if _can_act():
		_rival_consequences(choice)
	if result["enemy"] != "" and _can_act():
		if fight(result["enemy"]):
			_grateful_npc(choice)
	elif _can_act():
		_grateful_npc(choice)


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
	return Rivals.fill(text, Rivals.rival_of(player, npcs), data)


## Applies an encounter's (or choice's) rival fields: rival_grudge and
## rival_favor change the rival's ledger and favor, fight_rival starts a
## non-lethal fight with the rival (RIV-002).
func _rival_consequences(entry: Dictionary) -> void:
	var rival := Rivals.rival_of(player, npcs)
	if rival == null:
		return
	var grudge := int(entry.get("rival_grudge", 0))
	if grudge > 0:
		Karma.add_grudge(player, data, rival.id, grudge)
	var favor := int(entry.get("rival_favor", 0))
	if favor != 0:
		npc_favor[rival.id] = clampi(int(npc_favor.get(rival.id, 0)) + favor, -100, 100)
	if bool(entry.get("fight_rival", false)):
		fight_enemy(Karma.npc_enemy(rival, data))


## Leave the pending encounter without choosing (the UI offers this only when
## every choice is locked).
func dismiss_encounter() -> void:
	EventBus.topic = "world"
	if pending_encounter == "":
		return
	pending_encounter = ""
	EventBus.post("You leave the matter be and walk away.")
	EventBus.encounter_choice_resolved.emit()
	EventBus.player_changed.emit()


## Gather materials from a place's gathering table (see Exploration.gather).
func gather(table: Array, days: int) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var found := Exploration.gather(player, Exploration.gather_table_for(player, data, table), rng)
	var notes: PackedStringArray = []
	for item_id in found:
		player.add_item(item_id, found[item_id])
		notes.append("+%d %s" % [found[item_id], data.items[item_id]["name"]])
	if notes.is_empty():
		EventBus.post("You search for %s but find nothing worth taking." % Calendar.format_duration(days))
	else:
		EventBus.post("You gather for %s. (%s)" % [Calendar.format_duration(days), ", ".join(notes)], "progress")
	if Exploration.locked_gather_count(player, data, table) > 0:
		EventBus.post("You sense rarer treasures here, but your cultivation is too shallow to find them.")
	_pass_time(days)


func sell_item(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	var result := Items.sell(player, data, item_id, quantity)
	if result["ok"]:
		EventBus.post("You sell %d %s for %d spirit stones." % [quantity, data.items[item_id]["name"], result["stones"]])
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


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
		npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + result["favor"]
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
	return {"player": player, "npc": npcs.get(npc_id), "data": data, "flags": world_flags, "favor": int(npc_favor.get(npc_id, 0))}


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
	npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + courted
	EventBus.post("You spend days in %s's company. They warm to you. (+%d favor)" % [npcs[npc_id].name, courted], "progress")
	_pass_time(result["days"])


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
	var base := NpcClans.scaled_favor(npc_clans, data, npc_id, int(result["favor"]), cap - favor)
	var gain: int = base + Karma.favor_bonus(player, data, npc_id, base, cap - favor - base)
	npc_favor[npc_id] = favor + gain
	EventBus.post("You pass some time talking with %s. (+%d favor)" % [npcs[npc_id].name, gain])
	_pass_time(result["days"])


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
	var base := NpcClans.scaled_favor(npc_clans, data, npc_id, int(result["favor"]), cap - favor)
	var gain: int = base + Karma.favor_bonus(player, data, npc_id, base, cap - favor - base)
	npc_favor[npc_id] = favor + gain
	Karma.on_kindness(player, data, npc_id, "gift")
	EventBus.post("%s accepts your %s. (+%d favor)" % [npcs[npc_id].name, data.items[item_id].get("name", item_id), gain])
	_clan_deed(npc_id, "gift")
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
	var result := Karma.commit(player, npc, act_id, won, npcs, data, rng)
	npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + int(result["favor"])
	var notes: PackedStringArray = result["notes"]
	var suffix := " (%s)" % ", ".join(notes) if not notes.is_empty() else ""
	if not won:
		EventBus.post("%s drives you off.%s" % [npc.name, suffix], "warning")
	elif not npc.alive:
		EventBus.post("You kill %s.%s" % [npc.name, suffix], "danger")
	else:
		EventBus.post("%s: %s.%s" % [String(act.get("name", act_id)), npc.name, suffix], "warning")
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
	var density := location_density * region_qi_density() * Sects.cultivation_bonus(player, data)
	_start_time_skip()
	var result := Family.dual_cultivate(player, spouse, data, days, density)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
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
			parts.append("%d %s" % [herbs[item_id], data.items[item_id].get("name", item_id)])
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
	var result := Dao.contemplate(player, data, insight_id, days, rng)
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
		EventBus.post("You are now %s!" % Text.a(Professions.rank_title(player, data, Medicine.DOCTOR)), "progress")
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
	npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + treated
	var injury_name := Injuries.injury_name(data, result["injury"])
	var outcome := "it is fully healed" if result["healed"] else "%s left" % Calendar.format_duration(patient.injuries[result["injury"]])
	var owed := Karma.on_kindness(player, data, npc_id, "treat_npc")
	var debt := ", they owe you" if owed > 0 else ""
	EventBus.post("You treat %s's %s: %s. (+%d favor, alignment %+d%s)" % [patient.name, injury_name, outcome, treated, result["alignment"], debt], "karma")
	_clan_deed(npc_id, "treat_npc")
	if result["ranks_gained"] > 0:
		EventBus.post("You are now %s!" % Text.a(Professions.rank_title(player, data, Medicine.DOCTOR)), "progress")
	_pass_time(result["days"])


## Work as a doctor: treat village patients for income, Doctor xp and alignment.
func treat_patients(days: int) -> void:
	EventBus.topic = "trade"
	if not _can_act():
		return
	_start_time_skip()
	var result := Medicine.treat_patients(player, data, days)
	EventBus.post("You treat patients for %s: +%d xp, +%d spirit stones, alignment %+d." % [Calendar.format_duration(days), int(result["xp"]), result["income"], result["alignment"]], "karma")
	if result["ranks_gained"] > 0:
		EventBus.post("You are now %s!" % Text.a(Professions.rank_title(player, data, Medicine.DOCTOR)), "progress")
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
	var result := Alchemy.refine(player, data, recipe_id, rng)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	var recipe_name: String = data.recipes[recipe_id].get("name", recipe_id)
	var prof_id: String = data.recipes[recipe_id]["profession"]
	var flavor: Dictionary = CRAFT_FLAVOR.get(prof_id, CRAFT_FLAVOR["alchemist"])
	if result["great"]:
		EventBus.post("%s A great success: %s yields +%d %s, +%d xp." % [flavor["great"], recipe_name, result["count"], data.items[result["item"]].get("name", result["item"]), int(result["xp"])], "progress")
	elif result["success"]:
		EventBus.post("You %s %s: +%d %s, +%d xp." % [flavor["verb"], recipe_name, result["count"], data.items[result["item"]].get("name", result["item"]), int(result["xp"])], "progress")
	else:
		EventBus.post("%s %s failed (+%d xp)." % [flavor["fail"], recipe_name, int(result["xp"])], "warning")
	if result["ranks_gained"] > 0:
		EventBus.post("You are now %s!" % Text.a(Professions.rank_title(player, data, prof_id)), "progress")
	if not player.is_rogue():
		var contribution := int(result["xp"] / (1.0 if Sects.is_favored_profession(player, data, prof_id) else 2.0))
		if Sects.add_contribution(player, data, contribution):
			EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")
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
	var reason := Sects.check_mission(player, data, mission_id)
	if reason != "":
		EventBus.post(reason, "warning")
		EventBus.player_changed.emit()
		return
	var mission: Dictionary = data.sect_missions[mission_id]
	var enemy_id := String(mission.get("enemy", ""))
	if enemy_id != "":
		EventBus.post("Sect mission: %s." % mission["name"])
		if not fight_enemy(data.enemies[enemy_id]):
			if _can_act():
				EventBus.post("You fail the mission: %s." % mission["name"], "warning")
			return
	_start_time_skip()
	var result := Sects.complete_mission(player, data, mission_id, world_flags)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
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
		EventBus.post("The sect treasury grants you %s for %d contribution. (%d left)" % [data.items[item_id].get("name", item_id), result["cost"], Sects.contribution_balance(player)], "progress")
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


## Qi density of the current region, including active world events (LW-001).
func region_qi_density() -> float:
	return Exploration.qi_density(data, current_region) * WorldEvents.qi_multiplier(data, world_events, current_region)


## Merchant price multiplier of the current region's active world events.
func market_multiplier() -> float:
	return WorldEvents.price_multiplier(data, world_events, current_region)


## Hear the market gossip: world events under way and when the next auction
## opens (LW-001b). Takes no time.
func hear_rumors() -> void:
	EventBus.topic = "world"
	if not _can_act():
		return
	var extra := auction_rumors()
	extra.append_array(SectFactions.rumors(data, npcs))
	for line in WorldEvents.rumors(data, world_events, extra, GameClock.total_days):
		EventBus.post(line)


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


## Sects strongest first as {id, name, strength, members} (LW-002).
func sect_standings() -> Array[Dictionary]:
	return SectFactions.standings(data, npcs)


## Expire and roll world events at a month boundary, posting the news.
func _world_events_month() -> void:
	for ended in WorldEvents.expire(world_events, GameClock.total_days):
		EventBus.post(WorldEvents.news(data, ended, false), "info")
	for started in WorldEvents.roll(data, world_events, GameClock.total_days, rng):
		EventBus.post(WorldEvents.news(data, started, true), "warning")


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
func fight_enemy(enemy: Dictionary) -> bool:
	EventBus.topic = "combat"
	if not _can_act():
		return false
	devour_target = {}
	var allies: Array = []
	if not enemy.get("spar", false):
		var ally_id := Karma.strike_ally(player, npcs, data, current_region, String(enemy.get("id", "")))
		if ally_id != "":
			allies.append(Karma.ally_strike(player, npcs, data, ally_id))
	var result := Combat.resolve(player, data, enemy, rng, allies)
	# The full blow-by-blow goes out with combat_finished; the log gets a summary.
	var lines: PackedStringArray = result["log"]
	EventBus.post(lines[0], "danger")
	var outcome := Combat.apply_outcome(player, data, enemy, result, world_flags, rng)
	var rounds := int(result["rounds"])
	var summary := "%d %s, %d/%d hp left" % [rounds, "round" if rounds == 1 else "rounds", result["player_hp"], result["player_max_hp"]]
	if not outcome["notes"].is_empty():
		summary += "; " + ", ".join(outcome["notes"])
	EventBus.post("%s (%s)" % [lines[-1], summary], "progress" if result["victory"] else "danger")
	if result["victory"] and not outcome["died"] and Devouring.is_devourable(data, enemy):
		devour_target = enemy
	EventBus.combat_finished.emit(enemy.get("name", "enemy"), result["victory"], result["log"])
	var drained := 0 if outcome["died"] else Equipment.drain_after_fight(player, data)
	if drained > 0:
		EventBus.post("Your weapon drinks %d %s of your life. %d years remain." % [drained, "year" if drained == 1 else "years", Cultivation.years_left(player, data)], "danger")
		if player.age_years() >= Cultivation.lifespan_years(player, data):
			_kill("Your weapon drinks the last of your years. You wither and die of old age at %d." % player.age_years())
			EventBus.player_changed.emit()
			return false
	if outcome["died"]:
		_die_violently(outcome["cause"])
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
	EventBus.post("You press your palm to the fallen %s's dantian and drink their cultivation dry: +%d qi. (Alignment %+d)" % [enemy.get("name", "cultivator"), result["qi"], result["alignment"]], "karma")
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
		EventBus.post("You are now %s!" % Text.a(Professions.rank_title(player, data, Beasts.PROFESSION)), "progress")
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
			parts.append("%d %s" % [gained[item_id], data.items.get(item_id, {}).get("name", item_id)])
		EventBus.post("You harvest the spirit garden: %s." % ", ".join(parts), "progress")
	EventBus.player_changed.emit()


## Feed items (spirit stones, treasures) to the Creation Artifact for energy.
func feed_artifact(item_id: String, quantity: int = 1) -> void:
	EventBus.topic = "cultivation"
	if not _can_act():
		return
	var result := ArtifactFunctions.feed(player, data, item_id, quantity)
	if result["ok"]:
		EventBus.post("The artifact devours %d %s. (+%d energy, %d total)" % [quantity, data.items.get(item_id, {}).get("name", item_id), result["energy"], player.artifact_energy], "progress")
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
		EventBus.post("You tuck %d %s away inside the artifact." % [quantity, data.items.get(item_id, {}).get("name", item_id)])
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
		EventBus.post("You draw %d %s out of the artifact." % [quantity, data.items.get(item_id, {}).get("name", item_id)])
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
	if not d.get("player", {}).has("known_recipes"):
		Alchemy.grant_rank_recipes(player, data)  # saves from before recipe learning
	CreationArtifact.ensure(player, data)
	world_flags = d.get("world_flags", {})
	auctions = d.get("auctions", {})
	world_events = []
	for instance in d.get("world_events", []):
		if instance is Dictionary and data.world_events.has(String(instance.get("id", ""))):
			world_events.append({"id": String(instance["id"]), "region": String(instance.get("region", "")), "start_day": int(instance.get("start_day", 0)), "end_day": int(instance.get("end_day", 0))})
	current_region = d.get("region", data.start_region)
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
	NpcClans.ensure(npc_clans, npcs, data, rng)  # older saves gain the clans
	if player.rival == "" or not npcs.has(player.rival):
		Rivals.spawn(player, npcs, data, rng, data.start_region)  # older saves gain a rival
	dialogue_npc = ""
	dialogue_node = ""
	dialogue_event = ""
	pending_event = ""  # a loaded game never replays the intro event
	pending_encounter = ""
	if not data.regions.has(current_region):
		current_region = data.start_region
	GameClock.from_dict(d.get("clock", {}))
	EventBus.clear_history()
	rng.seed = String(d.get("rng_seed", "0")).to_int()
	rng.state = String(d.get("rng_state", "0")).to_int()
	EventBus.session_started.emit()
	EventBus.player_changed.emit()


# --- Internals ---------------------------------------------------------------

func _can_act() -> bool:
	return player != null and player.alive


## Advance the clock. A non-empty `skip_title` (e.g. "Meditating") also emits
## EventBus.time_skipped with a summary against _start_time_skip()'s snapshot.
func _pass_time(days: int, skip_title: String = "") -> void:
	var posted_before := EventBus.posted_count
	GameClock.advance(days)
	if skip_title != "" and _can_act() and not _skip_before.is_empty():
		var summary := TimeSkip.summarize(skip_title, days, _skip_before, TimeSkip.snapshot(player),
				Cultivation.realm_label(player, data), EventBus.posted_count - posted_before)
		EventBus.time_skipped.emit(days, summary)
	_skip_before = {}
	EventBus.player_changed.emit()


## Remember the player's numbers before a long action (see _pass_time).
func _start_time_skip() -> void:
	_skip_before = TimeSkip.snapshot(player)


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
	for buff_name in Buffs.pass_days(player, days):
		EventBus.post("The power of your %s fades." % buff_name)
	for item_id in SpiritGarden.advance(player, data, days):
		EventBus.post("The %s in your spirit garden is ready to harvest." % data.items.get(item_id, {}).get("name", item_id), "progress")
	EventBus.topic = "family"
	# NPCs the player knows (favor) or married never marry off-screen.
	var reserved := npc_favor.duplicate()
	for spouse_id in player.spouses:
		reserved[spouse_id] = true
	var married_off := false
	for event in Npcs.simulate(npcs, data, days, rng, reserved):
		married_off = married_off or event.get("kind", "") == "marriage"
		# News about generated strangers is noise; only report people the player knows.
		if not Npcs.is_newsworthy(String(event["npc_id"]), player, npc_favor):
			continue
		EventBus.post(event["text"], event["category"])
	if married_off:
		Npcs.ensure_eligible(npcs, data, rng, Children.descendants(player, npcs))  # keep courtship candidates in every region
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
			EventBus.post(String(legacy.get("rival_news", "Word spreads that someone has claimed the %s." % legacy["name"])), "info")
	@warning_ignore("integer_division")
	var months := player.age_days / Calendar.DAYS_PER_MONTH - age_before / Calendar.DAYS_PER_MONTH
	for i in months:
		EventBus.topic = "sect"
		_sect_month_end()
		EventBus.topic = "world"
		_world_events_month()
		_sect_factions_month()
	EventBus.topic = "family"
	for event in Training.advance(player, npcs, data, months, ClanEstate.training_multiplier(clan, data)):
		EventBus.post(event["text"], event["category"])
	for repaid in Karma.repay_debts(player, npcs, data, months, rng, world_flags):
		EventBus.post("%s repays a debt of gratitude. (%s)" % [npcs[repaid["npc_id"]].name, ", ".join(repaid["notes"])], "progress")
	if clan != null:
		_advance_estate(days, months)
		for joined in Clans.sync_family(player, clan, npcs, data):
			EventBus.post("%s joins the %s." % [joined, clan.name], "progress")
	EventBus.topic = "world"
	for line in SecretRealms.opening_news(player, data, current_region, GameClock.total_days - days, GameClock.total_days):
		EventBus.post(line, "progress")
	for def: Dictionary in data.secret_realms.values():
		if SecretRealms.closed_between(def, GameClock.total_days - days, GameClock.total_days):
			var cleared := SecretRealms.cleared_last_opening(player, def, GameClock.total_days)
			if SecretRealms.rival_claims_inheritance(player, data, String(def["id"]), cleared, world_flags, rng):
				EventBus.post("Word spreads that a rival emerged from the %s carrying the %s. That legacy is gone for good." % [def["name"], def["inheritance"].get("name", "inheritance")], "warning")
	EventBus.topic = action_topic
	if player.age_years() >= Cultivation.lifespan_years(player, data):
		_kill("Your lifespan is exhausted. You die of old age at %d." % player.age_years())


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
			parts.append("%d %s" % [result["items"][item_id], data.items[item_id].get("name", item_id)])
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
func _die_violently(cause: String) -> void:
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
	pending_respawn = {"cause": cause, "anchor_id": result["anchor_id"], "lives_left": result["lives_left"], "qi_lost": result["qi_lost"]}
	if moved:
		spawn_anchor = result["anchor_id"]
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
	spawn_anchor = anchor_id
	EventBus.player_changed.emit()
	EventBus.region_changed.emit(current_region)


func _kill(cause: String) -> void:
	player.alive = false
	player.cause_of_death = cause
	EventBus.post(cause, "danger")
	EventBus.player_died.emit(cause)
