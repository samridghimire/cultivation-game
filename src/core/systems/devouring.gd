class_name Devouring
extends RefCounted
## Devouring (DEM-001), the smallest demonic art: after beating a cultivator
## enemy (enemies.json tag from data/demonic_arts.json "devouring") the player
## may devour its cultivation for qi, at a big alignment cost and a growing risk
## of a heart demon (an injury). CharacterData.devoured counts the victims.


static func rules(data: GameData) -> Dictionary:
	return data.demonic_arts.get("devouring", {})


## True if `enemy` (an enemies.json dictionary) can be devoured once beaten:
## it carries the devouring tag and is not a sparring match.
static func is_devourable(data: GameData, enemy: Dictionary) -> bool:
	var tag := String(rules(data).get("tag", ""))
	return tag != "" and (enemy.get("tags", []) as Array).has(tag) and not bool(enemy.get("spar", false))


## Qi gained from devouring `enemy`: qi_fraction of what its realm needs at its stage.
static func qi_gain(data: GameData, enemy: Dictionary) -> int:
	var realm := data.realm_index_of(String(enemy.get("realm", "mortal")))
	if realm < 0:
		return 0
	var def: RealmDef = data.realms[realm]
	var stage := clampi(int(enemy.get("stage", 0)), 0, def.stage_count() - 1)
	return roundi(float(rules(data).get("qi_fraction", 0.0)) * def.qi_required(stage))


## Base chance of a heart demon for `c`'s next devouring (before the Fortune and
## body-tempering reductions every injury roll gets).
static func heart_demon_chance(c: CharacterData, data: GameData) -> float:
	var r := rules(data)
	var chance := float(r.get("heart_demon_chance", 0.0)) + float(r.get("heart_demon_per_devour", 0.0)) * c.devoured
	return clampf(chance, 0.0, float(r.get("heart_demon_max_chance", 1.0)))


## Why `c` cannot devour `enemy`, or "".
static func check_devour(c: CharacterData, data: GameData, enemy: Dictionary) -> String:
	if not is_devourable(data, enemy):
		return "There is no cultivation there to devour."
	if c.realm_index <= 0:
		return "A mortal has no dantian to hold stolen qi."
	return ""


## Devours `enemy`'s cultivation. Returns {ok, reason, qi, stages, alignment,
## injury ("" or the heart demon injury id), days}.
static func devour(c: CharacterData, data: GameData, enemy: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var reason := check_devour(c, data, enemy)
	if reason != "":
		return {"ok": false, "reason": reason, "qi": 0, "stages": 0, "alignment": 0, "injury": "", "days": 0}
	var r := rules(data)
	var chance := heart_demon_chance(c, data)
	var gained := Cultivation.add_qi(c, data, qi_gain(data, enemy))
	var shift := int(r.get("alignment", 0))
	Alignment.shift(c, data, shift)
	c.devoured += 1
	var injury := ""
	var injury_id := String(r.get("injury", ""))
	if injury_id != "" and chance > 0.0:
		chance -= (c.attribute("fortune") - 10) * data.injury_fortune_step
		chance *= 1.0 - BodyTempering.injury_resistance(c, data)
		if rng.randf() < chance and Injuries.inflict(c, data, injury_id):
			injury = injury_id
	return {"ok": true, "reason": "", "qi": int(gained["qi_gained"]), "stages": int(gained["stages_gained"]), "alignment": shift, "injury": injury, "days": int(r.get("days", 0))}


## Load errors for data/demonic_arts.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if r.is_empty():
		return errors
	if String(r.get("tag", "")) == "":
		errors.append("demonic_arts.json devouring needs a tag")
	if float(r.get("qi_fraction", 0.0)) <= 0.0:
		errors.append("demonic_arts.json devouring qi_fraction must be > 0")
	if int(r.get("alignment", 0)) > 0:
		errors.append("demonic_arts.json devouring alignment must not be positive")
	var injury_id := String(r.get("injury", ""))
	if injury_id != "" and not data.injuries.has(injury_id):
		errors.append("demonic_arts.json devouring has unknown injury '%s'" % injury_id)
	for key in ["heart_demon_chance", "heart_demon_per_devour", "heart_demon_max_chance"]:
		if float(r.get(key, 0.0)) < 0.0 or float(r.get(key, 0.0)) > 1.0:
			errors.append("demonic_arts.json devouring %s must be in 0..1" % key)
	if int(r.get("days", 0)) < 0:
		errors.append("demonic_arts.json devouring days must be >= 0")
	return errors
