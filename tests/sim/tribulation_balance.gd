extends RefCounted
## Tribulation balance analysis (QA-010), shared by the headless report
## (tests/sim/simulate_tribulation.gd) and its unit test
## (tests/unit/test_tribulation_balance.gd).
##
## The cultivator facing a tribulation is the one attempting the breakthrough:
## at the PREVIOUS realm's final stage, built like combat_balance.gd's players
## for that realm (bare: attributes 10 only; typical: Iron Fist + Stone Skin and
## the best buyable gear; prepared: typical plus the buyable shield that holds
## best against lightning (best_ward) readied; npc: a bare NPC, who faces the realm's npc_strength).
## Alignment only matters for the heart-demon wave.

const Balance := preload("res://tests/sim/combat_balance.gd")
const PROFILES: Array[String] = ["bare", "typical", "prepared", "npc"]


## The cultivator about to break into `realm_index` with `profile` and `alignment`.
static func attempter(data: GameData, realm_index: int, profile: String, alignment: int = 0) -> CharacterData:
	var from := realm_index - 1
	var stage := data.realms[from].stage_count() - 1
	var c: CharacterData
	match profile:
		"bare", "npc":
			c = Balance.bare_player(data, from, stage)
		"typical":
			c = Balance.typical_player(data, from, stage)
		_:
			c = Balance.typical_player(data, from, stage)
			var shield := best_ward(data, from)
			if shield != "":
				c.add_item(shield, 1)
				c.readied_talismans.append(shield)
	c.alignment = alignment
	return c


## The buyable shield talisman (grade up to the attempter's realm) that holds
## best against tribulation lightning (Tribulation.ward_amount), or "".
static func best_ward(data: GameData, from: int) -> String:
	var best := ""
	for item_id: String in data.items:
		if CombatTalismans.kind_of(data, item_id) != "shield" or int(data.items[item_id].get("price", 0)) <= 0:
			continue
		if int(CombatTalismans.combat_def(data, item_id).get("grade", 1)) > from + 1:
			continue
		if best == "" or Tribulation.ward_amount(data, item_id) > Tribulation.ward_amount(data, best):
			best = item_id
	return best


## Outcome rates over `samples` tribulations, each faced by a fresh attempter
## (endure burns talismans and inflicts injuries): {survive, fail, die}.
static func odds(data: GameData, realm_index: int, profile: String, alignment: int, samples: int, seed_value: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var survived := 0
	var died := 0
	for i in samples:
		var r := Tribulation.endure(attempter(data, realm_index, profile, alignment), data, realm_index, rng, profile == "npc")
		if r["survived"]:
			survived += 1
		elif r["died"]:
			died += 1
	return {"survive": float(survived) / samples, "fail": float(samples - survived - died) / samples, "die": float(died) / samples}


## Realm indices whose breakthrough summons a tribulation.
static func tribulation_realms(data: GameData) -> Array[int]:
	var out: Array[int] = []
	for i in range(1, data.realms.size()):
		if Tribulation.has_tribulation(data, i):
			out.append(i)
	return out
