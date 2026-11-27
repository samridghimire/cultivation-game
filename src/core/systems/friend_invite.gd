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
