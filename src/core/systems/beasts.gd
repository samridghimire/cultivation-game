class_name Beasts
extends RefCounted
## Spirit beast companions (BEAST-001), defined in data/beasts.json. A Beast
## Tamer who defeats a beast's enemy may tame it; companions (CharacterData.
## companions, beast ids) add a fraction of their master's combat stats,
## stronger with Beast Tamer rank and fading once the master outgrows them.

const PROFESSION := "beast_tamer"
const BONUS_KEYS := ["max_hp", "attack", "defense", "speed"]


static func def(data: GameData, beast_id: String) -> Dictionary:
	return data.beasts.get(beast_id, {})


static func beast_name(data: GameData, beast_id: String) -> String:
	return String(def(data, beast_id).get("name", beast_id))


## The beast id an enemy can be tamed into, or "".
static func beast_for_enemy(data: GameData, enemy_id: String) -> String:
	for beast: Dictionary in data.beasts.values():
		if String(beast.get("enemy", "")) == enemy_id:
			return String(beast["id"])
	return ""


static func is_tamer(c: CharacterData) -> bool:
	return c.professions.has(PROFESSION)


static func max_companions(data: GameData) -> int:
	return int(data.beast_rules.get("max_companions", 1))


## Chance that `c` tames a defeated beast: base + per rank, capped.
static func tame_chance(c: CharacterData, data: GameData) -> float:
	var tame: Dictionary = data.beast_rules.get("tame", {})
	var chance := float(tame.get("base_chance", 0.0)) + float(tame.get("chance_per_rank", 0.0)) * Professions.rank_of(c, PROFESSION)
	return clampf(chance, 0.0, float(tame.get("max_chance", 1.0)))


## Why `c` cannot try to tame `beast_id` after defeating it, or "" if they can.
static func check_tame(c: CharacterData, data: GameData, beast_id: String) -> String:
	if not data.beasts.has(beast_id):
		return "That creature cannot be tamed."
	if not is_tamer(c):
		return "Only a Beast Tamer knows how to tame a spirit beast."
	var min_rank := int(def(data, beast_id).get("min_rank", 0))
	if Professions.rank_of(c, PROFESSION) < min_rank:
		return "You need to be a %s Beast Tamer to tame a %s." % [data.profession_rank_names[min_rank], beast_name(data, beast_id)]
	if c.companions.size() >= max_companions(data):
		return "You cannot keep another companion."
	return ""


## After defeating `enemy_id`, tries to tame it. Tries only when the enemy is a
## beast and check_tame passes. Returns {attempted, tamed, beast, chance,
## ranks_gained}.
static func try_tame(c: CharacterData, data: GameData, enemy_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var beast_id := beast_for_enemy(data, enemy_id)
	var out := {"attempted": false, "tamed": false, "beast": beast_id, "chance": 0.0, "ranks_gained": 0}
	if beast_id == "" or check_tame(c, data, beast_id) != "":
		return out
	out["attempted"] = true
	out["chance"] = tame_chance(c, data)
	out["ranks_gained"] = Professions.add_xp(c, data, PROFESSION, float(data.beast_rules.get("tame", {}).get("xp", 0)))
	if rng.randf() < float(out["chance"]):
		c.companions.append(beast_id)
		out["tamed"] = true
	return out


## How much of its full bonus `beast_id` still gives `c`: Beast Tamer rank
## raises it, outgrowing the beast's realm lowers it.
static func strength_of(c: CharacterData, data: GameData, beast_id: String) -> float:
	var rank_mult := 1.0 + float(data.beast_rules.get("rank_scale", 0.0)) * Professions.rank_of(c, PROFESSION)
	var enemy: Dictionary = data.enemies.get(String(def(data, beast_id).get("enemy", "")), {})
	var beast_realm := data.realm_index_of(String(enemy.get("realm", "mortal")))
	var outgrown := maxi(0, c.realm_index - beast_realm)
	return rank_mult * pow(float(data.beast_rules.get("outgrown_scale", 1.0)), outgrown)


## The combat stat fraction (`key` in BONUS_KEYS) all of `c`'s companions add.
static func bonus(c: CharacterData, data: GameData, key: String) -> float:
	var total := 0.0
	for beast_id in c.companions:
		total += float(def(data, beast_id).get("bonuses", {}).get(key, 0.0)) * strength_of(c, data, beast_id)
	return total


## Sends companion `index` back to the wild. Returns its name, or "" if none.
static func release(c: CharacterData, data: GameData, index: int) -> String:
	if index < 0 or index >= c.companions.size():
		return ""
	var beast_id: String = c.companions[index]
	c.companions.remove_at(index)
	return beast_name(data, beast_id)


## One line per companion, e.g. "Mist Wolf: +9% attack, +6% speed".
static func describe(c: CharacterData, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	for beast_id in c.companions:
		var parts: PackedStringArray = []
		var strength := strength_of(c, data, beast_id)
		var bonuses: Dictionary = def(data, beast_id).get("bonuses", {})
		for key in BONUS_KEYS:
			if bonuses.has(key):
				parts.append("+%d%% %s" % [roundi(float(bonuses[key]) * strength * 100.0), key.replace("max_hp", "hp")])
		lines.append("%s: %s" % [beast_name(data, beast_id), ", ".join(parts)])
	return lines


## Load errors for data/beasts.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.beasts.is_empty():
		return errors
	if max_companions(data) < 1:
		errors.append("beasts.json needs max_companions >= 1")
	var tame: Dictionary = data.beast_rules.get("tame", {})
	var max_chance := float(tame.get("max_chance", 1.0))
	if float(tame.get("base_chance", 0.0)) < 0.0 or max_chance <= 0.0 or max_chance > 1.0:
		errors.append("beasts.json tame needs base_chance >= 0 and max_chance in (0, 1]")
	var outgrown := float(data.beast_rules.get("outgrown_scale", 1.0))
	if outgrown <= 0.0 or outgrown > 1.0:
		errors.append("beasts.json outgrown_scale must be in (0, 1]")
	var seen_enemies := {}
	for beast: Dictionary in data.beasts.values():
		var enemy_id := String(beast.get("enemy", ""))
		if not data.enemies.has(enemy_id):
			errors.append("Beast '%s' references unknown enemy '%s'" % [beast["id"], enemy_id])
		elif seen_enemies.has(enemy_id):
			errors.append("Beast '%s' shares enemy '%s' with another beast" % [beast["id"], enemy_id])
		seen_enemies[enemy_id] = true
		var min_rank := int(beast.get("min_rank", 0))
		if min_rank < 0 or min_rank > Professions.max_rank(data):
			errors.append("Beast '%s' has min_rank %d outside the profession ranks" % [beast["id"], min_rank])
		var bonuses: Dictionary = beast.get("bonuses", {})
		if bonuses.is_empty():
			errors.append("Beast '%s' has no bonuses" % beast["id"])
		for key in bonuses:
			if not BONUS_KEYS.has(key):
				errors.append("Beast '%s' has unknown bonus '%s'" % [beast["id"], key])
			elif float(bonuses[key]) <= 0.0:
				errors.append("Beast '%s' bonus '%s' must be > 0" % [beast["id"], key])
	if not data.professions.has(PROFESSION):
		errors.append("beasts.json needs the '%s' profession" % PROFESSION)
	return errors
