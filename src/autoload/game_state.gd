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
## Live NPCs: id -> CharacterData (definitions in data/npcs.json).
var npcs: Dictionary = {}
## How much each NPC likes the player: id -> int.
var npc_favor: Dictionary = {}
## The conversation in progress ("" = none) and its current node.
var dialogue_npc := ""
var dialogue_node := ""
## Encounter id waiting for the player's choice (W-004c, "" = none). Like a
## conversation it is not saved: loading a save drops it.
var pending_encounter := ""
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
	CreationArtifact.ensure(player, data)
	world_flags = {}
	current_region = data.start_region
	npcs = {}
	npc_favor = {}
	dialogue_npc = ""
	pending_encounter = ""
	Npcs.ensure_all(npcs, data, rng)
	Npcs.ensure_eligible(npcs, data, rng)
	GameClock.reset()
	EventBus.session_started.emit()
	EventBus.post("%s sets out on the path of cultivation." % player.name, "progress")
	EventBus.player_changed.emit()


func end_session() -> void:
	player = null
	world_flags = {}
	npcs = {}
	npc_favor = {}
	dialogue_npc = ""
	pending_encounter = ""


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
		if result["injury"] != "":
			EventBus.post("You suffer %s." % Injuries.injury_name(data, result["injury"]), "danger")
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
	if Equipment.is_equipment(data, item_id):
		equip_item(item_id)
		return
	var result := Items.use(player, data, item_id, world_flags)
	if result["ok"]:
		EventBus.post("You use a %s. (%s)" % [data.items[item_id]["name"], ", ".join(result["notes"])], "progress")
		var burned := int(data.items[item_id].get("effects", {}).get("burn_lifespan", 0))
		if burned > 0:
			EventBus.post("You feel %d years of life drain away. %d years remain." % [burned, Cultivation.years_left(player, data)], "danger")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


## Equip a weapon/armor from the inventory (takes no time).
func equip_item(item_id: String) -> void:
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
		if Equipment.item_drain(data, item_id) > 0:
			EventBus.post("It thirsts for your life. %d years remain to you." % Cultivation.years_left(player, data), "danger")
	EventBus.player_changed.emit()


func unequip(slot: String) -> void:
	if not _can_act():
		return
	var item_id := Equipment.unequip(player, slot)
	if item_id != "":
		EventBus.post("You put away the %s." % data.items[item_id]["name"], "info")
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
	pending_encounter = ""
	_pass_time(result["days"])
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


## The pending encounter's choices for the UI: [{index, label, disabled, reason}]
## ([] when no encounter is waiting).
func encounter_choices() -> Array[Dictionary]:
	if pending_encounter == "" or not _can_act():
		return []
	return Exploration.choices(player, data, data.encounters.get(pending_encounter, {}), world_flags)


## Pick choice `index` of the pending encounter: applies its outcome, passes
## its days and starts its fight, if any (a chosen fight is never evaded).
func choose_encounter(index: int) -> void:
	if pending_encounter == "" or not _can_act():
		return
	var result := Exploration.resolve_choice(player, data, data.encounters.get(pending_encounter, {}), index, world_flags)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	pending_encounter = ""
	var text: String = result["text"]
	if not result["notes"].is_empty():
		text += " (%s)" % ", ".join(result["notes"])
	if text != "":
		EventBus.post(text, "danger" if result["enemy"] != "" else "karma" if result["karma"] else "info")
	EventBus.encounter_choice_resolved.emit()
	_pass_time(result["days"])
	if result["enemy"] != "" and _can_act():
		fight(result["enemy"])


## Gather materials from a place's gathering table (see Exploration.gather).
func gather(table: Array, days: int) -> void:
	if not _can_act():
		return
	var found := Exploration.gather(player, table, rng)
	var notes: PackedStringArray = []
	for item_id in found:
		player.add_item(item_id, found[item_id])
		notes.append("+%d %s" % [found[item_id], data.items[item_id]["name"]])
	if notes.is_empty():
		EventBus.post("You search for %s but find nothing worth taking." % Calendar.format_duration(days))
	else:
		EventBus.post("You gather for %s. (%s)" % [Calendar.format_duration(days), ", ".join(notes)], "progress")
	_pass_time(days)


func sell_item(item_id: String, quantity: int = 1) -> void:
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
	dialogue_node = node
	EventBus.dialogue_requested.emit(npc_id)


## The current node: {id, speaker, text, choices: [{index, label, disabled,
## reason}]}, or {} when no conversation is in progress.
func dialogue_view() -> Dictionary:
	if dialogue_npc == "":
		return {}
	return Dialogue.view(_npc_dialogue(dialogue_npc), dialogue_node, _dialogue_ctx(dialogue_npc))


## Picks choice `index` (from dialogue_view) of the current node. Emits
## dialogue_ended once effects and time are applied if the conversation is over.
func choose_dialogue(index: int) -> void:
	if dialogue_npc == "" or not _can_act():
		return
	var npc_id := dialogue_npc
	var result := Dialogue.choose(_npc_dialogue(npc_id), dialogue_node, index, _dialogue_ctx(npc_id))
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		return
	if result["favor"] != 0:
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
	EventBus.dialogue_ended.emit(npc_id)
	EventBus.player_changed.emit()


func _npc_dialogue(npc_id: String) -> Dictionary:
	return data.dialogues.get(data.npcs.get(npc_id, {}).get("dialogue", ""), {})


func _dialogue_ctx(npc_id: String) -> Dictionary:
	return {"player": player, "npc": npcs.get(npc_id), "data": data, "flags": world_flags, "favor": int(npc_favor.get(npc_id, 0))}


## Spend time courting an NPC (needs some favor first); raises their favor.
func court(npc_id: String) -> void:
	if not _can_act():
		return
	var result := Family.court(player, npcs.get(npc_id), int(npc_favor.get(npc_id, 0)), data, npcs)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	npc_favor[npc_id] = int(npc_favor.get(npc_id, 0)) + result["favor"]
	EventBus.post("You spend days in %s's company. They warm to you. (+%d favor)" % [npcs[npc_id].name, result["favor"]], "progress")
	_pass_time(result["days"])


## Pick the player's gender once, for old saves where it is unknown ("").
func choose_gender(gender: String) -> void:
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
	if not _can_act():
		return
	var result := Family.propose(player, npcs.get(npc_id), int(npc_favor.get(npc_id, 0)), rank, data, npcs)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("%s accepts your proposal and becomes your %s." % [npcs[npc_id].name, Family.rank_name(data, player.gender, rank).to_lower()], "progress")
	_pass_time(result["days"])


## Cultivate together with a spouse who is in the current region: both gain
## qi with the dual cultivation bonus (data/family.json) and favor rises.
func dual_cultivate(spouse_id: String, days: int, location_density: float = 1.0) -> void:
	if not _can_act():
		return
	var spouse: CharacterData = npcs.get(spouse_id)
	if spouse != null and spouse.alive and Npcs.region_of(spouse, data) != current_region:
		EventBus.post("%s is not here." % spouse.name, "warning")
		EventBus.player_changed.emit()
		return
	var density := location_density * Exploration.qi_density(data, current_region) * Sects.cultivation_bonus(player, data)
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
	_pass_time(days)


## Spend time with a spouse in the current region trying for a child
## (data/family.json "children"). On conception the carrier's pregnancy begins;
## the birth happens as time passes (see _advance_pregnancies).
func try_for_child(spouse_id: String) -> void:
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


## Activate a secret art: burn its lifespan cost for a temporary combat buff. Takes no time.
func activate_technique(tech_id: String) -> void:
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
		EventBus.post("You are now a %s!" % Professions.rank_title(player, data, Medicine.DOCTOR), "progress")
	_pass_time(result["days"])


## Pay a clinic to heal an injury fully.
func visit_clinic(injury_id: String) -> void:
	if not _can_act():
		return
	var result := Medicine.visit_clinic(player, data, injury_id)
	if not result["ok"]:
		EventBus.post(result["reason"], "warning")
		EventBus.player_changed.emit()
		return
	EventBus.post("The doctor heals your %s for %d spirit stones." % [Injuries.injury_name(data, injury_id), result["cost"]], "progress")
	_pass_time(result["days"])


## Work as a doctor: treat village patients for income, Doctor xp and alignment.
func treat_patients(days: int) -> void:
	if not _can_act():
		return
	var result := Medicine.treat_patients(player, data, days)
	EventBus.post("You treat patients for %s: +%d xp, +%d spirit stones, alignment %+d." % [Calendar.format_duration(days), int(result["xp"]), result["income"], result["alignment"]], "karma")
	if result["ranks_gained"] > 0:
		EventBus.post("You are now a %s!" % Professions.rank_title(player, data, Medicine.DOCTOR), "progress")
	_pass_time(days)


## Crafting messages per profession (GameState.refine).
const CRAFT_FLAVOR := {
	"alchemist": {"verb": "refine", "great": "Pill fragrance fills the room!", "fail": "The cauldron cracks and your herbs turn to ash."},
	"blacksmith": {"verb": "forge", "great": "The blade sings as it leaves the forge!", "fail": "The metal cracks under the hammer and the ore is ruined."},
	"talisman_master": {"verb": "inscribe", "great": "The runes blaze with golden light!", "fail": "Your brush slips; the talisman flares and burns to ash."},
}


## Refine one batch of a recipe from data/recipes.json. Failure burns the ingredients.
func refine(recipe_id: String) -> void:
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
		EventBus.post("You are now a %s!" % Professions.rank_title(player, data, prof_id), "progress")
	if not player.is_rogue():
		var contribution := int(result["xp"] / (1.0 if Sects.is_favored_profession(player, data, prof_id) else 2.0))
		if Sects.add_contribution(player, data, contribution):
			EventBus.post("Your sect promotes you to %s." % Sects.describe(player, data), "progress")
	_pass_time(result["days"])


## Craft `times` batches in a row, stopping when one is no longer possible
## (missing ingredients, rank) or the character dies.
func refine_batch(recipe_id: String, times: int) -> void:
	for i in times:
		if not _can_act() or Alchemy.check(player, data, recipe_id) != "":
			break
		refine(recipe_id)


## Take a sect mission (data/sect_missions.json): beat its enemy if it has
## one (losing fails the mission), then hand in items, earn contribution and
## rewards, and spend the mission's days.
func take_mission(mission_id: String) -> void:
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
	_pass_time(result["days"])


## Fight an enemy from data/enemies.json.
func fight(enemy_id: String) -> void:
	if not data.enemies.has(enemy_id):
		push_error("Unknown enemy '%s'" % enemy_id)
		return
	fight_enemy(data.enemies[enemy_id])


## Ready a combat talisman so it is burned automatically in the next fights.
func ready_talisman(item_id: String) -> void:
	if not _can_act():
		return
	var reason := CombatTalismans.ready_talisman(player, data, item_id)
	if reason != "":
		EventBus.post(reason, "warning")
	else:
		EventBus.post("You tuck a %s into your sleeve, ready for battle." % data.items[item_id].get("name", item_id))
	EventBus.player_changed.emit()


func unready_talisman(item_id: String) -> void:
	if not _can_act():
		return
	if CombatTalismans.unready_talisman(player, item_id):
		EventBus.post("You put the %s away." % data.items.get(item_id, {}).get("name", item_id))
	EventBus.player_changed.emit()


## Fight any enemy dictionary in the enemies.json format. Returns true if the
## player won and is still alive.
func fight_enemy(enemy: Dictionary) -> bool:
	if not _can_act():
		return false
	var result := Combat.resolve(player, data, enemy, rng)
	# The full blow-by-blow goes out with combat_finished; the log gets a summary.
	var lines: PackedStringArray = result["log"]
	EventBus.post(lines[0], "danger")
	EventBus.post("%s (%d rounds, %d/%d hp left)" % [lines[-1], result["rounds"], result["player_hp"], result["player_max_hp"]], "progress" if result["victory"] else "danger")
	var outcome := Combat.apply_outcome(player, data, enemy, result, world_flags, rng)
	if not outcome["notes"].is_empty():
		EventBus.post("(%s)" % ", ".join(outcome["notes"]), "progress" if result["victory"] else "warning")
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
	_pass_time(outcome["days"])
	return bool(result["victory"]) and _can_act()


## Bind the Creation Artifact to an anchor place (data/regions.json "anchor_id").
func bind_anchor(anchor_id: String) -> void:
	if not _can_act():
		return
	var result := CreationArtifact.bind_anchor(player, data, anchor_id)
	if result["ok"]:
		EventBus.post("The Creation Artifact hums as you bind its anchor to %s. You will return here if you fall." % CreationArtifact.anchor_name(data, anchor_id), "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


func unbind_anchor(anchor_id: String) -> void:
	if not _can_act():
		return
	if CreationArtifact.unbind_anchor(player, anchor_id):
		EventBus.post("You release the anchor at %s." % CreationArtifact.anchor_name(data, anchor_id))
	EventBus.player_changed.emit()


## Feed spirit stones to the Creation Artifact for one more life.
func recharge_artifact() -> void:
	if not _can_act():
		return
	var result := CreationArtifact.recharge(player, data)
	if result["ok"]:
		EventBus.post("The artifact drinks %d spirit stones. Lives: %d." % [result["cost"], player.artifact_lives], "progress")
	else:
		EventBus.post(result["reason"], "warning")
	EventBus.player_changed.emit()


# --- Save data ---------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"player": player.to_dict(),
		"world_flags": world_flags.duplicate(),
		"region": current_region,
		"npcs": Npcs.to_dict(npcs),
		"npc_favor": npc_favor.duplicate(),
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
	current_region = d.get("region", data.start_region)
	npcs = Npcs.from_dict(d.get("npcs", {}))
	Npcs.ensure_all(npcs, data, rng)
	Npcs.ensure_eligible(npcs, data, rng)
	npc_favor = {}
	for npc_id in d.get("npc_favor", {}):
		npc_favor[npc_id] = int(d["npc_favor"][npc_id])
	dialogue_npc = ""
	dialogue_node = ""
	pending_encounter = ""
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
	var age_before := player.age_days
	player.age_days += days
	var spouse_favor := Family.spouse_favor_gain(data, age_before, player.age_days)
	if spouse_favor > 0:
		for spouse_id in player.spouses:
			var spouse: CharacterData = npcs.get(spouse_id)
			if spouse != null and spouse.alive:
				npc_favor[spouse_id] = Family.add_spouse_favor(data, int(npc_favor.get(spouse_id, 0)), spouse_favor)
	for injury_id in Injuries.pass_days(player, days):
		EventBus.post("Your %s has healed." % Injuries.injury_name(data, injury_id), "progress")
	for buff_name in Buffs.pass_days(player, days):
		EventBus.post("The power of your %s fades." % buff_name)
	for event in Npcs.simulate(npcs, data, days, rng):
		# News about generated strangers is noise; only report people the player knows.
		if not Npcs.is_newsworthy(String(event["npc_id"]), player, npc_favor):
			continue
		EventBus.post(event["text"], event["category"])
	_advance_pregnancies(days)
	if player.age_years() >= Cultivation.lifespan_years(player, data):
		_kill("Your lifespan is exhausted. You die of old age at %d." % player.age_years())


## Pregnancies of the player and the player's spouses progress; due ones give birth.
func _advance_pregnancies(days: int) -> void:
	var expecting: Array[CharacterData] = [player]
	for spouse_id in player.spouses:
		var spouse: CharacterData = npcs.get(spouse_id)
		if spouse != null and spouse.alive:
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
	EventBus.player_respawned.emit(result["anchor_id"], result["lives_left"])
	_pass_time(result["days"])
	if moved:
		EventBus.region_changed.emit(current_region)


func _kill(cause: String) -> void:
	player.alive = false
	player.cause_of_death = cause
	EventBus.post(cause, "danger")
	EventBus.player_died.emit(cause)
