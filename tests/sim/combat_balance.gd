extends RefCounted
## Combat balance analysis (QA-007), shared by the headless report
## (tests/sim/simulate_combat.gd) and its unit test (tests/unit/test_combat_balance.gd).
##
## Builds a "typical player" for a realm/stage and measures win rates against
## every enemy at the realm where encounters.json (plain encounters and choices)
## and sect_missions.json first make the player fight it.
##
## Typical player assumptions (documented so the numbers can be challenged):
## - every attribute 10, no spiritual roots (techniques work at 1.0x),
## - Iron Fist + Stone Skin Tempering at level tech_level(realm) (1, 3, 5, 7, 9, 10...),
## - the best priced, non-demonic weapon and armor with grade <= realm index + 1
##   (grade 1 = mortal gear, 2 = Qi Refining, ...),
## - optionally one readied strike + shield talisman of the same grade cap,
## - no injuries, buffs, pills or forbidden arts.

const TECHNIQUES: Array[String] = ["iron_fist", "stone_skin"]
## QA-018 veteran profile: technique kinds that fill the loadout, one art each.
## Last realm index (Soul Formation) the veteran profile and its guard cover.
const LATE_REALMS := 5
const LOADOUT_KINDS: Array[String] = ["combat", "body"]
## A player at the realm's peak wins less often than this: flagged unbeatable.
const UNBEATABLE_BELOW := 0.1
## A player entering the realm wins at least this often: flagged trivial.
const TRIVIAL_FROM := 0.99
## A player entering the realm wins less often than this: flagged hard.
const HARD_BELOW := 0.5


static func tech_level(data: GameData, realm_index: int, tech_ids: Array[String] = TECHNIQUES) -> int:
	var lvl := 1 + 2 * realm_index
	for tech_id in tech_ids:
		var def: TechniqueDef = data.techniques.get(tech_id)
		if def != null:
			lvl = mini(lvl, def.max_level)
	return lvl


## The strongest passive-bonus art of `kind` a player at `realm_index` can have: its
## min_realm is reached, it has no activation (forbidden arts burn lifespan), and
## its manual exists and is not demonic.
static func best_technique(data: GameData, realm_index: int, kind: String) -> String:
	var best := ""
	var best_score := -1.0
	for tech_id: String in data.techniques:
		var def: TechniqueDef = data.techniques[tech_id]
		if def.kind != kind or not def.activation.is_empty() or data.realm_index_of(def.min_realm) > realm_index:
			continue
		var manual: Dictionary = data.items.get(def.manual_item, {})
		if manual.is_empty() or manual.get("tags", []).has("demonic") or int(manual.get("effects", {}).get("alignment", 0)) < 0 or String(manual.get("description", "")).to_lower().contains("demonic"):
			continue
		var score := 0.0
		for key: String in def.bonuses:
			score += float(def.bonuses[key]) * (0.2 if key == "max_hp" else 1.0)
		if score > best_score:
			best_score = score
			best = tech_id
	return best


## The techniques a typical player knows at `realm_index`.
static func loadout(data: GameData, realm_index: int) -> Array[String]:
	var out: Array[String] = []
	for kind in LOADOUT_KINDS:
		var tech_id := best_technique(data, realm_index, kind)
		if tech_id != "":
			out.append(tech_id)
	return out


## The best item for `slot` that a player at `realm_index` can normally buy.
static func best_gear(data: GameData, realm_index: int, slot: String) -> String:
	var best := ""
	var best_score := -1.0
	for item_id: String in data.items:
		var item: Dictionary = data.items[item_id]
		var equip: Dictionary = item.get("equip", {})
		if equip.is_empty() or String(equip.get("slot", "")) != slot:
			continue
		if int(item.get("price", 0)) <= 0 or item.get("tags", []).has("demonic"):
			continue
		if int(equip.get("grade", 1)) > realm_index + 1:
			continue
		var stats: Dictionary = equip.get("stats", {})
		var score := float(stats.get("attack", 0)) + float(stats.get("defense", 0)) + float(stats.get("max_hp", 0)) * 0.2 + float(stats.get("speed", 0))
		if score > best_score:
			best_score = score
			best = item_id
	return best


## The strongest priced combat talisman of `kind` within the grade cap.
static func best_talisman(data: GameData, realm_index: int, kind: String) -> String:
	var best := ""
	var best_amount := -1
	for item_id: String in data.items:
		var item: Dictionary = data.items[item_id]
		if CombatTalismans.kind_of(data, item_id) != kind or int(item.get("price", 0)) <= 0:
			continue
		if int(CombatTalismans.combat_def(data, item_id).get("grade", 1)) > realm_index + 1:
			continue
		var amount := CombatTalismans.amount(data, item_id)
		if amount > best_amount:
			best_amount = amount
			best = item_id
	return best


## A player who just reached the realm with nothing else: attributes 10, no
## techniques, gear or talismans.
static func bare_player(data: GameData, realm_index: int, stage: int) -> CharacterData:
	var c := CharacterData.new()
	for attr: Dictionary in data.attributes:
		c.attributes[attr["id"]] = 10
	c.realm_index = realm_index
	c.stage = stage
	return c


static func typical_player(data: GameData, realm_index: int, stage: int, talismans: bool = false) -> CharacterData:
	var c := bare_player(data, realm_index, stage)
	for tech_id in TECHNIQUES:
		if data.techniques.has(tech_id):
			c.techniques[tech_id] = {"level": tech_level(data, realm_index), "xp": 0.0}
	for slot in Equipment.SLOTS:
		var item_id := best_gear(data, realm_index, slot)
		if item_id != "":
			c.equipment[slot] = item_id
	if talismans:
		for kind in ["strike", "shield"]:
			var item_id := best_talisman(data, realm_index, kind)
			if item_id != "":
				c.add_item(item_id, 1)
				c.readied_talismans.append(item_id)
	return c


## QA-018: like typical_player but with the best art of each kind in the data for
## the realm (loadout()) at the matching level, so late realms are not judged
## with Iron Fist. Optimistic: some arts come only from ruins or secret realms.
static func veteran_player(data: GameData, realm_index: int, stage: int, talismans: bool = false) -> CharacterData:
	var c := typical_player(data, realm_index, stage, talismans)
	c.techniques.clear()
	var arts := loadout(data, realm_index)
	for tech_id in arts:
		c.techniques[tech_id] = {"level": mini(tech_level(data, realm_index, [tech_id]), data.techniques[tech_id].max_level), "xp": 0.0}
	return c


## Fraction of `samples` fights won, with a fixed seed so reports are stable.
static func win_rate(c: CharacterData, data: GameData, enemy: Dictionary, samples: int, seed_value: int = 1) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wins := 0
	for i in samples:
		if Combat.resolve(c, data, enemy, rng)["victory"]:
			wins += 1
	return float(wins) / samples


## Every place the player is made to fight an enemy:
## [{enemy, source, realm_index, forced}]. forced = the player cannot slip away
## from a Deadly foe (sect missions, encounter choices, non-lethal enemies).
static func appearances(data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enc_id: String in data.encounters:
		var enc: Dictionary = data.encounters[enc_id]
		var min_realm := maxi(0, data.realm_index_of(String(enc.get("min_realm", "mortal"))))
		if enc.has("enemy"):
			var enemy_id := String(enc["enemy"])
			out.append({"enemy": enemy_id, "source": "encounter " + enc_id, "realm_index": min_realm, "stage": int(enc.get("min_stage", 0)), "forced": not data.enemies.get(enemy_id, {}).get("lethal", false)})
		for choice: Dictionary in enc.get("choices", []):
			if not choice.has("enemy"):
				continue
			var need := String(choice.get("requires", {}).get("min_realm", "mortal"))
			out.append({"enemy": String(choice["enemy"]), "source": "choice %s/%s" % [enc_id, choice.get("label", "?")], "realm_index": maxi(min_realm, data.realm_index_of(need)), "stage": int(enc.get("min_stage", 0)) if data.realm_index_of(need) <= min_realm else 0, "forced": true})
	for mission_id: String in data.sect_missions:
		var mission: Dictionary = data.sect_missions[mission_id]
		if String(mission.get("enemy", "")) == "":
			continue
		out.append({"enemy": String(mission["enemy"]), "source": "mission " + mission_id, "realm_index": maxi(0, data.realm_index_of(String(mission.get("min_realm", "mortal")))), "stage": int(mission.get("min_stage", 0)), "forced": true})
	_add_secret_realm_guardians(data, out)
	_add_inheritance_trials(data, out)
	_add_world_event_foes(data, out)
	_add_sect_trials(data, out)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return [a["realm_index"], a["enemy"], a["source"]] < [b["realm_index"], b["enemy"], b["source"]])
	return out


## QA-027: secret realm floor guardians, rated at the realm's min_realm (or its
## max_realm when it has none). "optional": the player chooses to enter and a
## lost fight only expels them, so the beatable-at-the-peak guard skips them.
static func _add_secret_realm_guardians(data: GameData, out: Array[Dictionary]) -> void:
	for realm_id: String in data.secret_realms:
		var def: Dictionary = data.secret_realms[realm_id]
		var realm := maxi(0, data.realm_index_of(String(def.get("min_realm", def.get("max_realm", "mortal")))))
		var floor_no := 0
		for floor_def: Dictionary in def.get("floors", []):
			floor_no += 1
			var guardian := String(floor_def.get("guardian", ""))
			if guardian != "":
				out.append({"enemy": guardian, "source": "realm %s floor %d" % [realm_id, floor_no], "realm_index": realm, "forced": true, "optional": true})


## QA-027: inheritance trial fights, rated at the highest realm any stage of the
## inheritance requires. Trials never kill (Inheritances.stage_enemy).
static func _add_inheritance_trials(data: GameData, out: Array[Dictionary]) -> void:
	for id: String in data.inheritances:
		var def: Dictionary = data.inheritances[id]
		var realm := 0
		for stage: Dictionary in def.get("stages", []):
			if String(stage.get("test", "")) == "realm":
				realm = maxi(realm, data.realm_index_of(String(stage.get("min_realm", "mortal"))))
		var stage_no := 0
		for stage: Dictionary in def.get("stages", []):
			stage_no += 1
			if String(stage.get("test", "")) == "fight" and data.enemies.has(String(stage.get("enemy", ""))):
				out.append({"enemy": String(stage["enemy"]), "source": "trial %s stage %d" % [id, stage_no], "realm_index": realm, "forced": true})


## QA-027: world event defence foes. WorldEvents.opponent() rebuilds them at the
## player's own realm and stage, so they are rated "scaled" from Qi Refining on
## (the realm a player may join at).
static func _add_world_event_foes(data: GameData, out: Array[Dictionary]) -> void:
	for event_id: String in data.world_events:
		var def: Dictionary = data.world_events[event_id]
		if def.has("defence") and data.enemies.has(String(def["defence"].get("enemy", ""))):
			out.append({"enemy": String(def["defence"]["enemy"]), "source": "defence " + event_id, "realm_index": 1, "forced": true, "scaled": true})


## QA-027: sect rank trials (sparring matches), rated at the rank's min_realm, or
## at the foe's own realm when the rank has none.
static func _add_sect_trials(data: GameData, out: Array[Dictionary]) -> void:
	for sect_id: String in data.sects:
		var rank_no := 0
		for rank: Dictionary in (data.sects[sect_id] as SectDef).ranks:
			rank_no += 1
			var enemy_id := String(rank.get("trial", ""))
			if enemy_id == "" or not data.enemies.has(enemy_id):
				continue
			var realm := data.realm_index_of(String(rank.get("min_realm", data.enemies[enemy_id].get("realm", "mortal"))))
			out.append({"enemy": enemy_id, "source": "trial %s rank %d" % [sect_id, rank_no], "realm_index": maxi(0, realm), "stage": int(rank.get("min_stage", 0)), "forced": true})


## Win rates at the first realm an appearance allows: a typical player entering
## it at its gate (stage 0, or the appearance's min_stage), at its peak (last stage) and entering it with talismans, and a
## bare player entering it.
static func rate(data: GameData, appearance: Dictionary, samples: int) -> Dictionary:
	var enemy: Dictionary = data.enemies.get(appearance["enemy"], {})
	var realm: int = appearance["realm_index"]
	var peak_stage := data.realms[realm].stage_count() - 1
	var scaled: bool = appearance.get("scaled", false)
	var gate: int = appearance.get("stage", 0)
	var entry := win_rate(typical_player(data, realm, gate), data, _scaled(data, enemy, realm, gate, scaled), samples)
	var peak := win_rate(typical_player(data, realm, peak_stage), data, _scaled(data, enemy, realm, peak_stage, scaled), samples)
	var talisman := win_rate(typical_player(data, realm, gate, true), data, _scaled(data, enemy, realm, gate, scaled), samples)
	var bare := win_rate(bare_player(data, realm, gate), data, _scaled(data, enemy, realm, gate, scaled), samples)
	var veteran := win_rate(veteran_player(data, realm, gate), data, _scaled(data, enemy, realm, gate, scaled), samples)
	return {"entry": entry, "veteran": veteran, "peak": peak, "talisman": talisman, "bare": bare, "verdict": verdict(entry, peak)}


## `enemy` at the player's realm and stage, like WorldEvents.opponent() does.
static func _scaled(data: GameData, enemy: Dictionary, realm: int, stage: int, scaled: bool) -> Dictionary:
	if not scaled:
		return enemy
	var out := enemy.duplicate(true)
	out["realm"] = data.realms[realm].id
	out["stage"] = stage
	out["lethal"] = false
	return out


## A plain enemy of `realm_index`/`stage`: realm power and enemies.json
## realm_training only, no techniques or flat tweaks (QA-007d yardstick).
static func plain_enemy(data: GameData, realm_index: int, stage: int) -> Dictionary:
	return {"name": "Plain foe", "realm": data.realms[realm_index].id, "stage": stage, "techniques": []}


## Typical player vs a plain enemy of the same realm and `stage`.
static func same_stage_rate(data: GameData, realm_index: int, stage: int, samples: int) -> float:
	return win_rate(typical_player(data, realm_index, stage), data, plain_enemy(data, realm_index, stage), samples)


static func verdict(entry: float, peak: float) -> String:
	if peak < UNBEATABLE_BELOW:
		return "unbeatable"
	if entry >= TRIVIAL_FROM:
		return "trivial"
	if entry < HARD_BELOW:
		return "hard"
	return "ok"
