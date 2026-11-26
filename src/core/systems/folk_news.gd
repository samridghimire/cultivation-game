class_name FolkNews
extends RefCounted
## FOLK-046: friends hear your sect news. Joining or a promotion leaves a one-time pending reaction on each
## named villager of the start region at favor >= folk_news.min_favor; the next greeting uses it. Lines are
## picked with a stable hash, never the session rng (RV-FOLK041). FOLK-047 adds "breakthrough" and "wedding".

## FOLK-049 adds "contest" (a champion of the sect contest; it names the sect, so it is sect news too).
const SECT_KINDS: Array[String] = ["sect_join", "promotion", "contest"]


## Marks every qualifying villager of the player's start region. `kind` is "sect_join", "promotion", "breakthrough" or "wedding"; a newer kind replaces an unheard older one.
static func queue(player: CharacterData, data: GameData, favor: Dictionary, kind: String) -> int:
	var cfg: Dictionary = data.family.get("folk_news", {})
	if cfg.is_empty() or player == null:
		return 0
	var min_favor: int = int(cfg.get("min_favor", 40))
	var n := 0
	var home := player.home_region if player.home_region != "" else data.start_region  # WU-615: players never get a home_region; their friends are in the start village
	for id: String in data.npcs:
		var def: Dictionary = data.npcs[id]
		if String(def.get("region", "")) != home:
			continue
		if int(favor.get(id, int(def.get("favor", 0)))) < min_favor:
			continue
		if kind == "wedding" and player.spouses.has(id):
			continue  # RV-FOLK047: the new spouse does not congratulate you on marrying them
		player.folk_news[id] = kind
		n += 1
	return n


## GFX-249: true while `npc_id` holds a pending news reaction (the world shows a bubble over them).
## FOLK-051: pass `data` and `day` (>= 0) so an expired, not yet pruned own-news entry shows no bubble.
static func has_pending(player: CharacterData, npc_id: String, data: GameData = null, day: int = -1) -> bool:
	if player != null and npc_id != "" and player.friend_news.has(npc_id) and not bool(player.friend_news[npc_id].get("told", false)):
		if day < 0 or data == null or not _expired(player, data, npc_id, day):
			return true  # FOLK-050: their own news waits to be heard
	if player == null or npc_id == "" or not player.folk_news.has(npc_id):
		return false
	if SECT_KINDS.has(String(player.folk_news[npc_id])):
		return not player.is_rogue()  # FOLK-048: `take` drops sect news once you left; no bubble for it either
	return true


## The reaction line for `npc_id` ("" when none pending); clears it. Tokens {player} {sect} {rank} {realm} {spouse}. Only sect kinds need a sect.
static func take(player: CharacterData, data: GameData, npc_id: String, people: Dictionary = {}) -> String:
	if not player.folk_news.has(npc_id):
		return ""
	var kind := String(player.folk_news[npc_id])
	player.folk_news.erase(npc_id)
	var in_sect: bool = not player.is_rogue() and data.sects.has(String(player.sect.get("id", "")))
	if SECT_KINDS.has(kind) and not in_sect:
		return ""  # RV-FOLK046: news of a sect the player has since left is stale; drop it
	var def: Dictionary = data.npcs.get(npc_id, {})
	var own: Dictionary = def.get("news_lines", {})
	var shared: Dictionary = data.family.get("folk_news", {}).get("lines", {})
	var demonic := false
	if in_sect and SECT_KINDS.has(kind):  # FOLK-048: friends who disapprove of a demonic sect
		demonic = (data.sects[String(player.sect["id"])] as SectDef).alignment_tag == "demonic"
	var pool: Array = []
	if demonic:
		pool = own.get(kind + "_demonic", [])
	if pool.is_empty():
		pool = own.get(kind, [])
	if pool.is_empty() and demonic:
		pool = shared.get(kind + "_demonic", [])
	if pool.is_empty():
		pool = shared.get(kind, [])
	if pool.is_empty():
		return ""
	var line := String(pool[absi(("%s|%s|%d" % [npc_id, kind, player.age_days]).hash()) % pool.size()])
	line = line.replace("{player}", player.name)
	if in_sect:
		var sect: SectDef = data.sects[String(player.sect["id"])]
		line = line.replace("{sect}", sect.name).replace("{rank}", sect.rank_name(int(player.sect["rank"])))
	var realm_name := ""
	if player.realm_index >= 0 and player.realm_index < data.realms.size():
		realm_name = String(data.realms[player.realm_index].name)
	var spouse_name := "your spouse"
	if not player.spouses.is_empty() and people.has(player.spouses.back()):
		spouse_name = String((people[player.spouses.back()] as CharacterData).name)
	return line.replace("{realm}", realm_name).replace("{spouse}", spouse_name)


## FOLK-050: a named, living friend (favor >= min_favor, any region) has news of their own. Newer replaces older.
static func queue_own(player: CharacterData, data: GameData, favor: Dictionary, npc: CharacterData, kind: String, realm: String, day: int) -> bool:
	var cfg: Dictionary = data.family.get("folk_news", {})
	if cfg.is_empty() or player == null or npc == null or not npc.alive or not data.npcs.has(npc.id):
		return false
	if int(favor.get(npc.id, int(data.npcs[npc.id].get("favor", 0)))) < int(cfg.get("min_favor", 40)):
		return false
	player.friend_news[npc.id] = {"kind": kind, "realm": realm, "day": day, "told": false}
	return true


## Pure: their own entry is older than own_days (no erasing).
static func _expired(player: CharacterData, data: GameData, npc_id: String, day: int) -> bool:
	var own_days: int = int(data.family.get("folk_news", {}).get("own_days", 30))
	return day - int(player.friend_news[npc_id].get("day", 0)) > own_days


## True while their own news is fresh (not older than own_days); expired entries are dropped.
static func _fresh(player: CharacterData, data: GameData, npc_id: String, day: int) -> bool:
	if player == null or not player.friend_news.has(npc_id):
		return false
	if _expired(player, data, npc_id, day):
		player.friend_news.erase(npc_id)
		return false
	return true


## Their news is pending and not yet heard.
static func has_own(player: CharacterData, data: GameData, npc_id: String, day: int) -> bool:
	return _fresh(player, data, npc_id, day) and not bool(player.friend_news[npc_id].get("told", false))


## They can still be congratulated (heard or not, until it goes stale or you do).
static func can_congratulate(player: CharacterData, data: GameData, npc_id: String, day: int) -> bool:
	return _fresh(player, data, npc_id, day)


## Their own line, once ("" when none). The entry stays (marked told) so the talk can offer to congratulate.
static func take_own(player: CharacterData, data: GameData, npc_id: String, day: int) -> String:
	if not has_own(player, data, npc_id, day):
		return ""
	var entry: Dictionary = player.friend_news[npc_id]
	entry["told"] = true
	var kind := String(entry["kind"])
	var cfg: Dictionary = data.family.get("folk_news", {})
	var pool: Array = data.npcs.get(npc_id, {}).get("own_news_lines", {}).get(kind, [])
	if pool.is_empty():
		pool = cfg.get("own_fallback", {}).get(kind, [])
	if pool.is_empty():
		return ""
	var line := String(pool[absi(("%s|own|%d" % [npc_id, day]).hash()) % pool.size()])
	return line.replace("{player}", player.name).replace("{realm}", String(entry.get("realm", "")))


## Congratulate: clears the entry and returns the favor to add (0 when there is nothing to congratulate).
static func congratulate(player: CharacterData, data: GameData, npc_id: String, day: int) -> int:
	if not can_congratulate(player, data, npc_id, day):
		return 0
	player.friend_news.erase(npc_id)
	return int(data.family.get("folk_news", {}).get("congratulate_favor", 3))


## Drops every expired entry (call on month change).
static func prune_own(player: CharacterData, data: GameData, day: int) -> void:
	for id: String in player.friend_news.keys():
		_fresh(player, data, id, day)
