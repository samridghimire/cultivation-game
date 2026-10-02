class_name Family
extends RefCounted
## Courtship and marriage (FAM-002), with per-gender rules from data/family.json:
## who may court whom, spousal ranks (e.g. one wife + concubines, or one Dao
## companion) and how many of each rank a character can have. Spouses are
## linked on both characters (CharacterData.spouses + spouse_ranks).
## Favor is owned by the caller (GameState.npc_favor) and passed in.


## The family.json rules for `gender` ({} if none).
static func gender_rules(data: GameData, gender: String) -> Dictionary:
	return data.family.get("genders", {}).get(gender, {})


## Rank ids a character of `gender` can give a spouse, in data order.
static func ranks(data: GameData, gender: String) -> Array[String]:
	var out: Array[String] = []
	for rank in gender_rules(data, gender).get("ranks", {}):
		out.append(String(rank))
	return out


static func rank_name(data: GameData, gender: String, rank: String) -> String:
	return String(gender_rules(data, gender).get("ranks", {}).get(rank, {}).get("name", rank))


## How many spouses of `rank` `c` may have (grows with realm for some ranks).
static func rank_limit(c: CharacterData, data: GameData, rank: String) -> int:
	var def: Dictionary = gender_rules(data, c.gender).get("ranks", {}).get(rank, {})
	return int(def.get("max", 0)) + int(def.get("max_per_realm", 0)) * c.realm_index


static func spouses_of_rank(c: CharacterData, rank: String) -> int:
	var count := 0
	for spouse_id in c.spouses:
		if String(c.spouse_ranks.get(spouse_id, "")) == rank:
			count += 1
	return count


static func is_married_to(a: CharacterData, b: CharacterData) -> bool:
	return a.spouses.has(b.id)


## Why `c` cannot pursue `other` romantically at all, or "" if they can.
static func check_partner(c: CharacterData, other: CharacterData, data: GameData) -> String:
	if other == null or not other.alive:
		return "There is no one to court."
	if not Names.is_gender(data, c.gender):
		return "Decide who you are before courting anyone."
	var adult := int(data.family.get("adult_age", 16))
	if c.age_years() < adult or other.age_years() < adult:
		return "Neither of you is old enough for that."
	if not (gender_rules(data, c.gender).get("partner_genders", []) as Array).has(other.gender):
		return "%s does not return that kind of interest." % other.name
	if is_married_to(c, other):
		return "%s is already your spouse." % other.name
	if not other.spouses.is_empty():
		return "%s is already married." % other.name
	return ""


## Favor gained per courtship outing: base, adjusted by Charisma (minimum 1).
static func courtship_gain(c: CharacterData, data: GameData) -> int:
	var rules: Dictionary = data.family.get("courtship", {})
	var step := maxi(1, int(rules.get("charisma_step", 2)))
	@warning_ignore("integer_division")
	var bonus := (c.attribute("charisma") - 10) / step
	return maxi(1, int(rules.get("favor_gain", 5)) + bonus)


static func check_court(c: CharacterData, other: CharacterData, favor: int, data: GameData) -> String:
	var reason := check_partner(c, other, data)
	if reason != "":
		return reason
	if favor < int(data.family.get("courtship", {}).get("min_favor", 0)):
		return "%s does not know you well enough to accept your attentions." % other.name
	return ""


## A courtship outing. Returns {ok, reason, favor (gain), days}.
static func court(c: CharacterData, other: CharacterData, favor: int, data: GameData) -> Dictionary:
	var reason := check_court(c, other, favor, data)
	if reason != "":
		return {"ok": false, "reason": reason, "favor": 0, "days": 0}
	return {"ok": true, "reason": "", "favor": courtship_gain(c, data), "days": int(data.family.get("courtship", {}).get("days", 1))}


## Why `other` would refuse `c`'s proposal for `rank`, or "" if they accept.
static func check_proposal(c: CharacterData, other: CharacterData, favor: int, rank: String, data: GameData) -> String:
	var reason := check_partner(c, other, data)
	if reason != "":
		return reason
	if not ranks(data, c.gender).has(rank):
		return "That is not a station you can offer."
	if spouses_of_rank(c, rank) >= rank_limit(c, data, rank):
		return "You cannot take another %s." % rank_name(data, c.gender, rank).to_lower()
	var rules: Dictionary = data.family.get("proposal", {})
	if favor < int(rules.get("min_favor", 0)):
		return "%s is not ready to bind their life to yours." % other.name
	if absi(c.realm_index - other.realm_index) > int(rules.get("max_realm_gap", 99)):
		return "The gap between your cultivation realms is too wide for %s." % other.name
	if absi(c.alignment - other.alignment) > int(rules.get("max_alignment_gap", 2000)):
		return "%s cannot walk the same path as you." % other.name
	if rank == String(data.family.get("concubine_rank", "")):
		if bool(data.npcs.get(other.id, {}).get("proud", false)) or other.realm_index > c.realm_index:
			return "%s is too proud to become anyone's %s." % [other.name, rank_name(data, c.gender, rank).to_lower()]
	return ""


## Proposes to `other` for `rank` and marries them on success.
## Returns {ok, reason, days}.
static func propose(c: CharacterData, other: CharacterData, favor: int, rank: String, data: GameData) -> Dictionary:
	var reason := check_proposal(c, other, favor, rank, data)
	if reason != "":
		return {"ok": false, "reason": reason, "days": 0}
	marry(c, other, rank)
	return {"ok": true, "reason": "", "days": int(data.family.get("proposal", {}).get("days", 1))}


## Links two characters as spouses, recording the marriage's rank on both.
static func marry(a: CharacterData, b: CharacterData, rank: String) -> void:
	if not a.spouses.has(b.id):
		a.spouses.append(b.id)
	if not b.spouses.has(a.id):
		b.spouses.append(a.id)
	a.spouse_ranks[b.id] = rank
	b.spouse_ranks[a.id] = rank


## Load errors for data/family.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var genders: Dictionary = data.family.get("genders", {})
	for gender in Names.genders(data):
		if not genders.has(gender):
			errors.append("family.json has no rules for gender '%s'" % gender)
	for gender in genders:
		if not Names.is_gender(data, String(gender)):
			errors.append("family.json has rules for unknown gender '%s'" % gender)
		var rules: Dictionary = genders[gender]
		for partner in rules.get("partner_genders", []):
			if not Names.is_gender(data, String(partner)):
				errors.append("family.json gender '%s' has unknown partner gender '%s'" % [gender, partner])
		if (rules.get("ranks", {}) as Dictionary).is_empty():
			errors.append("family.json gender '%s' has no ranks" % gender)
		for rank in rules.get("ranks", {}):
			if int(rules["ranks"][rank].get("max", 0)) < 1:
				errors.append("family.json rank '%s' needs max >= 1" % rank)
	return errors
