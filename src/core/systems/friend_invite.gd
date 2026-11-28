class_name FriendInvite
extends RefCounted
## FOLK-055: a named friend (favor >= family.friend_invite.min_favor) who cultivates and belongs to no sect can be
## invited into the player's sect once the player holds rank >= min_player_rank. The sect must accept them (the same
## realm and alignment checks Rivals.follow_into_sect uses). They join as an outer disciple and move to the sect's
## home region (CharacterData.home_region). Once per friend (world flag). Pure rules, no rng.


static func rules(data: GameData) -> Dictionary:
	return data.family.get("friend_invite", {})


static func flag_key(npc_id: String) -> String:
	return "friend_invited_" + npc_id


## True while an invitation could be offered to `npc` at all (the menu entry shows): friend, rogue, you hold the rank.
static func offered(player: CharacterData, data: GameData, flags: Dictionary, npc: CharacterData, favor: int) -> bool:
	if player == null or npc == null or not npc.alive or not data.npcs.has(npc.id) or player.is_rogue():
		return false
	if favor < int(rules(data).get("min_favor", 60)) or not npc.is_rogue() or flags.get(flag_key(npc.id), false):
		return false
	return int(player.sect.get("rank", 0)) >= int(rules(data).get("min_player_rank", 1)) and Npcs.cultivates(npc, data)


## "" when the sect accepts `npc`, else the friend's one-line reason.
static func decline_reason(player: CharacterData, data: GameData, npc: CharacterData) -> String:
	var sect_id := String(player.sect.get("id", ""))
	if not data.sects.has(sect_id):
		return "%s shakes their head." % npc.name
	var sect: SectDef = data.sects[sect_id]
	if npc.realm_index < data.realm_index_of(sect.min_realm):
		return "%s sighs. \"The %s wants more cultivation than I have yet. Ask me again when I am stronger.\"" % [npc.name, sect.name]
	if npc.alignment < sect.min_alignment:
		return "%s looks away. \"The %s would never take someone with my past, %s.\"" % [npc.name, sect.name, player.name]
	if npc.alignment > sect.max_alignment:
		return "%s shakes their head. \"The %s is not for a heart as soft as mine, %s.\"" % [npc.name, sect.name, player.name]
	return ""


## Invites `npc`: returns {ok, reason, favor}. On success the friend is an outer disciple in the sect's home region.
static func invite(player: CharacterData, data: GameData, flags: Dictionary, npc: CharacterData, favor: int) -> Dictionary:
	if not offered(player, data, flags, npc, favor):
		return {"ok": false, "reason": "%s cannot join your sect." % (npc.name if npc != null else "They"), "favor": 0}
	var why := decline_reason(player, data, npc)
	if why != "":
		return {"ok": false, "reason": why, "favor": 0}
	var sect_id := String(player.sect["id"])
	npc.sect = {"id": sect_id, "rank": 0, "contribution": 0}
	var home := Sects.home_region(data, sect_id)
	if home != "":
		npc.home_region = home
	flags[flag_key(npc.id)] = true
	return {"ok": true, "reason": "", "favor": int(rules(data).get("favor", 5))}


## WU-638: named friends who joined the player's sect (FOLK-055 flag set, same sect id, alive), in npcs.json order:
## [{id, name, realm}]. Empty for rogues.
static func sect_mates(player: CharacterData, npcs: Dictionary, data: GameData, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null or player.is_rogue():
		return out
	var sect_id := String(player.sect.get("id", ""))
	for id: String in data.npcs:
		var c: CharacterData = npcs.get(id)
		if c == null or not c.alive or not flags.get(flag_key(id), false) or String(c.sect.get("id", "")) != sect_id:
			continue
		out.append({"id": id, "name": c.name, "realm": String(data.realms[clampi(c.realm_index, 0, data.realms.size() - 1)].name)})
	return out


## WU-638: "Sect-mates you know: Xiao Ling (Qi Refining), ..." or "" with none.
static func sect_mates_line(mates: Array[Dictionary]) -> String:
	if mates.is_empty():
		return ""
	var parts := PackedStringArray()
	for m in mates:
		parts.append("%s (%s)" % [m["name"], m["realm"]])
	return "Sect-mates you know: " + ", ".join(parts)


## C-430: a friend who joined the player's sect greets them in their sect_mate_lines voice ("" when they have none or
## are not a sect-mate). Stable pick by npc id and day, never rng; `{sect}` is the sect's name, `{player}` is left alone.
static func sect_mate_greeting(player: CharacterData, data: GameData, flags: Dictionary, npc: CharacterData, day: int) -> String:
	if player == null or npc == null or player.is_rogue() or not flags.get(flag_key(npc.id), false):
		return ""
	var sect_id := String(player.sect.get("id", ""))
	var lines: Array = data.npcs.get(npc.id, {}).get("sect_mate_lines", [])
	if lines.is_empty() or String(npc.sect.get("id", "")) != sect_id or not data.sects.has(sect_id):
		return ""
	return String(lines[hash("%s/%d" % [npc.id, day]) % lines.size()]).replace("{sect}", data.sects[sect_id].name)
