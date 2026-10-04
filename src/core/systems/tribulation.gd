class_name Tribulation
extends RefCounted
## Heavenly Tribulations: when a breakthrough into a realm with a `tribulation`
## block (data/realms.json) succeeds, heaven answers with lightning waves. Each
## wave strikes with an attack scaled by the new realm's combat power and is
## resisted like a blow in combat (Combat.base_damage vs defense); the strongest
## readied shield talisman absorbs damage first, at only a fraction of its combat
## value against heavenly lightning (realms.json tribulation_shield_scale, or the
## item's own combat.tribulation for wards made for tribulations, TRIB-001d). Demonic cultivators also face a heart-demon
## wave that ignores defense. Falling before the final wave fails the
## breakthrough with an injury; falling to the final wave kills.


## The realm's tribulation block, or {} if breaking into it summons none.
static func def_for(data: GameData, realm_index: int) -> Dictionary:
	if realm_index < 0 or realm_index >= data.realms.size():
		return {}
	return data.realms[realm_index].tribulation


static func has_tribulation(data: GameData, realm_index: int) -> bool:
	return not def_for(data, realm_index).is_empty()


## True if `c` is demonic enough to face a heart demon (realms.json heart_demon).
static func faces_heart_demon(c: CharacterData, data: GameData) -> bool:
	return not data.heart_demon.is_empty() and c.alignment <= int(data.heart_demon.get("max_alignment", -300))


## The waves `c` would face breaking into `realm_index`, in order, before
## randomness: [{kind: "lightning"|"heart_demon", attack, damage}]. Lightning
## damage already accounts for `c`'s defense; the heart demon wave comes just
## before the final lightning wave. `npc` uses the block's `npc_strength`
## (NPCs carry no modelled techniques or gear), defaulting to `strength`.
static func waves(c: CharacterData, data: GameData, realm_index: int, npc: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var trib := def_for(data, realm_index)
	if trib.is_empty():
		return out
	var s := Combat.stats(c, data)
	var strength := float(trib.get("strength", 1.0))
	if npc:
		strength = float(trib.get("npc_strength", strength))
	var attack := Combat.realm_power(realm_index, 0) * strength
	var count := int(trib.get("waves", 1))
	for i in count:
		var a := attack * pow(float(trib.get("growth", 1.0)), i)
		out.append({"kind": "lightning", "attack": a, "damage": Combat.base_damage(a, s["defense"])})
	if faces_heart_demon(c, data):
		var depth := clampf(float(-c.alignment) / float(maxi(-data.alignment_min, 1)), 0.0, 1.0)
		var damage := float(s["max_hp"]) * float(data.heart_demon.get("hp_fraction", 0.3)) * depth
		out.insert(out.size() - 1, {"kind": "heart_demon", "attack": 0.0, "damage": damage})
	return out


## Shield points shield talisman `item_id` holds against heavenly lightning:
## its combat amount times its combat.tribulation (else tribulation_shield_scale).
static func ward_amount(data: GameData, item_id: String) -> int:
	var scale := float(CombatTalismans.combat_def(data, item_id).get("tribulation", data.tribulation_shield_scale))
	return roundi(CombatTalismans.amount(data, item_id) * scale)


## The readied shield talisman `c` carries that holds best against lightning
## (only one ward stands against heaven), or "".
static func best_ward(c: CharacterData, data: GameData) -> String:
	var best := ""
	for item_id in CombatTalismans.available(c, data, "shield"):
		if best == "" or ward_amount(data, item_id) > ward_amount(data, best):
			best = item_id
	return best


## Shield points `c`'s best readied ward would absorb.
static func shield_of(c: CharacterData, data: GameData) -> int:
	var ward := best_ward(c, data)
	return ward_amount(data, ward) if ward != "" else 0


## Expected outcome before attempting, for a "prepare" warning:
## {has_tribulation, waves, heart_demon, expected_damage, max_hp, shield}.
static func preview(c: CharacterData, data: GameData, realm_index: int) -> Dictionary:
	var list := waves(c, data, realm_index)
	var total := 0.0
	var heart := false
	for w in list:
		total += float(w["damage"])
		heart = heart or w["kind"] == "heart_demon"
	return {
		"has_tribulation": not list.is_empty(),
		"waves": list.size(),
		"heart_demon": heart,
		"expected_damage": roundi(total),
		"max_hp": int(Combat.stats(c, data)["max_hp"]),
		"shield": shield_of(c, data),
	}


## Endures the tribulation for breaking into `realm_index`. Burns the best
## readied ward (best_ward) and, on a non-lethal failure, inflicts a "tribulation_failure"
## injury. Returns {survived, died, waves: [{kind, damage, hp_left}], hp,
## max_hp, talismans_used: PackedStringArray of names, injury}. `npc`: see waves().
static func endure(c: CharacterData, data: GameData, realm_index: int, rng: RandomNumberGenerator, npc: bool = false) -> Dictionary:
	var list := waves(c, data, realm_index, npc)
	var max_hp: int = Combat.stats(c, data)["max_hp"]
	var shield := shield_of(c, data)
	var ward := best_ward(c, data)
	var used := CombatTalismans.consume(c, data, [ward]) if not list.is_empty() and ward != "" else PackedStringArray()
	var variance := float(def_for(data, realm_index).get("variance", 0.0))
	var hp := float(max_hp)
	var struck: Array[Dictionary] = []
	var fell_at := -1
	for i in list.size():
		var damage := float(list[i]["damage"]) * rng.randf_range(1.0 - variance, 1.0 + variance)
		var absorbed := minf(float(shield), damage)
		shield -= roundi(absorbed)
		damage -= absorbed
		hp -= damage
		struck.append({"kind": list[i]["kind"], "damage": roundi(damage), "hp_left": maxi(roundi(hp), 0)})
		if hp <= 0.0:
			fell_at = i
			break
	var survived := fell_at < 0
	var died := not survived and fell_at == list.size() - 1
	var injury := ""
	if not survived and not died:
		injury = Injuries.roll(c, data, "tribulation_failure", rng)
	return {
		"survived": survived,
		"died": died,
		"waves": struck,
		"hp": maxi(roundi(hp), 0),
		"max_hp": max_hp,
		"talismans_used": used,
		"injury": injury,
	}


## Load errors for tribulation blocks and heart_demon in realms.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.tribulation_shield_scale < 0.0 or data.tribulation_shield_scale > 1.0:
		errors.append("realms.json tribulation_shield_scale must be 0..1")
	for item_id: String in data.items:
		var ward: Variant = CombatTalismans.combat_def(data, item_id).get("tribulation")
		if ward != null and (CombatTalismans.kind_of(data, item_id) != "shield" or float(ward) < 0.0 or float(ward) > 1.0):
			errors.append("Item '%s' combat.tribulation must be 0..1 on a shield" % item_id)
	for realm: RealmDef in data.realms:
		var trib: Dictionary = realm.tribulation
		if trib.is_empty():
			continue
		if int(trib.get("waves", 0)) < 1:
			errors.append("Realm '%s' tribulation needs waves >= 1" % realm.id)
		if float(trib.get("strength", 0.0)) <= 0.0 or float(trib.get("growth", 1.0)) <= 0.0:
			errors.append("Realm '%s' tribulation needs strength > 0 and growth > 0" % realm.id)
		if trib.has("npc_strength") and float(trib["npc_strength"]) <= 0.0:
			errors.append("Realm '%s' tribulation needs npc_strength > 0" % realm.id)
		var variance := float(trib.get("variance", 0.0))
		if variance < 0.0 or variance >= 1.0:
			errors.append("Realm '%s' tribulation variance must be in [0, 1)" % realm.id)
	if not data.heart_demon.is_empty() and float(data.heart_demon.get("hp_fraction", 0.0)) <= 0.0:
		errors.append("realms.json heart_demon needs hp_fraction > 0")
	if not data.injury_sources.has("tribulation_failure") and data.realms.any(func(r: RealmDef) -> bool: return not r.tribulation.is_empty()):
		errors.append("injuries.json needs a tribulation_failure source")
	return errors
