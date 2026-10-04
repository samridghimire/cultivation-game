class_name NpcClans
extends RefCounted
## NPC clans (FAM-009), defined in data/clans.json. Each clan is founded once
## per game as generated NPCs (a head, a spouse and children sharing the clan
## surname) and kept as a ClanData keyed by clan id in GameState.npc_clans.
## Some clan youths are sent to sects at founding (FAM-009c).
## Members follow the head's family (Clans.sync_family); when the head dies the
## heir succeeds (Clans.succeed), and a clan whose line ends is extinct.
## Relations (FAM-009b, clans.json "relations"): each clan's standing toward the
## player (key PLAYER, shared with the player's clan) and the other clans,
## moved by deeds against members and by marriage alliances.

const PLAYER := "player"


static func clan_ids(data: GameData) -> Array[String]:
	var out: Array[String] = []
	for id in data.npc_clans:
		out.append(String(id))
	out.sort()
	return out


## Founds every clan in data/clans.json missing from `clans` (id -> ClanData),
## spawning its family into `npcs`. Returns the ids founded.
static func ensure(clans: Dictionary, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator) -> Array[String]:
	var founded: Array[String] = []
	for id in clan_ids(data):
		if not clans.has(id):
			clans[id] = found(data.npc_clans[id], npcs, data, rng)
			founded.append(id)
	return founded


## Spawns `def`'s founding family into `npcs` and returns its ClanData.
static func found(def: Dictionary, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator) -> ClanData:
	var surname := String(def.get("surname", ""))
	var region := String(def.get("region", ""))
	var alignment := int(def.get("alignment", 0))
	var head_def: Dictionary = def.get("head", {})
	var head := Npcs.spawn(npcs, data, rng, {"surname": surname, "region": region, "alignment": alignment, "gender": String(head_def.get("gender", "")), "age_years": int(head_def.get("age_years", 60)), "realm": String(head_def.get("realm", "mortal")), "stage": int(head_def.get("stage", 0))})
	var spouse_def: Dictionary = def.get("spouse", {})
	var partner_genders: Array = Family.gender_rules(data, head.gender).get("partner_genders", [])
	var spouse_ranks := Family.ranks(data, head.gender)
	var spouse: CharacterData = null
	if not partner_genders.is_empty() and not spouse_ranks.is_empty():
		spouse = Npcs.spawn(npcs, data, rng, {"gender": String(partner_genders[0]), "region": region, "alignment": alignment, "age_years": int(spouse_def.get("age_years", head.age_years())), "realm": String(spouse_def.get("realm", "mortal"))})
		Family.marry(head, spouse, spouse_ranks[0])
	var kids: Dictionary = def.get("children", {})
	var count_range: Array = kids.get("count", [0, 0])
	var age_range: Array = kids.get("age_years", [16, 30])
	for i in rng.randi_range(int(count_range[0]), int(count_range[1])):
		var child := Npcs.spawn(npcs, data, rng, {"surname": surname, "region": region, "alignment": alignment, "age_years": rng.randi_range(int(age_range[0]), int(age_range[1])), "realm": String(kids.get("realm", "mortal"))})
		head.children.append(child.id)
		child.parents.append(head.id)
		if spouse != null:
			spouse.children.append(child.id)
			child.parents.append(spouse.id)
			child.birth_rank = String(head.spouse_ranks.get(spouse.id, ""))
	_send_youths(head, npcs, data, rng)
	var clan := ClanData.new()
	clan.name = String(def.get("name", Clans.clan_name(head, data)))
	clan.head = head.id
	clan.members[head.id] = Clans.head_rank(data)
	Clans.sync_family(head, clan, npcs, data)
	return clan


## FAM-009c: each of `head`'s children old enough (family.json sect_entry)
## joins, with clan_youth_chance, a sect that would accept them.
static func _send_youths(head: CharacterData, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator) -> void:
	var rules: Dictionary = data.family.get("sect_entry", {})
	var chance := float(rules.get("clan_youth_chance", 0.0))
	if chance <= 0.0:
		return
	for child_id in head.children:
		var child: CharacterData = npcs.get(child_id)
		if child == null or child.age_years() < int(rules.get("min_age_years", 12)) or rng.randf() >= chance:
			continue
		var sects := Sects.accepting_sects(child, data)
		if not sects.is_empty():
			Sects.npc_join(child, data, sects[rng.randi_range(0, sects.size() - 1)])


## Whether the clan's line has ended (no head left).
static func is_extinct(clan: ClanData) -> bool:
	return clan.head == ""


## Keeps every clan in `clans` in step with its people after time passed:
## succession when the head has died, then new spouses/descendants join and
## the dead leave. Returns news events [{clan_id, text, category}].
static func simulate(clans: Dictionary, npcs: Dictionary, data: GameData) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for id in clans:
		var clan: ClanData = clans[id]
		if is_extinct(clan):
			continue
		var old: CharacterData = npcs.get(clan.head)
		if old == null or not old.alive:
			var result := Clans.succeed(clan, npcs, data)
			var old_name := old.name if old != null else "its head"
			if result["succeeded"]:
				var heir: CharacterData = npcs[result["head"]]
				events.append({"clan_id": id, "text": "The %s mourns %s. %s now leads the clan as its %s." % [clan.name, old_name, heir.name, Clans.rank_name(data, Clans.head_rank(data), heir.gender)], "category": "info"})
			else:
				events.append({"clan_id": id, "text": "With the death of %s, the line of the %s has ended." % [old_name, clan.name], "category": "info"})
				continue
		Clans.sync_family(npcs[clan.head], clan, npcs, data)
	return events


## The clan id that `npc_id` belongs to ("" if none).
static func clan_of(clans: Dictionary, npc_id: String) -> String:
	for id in clans:
		if (clans[id] as ClanData).members.has(npc_id):
			return String(id)
	return ""


## "Patriarch of the Zhao Clan", "Young Master of the Zhao Clan" (the heir) or
## "Elder of the Zhao Clan" for a member of an NPC clan; "" for anyone else.
static func membership_text(clans: Dictionary, npcs: Dictionary, data: GameData, npc_id: String) -> String:
	var clan_id := clan_of(clans, npc_id)
	if clan_id == "":
		return ""
	var clan: ClanData = clans[clan_id]
	var npc: CharacterData = npcs.get(npc_id)
	var gender := npc.gender if npc != null else ""
	var head: CharacterData = npcs.get(clan.head)
	if npc_id != clan.head and head != null and Clans.heir(clan, head, npcs, data) == npc_id:
		return "%s of the %s" % [Clans.heir_title(data, gender), clan.name]
	return "%s of the %s" % [Clans.rank_name(data, String(clan.members[npc_id]), gender), clan.name]


## "Zhao Clan (Qingshi Village): led by Zhao Tianba, 5 members; Neutral toward
## you" per living NPC clan, sorted by name; extinct clans say so.
static func summary_lines(clans: Dictionary, npcs: Dictionary, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	var ids: Array = clans.keys()
	ids.sort()
	for id in ids:
		var clan: ClanData = clans[id]
		var region := Exploration.region_name(data, String(data.npc_clans.get(id, {}).get("region", "")))
		if is_extinct(clan):
			lines.append("%s (%s): its line has ended" % [clan.name, region])
			continue
		var head: CharacterData = npcs.get(clan.head)
		var line := "%s (%s): led by %s, %d %s" % [clan.name, region, head.name if head != null else "?", clan.members.size(), "member" if clan.members.size() == 1 else "members"]
		if not data.clan_relations.is_empty():
			line += "; %s" % standing_text(clans, data, String(id))
		lines.append(line)
	return lines


static func _rules(data: GameData) -> Dictionary:
	return data.clan_relations


## Starting relation between clans `a` and `b` (relations.start); 0 if unlisted
## and for the player.
static func start_relation(data: GameData, a: String, b: String) -> int:
	if a == b:
		return 0
	for entry: Dictionary in _rules(data).get("start", []):
		var pair: Array = entry.get("clans", [])
		if pair.has(a) and pair.has(b):
			return int(entry.get("value", 0))
	return 0


## Clan `clan_id`'s relation toward `other` (a clan id or PLAYER).
static func relation(clans: Dictionary, data: GameData, clan_id: String, other: String) -> int:
	var clan: ClanData = clans.get(clan_id)
	if clan == null:
		return 0
	return int(clan.relations.get(other, start_relation(data, clan_id, other)))


## Moves clan `clan_id`'s relation toward `other` by `amount` within
## relations.min/max. Returns the new value.
static func change_relation(clans: Dictionary, data: GameData, clan_id: String, other: String, amount: int) -> int:
	var clan: ClanData = clans.get(clan_id)
	if clan == null:
		return 0
	var value := clampi(relation(clans, data, clan_id, other) + amount, int(_rules(data).get("min", -100)), int(_rules(data).get("max", 100)))
	clan.relations[other] = value
	return value


## The standing ({min, name, favor_scale, grudge?}) a relation `value` reaches.
static func standing(data: GameData, value: int) -> Dictionary:
	var standings: Array = _rules(data).get("standings", [])
	var out: Dictionary = standings[0] if not standings.is_empty() else {}
	for entry: Dictionary in standings:
		if value >= int(entry.get("min", 0)):
			out = entry
	return out


static func standing_name(data: GameData, value: int) -> String:
	return String(standing(data, value).get("name", "Neutral"))


## "Friendly toward you, allied by marriage" for clan `clan_id`.
static func standing_text(clans: Dictionary, data: GameData, clan_id: String) -> String:
	var clan: ClanData = clans.get(clan_id)
	if clan == null:
		return ""
	var text := "%s toward you" % standing_name(data, relation(clans, data, clan_id, PLAYER))
	if clan.allies.has(PLAYER):
		text += ", allied by marriage"
	return text


## Favor gained with `npc_id` scaled by their clan's standing toward the player
## (favor_scale); a raised gain never goes past `room` (the favor cap left).
static func scaled_favor(clans: Dictionary, data: GameData, npc_id: String, gain: int, room: int) -> int:
	var clan_id := clan_of(clans, npc_id)
	if clan_id == "" or gain <= 0:
		return gain
	var scale := float(standing(data, relation(clans, data, clan_id, PLAYER)).get("favor_scale", 1.0))
	var scaled := roundi(gain * scale)
	return mini(scaled, maxi(gain, room)) if scaled > gain else scaled


## A deed by `player` toward clan member `npc_id`: a karma.json act id
## (relations.acts) or a kindness source (relations.kindness). Shifts the
## clan's relation toward the player; on falling into a standing with a grudge
## every living member outside the player's family holds at least that grudge.
## Returns {} when `npc_id` is in no clan or the deed does not count, else
## {clan_id, change, value, standing_changed, feud (members now holding a grudge)}.
static func on_deed(clans: Dictionary, npcs: Dictionary, data: GameData, player: CharacterData, npc_id: String, deed: String) -> Dictionary:
	var clan_id := clan_of(clans, npc_id)
	if clan_id == "":
		return {}
	var amount := int(_rules(data).get("acts", {}).get(deed, _rules(data).get("kindness", {}).get(deed, 0)))
	if amount == 0:
		return {}
	var before := relation(clans, data, clan_id, PLAYER)
	var after := change_relation(clans, data, clan_id, PLAYER, amount)
	var old_standing := standing(data, before)
	var new_standing := standing(data, after)
	var feud := 0
	if new_standing != old_standing and new_standing.has("grudge"):
		feud = _swear_feud(clans[clan_id], player, npcs, data, int(new_standing["grudge"]))
	return {"clan_id": clan_id, "change": after - before, "value": after, "standing_changed": new_standing != old_standing, "feud": feud}


static func _swear_feud(clan: ClanData, player: CharacterData, npcs: Dictionary, data: GameData, amount: int) -> int:
	var count := 0
	for member_id: String in clan.members:
		var member: CharacterData = npcs.get(member_id)
		if member == null or not member.alive or player.spouses.has(member_id) or player.children.has(member_id) or player.parents.has(member_id):
			continue
		var held := Karma.grudge(player, member_id)
		if held < amount:
			Karma.add_grudge(player, data, member_id, amount - held)
		count += 1
	return count


## Marriage alliances: an NPC clan is bound to the player (PLAYER) when one of
## its members is wed to the player or to a member of `player_clan`, and to
## another NPC clan when wed to one of its members. A new alliance raises the
## relation by relations.marriage (both ways between NPC clans). Returns news
## [{clan_id, ally, text}].
static func sync_alliances(clans: Dictionary, npcs: Dictionary, data: GameData, player: CharacterData, player_clan: ClanData) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var bonus := int(_rules(data).get("marriage", 0))
	var ids: Array = clans.keys()
	ids.sort()
	for id: String in ids:
		var clan: ClanData = clans[id]
		for member_id: String in clan.members.keys():
			var member: CharacterData = npcs.get(member_id)
			if member == null:
				continue
			for spouse_id in member.spouses:
				var ally := ""
				if player != null and (spouse_id == player.id or (player_clan != null and player_clan.members.has(spouse_id))):
					ally = PLAYER
				else:
					ally = clan_of(clans, spouse_id)
				if ally == "" or ally == id or clan.allies.has(ally):
					continue
				clan.allies.append(ally)
				change_relation(clans, data, id, ally, bonus)
				var spouse: CharacterData = npcs.get(spouse_id, player if player != null and spouse_id == player.id else null)
				var spouse_name := "you" if player != null and spouse_id == player.id else (spouse.name if spouse != null else "?")
				if ally == PLAYER:
					events.append({"clan_id": id, "ally": ally, "text": "The marriage of %s and %s binds the %s to your family." % [member.name, spouse_name, clan.name]})
				else:
					var other: ClanData = clans[ally]
					if not other.allies.has(id):
						other.allies.append(id)
						change_relation(clans, data, ally, id, bonus)
					events.append({"clan_id": id, "ally": ally, "text": "The %s and the %s are joined by the marriage of %s and %s." % [clan.name, other.name, member.name, spouse_name]})
	return events


## "The Mo Clan and the Yun Clan are Hostile." for each pair of living NPC
## clans whose relation is not Neutral (or that are allied), sorted.
static func rivalry_lines(clans: Dictionary, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	var ids: Array = clans.keys()
	ids.sort()
	var neutral := standing_name(data, 0)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: ClanData = clans[ids[i]]
			var b: ClanData = clans[ids[j]]
			if is_extinct(a) or is_extinct(b):
				continue
			var name := standing_name(data, relation(clans, data, ids[i], ids[j]))
			var allied := a.allies.has(String(ids[j]))
			if name == neutral and not allied:
				continue
			lines.append("The %s and the %s are %s%s." % [a.name, b.name, name, ", allied by marriage" if allied else ""])
	return lines


static func to_dict(clans: Dictionary) -> Dictionary:
	var out := {}
	for id in clans:
		out[id] = (clans[id] as ClanData).to_dict()
	return out


static func from_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for id in d:
		out[String(id)] = ClanData.from_dict(d[id])
	return out


## Load errors for data/clans.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for id in clan_ids(data):
		var def: Dictionary = data.npc_clans[id]
		if String(def.get("name", "")) == "" or String(def.get("surname", "")) == "":
			errors.append("clans.json clan '%s' needs a name and a surname" % id)
		if not data.regions.has(String(def.get("region", ""))):
			errors.append("clans.json clan '%s' has unknown region '%s'" % [id, def.get("region", "")])
		var head: Dictionary = def.get("head", {})
		var gender := String(head.get("gender", ""))
		if gender != "" and not Names.is_gender(data, gender):
			errors.append("clans.json clan '%s' head has unknown gender '%s'" % [id, gender])
		for part in ["head", "spouse", "children"]:
			var section: Dictionary = def.get(part, {})
			if section.has("realm") and data.realm_index_of(String(section["realm"])) < 0:
				errors.append("clans.json clan '%s' %s has unknown realm '%s'" % [id, part, section["realm"]])
		var kids: Dictionary = def.get("children", {})
		for key in ["count", "age_years"]:
			var range_value: Array = kids.get(key, [0, 0])
			if range_value.size() != 2 or int(range_value[0]) < 0 or int(range_value[0]) > int(range_value[1]):
				errors.append("clans.json clan '%s' children.%s must be [min, max] with 0 <= min <= max" % [id, key])
	errors.append_array(_validate_relations(data))
	return errors


static func _validate_relations(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var rules := _rules(data)
	if rules.is_empty():
		return errors
	var low := int(rules.get("min", -100))
	var high := int(rules.get("max", 100))
	if low >= 0 or high <= 0:
		errors.append("clans.json relations needs min < 0 < max")
	for entry: Dictionary in rules.get("start", []):
		var pair: Array = entry.get("clans", [])
		if pair.size() != 2 or pair[0] == pair[1] or not data.npc_clans.has(pair[0]) or not data.npc_clans.has(pair[1]):
			errors.append("clans.json relations.start entry %s needs two different clan ids" % str(pair))
		var value := int(entry.get("value", 0))
		if value < low or value > high:
			errors.append("clans.json relations.start value %d is outside min/max" % value)
	for act_id in rules.get("acts", {}):
		if not data.karma.get("acts", {}).has(act_id):
			errors.append("clans.json relations.acts has unknown karma act '%s'" % act_id)
	for source in rules.get("kindness", {}):
		if not data.karma.get("gratitude", {}).get("sources", {}).has(source):
			errors.append("clans.json relations.kindness has unknown gratitude source '%s'" % source)
	var standings: Array = rules.get("standings", [])
	if standings.is_empty() or int(standings[0].get("min", 0)) != low:
		errors.append("clans.json relations.standings must start at relations.min")
	for i in standings.size():
		var entry: Dictionary = standings[i]
		if String(entry.get("name", "")) == "" or float(entry.get("favor_scale", 1.0)) < 0.0:
			errors.append("clans.json relations.standings[%d] needs a name and favor_scale >= 0" % i)
		if i > 0 and int(entry.get("min", 0)) <= int(standings[i - 1].get("min", 0)):
			errors.append("clans.json relations.standings must be in ascending min order")
	if standing_name(data, 0) == "":
		errors.append("clans.json relations.standings needs a standing for 0")
	return errors
