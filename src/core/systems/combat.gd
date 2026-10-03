class_name Combat
extends RefCounted
## Auto-resolved, turn-based duels between the player and an enemy from
## data/enemies.json. resolve() is pure (it never mutates the character);
## apply_outcome() then applies rewards or the price of defeat.
##
## Stats scale with realm power, so a realm gap is nearly impossible to
## overcome, while techniques, attributes and luck decide fights within a realm.

const MAX_ROUNDS := 30
## Each major realm multiplies base combat power by this.
const REALM_POWER_GROWTH := 3.0
## Each minor stage adds this fraction of the realm's base power.
const STAGE_POWER_STEP := 0.1
const BASE_HP := 30.0
const BASE_ATTACK := 8.0
const BASE_DEFENSE := 4.0
const BASE_SPEED := 10.0
const CRIT_MULTIPLIER := 1.5
const MAX_DODGE := 0.3


static func realm_power(realm_index: int, stage: int) -> float:
	return pow(REALM_POWER_GROWTH, realm_index) * (1.0 + stage * STAGE_POWER_STEP)


## Builds stats from realm power, attributes ({id: int}) and technique bonuses
## (flat per-level values, scaled by realm power except speed).
static func _build_stats(power: float, attrs: Dictionary, tech: Callable) -> Dictionary:
	var con := int(attrs.get("constitution", 10))
	var spi := int(attrs.get("spirit", 10))
	return {
		"max_hp": maxi(1, roundi(power * (BASE_HP + con * 2.0 + tech.call("max_hp")))),
		"attack": maxi(1, roundi(power * (BASE_ATTACK + spi * 0.4 + tech.call("attack")))),
		"defense": maxi(0, roundi(power * (BASE_DEFENSE + con * 0.2 + tech.call("defense")))),
		"speed": roundi(BASE_SPEED + tech.call("speed")),
		"crit": clampf(0.05 + (int(attrs.get("fortune", 10)) - 10) * 0.01, 0.0, 0.5),
	}


## Combat stats of a character: {max_hp, attack, defense, speed, crit}.
## Equipment adds flat bonuses first and an awakened bloodline scales them up;
## injuries then scale down max_hp, attack and defense, and temporary buffs
## (Buffs) scale them up.
static func stats(c: CharacterData, data: GameData) -> Dictionary:
	var power := realm_power(c.realm_index, c.stage)
	var s := _build_stats(power, c.attributes, func(key: String) -> float: return Techniques.bonus(c, data, key))
	for key in Equipment.STAT_KEYS:
		s[key] = maxi(1 if key != "defense" else 0, s[key] + Equipment.bonus(c, data, key))
	for key in ["max_hp", "attack", "defense", "speed"]:
		var blood := Bloodlines.bonus(c, data, key)
		if blood != 0.0:
			s[key] = maxi(1, roundi(s[key] * (1.0 + blood)))
	var hurt := Injuries.combat_multiplier(c, data)
	if hurt < 1.0:
		for key in ["max_hp", "attack", "defense"]:
			s[key] = maxi(1, roundi(s[key] * hurt))
	for key in Buffs.STAT_KEYS:
		var mult := Buffs.multiplier(c, key)
		if mult != 1.0:
			s[key] = maxi(1, roundi(s[key] * mult))
	return s


## Combat stats of an enemy definition. The flat hp/attack/defense/speed in
## the enemy data are added after scaling.
static func enemy_stats(enemy: Dictionary, data: GameData) -> Dictionary:
	var realm_index := maxi(0, data.realm_index_of(enemy.get("realm", "mortal")))
	var power := realm_power(realm_index, int(enemy.get("stage", 0)))
	var levels := {}
	for tech_id in enemy.get("techniques", []):
		levels[tech_id] = data.enemy_technique_level
	var s := _build_stats(power, {}, func(key: String) -> float: return Techniques.bonus_from(levels, {}, data, key))
	s["max_hp"] = maxi(1, s["max_hp"] + int(enemy.get("hp", 0)))
	s["attack"] = maxi(1, s["attack"] + int(enemy.get("attack", 0)))
	s["defense"] = maxi(0, s["defense"] + int(enemy.get("defense", 0)))
	s["speed"] = s["speed"] + int(enemy.get("speed", 0))
	return s


## Damage before randomness. Defense reduces damage proportionally, so it
## never makes an attacker completely harmless.
static func base_damage(attack: float, defense: float) -> float:
	return maxf(1.0, attack * attack / (attack + defense))


static func dodge_chance(defender_speed: int, attacker_speed: int) -> float:
	return clampf((defender_speed - attacker_speed) * 0.02, 0.0, MAX_DODGE)


## Fights to the end. Returns {victory, draw, escaped, rounds, log, player_hp,
## player_max_hp, enemy_hp, enemy_max_hp, talismans_used}. Readied combat
## talismans (CombatTalismans) strike first, shield the player, or turn a
## defeat into an escape. Does not modify `c`.
static func resolve(c: CharacterData, data: GameData, enemy: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var p := stats(c, data)
	var e := enemy_stats(enemy, data)
	var enemy_name: String = enemy.get("name", "The enemy")
	var player_hp: int = p["max_hp"]
	var enemy_hp: int = e["max_hp"]
	var lines: PackedStringArray = []
	var player_first: bool = p["speed"] >= e["speed"]
	lines.append("You face the %s. (You: %d hp, %d atk. Foe: %d hp, %d atk.)" % [enemy_name, player_hp, p["attack"], enemy_hp, e["attack"]])
	var used: Array[String] = []
	var shield := 0
	for item_id in CombatTalismans.available(c, data, "shield"):
		used.append(item_id)
		shield += CombatTalismans.amount(data, item_id)
		lines.append("You burn a %s: a barrier of qi surrounds you. (%d shield)" % [_item_name(data, item_id), CombatTalismans.amount(data, item_id)])
	for item_id in CombatTalismans.available(c, data, "strike"):
		if enemy_hp <= 0:
			break
		used.append(item_id)
		enemy_hp -= CombatTalismans.amount(data, item_id)
		lines.append("You hurl a %s for %d. (%s: %d hp)" % [_item_name(data, item_id), CombatTalismans.amount(data, item_id), enemy_name, maxi(enemy_hp, 0)])
	var rounds := 0
	while rounds < MAX_ROUNDS and player_hp > 0 and enemy_hp > 0:
		rounds += 1
		for player_turn in ([true, false] if player_first else [false, true]):
			if player_hp <= 0 or enemy_hp <= 0:
				break
			var atk: Dictionary = p if player_turn else e
			var def: Dictionary = e if player_turn else p
			var hit := _strike(atk, def, rng)
			if player_turn:
				enemy_hp -= hit["damage"]
				if hit["dodged"]:
					lines.append("The %s evades your strike." % enemy_name)
				else:
					lines.append("You strike%s for %d. (%s: %d hp)" % [" critically" if hit["crit"] else "", hit["damage"], enemy_name, maxi(enemy_hp, 0)])
			else:
				var absorbed := mini(shield, int(hit["damage"]))
				shield -= absorbed
				player_hp -= int(hit["damage"]) - absorbed
				if absorbed > 0 and absorbed == int(hit["damage"]):
					lines.append("Your barrier absorbs the %s's attack. (%d shield left)" % [enemy_name, shield])
				elif hit["dodged"]:
					lines.append("You evade the %s's attack." % enemy_name)
				else:
					lines.append("The %s hits you%s for %d. (You: %d hp)" % [enemy_name, " critically" if hit["crit"] else "", hit["damage"], maxi(player_hp, 0)])
	var victory := enemy_hp <= 0
	var draw := not victory and player_hp > 0
	var escapes := CombatTalismans.available(c, data, "escape")
	var escaped := not victory and not draw and not escapes.is_empty()
	if victory:
		lines.append("You defeat the %s!" % enemy_name)
	elif draw:
		lines.append("Neither side can finish the fight. You disengage.")
	elif escaped:
		used.append(escapes[0])
		player_hp = 1
		lines.append("On the brink of death you burn a %s and flee from the %s!" % [_item_name(data, escapes[0]), enemy_name])
	else:
		lines.append("You are defeated by the %s." % enemy_name)
	return {
		"victory": victory,
		"draw": draw,
		"escaped": escaped,
		"rounds": rounds,
		"log": lines,
		"player_hp": maxi(player_hp, 0),
		"player_max_hp": p["max_hp"],
		"enemy_hp": maxi(enemy_hp, 0),
		"enemy_max_hp": e["max_hp"],
		"talismans_used": used,
	}


static func _item_name(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("name", item_id))


## One attack. Returns {damage, crit, dodged}.
static func _strike(atk: Dictionary, def: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < dodge_chance(def["speed"], atk["speed"]):
		return {"damage": 0, "crit": false, "dodged": true}
	var dmg := base_damage(atk["attack"], def["defense"]) * rng.randf_range(0.6, 1.4)
	var crit := rng.randf() < float(atk["crit"])
	if crit:
		dmg *= CRIT_MULTIPLIER
	return {"damage": maxi(1, roundi(dmg)), "crit": crit, "dodged": false}


## Applies the result of resolve(). Burned talismans are consumed. Victory
## grants the enemy's rewards; an escape or draw costs nothing more; a lethal
## defeat kills; any other defeat costs spirit stones and may injure
## ("combat_defeat" in injuries.json). Returns {notes, died, cause, days,
## injury}. Marking the character dead is left to the caller.
static func apply_outcome(c: CharacterData, data: GameData, enemy: Dictionary, result: Dictionary, flags: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var enemy_name: String = enemy.get("name", "enemy")
	var burned := CombatTalismans.consume(c, data, result.get("talismans_used", []))
	var outcome := _outcome(c, data, enemy, enemy_name, result, flags, rng)
	if not burned.is_empty():
		var notes: PackedStringArray = ["Burned: %s" % ", ".join(burned)]
		notes.append_array(outcome["notes"])
		outcome["notes"] = notes
	return outcome


static func _outcome(c: CharacterData, data: GameData, enemy: Dictionary, enemy_name: String, result: Dictionary, flags: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if result["victory"]:
		return {"notes": Effects.apply(c, data, enemy.get("rewards", {}), flags), "died": false, "cause": "", "days": 1, "injury": ""}
	if result["draw"] or result.get("escaped", false):
		return {"notes": PackedStringArray(), "died": false, "cause": "", "days": 1, "injury": ""}
	if enemy.get("lethal", false):
		return {"notes": PackedStringArray(), "died": true, "cause": "You were slain by a %s at age %d." % [enemy_name, c.age_years()], "days": 0, "injury": ""}
	var lost := int(c.item_count("spirit_stone") * data.defeat_stone_loss)
	var notes: PackedStringArray = []
	if lost > 0:
		c.add_item("spirit_stone", -lost)
		notes.append("-%d Spirit Stone" % lost)
	var injury := Injuries.roll(c, data, "combat_defeat", rng)
	if injury != "":
		notes.append("Injured: %s" % Injuries.injury_name(data, injury))
	return {"notes": notes, "died": false, "cause": "", "days": 1, "injury": injury}


## Estimated chance (0..1) that `c` beats `enemy`, by simulating fights with
## a private fixed-seed rng (so it is stable and never touches game rng).
static func win_chance(c: CharacterData, data: GameData, enemy: Dictionary, samples: int = 40) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var wins := 0
	for i in samples:
		if resolve(c, data, enemy, rng)["victory"]:
			wins += 1
	return float(wins) / samples


## Danger rating for menus and encounter evasion, from win_chance().
static func danger_label(c: CharacterData, data: GameData, enemy: Dictionary) -> String:
	var chance := win_chance(c, data, enemy)
	if chance >= 0.9:
		return "Weak"
	if chance >= 0.5:
		return "Even"
	if chance >= 0.15:
		return "Dangerous"
	return "Deadly"
