class_name Dialogue
extends RefCounted
## Branching conversations from data/dialogue/*.json. Pure rules: GameState
## keeps the current node, applies time and emits events.
##
## A dialogue file: {"id", "entries": [{"node", "if"}], "nodes": {node_id: node}}.
## The first entry whose "if" passes is where a conversation starts.
## node: {"text", "speaker" (optional), "choices": [choice]}
## choice: {"label", "next" (node id; "" or "end" ends), "if", "effects",
##          "favor" (int, change in this NPC's favor), "days",
##          "show_locked" (bool: show disabled with a reason instead of hiding)}
## Text may use {player}, {npc}, {npc_realm} and {player_realm}.
##
## Conditions ("if") are all optional and all must pass:
##   min_realm / max_realm: realm id      min_alignment / max_alignment: int
##   flag / not_flag: world flag          min_favor / max_favor: int
##   has_items: {item_id: count}          knows_technique / not_knows_technique: id
##   npc_alive: bool                      above_npc: bool (player realm > NPC realm)
##
## `ctx` everywhere is {player: CharacterData, npc: CharacterData, data: GameData,
## flags: Dictionary, favor: int}.

const END := "end"


static func entry_node(dialogue: Dictionary, ctx: Dictionary) -> String:
	for entry: Dictionary in dialogue.get("entries", []):
		if unmet_reason(entry.get("if", {}), ctx) == "":
			return entry["node"]
	return ""


## What to show for `node_id`: {id, speaker, text, choices: [{index, label,
## disabled, reason}]}. `index` is what choose() expects.
static func view(dialogue: Dictionary, node_id: String, ctx: Dictionary) -> Dictionary:
	var node: Dictionary = dialogue.get("nodes", {}).get(node_id, {})
	var npc: CharacterData = ctx["npc"]
	var choices: Array[Dictionary] = []
	var raw: Array = node.get("choices", [])
	for i in raw.size():
		var choice: Dictionary = raw[i]
		var reason := _choice_blocker(choice, ctx)
		if reason != "" and not choice.get("show_locked", false):
			continue
		choices.append({"index": i, "label": format(choice.get("label", "..."), ctx), "disabled": reason != "", "reason": reason})
	if choices.is_empty():
		choices.append({"index": -1, "label": "Farewell.", "disabled": false, "reason": ""})
	return {
		"id": "%s:%s" % [dialogue.get("id", ""), node_id],
		"speaker": node.get("speaker", npc.name if npc else ""),
		"text": format(node.get("text", ""), ctx),
		"choices": choices,
	}


## Takes choice `index` of `node_id`. index -1 is the implicit farewell.
## Returns {ok, reason, notes, next ("" = conversation over), days, favor}.
static func choose(dialogue: Dictionary, node_id: String, index: int, ctx: Dictionary) -> Dictionary:
	var fail := {"ok": false, "reason": "", "notes": PackedStringArray(), "next": node_id, "days": 0, "favor": 0}
	if index == -1:
		return {"ok": true, "reason": "", "notes": PackedStringArray(), "next": "", "days": 0, "favor": 0}
	var raw: Array = dialogue.get("nodes", {}).get(node_id, {}).get("choices", [])
	if index < 0 or index >= raw.size():
		fail["reason"] = "That is not an option."
		return fail
	var choice: Dictionary = raw[index]
	var reason := _choice_blocker(choice, ctx)
	if reason != "":
		fail["reason"] = reason
		return fail
	var notes: PackedStringArray = []
	var effects: Dictionary = choice.get("effects", {})
	if not effects.is_empty():
		notes = Effects.apply(ctx["player"], ctx["data"], effects, ctx["flags"])
	var favor := int(choice.get("favor", 0))
	if favor != 0:
		notes.append("%s's favor %+d" % [(ctx["npc"] as CharacterData).name, favor])
	var next: String = choice.get("next", "")
	if next == END:
		next = ""
	return {"ok": true, "reason": "", "notes": notes, "next": next, "days": int(choice.get("days", 0)), "favor": favor}


## "" if every condition passes, otherwise why not (for locked choices).
static func unmet_reason(cond: Dictionary, ctx: Dictionary) -> String:
	var c: CharacterData = ctx["player"]
	var npc: CharacterData = ctx["npc"]
	var data: GameData = ctx["data"]
	var flags: Dictionary = ctx["flags"]
	var favor := int(ctx.get("favor", 0))
	if cond.has("min_realm") and c.realm_index < data.realm_index_of(cond["min_realm"]):
		return "Requires %s." % data.realms[data.realm_index_of(cond["min_realm"])].name
	if cond.has("max_realm") and c.realm_index > data.realm_index_of(cond["max_realm"]):
		return "Only below %s." % data.realms[data.realm_index_of(cond["max_realm"])].name
	if cond.has("min_alignment") and c.alignment < int(cond["min_alignment"]):
		return "Your reputation is too dark."
	if cond.has("max_alignment") and c.alignment > int(cond["max_alignment"]):
		return "You are too righteous."
	if cond.has("flag") and not flags.get(cond["flag"], false):
		return "Not yet."
	if cond.has("not_flag") and flags.get(cond["not_flag"], false):
		return "No longer possible."
	if cond.has("min_favor") and favor < int(cond["min_favor"]):
		return "Needs more favor (%d/%d)." % [favor, int(cond["min_favor"])]
	if cond.has("max_favor") and favor > int(cond["max_favor"]):
		return "Too friendly for that."
	for item_id in cond.get("has_items", {}):
		var need := int(cond["has_items"][item_id])
		if c.item_count(item_id) < need:
			return "Requires %d %s." % [need, data.items.get(item_id, {}).get("name", item_id)]
	if cond.has("knows_technique") and not c.techniques.has(cond["knows_technique"]):
		return "Requires a technique you do not know."
	if cond.has("not_knows_technique") and c.techniques.has(cond["not_knows_technique"]):
		return "You already know it."
	if cond.has("npc_alive") and npc != null and npc.alive != bool(cond["npc_alive"]):
		return "Not possible."
	if cond.has("above_npc") and npc != null and (c.realm_index > npc.realm_index) != bool(cond["above_npc"]):
		return "Your cultivation does not match."
	return ""


static func format(text: String, ctx: Dictionary) -> String:
	var c: CharacterData = ctx["player"]
	var npc: CharacterData = ctx["npc"]
	var data: GameData = ctx["data"]
	return text.format({
		"player": c.name,
		"player_realm": Cultivation.realm_label(c, data),
		"npc": npc.name if npc else "",
		"npc_realm": Cultivation.realm_label(npc, data) if npc else "",
	})


static func _choice_blocker(choice: Dictionary, ctx: Dictionary) -> String:
	var reason := unmet_reason(choice.get("if", {}), ctx)
	if reason == "":
		reason = Effects.check(ctx["player"], ctx["data"], choice.get("effects", {}))
	return reason


## Problems with a dialogue file, for GameData validation.
static func validate(dialogue: Dictionary, data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var id: String = dialogue.get("id", "?")
	var nodes: Dictionary = dialogue.get("nodes", {})
	if dialogue.get("entries", []).is_empty():
		errors.append("Dialogue '%s' has no entries" % id)
	var conds: Array = []
	for entry: Dictionary in dialogue.get("entries", []):
		if not nodes.has(entry.get("node", "")):
			errors.append("Dialogue '%s' entry points to unknown node '%s'" % [id, entry.get("node", "")])
		conds.append(entry.get("if", {}))
	for node_id in nodes:
		for choice: Dictionary in nodes[node_id].get("choices", []):
			var next: String = choice.get("next", "")
			if next != "" and next != END and not nodes.has(next):
				errors.append("Dialogue '%s' node '%s' links to unknown node '%s'" % [id, node_id, next])
			for item_id in choice.get("effects", {}).get("items", {}):
				if not data.items.has(item_id):
					errors.append("Dialogue '%s' node '%s' references unknown item '%s'" % [id, node_id, item_id])
			var tech: String = choice.get("effects", {}).get("learn_technique", "")
			if tech != "" and not data.techniques.has(tech):
				errors.append("Dialogue '%s' node '%s' teaches unknown technique '%s'" % [id, node_id, tech])
			conds.append(choice.get("if", {}))
	for cond: Dictionary in conds:
		for key in ["min_realm", "max_realm"]:
			if cond.has(key) and data.realm_index_of(cond[key]) < 0:
				errors.append("Dialogue '%s' has unknown realm '%s'" % [id, cond[key]])
		for item_id in cond.get("has_items", {}):
			if not data.items.has(item_id):
				errors.append("Dialogue '%s' condition references unknown item '%s'" % [id, item_id])
	return errors
