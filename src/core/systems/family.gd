class_name Family
extends RefCounted
## Courtship and marriage (FAM-002), with per-gender rules from data/family.json:
## who may court whom, spousal ranks (e.g. one wife + concubines, or one Dao
## companion) and how many of each rank a character can have. Spouses are
## linked on both characters (CharacterData.spouses + spouse_ranks).
## Favor is owned by the caller (GameState.npc_favor) and passed in.
## Dead spouses stay in `spouses` as family history but no longer hold a rank
## slot (FAM-002g): functions that count spouses take `people` (id ->
## CharacterData, e.g. GameState.npcs); ids missing from it (e.g. the player)
## count as living.


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


## Whether the character `id` is alive according to `people`; unknown ids
## (not in `people`, e.g. the player) count as living.
static func is_living(id: String, people: Dictionary) -> bool:
	var other: CharacterData = people.get(id)
	return other == null or other.alive


## `c`'s spouses who are still alive (dead spouses remain in c.spouses).
static func living_spouses(c: CharacterData, people: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	for spouse_id in c.spouses:
		if is_living(spouse_id, people):
			out.append(spouse_id)
	return out


## Living spouses of `c` married at `rank`.
static func spouses_of_rank(c: CharacterData, rank: String, people: Dictionary = {}) -> int:
	var count := 0
	for spouse_id in living_spouses(c, people):
		if String(c.spouse_ranks.get(spouse_id, "")) == rank:
			count += 1
	return count


static func is_married_to(a: CharacterData, b: CharacterData) -> bool:
	return a.spouses.has(b.id)


## Why `c` cannot pursue `other` romantically at all, or "" if they can.
static func check_partner(c: CharacterData, other: CharacterData, data: GameData, people: Dictionary = {}) -> String:
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
	if is_close_kin(c, other, people):
		return "%s is your kin." % other.name
	if not living_spouses(other, people).is_empty():
		return "%s is already married." % other.name
	return ""


## Whether `a` and `b` are close kin who may not marry: parent and child,
## grandparent and grandchild, or (half-)siblings. Grandparents are looked up
## through `people` (ids missing from it are skipped).
static func is_close_kin(a: CharacterData, b: CharacterData, people: Dictionary = {}) -> bool:
	if a.children.has(b.id) or b.children.has(a.id):
		return true
	for parent_id in a.parents:
		if b.parents.has(parent_id):
			return true
	return _ancestors(a, people, a, b).has(b.id) or _ancestors(b, people, a, b).has(a.id)


## Parent and grandparent ids of `c`. `a` and `b` are found by id even when
## they are not in `people` (e.g. the player).
static func _ancestors(c: CharacterData, people: Dictionary, a: CharacterData, b: CharacterData) -> Array[String]:
	var out: Array[String] = []
	for parent_id in c.parents:
		out.append(parent_id)
		var parent: CharacterData = a if parent_id == a.id else b if parent_id == b.id else people.get(parent_id)
		if parent != null:
			out.append_array(parent.parents)
	return out


## Favor gained per courtship outing: base, adjusted by Charisma (minimum 1).
static func courtship_gain(c: CharacterData, data: GameData) -> int:
	var rules: Dictionary = data.family.get("courtship", {})
	var step := maxi(1, int(rules.get("charisma_step", 2)))
	@warning_ignore("integer_division")
	var bonus := (c.attribute("charisma") - 10) / step
	return maxi(1, int(rules.get("favor_gain", 5)) + bonus)


static func check_court(c: CharacterData, other: CharacterData, favor: int, data: GameData, people: Dictionary = {}) -> String:
	var reason := check_partner(c, other, data, people)
	if reason != "":
		return reason
	if favor < int(data.family.get("courtship", {}).get("min_favor", 0)):
		return "%s does not know you well enough to accept your attentions." % other.name
	return ""


## A courtship outing. Returns {ok, reason, favor (gain), days}.
static func court(c: CharacterData, other: CharacterData, favor: int, data: GameData, people: Dictionary = {}) -> Dictionary:
	var reason := check_court(c, other, favor, data, people)
	if reason != "":
		return {"ok": false, "reason": reason, "favor": 0, "days": 0}
	return {"ok": true, "reason": "", "favor": courtship_gain(c, data), "days": int(data.family.get("courtship", {}).get("days", 1))}


## Favor gained per chat (data/family.json acquaintance): base chat_favor,
## adjusted by Charisma like courtship (minimum 1).
static func chat_gain(c: CharacterData, data: GameData) -> int:
	var rules: Dictionary = data.family.get("acquaintance", {})
	var step := maxi(1, int(rules.get("charisma_step", 4)))
	@warning_ignore("integer_division")
	var bonus := (c.attribute("charisma") - 10) / step
	return maxi(1, int(rules.get("chat_favor", 2)) + bonus)


## Why `c` cannot chat with `other` (favor `favor`), or "" if they can.
## NPCs with a dialogue file (data/npcs.json) are talked to through it instead.
static func check_chat(c: CharacterData, other: CharacterData, favor: int, data: GameData) -> String:
	if other == null or not other.alive or other.id == c.id:
		return "There is no one to talk to."
	if String(data.npcs.get(other.id, {}).get("dialogue", "")) != "":
		return "Speak with %s properly instead." % other.name
	if favor >= int(data.family.get("acquaintance", {}).get("chat_max_favor", 0)):
		return "Small talk will not bring you closer to %s now." % other.name
	return ""


## Passing the time with an NPC. Returns {ok, reason, favor (gain, never past
## chat_max_favor), days}.
static func chat(c: CharacterData, other: CharacterData, favor: int, data: GameData) -> Dictionary:
	var reason := check_chat(c, other, favor, data)
	if reason != "":
		return {"ok": false, "reason": reason, "favor": 0, "days": 0}
	var rules: Dictionary = data.family.get("acquaintance", {})
	var gain := mini(chat_gain(c, data), int(rules.get("chat_max_favor", 0)) - favor)
	return {"ok": true, "reason": "", "favor": gain, "days": int(rules.get("chat_days", 1))}


## Favor a gift of `item_id` is worth: its price / gift_price_per_favor,
## between 1 and gift_max_per_item; 0 for worthless (price 0) items.
static func gift_value(data: GameData, item_id: String) -> int:
	var rules: Dictionary = data.family.get("acquaintance", {})
	var price := int(data.items.get(item_id, {}).get("price", 0))
	if price <= 0:
		return 0
	@warning_ignore("integer_division")
	return clampi(price / maxi(1, int(rules.get("gift_price_per_favor", 10))), 1, int(rules.get("gift_max_per_item", 10)))


## How the named NPC `npc_id` feels about `item_id` (GIFT-001): 1 liked, -1 disliked,
## 0 neutral. npcs.json `likes`/`dislikes` entries match an item id or one of its
## tags; a dislike wins over a like. Generated NPCs have no tastes.
static func gift_taste(data: GameData, npc_id: String, item_id: String) -> int:
	var def: Dictionary = data.npcs.get(npc_id, {})
	var tags: Array = data.items.get(item_id, {}).get("tags", [])
	for entry in def.get("dislikes", []):
		if entry == item_id or tags.has(entry):
			return -1
	for entry in def.get("likes", []):
		if entry == item_id or tags.has(entry):
			return 1
	return 0


## WU-108: true when `item_id` matches the NPC's first `likes` entry (an item id or one of its tags),
## the one a chat hint ("<Name> is fond of herbs.") names.
static func matches_first_like(data: GameData, npc_id: String, item_id: String) -> bool:
	var likes: Array = data.npcs.get(npc_id, {}).get("likes", [])
	if likes.is_empty():
		return false
	var tags: Array = data.items.get(item_id, {}).get("tags", [])
	return likes[0] == item_id or tags.has(likes[0])


## The favor a gift of `item_id` is worth to `npc_id` before the favor cap, given what the
## player has learned of their `taste` (1, -1 or 0 = unknown/neutral; WU-089).
static func gift_favor_preview(data: GameData, item_id: String, taste: int) -> int:
	var rules: Dictionary = data.family.get("acquaintance", {})
	if taste < 0:
		return int(rules.get("gift_dislike_favor", 0))
	var gain := gift_value(data, item_id)
	if taste > 0:
		gain = ceili(gain * float(rules.get("gift_like_mult", 1.0)))
	return gain


## A readable word for a likes entry: the item's name, or the plural of a tag.
static func _taste_word(data: GameData, entry: String) -> String:
	if data.items.has(entry):
		return String(data.items[entry].get("name", entry)).to_lower()
	var word := entry.replace("_", " ")
	return word if word.ends_with("s") else word + "s"


## WU-106: the gift tastes learned for `npc_id` from world flags taste_<npc>_<item>:
## item_id -> 1 (liked) or -1 (disliked). Only keys whose remainder is a real item id count,
## so "li" never matches "li_wei"'s flags, and taste_told_* is skipped.
static func known_tastes(flags: Dictionary, data: GameData, npc_id: String) -> Dictionary:
	var prefix := "taste_%s_" % npc_id
	var out := {}
	for key: String in flags:
		if not key.begins_with(prefix) or key.begins_with("taste_told_"):
			continue
		var item_id := key.substr(prefix.length())
		if not data.items.has(item_id):
			continue
		var taste := int(flags[key])
		if taste != 0:
			out[item_id] = 1 if taste > 0 else -1
	return out


## "<Name> is fond of herbs." for the NPC's first like, or "" if they have none.
static func taste_hint(data: GameData, npc_id: String) -> String:
	var def: Dictionary = data.npcs.get(npc_id, {})
	var likes: Array = def.get("likes", [])
	if likes.is_empty():
		return ""
	return "%s is fond of %s." % [def.get("name", npc_id), _taste_word(data, String(likes[0]))]


## Why `c` cannot give `item_id` to `other`, or "" if they can.
static func check_gift(c: CharacterData, other: CharacterData, favor: int, item_id: String, data: GameData) -> String:
	if other == null or not other.alive or other.id == c.id:
		return "There is no one to give it to."
	if c.item_count(item_id) < 1:
		return "You do not have that."
	if gift_value(data, item_id) <= 0:
		return "%s has no use for that." % other.name
	if favor >= int(data.family.get("acquaintance", {}).get("gift_max_favor", 0)) and gift_taste(data, other.id, item_id) >= 0:
		return "%s politely declines. Gifts alone will not win more of their heart." % other.name
	return ""


## Gives one `item_id` to `other` (removed from `c`'s inventory).
## Returns {ok, reason, favor (gain, never past gift_max_favor; negative for a
## disliked gift), days, taste (1 liked, -1 disliked, 0)}. `other.id` picks the tastes.
static func give_gift(c: CharacterData, other: CharacterData, favor: int, item_id: String, data: GameData) -> Dictionary:
	var reason := check_gift(c, other, favor, item_id, data)
	if reason != "":
		return {"ok": false, "reason": reason, "favor": 0, "days": 0, "taste": 0}
	var rules: Dictionary = data.family.get("acquaintance", {})
	c.add_item(item_id, -1)
	var taste := gift_taste(data, other.id, item_id)
	var gain := gift_value(data, item_id)
	if taste > 0:
		gain = ceili(gain * float(rules.get("gift_like_mult", 1.0)))
	gain = mini(gain, int(rules.get("gift_max_favor", 0)) - favor)
	if taste < 0:
		gain = int(rules.get("gift_dislike_favor", 0))
	return {"ok": true, "reason": "", "favor": gain, "days": int(rules.get("gift_days", 0)), "taste": taste}


## Why `other` would refuse `c`'s proposal for `rank`, or "" if they accept.
static func check_proposal(c: CharacterData, other: CharacterData, favor: int, rank: String, data: GameData, people: Dictionary = {}) -> String:
	var reason := check_partner(c, other, data, people)
	if reason != "":
		return reason
	if not ranks(data, c.gender).has(rank):
		return "That is not a station you can offer."
	if spouses_of_rank(c, rank, people) >= rank_limit(c, data, rank):
		return "You cannot take another %s." % rank_name(data, c.gender, rank).to_lower()
	var rules: Dictionary = data.family.get("proposal", {})
	if favor < int(rules.get("min_favor", 0)):
		return "%s is not ready to bind their life to yours." % other.name
	if absi(c.realm_index - other.realm_index) > int(rules.get("max_realm_gap", 99)):
		return "The gap between your cultivation realms is too wide for %s." % other.name
	if absi(c.alignment - other.alignment) > int(rules.get("max_alignment_gap", 2000)):
		return "%s cannot walk the same path as you." % other.name
	if rank == String(data.family.get("concubine_rank", "")):
		if Npcs.is_proud(other, data) or other.realm_index > c.realm_index:
			return "%s is too proud to become anyone's %s." % [other.name, rank_name(data, c.gender, rank).to_lower()]
	return ""


## Proposes to `other` for `rank` and marries them on success.
## Returns {ok, reason, days}.
static func propose(c: CharacterData, other: CharacterData, favor: int, rank: String, data: GameData, people: Dictionary = {}) -> Dictionary:
	var reason := check_proposal(c, other, favor, rank, data, people)
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


## How strongly `spouse` boosts `c`'s dual cultivation: sqrt of the spouse's
## root multiplier, scaled per major realm the spouse is above (or below) `c`,
## clamped to data/family.json dual_cultivation min_factor..max_factor.
static func partner_factor(c: CharacterData, spouse: CharacterData, data: GameData) -> float:
	var rules: Dictionary = data.family.get("dual_cultivation", {})
	var roots := sqrt(maxf(0.0, SpiritualRoots.cultivation_multiplier(spouse.spiritual_roots, data)))
	var realm := pow(1.0 + float(rules.get("realm_step", 0.0)), spouse.realm_index - c.realm_index)
	return clampf(roots * realm, float(rules.get("min_factor", 0.0)), float(rules.get("max_factor", 1.0)))


## Qi multiplier for `c` cultivating together with `spouse` (1.0 = no bonus).
static func dual_multiplier(c: CharacterData, spouse: CharacterData, data: GameData) -> float:
	return 1.0 + float(data.family.get("dual_cultivation", {}).get("qi_bonus", 0.0)) * partner_factor(c, spouse, data)


## Why `c` cannot dual cultivate with `spouse`, or "" if they can.
static func check_dual_cultivation(c: CharacterData, spouse: CharacterData, data: GameData) -> String:
	if spouse == null or not spouse.alive:
		return "There is no one to cultivate with."
	if not is_married_to(c, spouse):
		return "Only spouses may share their cultivation."
	if SpiritualRoots.cultivation_multiplier(c.spiritual_roots, data) <= 0.0:
		return "Without a spiritual root, qi slips through you like water."
	if SpiritualRoots.cultivation_multiplier(spouse.spiritual_roots, data) <= 0.0:
		return "%s has no spiritual root to share qi with." % spouse.name
	if Cultivation.is_at_bottleneck(c, data):
		return "You are at a bottleneck. Attempt a breakthrough first."
	return ""


## Both partners cultivate for `days` at `density`, each with their dual
## cultivation multiplier. Returns {ok, reason, qi_gained, stages_gained,
## at_bottleneck, spouse_qi, spouse_stages, favor}. A spouse at their own
## bottleneck still helps but gains nothing.
static func dual_cultivate(c: CharacterData, spouse: CharacterData, data: GameData, days: int, density: float = 1.0) -> Dictionary:
	var reason := check_dual_cultivation(c, spouse, data)
	if reason != "":
		return {"ok": false, "reason": reason}
	var own := Cultivation.cultivate(c, data, days, density * dual_multiplier(c, spouse, data))
	var theirs := Cultivation.cultivate(spouse, data, days, density * dual_multiplier(spouse, c, data))
	own["ok"] = true
	own["reason"] = ""
	own["spouse_qi"] = theirs["qi_gained"]
	own["spouse_stages"] = theirs["stages_gained"]
	own["favor"] = int(data.family.get("dual_cultivation", {}).get("favor_per_session", 0))
	return own


## Favor each spouse gains when time passes from `age_days_before` to
## `age_days_after` (counted per 30-day month boundary crossed, so many short
## actions add up the same as one long one).
static func spouse_favor_gain(data: GameData, age_days_before: int, age_days_after: int) -> int:
	@warning_ignore("integer_division")
	var months := age_days_after / 30 - age_days_before / 30
	return maxi(0, months) * int(data.family.get("dual_cultivation", {}).get("favor_per_month", 0))


## Adds `gain` to `favor`, but never raises it past dual_cultivation max_favor
## (favor already above the cap is kept).
static func add_spouse_favor(data: GameData, favor: int, gain: int) -> int:
	var cap := int(data.family.get("dual_cultivation", {}).get("max_favor", 100))
	return maxi(favor, mini(cap, favor + gain))


## NEWS-001: word of a major-realm breakthrough spreads. Every living NPC the
## player knows (favor >= min_favor) gains `favor` (capped at 100), and a sect
## member gains `sect_reputation` with their own sect. `favor_map` is
## GameState.npc_favor and is changed in place. Returns the ids raised; nothing
## happens without data/family.json `breakthrough_news`.
static func breakthrough_news(c: CharacterData, data: GameData, npcs: Dictionary, favor_map: Dictionary) -> Array[String]:
	var raised: Array[String] = []
	var rules: Dictionary = data.family.get("breakthrough_news", {})
	if rules.is_empty():
		return raised
	var min_favor := int(rules.get("min_favor", 10))
	var gain := int(rules.get("favor", 0))
	if gain > 0:
		for id: String in favor_map:
			var other: CharacterData = npcs.get(id)
			if other == null or not other.alive or int(favor_map[id]) < min_favor:
				continue
			var after := mini(100, int(favor_map[id]) + gain)
			if after > int(favor_map[id]):
				favor_map[id] = after
				raised.append(id)
	var sect_id := String(c.sect.get("id", ""))
	if sect_id != "":
		Reputation.change(c, data, sect_id, int(rules.get("sect_reputation", 0)))
	return raised


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
	errors.append_array(Mentorship.validate(data))
	errors.append_array(Letters.validate(data))
	for key: String in data.family.get("breakthrough_news", {}):
		var v: Variant = data.family["breakthrough_news"][key]
		if (typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT) or int(v) < 0 or float(v) != int(v):
			errors.append("family.json breakthrough_news.%s must be an int >= 0" % key)
	var dual: Dictionary = data.family.get("dual_cultivation", {})
	if dual.is_empty():
		errors.append("family.json needs a dual_cultivation block")
	elif float(dual.get("min_factor", 0.0)) > float(dual.get("max_factor", 0.0)) or float(dual.get("qi_bonus", -1.0)) < 0.0:
		errors.append("family.json dual_cultivation needs qi_bonus >= 0 and min_factor <= max_factor")
	var acq: Dictionary = data.family.get("acquaintance", {})
	if not acq.is_empty():
		for key in ["chat_days", "chat_favor", "chat_max_favor", "gift_days", "gift_price_per_favor", "gift_max_per_item", "gift_max_favor"]:
			if not acq.has(key) or int(acq[key]) < 0:
				errors.append("family.json acquaintance needs %s >= 0" % key)
		if int(acq.get("gift_price_per_favor", 0)) < 1 or int(acq.get("gift_max_per_item", 0)) < 1:
			errors.append("family.json acquaintance needs gift_price_per_favor and gift_max_per_item >= 1")
		if float(acq.get("gift_like_mult", 1.0)) < 1.0:
			errors.append("family.json acquaintance gift_like_mult must be >= 1")
		if int(acq.get("gift_dislike_favor", 0)) > 0:
			errors.append("family.json acquaintance gift_dislike_favor must be <= 0")
	var tags_used: Dictionary = {}
	for item: Dictionary in data.items.values():
		for tag in item.get("tags", []):
			tags_used[tag] = true
	for npc_id in data.npcs:
		for key in ["likes", "dislikes"]:
			for entry in data.npcs[npc_id].get(key, []):
				if not data.items.has(entry) and not tags_used.has(entry):
					errors.append("NPC '%s' %s unknown item or tag '%s'" % [npc_id, key, entry])
	var eligible: Dictionary = data.family.get("eligible_npcs", {})
	if eligible.is_empty():
		return errors  # optional: no generated courtship candidates
	if int(eligible.get("age_min", 0)) < int(data.family.get("adult_age", 16)) or int(eligible.get("age_max", 0)) < int(eligible.get("age_min", 0)):
		errors.append("family.json eligible_npcs needs adult_age <= age_min <= age_max")
	if (eligible.get("realms_by_danger", []) as Array).is_empty():
		errors.append("family.json eligible_npcs needs realms_by_danger")
	for realms in eligible.get("realms_by_danger", []):
		if (realms as Array).is_empty():
			errors.append("family.json eligible_npcs realms_by_danger has an empty entry")
		for realm_id in realms:
			if data.realm_index_of(String(realm_id)) < 0:
				errors.append("family.json eligible_npcs has unknown realm '%s'" % realm_id)
	return errors


## Display lines for `c`'s family links (spouses with their rank, children,
## parents), looked up by id in `people` (e.g. GameState.npcs). Ids that are
## not in `people` show as "Unknown". Kin's bloodlines are known, even dormant ones.
static func describe_links(c: CharacterData, people: Dictionary, data: GameData) -> Array[String]:
	var out: Array[String] = []
	for spouse_id in c.spouses:
		var title := rank_name(data, c.gender, String(c.spouse_ranks.get(spouse_id, ""))).capitalize()
		out.append("%s: %s" % [title if title != "" else "Spouse", _describe_relative(people.get(spouse_id), data)])
	for child_id in c.children:
		out.append("%s: %s" % [_kin_title(people.get(child_id), "Son", "Daughter", "Child"), _describe_relative(people.get(child_id), data)])
	for parent_id in c.parents:
		out.append("%s: %s" % [_kin_title(people.get(parent_id), "Father", "Mother", "Parent"), _describe_relative(people.get(parent_id), data)])
	return out


static func _kin_title(other: CharacterData, male: String, female: String, unknown: String) -> String:
	if other == null:
		return unknown
	match other.gender:
		"male":
			return male
		"female":
			return female
	return unknown


static func _describe_relative(other: CharacterData, data: GameData) -> String:
	if other == null:
		return "Unknown"
	if not other.alive:
		return "%s (deceased)" % other.name
	var text := "%s (%s, age %d" % [other.name, Cultivation.realm_label(other, data), other.age_years()]
	var bloodline := Bloodlines.describe(other, data)
	if bloodline != "":
		text += ", " + bloodline
	return text + ")"


## `c`'s living spouses whose home is `region_id`, in marriage order.
static func spouses_in_region(c: CharacterData, people: Dictionary, data: GameData, region_id: String) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for spouse_id in c.spouses:
		var spouse: CharacterData = people.get(spouse_id)
		if spouse != null and spouse.alive and Npcs.region_of(spouse, data) == region_id:
			out.append(spouse)
	return out


## "favor 25; 60 to propose": the next courtship threshold above `favor`
## (data/family.json courtship.min_favor, proposal.min_favor), or just "favor N".
static func favor_progress(favor: int, data: GameData) -> String:
	for step in [["court", data.family.get("courtship", {}).get("min_favor", 0)], ["propose", data.family.get("proposal", {}).get("min_favor", 0)]]:
		var needed := int(step[1])
		if needed > favor:
			return "favor %d; %d to %s" % [favor, needed - favor, step[0]]
	return "favor %d" % favor
