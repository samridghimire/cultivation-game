class_name SpeakerPortrait
extends RefCounted
## WU-558: a face for a speaker who has no world source (a story event's dialogue). Resolves the speaker's
## display name ("{rival}" is already filled in) to an NPC id, then draws their pixel figure like the HUD chips do.

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


## The NPC id whose name is `speaker` (the player's rival first, then the folk by name); "" when unknown.
static func npc_id_for(speaker: String) -> String:
	if speaker == "" or GameState.npcs == null:
		return ""
	var rival := Rivals.rival_of(GameState.player, GameState.npcs)
	if rival != null and rival.name == speaker:
		return rival.id
	for id: String in GameState.npcs:
		var c: CharacterData = GameState.npcs[id]
		if c != null and c.alive and c.name == speaker:
			return id
	return ""


## The speaker's portrait, or null for no/unknown speaker.
static func texture_for(speaker: String) -> Texture2D:
	var id := npc_id_for(speaker)
	if id == "":
		return null
	return PixelFigure.frame(NPC_SCRIPT.look_of(id, Color("9a8f7a")), "down", 0)
