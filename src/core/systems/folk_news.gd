class_name FolkNews
extends RefCounted
## FOLK-046: friends hear your sect news. Joining or a promotion leaves a one-time pending reaction on each
## named villager of the start region at favor >= folk_news.min_favor; the next greeting uses it. Lines are
## picked with a stable hash, never the session rng (RV-FOLK041).


## Marks every qualifying villager of the player's start region. `kind` is "sect_join" or "promotion".
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
		player.folk_news[id] = kind
		n += 1
	return n


## The reaction line for `npc_id` ("" when none pending); clears it. Tokens {player} {sect} {rank}.
static func take(player: CharacterData, data: GameData, npc_id: String) -> String:
	if not player.folk_news.has(npc_id):
		return ""
	var kind := String(player.folk_news[npc_id])
	player.folk_news.erase(npc_id)
	if player.is_rogue() or not data.sects.has(String(player.sect.get("id", ""))):
		return ""  # RV-FOLK046: news of a sect the player has since left is stale; drop it
	var def: Dictionary = data.npcs.get(npc_id, {})
	var own: Dictionary = def.get("news_lines", {})
	var pool: Array = own.get(kind, [])
	if pool.is_empty():
		pool = data.family.get("folk_news", {}).get("lines", {}).get(kind, [])
	if pool.is_empty():
		return ""
	var line := String(pool[absi(("%s|%s|%d" % [npc_id, kind, player.age_days]).hash()) % pool.size()])
	var sect: SectDef = data.sects[String(player.sect["id"])]
	return line.replace("{player}", player.name).replace("{sect}", sect.name).replace("{rank}", sect.rank_name(int(player.sect["rank"])))
