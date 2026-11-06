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
		var key := String(st["season_key"])
		if not c.seasons_completed.has(key):
			c.seasons_completed.append(key)
			var rest := restoration(data)
			var stages: Array = rest.get("stages", [])
			if not stages.is_empty():
				var idx := mini(c.seasons_completed.size(), stages.size()) - 1
				lines.append(String(stages[idx]["text"]))
				if c.seasons_completed.size() == stages.size():
					var qf: Dictionary = rest.get("qi_flag", {})
					lines.append("%s stands again: Qingshi's qi rises %d%%." % [_cap(String(rest.get("name", "The shrine"))), roundi(float(qf.get("bonus", 0.0)) * 100.0)])
	return lines


## The restoration block of data/season_tasks.json ({} when absent).
static func restoration(data: GameData) -> Dictionary:
	return data.season_tasks.get("restoration", {})


## SEASON-006: stages of the restoration reached (0..stages).
static func restoration_stage(c: CharacterData, data: GameData) -> int:
	return mini(c.seasons_completed.size(), (restoration(data).get("stages", []) as Array).size())


## World flags the reached stages set (plus the qi flag once all are reached).
static func restoration_flags(c: CharacterData, data: GameData) -> Array[String]:
	var out: Array[String] = []
	var rest := restoration(data)
	var stages: Array = rest.get("stages", [])
	var n := restoration_stage(c, data)
	for i in n:
		out.append(String(stages[i]["flag"]))
	if not stages.is_empty() and n >= stages.size():
		out.append(String((rest.get("qi_flag", {}) as Dictionary).get("flag", "")))
	return out


## SEASON-007: the incense block ({} when absent).
static func incense(data: GameData) -> Dictionary:
	return restoration(data).get("incense", {})


static func _incense_item_name(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("name", item_id))


## "" when incense can be lit now, else why not.
static func can_offer_incense(c: CharacterData, data: GameData, flags: Dictionary, day: int) -> String:
	var inc := incense(data)
	if inc.is_empty() or restoration_stage(c, data) < (restoration(data).get("stages", []) as Array).size():
		return "The shrine is not restored yet."
	var item := String(inc["item"])
	if Effects.flag_active(flags, String(inc["flag"]), day):
		return "Incense already burns today."
	if c.item_count(item) < 1:
		return "You have no %s." % _incense_item_name(data, item)
	return ""


## Spends one incense item and sets the timed flag; returns the line to post ("" when it cannot be lit).
static func offer_incense(c: CharacterData, data: GameData, flags: Dictionary, day: int) -> String:
	if can_offer_incense(c, data, flags, day) != "":
		return ""
	var inc := incense(data)
	c.add_item(String(inc["item"]), -1)
	flags[String(inc["flag"])] = {"until": day + int(inc["days"])}
	return "%s (+%d%% qi in %s today)" % [String(inc["text"]), roundi(float(inc["bonus"]) * 100.0), String(data.regions.get(REGION, {}).get("name", "Qingshi"))]


## SEASON-007: the Today line for the restored shrine ("" before it is restored).
static func incense_line(c: CharacterData, data: GameData, flags: Dictionary, day: int) -> String:
	var inc := incense(data)
	if inc.is_empty() or can_offer_incense(c, data, flags, day) == "The shrine is not restored yet.":
		return ""
	var pct := roundi(float(inc["bonus"]) * 100.0)
	if Effects.flag_active(flags, String(inc["flag"]), day):
		return "Incense burns at the old shrine (+%d%% qi)." % pct
	return "The old shrine is restored: light incense for +%d%% qi today." % pct


## "The old shrine: 1 of 4 stages repaired." while unfinished, else "".
static func restoration_line(c: CharacterData, data: GameData) -> String:
	var rest := restoration(data)
	var total := (rest.get("stages", []) as Array).size()
	var n := restoration_stage(c, data)
	if total == 0 or n >= total:
		return ""
	return "%s: %d of %d stages repaired." % [_cap(String(rest["name"])), n, total]


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


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
		out.append({"text": String(t["text"]), "where": where(t, c, data, day), "n": n, "count": int(t["count"]), "done": n >= int(t["count"])})
	return out


## GUIDE-214: where to do a task ("at Village Pond Jetty", "Misty Forest Pond in Misty Forest", "" when nothing fits).
## Pure. Qingshi's places come first, then regions by travel days from Qingshi.
static func where(task: Dictionary, c: CharacterData, data: GameData, day: int = -1) -> String:
	if day < 0:
		day = GameClock.total_days
	var season := Calendar.season_of(day).to_lower()
	var target := String(task.get("target", ""))
	var kind := String(task.get("kind", ""))
	match kind:
		"catch", "gather":
			for rid in _regions_nearest(data):
				var region: Dictionary = data.regions[rid]
				for place: Dictionary in region.get("places", []):
					var table: Array = place.get("catch_table", []) if kind == "catch" else place.get("gather_table", [])
					for e: Dictionary in table:
						if String(e.get("item", "")) == target and Exploration.in_season(e, season):
							return "at %s" % place["display_name"] if rid == REGION else "%s in %s" % [place["display_name"], region["name"]]
				if kind == "gather":
					for e: Dictionary in region.get("forage", {}).get("items", []):
						if String(e.get("item", "")) == target and Exploration.in_season(e, season):
							return "by the paths of %s" % region["name"] if rid != REGION else "by the village paths"
		"hunt":
			var realm := c.realm_index if c != null else 0
			for rid in _regions_nearest(data):
				for r in _roamer_days(data, rid, day, realm):
					if String(r) == target:
						return "in %s" % data.regions[rid]["name"]
			if VillageHunt.quarry(data, REGION, day) == target:
				return "at the village hunt"
		"contest":
			var ev: Dictionary = data.world_events.get(target, {})
			if not ev.is_empty():
				var months: Array = ev.get("months", [])
				var rnames: PackedStringArray = []
				for rid: String in ev.get("regions", []):
					rnames.append(String(data.regions.get(rid, {}).get("name", rid)))
				if not months.is_empty() and not rnames.is_empty():
					return "at the %s in %s, month %d" % [ev.get("name", target), ", ".join(rnames), int(months[0])]
		"sell_wanted":
			return "at a market stall's wanted item"
	return ""


## Region ids ordered by travel days from Qingshi (Qingshi first, unreachable ones last).
static func _regions_nearest(data: GameData) -> Array[String]:
	var dist := {REGION: 0}
	var queue: Array[String] = [REGION]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for route: Dictionary in data.regions.get(cur, {}).get("routes", []):
			var to := String(route.get("to", ""))
			var d: int = int(dist[cur]) + int(route.get("days", 1))
			if not dist.has(to) or d < int(dist[to]):
				dist[to] = d
				queue.append(to)
	var ids: Array[String] = []
	for rid: String in data.regions:
		ids.append(rid)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: int = int(dist.get(a, 9999))
		var db: int = int(dist.get(b, 9999))
		return da < db or (da == db and a < b))
	return ids


## Enemy ids roaming the region on any day of `day`'s season for a character of `realm`.
static func _roamer_days(data: GameData, rid: String, day: int, realm: int) -> Array[String]:
	var out: Array[String] = []
	var start := day - posmod(day, 90)
	for d in range(start, start + 90):
		for r in Wildlife.roamers(data, rid, d, realm, {}):
			var id := String(r["enemy"])
			if not out.has(id):
				out.append(id)
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
	if data.season_tasks.has("restoration"):
		errs.append_array(_validate_restoration(data))
	return errs


static func _validate_restoration(data: GameData) -> Array[String]:
	var errs: Array[String] = []
	var rest: Dictionary = data.season_tasks["restoration"]
	var region := String(rest.get("region", ""))
	if not data.regions.has(region):
		errs.append("season_tasks.json restoration has unknown region '%s'" % region)
	if String(rest.get("name", "")) == "":
		errs.append("season_tasks.json restoration needs a name")
	var stages: Array = rest.get("stages", [])
	if stages.size() < 1 or stages.size() > 8:
		errs.append("season_tasks.json restoration needs 1..8 stages")
	var seen := {}
	for st: Dictionary in stages:
		var f := String(st.get("flag", ""))
		if f == "" or String(st.get("text", "")) == "" or seen.has(f):
			errs.append("season_tasks.json restoration stage needs a unique flag and text (got '%s')" % f)
		seen[f] = true
	var qf: Dictionary = rest.get("qi_flag", {})
	var bonus := float(qf.get("bonus", 0.0))
	var qflag := String(qf.get("flag", ""))
	if qflag == "" or seen.has(qflag) or bonus <= 0.0 or bonus > 0.1:
		errs.append("season_tasks.json restoration qi_flag needs a unique flag and a bonus in (0, 0.1]")
	elif data.regions.has(region):
		var listed := false
		for e: Dictionary in data.regions[region].get("qi_flags", []):
			if String(e.get("flag", "")) == qflag and is_equal_approx(float(e.get("bonus", 0.0)), bonus):
				listed = true
		if not listed:
			errs.append("region '%s' qi_flags must list restoration flag '%s' with bonus %s" % [region, qflag, bonus])
	var inc: Dictionary = rest.get("incense", {})
	if not inc.is_empty():
		var iflag := String(inc.get("flag", ""))
		var ibonus := float(inc.get("bonus", 0.0))
		var idays: Variant = inc.get("days", 0)
		if not data.items.has(String(inc.get("item", ""))):
			errs.append("season_tasks.json restoration incense has unknown item '%s'" % inc.get("item", ""))
		if iflag == "" or seen.has(iflag) or iflag == qflag or ibonus <= 0.0 or ibonus > 0.1 or String(inc.get("text", "")) == "" or not (idays is int or idays is float) or int(idays) < 1 or int(idays) > 3:
			errs.append("season_tasks.json restoration incense needs a unique flag, text, days 1..3 and a bonus in (0, 0.1]")
		elif data.regions.has(region):
			var ilisted := false
			for e: Dictionary in data.regions[region].get("qi_flags", []):
				if String(e.get("flag", "")) == iflag and is_equal_approx(float(e.get("bonus", 0.0)), ibonus):
					ilisted = true
			if not ilisted:
				errs.append("region '%s' qi_flags must list incense flag '%s' with bonus %s" % [region, iflag, ibonus])
	return errs
