class_name FolkNews
extends RefCounted
## FOLK-046: friends hear your sect news. Joining or a promotion leaves a one-time pending reaction on each
## named villager of the start region at favor >= folk_news.min_favor; the next greeting uses it. Lines are
## picked with a stable hash, never the session rng (RV-FOLK041). FOLK-047 adds "breakthrough" and "wedding".

const SECT_KINDS: Array[String] = ["sect_join", "promotion"]


## Marks every qualifying villager of the player's start region. `kind` is "sect_join", "promotion", "breakthrough" or "wedding"; a newer kind replaces an unheard older one.
static func queue(player: CharacterData, data: GameData, favor: Dictionary, kind: String) -> int:
	var cfg: Dictionary = data.family.get("folk_news", {})
	if cfg.is_empty() or player == null:
		return 0
	var min_favor: int = int(cfg.get("min_favor", 40))
	var n := 0
	for id: String in data.npcs:
		var def: Dictionary = data.npcs[id]
		if String(def.get("region", "")) != player.home_region:
			continue
		if int(favor.get(id, int(def.get("favor", 0)))) < min_favor:
			continue
		if kind == "wedding" and player.spouses.has(id):
			continue  # RV-FOLK047: the new spouse does not congratulate you on marrying them
		player.folk_news[id] = kind
		n += 1
	return n


## GFX-249: true while `npc_id` holds a pending news reaction (the world shows a bubble over them).
static func has_pending(player: CharacterData, npc_id: String) -> bool:
	return player != null and npc_id != "" and player.folk_news.has(npc_id)


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
	var pool: Array = own.get(kind, [])
	if pool.is_empty():
		pool = data.family.get("folk_news", {}).get("lines", {}).get(kind, [])
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
