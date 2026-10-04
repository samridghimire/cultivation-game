class_name Tribulation
extends RefCounted
## Heavenly Tribulations: when a breakthrough into a realm with a `tribulation`
## block (data/realms.json) succeeds, heaven answers with lightning waves. Each
## wave strikes with an attack scaled by the new realm's combat power and is
## resisted like a blow in combat (Combat.base_damage vs defense); readied shield
## talismans absorb damage first. Demonic cultivators also face a heart-demon
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
## before the final lightning wave.
static func waves(c: CharacterData, data: GameData, realm_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var trib := def_for(data, realm_index)
	if trib.is_empty():
		return out
	var s := Combat.stats(c, data)
	var attack := Combat.realm_power(realm_index, 0) * float(trib.get("strength", 1.0))
	var count := int(trib.get("waves", 1))
	for i in count:
		var a := attack * pow(float(trib.get("growth", 1.0)), i)
		out.append({"kind": "lightning", "attack": a, "damage": Combat.base_damage(a, s["defense"])})
	if faces_heart_demon(c, data):
		var depth := clampf(float(-c.alignment) / float(maxi(-data.alignment_min, 1)), 0.0, 1.0)
		var damage := float(s["max_hp"]) * float(data.heart_demon.get("hp_fraction", 0.3)) * depth
		out.insert(out.size() - 1, {"kind": "heart_demon", "attack": 0.0, "damage": damage})
	return out


## Shield points `c`'s readied shield talismans would absorb.
static func shield_of(c: CharacterData, data: GameData) -> int:
	var total := 0
	for item_id in CombatTalismans.available(c, data, "shield"):
		total += CombatTalismans.amount(data, item_id)
	return total


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


## Endures the tribulation for breaking into `realm_index`. Burns readied shield
## talismans and, on a non-lethal failure, inflicts a "tribulation_failure"
## injury. Returns {survived, died, waves: [{kind, damage, hp_left}], hp,
## max_hp, talismans_used: PackedStringArray of names, injury}.
static func endure(c: CharacterData, data: GameData, realm_index: int, rng: RandomNumberGenerator) -> Dictionary:
	var list := waves(c, data, realm_index)
	var max_hp: int = Combat.stats(c, data)["max_hp"]
	var shield := shield_of(c, data)
	var used := CombatTalismans.consume(c, data, CombatTalismans.available(c, data, "shield")) if not list.is_empty() else PackedStringArray()
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
	for realm: RealmDef in data.realms:
		var trib: Dictionary = realm.tribulation
		if trib.is_empty():
			continue
		if int(trib.get("waves", 0)) < 1:
			errors.append("Realm '%s' tribulation needs waves >= 1" % realm.id)
		if float(trib.get("strength", 0.0)) <= 0.0 or float(trib.get("growth", 1.0)) <= 0.0:
			errors.append("Realm '%s' tribulation needs strength > 0 and growth > 0" % realm.id)
		var variance := float(trib.get("variance", 0.0))
		if variance < 0.0 or variance >= 1.0:
			errors.append("Realm '%s' tribulation variance must be in [0, 1)" % realm.id)
	if not data.heart_demon.is_empty() and float(data.heart_demon.get("hp_fraction", 0.0)) <= 0.0:
		errors.append("realms.json heart_demon needs hp_fraction > 0")
	if not data.injury_sources.has("tribulation_failure") and data.realms.any(func(r: RealmDef) -> bool: return not r.tribulation.is_empty()):
		errors.append("injuries.json needs a tribulation_failure source")
	return errors
