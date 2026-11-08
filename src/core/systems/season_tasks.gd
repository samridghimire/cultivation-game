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


## SEASON-009: the season's task sets (`sets`, or `tasks` as one set).
static func sets_of(d: Dictionary) -> Array:
	if d.has("sets"):
		return d["sets"]
	if d.has("tasks"):
		return [d["tasks"]]
	return []


## SEASON-009: the three tasks of `day`'s season for its year: sets[(year - 1) % sets.size()].
static func tasks_for(data: GameData, day: int) -> Array:
	var sets := sets_of(def(data, day))
	if sets.is_empty():
		return []
	return sets[(Calendar.year_of(day) - 1) % sets.size()]


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
	for t: Dictionary in tasks_for(data, day):
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
			var line := _stage_line(data, c.seasons_completed.size() - 1)
			if line != "":
				lines.append_array(line.split("\n"))
	return lines


## SEASON-008: the text for the project stage that season number `n` (0-based) completes ("" when all are whole).
static func _stage_line(data: GameData, n: int) -> String:
	var offset := 0
	for i in project_list(data).size():
		var proj: Dictionary = project_list(data)[i]
		var stages: Array = proj.get("stages", [])
		if n < offset + stages.size():
			var k := n - offset
			var out := String(stages[k]["text"])
			if k == stages.size() - 1:
				out += "\n" + String(proj.get("done_text", ""))
			return out.strip_edges()
		offset += stages.size()
	return ""


## SEASON-008: the village projects in order: the shrine (the restoration block itself), then restoration.projects.
static func project_list(data: GameData) -> Array[Dictionary]:
	var rest := restoration(data)
	var out: Array[Dictionary] = []
	if rest.is_empty():
		return out
	var shrine := {"id": "shrine", "name": rest.get("name", ""), "region": rest.get("region", REGION), "stages": rest.get("stages", []),
		"done_text": "%s stands again: Qingshi's qi rises %d%%." % [_cap(String(rest.get("name", "The shrine"))), roundi(float((rest.get("qi_flag", {}) as Dictionary).get("bonus", 0.0)) * 100.0)]}
	out.append(shrine)
	for p: Dictionary in rest.get("projects", []):
		out.append(p)
	return out


## Stages of project `index` (0 = the shrine) reached by `c`.
static func project_stage(c: CharacterData, data: GameData, index: int) -> int:
	var offset := 0
	var list := project_list(data)
	for i in list.size():
		var total := (list[i].get("stages", []) as Array).size()
		if i == index:
			return clampi(c.seasons_completed.size() - offset, 0, total)
		offset += total
	return 0


## SEASON-010: the project stage the season set that brought `c` to `done_count` finished sets just completed, as
## {index, project, final} ({} when beyond every project). `final` is true for the last stage of its project.
static func stage_reached(data: GameData, done_count: int) -> Dictionary:
	var offset := 0
	var list := project_list(data)
	for i in list.size():
		var total := (list[i].get("stages", []) as Array).size()
		if done_count > offset and done_count <= offset + total:
			return {"index": i, "project": list[i], "final": done_count == offset + total}
		offset += total
	return {}


## The project being worked on now (first unfinished) as {index, project, stage}; {} when all are whole.
static func current_project(c: CharacterData, data: GameData) -> Dictionary:
	var list := project_list(data)
	for i in list.size():
		var total := (list[i].get("stages", []) as Array).size()
		var st := project_stage(c, data, i)
		if st < total:
			return {"index": i, "project": list[i], "stage": st}
	return {}


## SEASON-008: crop growth bonus (fraction of an extra day per growing day) for fields in `region_id`.
static func crop_bonus(c: CharacterData, data: GameData, region_id: String) -> float:
	var total := 0.0
	var list := project_list(data)
	for i in list.size():
		var proj: Dictionary = list[i]
		if String(proj.get("region", "")) == region_id and proj.has("crop_bonus"):
			total += float(proj["crop_bonus"]) * project_stage(c, data, i)
	return total


## SEASON-011: extra catch weight (fraction) at fishing places in `region_id` from repaired projects.
static func fish_bonus(c: CharacterData, data: GameData, region_id: String) -> float:
	var total := 0.0
	var list := project_list(data)
	for i in list.size():
		var proj: Dictionary = list[i]
		if String(proj.get("region", "")) == region_id and proj.has("fish_bonus"):
			total += float(proj["fish_bonus"]) * project_stage(c, data, i)
	return total


## SEASON-011: "The jetty: 1/3 repaired" for the project with a fish_bonus in `region_id` ("" when none or whole).
static func fish_project_line(c: CharacterData, data: GameData, region_id: String) -> String:
	var list := project_list(data)
	for i in list.size():
		var proj: Dictionary = list[i]
		if String(proj.get("region", "")) == region_id and proj.has("fish_bonus"):
			var total := (proj["stages"] as Array).size()
			var st := project_stage(c, data, i)
			if st >= total:
				return ""
			return "%s: %d/%d repaired." % [_cap(String(proj["name"]).trim_prefix("the Village Pond ").trim_prefix("the ")), st, total]
	return ""


## The well-like project with a `daily` block ({} when absent) and whether it is whole.
static func daily_project(data: GameData) -> Dictionary:
	for p: Dictionary in project_list(data):
		if p.has("daily"):
			return p
	return {}


## "" when today's draw can be made, else why not.
static func can_draw(c: CharacterData, data: GameData, flags: Dictionary, day: int) -> String:
	var proj := daily_project(data)
	if proj.is_empty():
		return "There is nothing to draw."
	var list := project_list(data)
	if project_stage(c, data, list.find(proj)) < (proj["stages"] as Array).size():
		return "The %s is not restored yet." % String(proj["name"]).trim_prefix("the ")
	if Effects.flag_active(flags, String(proj["daily"]["flag"]), day):
		return "You have drawn today's water already."
	return ""


## Draws the day's item; returns the line to post ("" when not possible).
static func draw_daily(c: CharacterData, data: GameData, flags: Dictionary, day: int) -> String:
	if can_draw(c, data, flags, day) != "":
		return ""
	var d: Dictionary = daily_project(data)["daily"]
	c.add_item(String(d["item"]), 1)
	flags[String(d["flag"])] = {"until": day + 1}
	return String(d["text"])


## The Today line for the current project ("" when all are whole or only the shrine is open).
static func project_line(c: CharacterData, data: GameData, flags: Dictionary, day: int) -> String:
	var dp := daily_project(data)
	# A whole well with water still to draw today comes first; later projects follow (SEASON-011).
	if not dp.is_empty() and project_stage(c, data, project_list(data).find(dp)) >= (dp["stages"] as Array).size() and can_draw(c, data, flags, day) == "":
		return "%s is whole: draw %s today." % [_cap(String(dp["name"])), _incense_item_name(data, String(dp["daily"]["item"])).to_lower()]
	var cur := current_project(c, data)
	if not cur.is_empty() and int(cur["index"]) > 0:
		var proj: Dictionary = cur["project"]
		return "%s: %d of %d stages repaired." % [_cap(String(proj["name"])), int(cur["stage"]), (proj["stages"] as Array).size()]
	return ""


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
	var list := project_list(data)
	for i in range(1, list.size()):
		var pstages: Array = list[i].get("stages", [])
		for k in project_stage(c, data, i):
			out.append(String(pstages[k]["flag"]))
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
	for t: Dictionary in tasks_for(data, day):
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
	for t: Dictionary in tasks_for(data, day):
		var n := int(progress.get(String(t["id"]), 0))
		out.append({"text": String(t["text"]), "where": where(t, c, data, day), "n": n, "count": int(t["count"]), "done": n >= int(t["count"])})
	return out


## GUIDE-214: where to do a task ("at Village Pond Jetty", "Misty Forest Pond in Misty Forest", "" when nothing fits).
## Pure. Qingshi's places come first, then regions by travel days from Qingshi.
static func where(task: Dictionary, c: CharacterData, data: GameData, day: int) -> String:
	var key := "%d|%s|%s|%s|%d|%d" % [data.get_instance_id(), String(task.get("id", "")), String(task.get("kind", "")), String(task.get("target", "")), day, c.realm_index if c != null else 0]
	if _where_day != day:
		_where_cache.clear()
		_where_day = day
	if _where_cache.has(key):
		return _where_cache[key]
	where_scans += 1
	var text := _where(task, c, data, day)
	_where_cache[key] = text
	return text


## FOLK-014: memoized `where` results for _where_day, and how many were really computed (test hook).
static var _where_cache: Dictionary = {}
static var _where_day := -1
static var where_scans := 0


static func _where(task: Dictionary, c: CharacterData, data: GameData, day: int) -> String:
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
		if d.has("tasks") == d.has("sets"):
			errs.append("season_tasks.json %s needs exactly one of tasks/sets" % s)
		var all_tasks: Array = []
		for set_tasks: Array in sets_of(d):
			if set_tasks.size() != 3:
				errs.append("season_tasks.json %s needs exactly 3 tasks per set" % s)
			all_tasks.append_array(set_tasks)
		for t: Dictionary in all_tasks:
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
	for p: Dictionary in rest.get("projects", []):
		var pid := String(p.get("id", ""))
		if pid == "" or String(p.get("name", "")) == "" or not data.regions.has(String(p.get("region", ""))):
			errs.append("season_tasks.json project '%s' needs an id, a name and a known region" % pid)
		var pst: Array = p.get("stages", [])
		if pst.size() < 1 or pst.size() > 8:
			errs.append("season_tasks.json project '%s' needs 1..8 stages" % pid)
		for st: Dictionary in pst:
			var pf := String(st.get("flag", ""))
			if pf == "" or String(st.get("text", "")) == "" or seen.has(pf) or pf == qflag:
				errs.append("season_tasks.json project '%s' stage needs a unique flag and text (got '%s')" % [pid, pf])
			seen[pf] = true
		if p.has("done_line") and String(p["done_line"]) == "":
			errs.append("season_tasks.json project '%s' done_line must be non-empty" % pid)
		if p.has("crop_bonus") and (float(p["crop_bonus"]) <= 0.0 or float(p["crop_bonus"]) > 0.1):
			errs.append("season_tasks.json project '%s' crop_bonus must be in (0, 0.1]" % pid)
		if p.has("fish_bonus") and (float(p["fish_bonus"]) <= 0.0 or float(p["fish_bonus"]) > 0.1):
			errs.append("season_tasks.json project '%s' fish_bonus must be in (0, 0.1]" % pid)
		if p.has("daily"):
			var dd: Dictionary = p["daily"]
			if not data.items.has(String(dd.get("item", ""))) or String(dd.get("flag", "")) == "" or String(dd.get("text", "")) == "":
				errs.append("season_tasks.json project '%s' daily needs a known item, a flag and text" % pid)
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


## Index of project `id` in project_list (-1 when missing). Pure, so `-s` sim scripts can use it before autoloads exist.
static func project_index(data: GameData, id: String) -> int:
	var list := project_list(data)
	for i in list.size():
		if String(list[i].get("id", "")) == id:
			return i
	return -1
