class_name CreationArtifact
extends RefCounted
## The Creation Artifact bound to the player's soul: lives, respawn anchors and
## recharging. A violent death with a life left respawns the player at a bound
## anchor; with no lives left (or death by old age) death is final.
## Tunables live in data/artifact.json; anchors are places in data/regions.json
## with an "anchor_id".


## Give a character starting lives (and the start anchor) if they have never
## held the artifact. Safe to call on every new game and loaded save.
static func ensure(c: CharacterData, data: GameData) -> void:
	if c.artifact_lives >= 0:
		return
	c.artifact_lives = int(data.artifact.get("starting_lives", 3))
	var start: String = data.artifact.get("start_anchor", "")
	if c.anchors.is_empty() and data.anchors.has(start):
		c.anchors.append(start)


## How many anchors `c` may bind at their current realm.
static func anchor_slots(c: CharacterData, data: GameData) -> int:
	var slots := 1
	var by_realm: Dictionary = data.artifact.get("anchor_slots", {})
	for realm_id in by_realm:
		var index := data.realm_index_of(realm_id)
		if index >= 0 and index <= c.realm_index:
			slots = maxi(slots, int(by_realm[realm_id]))
	return slots


## Display name of an anchor, e.g. "Meditation Rock (Qingshi Village)".
static func anchor_name(data: GameData, anchor_id: String) -> String:
	var anchor: Dictionary = data.anchors.get(anchor_id, {})
	if anchor.is_empty():
		return anchor_id
	return "%s (%s)" % [anchor["name"], Exploration.region_name(data, anchor["region"])]


## Bind (or refresh) an anchor; the most recently bound one is the respawn point.
## Returns {ok, reason}.
static func bind_anchor(c: CharacterData, data: GameData, anchor_id: String) -> Dictionary:
	if not data.anchors.has(anchor_id):
		return {"ok": false, "reason": "The artifact cannot anchor here."}
	if c.anchors.has(anchor_id):
		c.anchors.erase(anchor_id)
	elif c.anchors.size() >= anchor_slots(c, data):
		return {"ok": false, "reason": "All %d anchor slots are bound. Release one first." % anchor_slots(c, data)}
	c.anchors.append(anchor_id)
	return {"ok": true, "reason": ""}


## Returns true if the anchor was bound.
static func unbind_anchor(c: CharacterData, anchor_id: String) -> bool:
	if not c.anchors.has(anchor_id):
		return false
	c.anchors.erase(anchor_id)
	return true


## Spirit stones the next life costs.
static func recharge_cost(c: CharacterData, data: GameData) -> int:
	var t: Dictionary = data.artifact.get("recharge", {})
	return roundi(float(t.get("base_cost", 100)) * pow(float(t.get("cost_growth", 2.0)), c.artifact_recharges))


## Why `c` cannot buy a life now, or "" if they can.
static func check_recharge(c: CharacterData, data: GameData) -> String:
	if c.artifact_lives >= int(data.artifact.get("max_lives", 9)):
		return "The artifact cannot hold more lives."
	var cost := recharge_cost(c, data)
	if c.item_count("spirit_stone") < cost:
		return "The artifact hungers for %d spirit stones." % cost
	return ""


## Buy one life with spirit stones. Returns {ok, reason, cost}.
static func recharge(c: CharacterData, data: GameData) -> Dictionary:
	var cost := recharge_cost(c, data)
	var reason := check_recharge(c, data)
	if reason != "":
		return {"ok": false, "reason": reason, "cost": cost}
	c.add_item("spirit_stone", -cost)
	c.artifact_lives += 1
	c.artifact_recharges += 1
	return {"ok": true, "reason": "", "cost": cost}


static func can_respawn(c: CharacterData) -> bool:
	return c.artifact_lives > 0


## Spend a life to survive a violent death. Respawns at `anchor_id` if bound,
## else the most recently bound anchor, else the start region.
## Returns {ok, anchor_id, region, days, qi_lost, lives_left}.
static func respawn(c: CharacterData, data: GameData, anchor_id: String = "") -> Dictionary:
	if not can_respawn(c):
		return {"ok": false, "anchor_id": "", "region": "", "days": 0, "qi_lost": 0.0, "lives_left": 0}
	if not c.anchors.has(anchor_id):
		anchor_id = c.anchors[-1] if not c.anchors.is_empty() else ""
	var region: String = data.anchors[anchor_id]["region"] if anchor_id != "" else data.start_region
	var t: Dictionary = data.artifact.get("respawn", {})
	var qi_lost := c.qi * float(t.get("qi_loss_fraction", 0.3))
	c.qi -= qi_lost
	c.artifact_lives -= 1
	return {"ok": true, "anchor_id": anchor_id, "region": region, "days": int(t.get("days", 7)), "qi_lost": qi_lost, "lives_left": c.artifact_lives}


## Region an anchor lies in, or the start region for "" / unknown anchors.
static func anchor_region(data: GameData, anchor_id: String) -> String:
	return String(data.anchors.get(anchor_id, {}).get("region", data.start_region))


## Where `c` may awaken after a respawn: every bound anchor, the current
## respawn point first, then the rest from most to least recently bound.
## Each entry is {anchor_id, label, respawn_point}; with no anchors the only
## choice is the start region (anchor_id "").
static func respawn_choices(c: CharacterData, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(c.anchors.size() - 1, -1, -1):
		var anchor_id: String = c.anchors[i]
		out.append({"anchor_id": anchor_id, "label": anchor_name(data, anchor_id), "respawn_point": i == c.anchors.size() - 1})
	if out.is_empty():
		out.append({"anchor_id": "", "label": Exploration.region_name(data, data.start_region), "respawn_point": true})
	return out


## Display lines for the character sheet: lives, recharge cost, bound anchors.
## The latest bound anchor (the respawn point) is marked.
static func describe(c: CharacterData, data: GameData) -> Array[String]:
	var lines: Array[String] = []
	var max_lives := int(data.artifact.get("max_lives", 9))
	lines.append("Lives: %d / %d%s   |   Next recharge: %d spirit stones" % [c.artifact_lives, max_lives, " (death is final)" if c.artifact_lives == 0 else "", recharge_cost(c, data)])
	lines.append("Anchors: %d / %d bound" % [c.anchors.size(), anchor_slots(c, data)])
	for i in c.anchors.size():
		var tag := "  (respawn point)" if i == c.anchors.size() - 1 else ""
		lines.append("  %s%s" % [anchor_name(data, c.anchors[i]), tag])
	return lines
