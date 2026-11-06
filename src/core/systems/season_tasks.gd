class_name SeasonTasks
extends RefCounted
## SEASON-005: three small village tasks per season (data/season_tasks.json). Progress lives in
## CharacterData.season_tasks {season_key, progress: {task_id: n}, done}; it resets when the season changes.

const KINDS: Array[String] = ["catch", "gather", "hunt", "contest", "sell_wanted"]
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const REGION := "qingshi_village"


## "<year>-<season>" for a day, the key progress is stored under.
static func season_key(day: int) -> String:
	return "%d-%s" % [Calendar.year_of(day), Calendar.season_of(day).to_lower()]


static func season_name(day: int) -> String:
	return Calendar.season_of(day).to_lower()


static func def(data: GameData, day: int) -> Dictionary:
	return (data.season_tasks.get("seasons", {}) as Dictionary).get(season_name(day), {})


## The character's progress record for `day`'s season, reset when the season changed.
static func _state(c: CharacterData, day: int) -> Dictionary:
	var key := season_key(day)
	if String(c.season_tasks.get("season_key", "")) != key:
		c.season_tasks = {"season_key": key, "progress": {}, "done": false}
	return c.season_tasks


## Adds `n` to every matching task of the season and returns the lines to post
## (one per finished task, plus the completion line once the third is done). Rewards are paid by GameState.
static func note(c: CharacterData, data: GameData, kind: String, target: String, n: int, day: int) -> Array[String]:
	var lines: Array[String] = []
	var d := def(data, day)
	if d.is_empty() or n < 1:
		return lines
	var st := _state(c, day)
	if bool(st["done"]):
		return lines
	var progress: Dictionary = st["progress"]
	for t: Dictionary in d["tasks"]:
		if String(t["kind"]) != kind or String(t["target"]) != target:
			continue
		var id := String(t["id"])
		var before := int(progress.get(id, 0))
		var count := int(t["count"])
		if before >= count:
			continue
		progress[id] = mini(count, before + n)
		if int(progress[id]) >= count:
			lines.append("Season task done: %s" % String(t["text"]))
	if all_done(c, data, day):
		st["done"] = true
		lines.append("The village thanks you for the %s: %s." % [season_name(day), reward_text(data, day)])
	return lines


static func all_done(c: CharacterData, data: GameData, day: int) -> bool:
	var d := def(data, day)
	if d.is_empty():
		return false
	var progress: Dictionary = _state(c, day)["progress"]
	for t: Dictionary in d["tasks"]:
		if int(progress.get(String(t["id"]), 0)) < int(t["count"]):
			return false
	return true


## [{text, n, count, done}] for today's season.
static func list(c: CharacterData, data: GameData, day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := def(data, day)
	if d.is_empty():
		return out
	var progress: Dictionary = _state(c, day)["progress"]
	for t: Dictionary in d["tasks"]:
		var n := int(progress.get(String(t["id"]), 0))
		out.append({"text": String(t["text"]), "n": n, "count": int(t["count"]), "done": n >= int(t["count"])})
	return out


static func reward_text(data: GameData, day: int) -> String:
	var r: Dictionary = def(data, day).get("payout", {})
	var parts: PackedStringArray = []
	if int(r.get("stones", 0)) > 0:
		parts.append("%d spirit stones" % int(r["stones"]))
	if int(r.get("renown", 0)) > 0:
		parts.append("%d renown" % int(r["renown"]))
	if String(r.get("item", "")) != "":
		parts.append(String(data.items.get(String(r["item"]), {}).get("name", r["item"])))
	if int(r.get("favor_all", 0)) > 0:
		parts.append("the villagers' goodwill")
	return ", ".join(parts)


static func validate(data: GameData) -> Array[String]:
	var errs: Array[String] = []
	var seasons: Dictionary = data.season_tasks.get("seasons", {})
	var ids := {}
	for s in SEASONS:
		var d: Dictionary = seasons.get(s, {})
		var tasks: Array = d.get("tasks", [])
		if tasks.size() != 3:
			errs.append("season_tasks.json %s needs exactly 3 tasks" % s)
		for t: Dictionary in tasks:
			var id := String(t.get("id", ""))
			if id == "" or ids.has(id) or String(t.get("text", "")) == "":
				errs.append("season_tasks.json task needs a unique id and text (got '%s')" % id)
			ids[id] = true
			var count := int(t.get("count", 0))
			if count < 1 or count > 5:
				errs.append("season task '%s' count must be 1..5" % id)
			var kind := String(t.get("kind", ""))
			var target := String(t.get("target", ""))
			match kind:
				"catch", "gather":
					if not data.items.has(target):
						errs.append("season task '%s' has unknown item '%s'" % [id, target])
					elif kind == "catch" and not data.items[target].get("tags", []).has("fish"):
						errs.append("season task '%s' target '%s' is not a fish" % [id, target])
				"hunt":
					if not data.enemies.has(target):
						errs.append("season task '%s' has unknown enemy '%s'" % [id, target])
				"contest":
					if not data.world_events.has(target) or not (data.world_events[target] as Dictionary).has("contest"):
						errs.append("season task '%s' has no contest festival '%s'" % [id, target])
				"sell_wanted":
					if target != "":
						errs.append("season task '%s' sell_wanted takes an empty target" % id)
				_:
					errs.append("season task '%s' has unknown kind '%s'" % [id, kind])
		var r: Dictionary = d.get("payout", {})
		for k in ["stones", "renown", "favor_all"]:
			if int(r.get(k, 0)) < 0:
				errs.append("season_tasks.json %s payout %s must be >= 0" % [s, k])
		if r.has("item") and not data.items.has(String(r["item"])):
			errs.append("season_tasks.json %s payout item '%s' is unknown" % [s, r["item"]])
	return errs
