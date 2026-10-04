class_name Clans
extends RefCounted
## Founding and running the player's clan (FAM-005), tuned by data/family.json
## "clan". The founder becomes Patriarch/Matriarch (the first rank); living
## spouses and descendants join automatically at `family_rank`, others are
## recruited at the last rank and can be promoted. The clan keeps a treasury
## of spirit stones. State is a ClanData owned by GameState.


static func rules(data: GameData) -> Dictionary:
	return data.family.get("clan", {})


## Rank ids, highest (the clan head) first.
static func ranks(data: GameData) -> Array[String]:
	var out: Array[String] = []
	for rank: Dictionary in rules(data).get("ranks", []):
		out.append(String(rank.get("id", "")))
	return out


static func rank_def(data: GameData, rank_id: String) -> Dictionary:
	for rank: Dictionary in rules(data).get("ranks", []):
		if String(rank.get("id", "")) == rank_id:
			return rank
	return {}


## Display name of a rank for a member of `gender` (e.g. Patriarch / Matriarch).
static func rank_name(data: GameData, rank_id: String, gender: String = "") -> String:
	var rank := rank_def(data, rank_id)
	return String(rank.get("names", {}).get(gender, rank.get("name", rank_id)))


static func head_rank(data: GameData) -> String:
	var all := ranks(data)
	return all[0] if not all.is_empty() else ""


static func lowest_rank(data: GameData) -> String:
	var all := ranks(data)
	return all[all.size() - 1] if not all.is_empty() else ""


## "<Surname> Clan" for `c` (their full name if they have no surname).
static func clan_name(c: CharacterData, data: GameData) -> String:
	var base := c.surname if c.surname != "" else c.name
	return "%s %s" % [base, String(rules(data).get("suffix", "Clan"))]


## Why `c` cannot found a clan now, or "".
static func check_found(c: CharacterData, clan: ClanData, data: GameData) -> String:
	if clan != null:
		return "You already lead the %s." % clan.name
	var r := rules(data)
	if r.is_empty():
		return "Clans cannot be founded."
	var min_index := data.realm_index_of(String(r.get("min_realm", "mortal")))
	if c.realm_index < min_index:
		return "Only a cultivator of the %s realm can found a clan." % data.realms[min_index].name
	var cost := int(r.get("found_cost", 0))
	if c.item_count("spirit_stone") < cost:
		return "Founding a clan costs %d spirit stones." % cost
	return ""


## Founds `c`'s clan on game day `day`, paying found_cost; family in `people`
## joins. Returns {ok, reason, clan, days}.
static func found(c: CharacterData, clan: ClanData, people: Dictionary, data: GameData, day: int) -> Dictionary:
	var reason := check_found(c, clan, data)
	if reason != "":
		return {"ok": false, "reason": reason, "clan": clan, "days": 0}
	c.add_item("spirit_stone", -int(rules(data).get("found_cost", 0)))
	var founded := ClanData.new()
	founded.name = clan_name(c, data)
	founded.head = c.id
	founded.founded_day = day
	founded.members[c.id] = head_rank(data)
	sync_family(c, founded, people, data)
	return {"ok": true, "reason": "", "clan": founded, "days": int(rules(data).get("found_days", 0))}


## Adds `c`'s living spouses and descendants (from `people`) who are not yet
## members at family_rank, and drops dead members. Returns the names that joined.
static func sync_family(c: CharacterData, clan: ClanData, people: Dictionary, data: GameData) -> Array[String]:
	var joined: Array[String] = []
	for member_id in clan.members.keys():
		var member: CharacterData = people.get(member_id)
		if member_id != clan.head and (member == null or not member.alive):
			clan.members.erase(member_id)
	if not clan.members.has(clan.heir):
		clan.heir = ""
	var family_rank := String(rules(data).get("family_rank", lowest_rank(data)))
	var kin: Array[String] = []
	kin.append_array(c.spouses)
	var queue: Array[String] = c.children.duplicate()
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if kin.has(id):
			continue
		kin.append(id)
		var descendant: CharacterData = people.get(id)
		if descendant != null:
			queue.append_array(descendant.children)
	for id in kin:
		var person: CharacterData = people.get(id)
		if person != null and person.alive and not clan.members.has(id):
			clan.members[id] = family_rank
			joined.append(person.name)
	return joined


## Why `npc` cannot be recruited into `clan` by `c`, or "".
static func check_recruit(c: CharacterData, clan: ClanData, npc: CharacterData, favor: int, data: GameData) -> String:
	if clan == null:
		return "You have no clan."
	if npc == null or not npc.alive:
		return "There is no one to recruit."
	if clan.members.has(npc.id):
		return "%s is already of the %s." % [npc.name, clan.name]
	if npc.age_years() < int(data.family.get("adult_age", 16)):
		return "%s is too young to swear allegiance." % npc.name
	var r := rules(data)
	if favor < int(r.get("recruit_min_favor", 0)):
		return "%s does not trust you enough to join your clan." % npc.name
	var cost := int(r.get("recruit_cost", 0))
	if c.item_count("spirit_stone") < cost:
		return "Recruiting a retainer costs %d spirit stones." % cost
	return ""


## Recruits `npc` as a retainer at the lowest rank. Returns {ok, reason, days}.
static func recruit(c: CharacterData, clan: ClanData, npc: CharacterData, favor: int, data: GameData) -> Dictionary:
	var reason := check_recruit(c, clan, npc, favor, data)
	if reason != "":
		return {"ok": false, "reason": reason, "days": 0}
	c.add_item("spirit_stone", -int(rules(data).get("recruit_cost", 0)))
	clan.members[npc.id] = lowest_rank(data)
	return {"ok": true, "reason": "", "days": int(rules(data).get("recruit_days", 0))}


## Members of `clan` holding `rank_id`.
static func count_rank(clan: ClanData, rank_id: String) -> int:
	return clan.members.values().count(rank_id)


## Why `member` cannot be given `rank_id`, or "".
static func check_promote(clan: ClanData, member: CharacterData, rank_id: String, data: GameData) -> String:
	if clan == null:
		return "You have no clan."
	if member == null or not clan.members.has(member.id):
		return "Only clan members can be given a rank."
	if member.id == clan.head:
		return "The head of the clan keeps their seat."
	var rank := rank_def(data, rank_id)
	if rank.is_empty() or rank_id == head_rank(data):
		return "There is no such rank to give."
	if String(clan.members[member.id]) == rank_id:
		return "%s already holds that rank." % member.name
	if rank.has("max") and count_rank(clan, rank_id) >= int(rank["max"]):
		return "The clan already has %d %ss." % [int(rank["max"]), rank_name(data, rank_id)]
	var min_index := data.realm_index_of(String(rank.get("min_realm", "mortal")))
	if member.realm_index < min_index:
		return "A %s must have reached %s." % [rank_name(data, rank_id), data.realms[min_index].name]
	return ""


## Sets `member`'s rank (promotion or demotion). Returns {ok, reason}.
static func promote(clan: ClanData, member: CharacterData, rank_id: String, data: GameData) -> Dictionary:
	var reason := check_promote(clan, member, rank_id, data)
	if reason != "":
		return {"ok": false, "reason": reason}
	clan.members[member.id] = rank_id
	return {"ok": true, "reason": ""}


## Moves `amount` spirit stones from `c` into the treasury. Returns {ok, reason}.
static func deposit(c: CharacterData, clan: ClanData, amount: int) -> Dictionary:
	if clan == null:
		return {"ok": false, "reason": "You have no clan."}
	if amount <= 0:
		return {"ok": false, "reason": "Deposit at least one spirit stone."}
	if c.item_count("spirit_stone") < amount:
		return {"ok": false, "reason": "You do not have %d spirit stones." % amount}
	c.add_item("spirit_stone", -amount)
	clan.treasury += amount
	return {"ok": true, "reason": ""}


## Heir rules (data/family.json clan.heir).
static func heir_rules(data: GameData) -> Dictionary:
	return rules(data).get("heir", {})


## Title of the clan heir of `gender` (e.g. Young Master / Young Mistress).
static func heir_title(data: GameData, gender: String = "") -> String:
	var r := heir_rules(data)
	return String(r.get("titles", {}).get(gender, r.get("title", "Clan Heir")))


## Living descendants of `head` (children first, then grandchildren...).
static func descendants(head: CharacterData, people: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var queue: Array[String] = head.children.duplicate()
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if out.has(id):
			continue
		var person: CharacterData = people.get(id)
		if person == null:
			continue
		out.append(id)
		queue.append_array(person.children)
	var living: Array[String] = []
	for id in out:
		if (people[id] as CharacterData).alive:
			living.append(id)
	return living


## The heir by custom when none is designated: among `head`'s living children
## who are clan members, the best birth rank (clan.heir.birth_rank_order),
## then the eldest. "" if there is none.
static func default_heir(clan: ClanData, head: CharacterData, people: Dictionary, data: GameData) -> String:
	var order: Array = heir_rules(data).get("birth_rank_order", [])
	var best := ""
	var best_key := Vector2i(0, 0)
	for child_id in head.children:
		var child: CharacterData = people.get(child_id)
		if child == null or not child.alive or not clan.members.has(child_id):
			continue
		var rank_index := order.find(child.birth_rank)
		# Lower key wins: birth rank first (unlisted ranks last), then the eldest.
		var key := Vector2i(rank_index if rank_index >= 0 else order.size(), -child.age_days)
		if best == "" or key < best_key:
			best = child_id
			best_key = key
	return best


## The clan's heir: the designated one while they are a living member, else the default heir.
static func heir(clan: ClanData, head: CharacterData, people: Dictionary, data: GameData) -> String:
	if clan == null or head == null:
		return ""
	var designated: CharacterData = people.get(clan.heir)
	if designated != null and designated.alive and clan.members.has(clan.heir):
		return clan.heir
	return default_heir(clan, head, people, data)


## Why `head` cannot designate `person` as the clan heir, or "".
static func check_designate(head: CharacterData, clan: ClanData, person: CharacterData, people: Dictionary) -> String:
	if clan == null:
		return "You have no clan."
	if clan.head != head.id:
		return "Only the head of the clan names its heir."
	if person == null or not person.alive:
		return "There is no one to name."
	if not clan.members.has(person.id):
		return "%s is not of the %s." % [person.name, clan.name]
	if not descendants(head, people).has(person.id):
		return "Only your own descendants can inherit the %s." % clan.name
	if clan.heir == person.id:
		return "%s is already your heir." % person.name
	return ""


## Names `person` the clan heir. Returns {ok, reason}.
static func designate_heir(head: CharacterData, clan: ClanData, person: CharacterData, people: Dictionary) -> Dictionary:
	var reason := check_designate(head, clan, person, people)
	if reason != "":
		return {"ok": false, "reason": reason}
	clan.heir = person.id
	return {"ok": true, "reason": ""}


## When the clan head in `people` has died, the heir (else the highest-ranked,
## then eldest, living member) becomes head at the head rank. For NPC clans
## (the player never permadies while the artifact has lives). Returns
## {succeeded: bool, previous: id, head: id}; head "" means the line ended.
static func succeed(clan: ClanData, people: Dictionary, data: GameData) -> Dictionary:
	var old: CharacterData = people.get(clan.head)
	if old != null and old.alive:
		return {"succeeded": false, "previous": clan.head, "head": clan.head}
	var previous := clan.head
	var next := heir(clan, old, people, data) if old != null else ""
	if next == "":
		var all := ranks(data)
		var best_key := Vector2i(0, 0)
		for member_id in clan.members:
			var member: CharacterData = people.get(member_id)
			if member_id == previous or member == null or not member.alive:
				continue
			var key := Vector2i(all.find(String(clan.members[member_id])), -member.age_days)
			if next == "" or key < best_key:
				next = member_id
				best_key = key
	clan.members.erase(previous)
	clan.heir = ""
	clan.head = next
	if next != "":
		clan.members[next] = head_rank(data)
	return {"succeeded": next != "", "previous": previous, "head": next}


## Load errors for data/family.json "clan" (optional block).
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var r := rules(data)
	if r.is_empty():
		return errors
	if data.realm_index_of(String(r.get("min_realm", ""))) < 0:
		errors.append("family.json clan.min_realm must be a realm id")
	var all := ranks(data)
	if all.size() < 2:
		errors.append("family.json clan.ranks needs a head rank and at least one member rank")
	if not all.has(String(r.get("family_rank", lowest_rank(data)))) or String(r.get("family_rank", "")) == head_rank(data):
		errors.append("family.json clan.family_rank must be a non-head clan rank")
	for rank: Dictionary in r.get("ranks", []):
		if String(rank.get("id", "")) == "" or String(rank.get("name", "")) == "":
			errors.append("family.json clan ranks need an id and a name")
		if rank.has("min_realm") and data.realm_index_of(String(rank["min_realm"])) < 0:
			errors.append("family.json clan rank '%s' has unknown min_realm" % rank.get("id", ""))
	var heir_rule := heir_rules(data)
	if not heir_rule.is_empty() and not heir_rule.get("birth_rank_order", []) is Array:
		errors.append("family.json clan.heir.birth_rank_order must be a list of spousal rank ids")
	else:
		for rank_id in heir_rule.get("birth_rank_order", []):
			var known := String(rank_id) == ""
			for gender in data.family.get("genders", {}):
				known = known or data.family["genders"][gender].get("ranks", {}).has(rank_id)
			if not known:
				errors.append("family.json clan.heir.birth_rank_order has unknown spousal rank '%s'" % rank_id)
	for key in ["found_cost", "found_days", "recruit_cost", "recruit_days", "recruit_min_favor"]:
		if int(r.get(key, 0)) < 0:
			errors.append("family.json clan.%s must be >= 0" % key)
	return errors
