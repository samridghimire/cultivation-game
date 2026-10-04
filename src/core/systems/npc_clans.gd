class_name NpcClans
extends RefCounted
## NPC clans (FAM-009), defined in data/clans.json. Each clan is founded once
## per game as generated NPCs (a head, a spouse and children sharing the clan
## surname) and kept as a ClanData keyed by clan id in GameState.npc_clans.
## Members follow the head's family (Clans.sync_family); when the head dies the
## heir succeeds (Clans.succeed), and a clan whose line ends is extinct.


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
	var clan := ClanData.new()
	clan.name = String(def.get("name", Clans.clan_name(head, data)))
	clan.head = head.id
	clan.members[head.id] = Clans.head_rank(data)
	Clans.sync_family(head, clan, npcs, data)
	return clan


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


## "Zhao Clan (Qingshi Village): led by Zhao Tianba, 5 members" per living
## NPC clan, sorted by name; extinct clans say so.
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
		lines.append("%s (%s): led by %s, %d %s" % [clan.name, region, head.name if head != null else "?", clan.members.size(), "member" if clan.members.size() == 1 else "members"])
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
	return errors
