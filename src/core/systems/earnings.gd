class_name Earnings
extends RefCounted
## GUIDE-226: what a day is worth where the player stands. Expected spirit stones per day for each
## way to earn here (chores, gathering, fishing, crafting). Pure and deterministic: no rng, expected values only.

const MAX_ROWS := 4


## Up to MAX_ROWS rows {kind, place, per_day: float, note}, best first, for the current region.
static func earning_options(c: CharacterData, data: GameData, flags: Dictionary, region_id: String, today: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var season := Calendar.season_of(today)
	var omen := Almanac.omen_for(data, today, Almanac.salt_of(c))  # CAL-010
	var region: Dictionary = data.regions.get(region_id, {})
	var best_chore := {}
	var best_gather := {}
	var best_fish := {}
	for place: Dictionary in region.get("places", []):
		var kind := String(place.get("type", ""))
		var name := String(place.get("display_name", kind))
		if kind == "deed_giver" and String(place.get("deed_context", "")) != "":
			var hidden := String(place.get("hidden_by_flag", ""))
			if hidden != "" and Effects.flag_active(flags, hidden, today):
				continue
			for deed in Deeds.available(data, String(place["deed_context"]), flags):
				var stones := int(deed.get("effects", {}).get("items", {}).get("spirit_stone", 0))
				# GUIDE-230: a wage is a good, repeatable errand, never a one-time crime or a fight.
				if stones <= 0 or not Deeds.is_repeatable(deed) or int(deed.get("effects", {}).get("alignment", 0)) < 0 \
						or String(deed.get("enemy", "")) != "" or Deeds.check(c, data, deed, flags, today) != "":
					continue
				var per_day := float(stones) / float(maxi(1, int(deed.get("days", 1))))
				if per_day > float(best_chore.get("per_day", 0.0)):
					best_chore = {"kind": "chore", "place": name, "per_day": per_day, "note": String(deed.get("name", ""))}
		elif kind == "gather":
			var v := _gather_trip_value(c, data, place.get("gather_table", []), region_id, today, season) * (1.0 + Almanac.gather_bonus(omen)) / float(maxi(1, int(place.get("gather_days", 1))))
			if v > float(best_gather.get("per_day", 0.0)):
				best_gather = {"kind": "gather", "place": name, "per_day": v, "note": "gathering"}
		elif kind == "fishing":
			var base := Fishing.filter_trophy(Fishing.skill_table(Exploration.gather_table_for(c, data, Fishing.filter_flags(place.get("catch_table", []), flags), season), 0.5, c.fishing_xp), 0.5, c.fishing_xp)
			var v := _fishing_trip_value(c, data, base, region_id, today, season) * Almanac.fishing_mult(omen) * (1.0 + Fishing.bonus_chance(c.fishing_xp)) / float(maxi(1, int(place.get("gather_days", 1))))
			if v > float(best_fish.get("per_day", 0.0)):
				best_fish = {"kind": "fishing", "place": name, "per_day": v, "note": "fishing"}
	if not best_chore.is_empty():
		rows.append(best_chore)
	if not best_gather.is_empty():
		rows.append(best_gather)
	if not best_fish.is_empty():
		rows.append(best_fish)
	var craft := _best_craft(c, data)
	if not craft.is_empty():
		rows.append(craft)
	var mission := _best_mission(c, data, flags, region_id)
	if not mission.is_empty():
		rows.append(mission)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["per_day"]) > float(b["per_day"]))
	return rows.slice(0, MAX_ROWS)


## GUIDE-234: the sect mission paying the most stones a day that `c` can take from a hall in `region_id` now
## (rank, realm, cooldown and items met; fights rated Dangerous or worse skipped). {} for a rogue or when none pays stones.
static func _best_mission(c: CharacterData, data: GameData, flags: Dictionary, region_id: String) -> Dictionary:
	if c.is_rogue() or Sects.hall_name(data, region_id, c) == "":
		return {}
	var best := {}
	var best_rank := 0.0
	var cv := Sects.contribution_value(data, String(c.sect["id"]))
	for id: String in Sects.available_missions(c, data, flags):
		if Sects.check_mission(c, data, id, flags, region_id) != "" or ["Dangerous", "Deadly"].has(Sects.mission_danger(c, data, id)):
			continue
		var mission: Dictionary = data.sect_missions[id]
		var days := float(maxi(1, int(mission.get("days", 1))))
		var cost := 0.0
		var needed: Dictionary = mission.get("requires", {}).get("items", {})
		for item_id: String in needed:
			cost += float(int(data.items.get(item_id, {}).get("price", 0)) * int(needed[item_id]))
		var stones := float(int(mission.get("rewards", {}).get("items", {}).get("spirit_stone", 0))) - cost
		var contribution := int(mission.get("contribution", 0))
		var per_day := stones / days
		var rank := (stones + float(contribution) * cv) / days
		if per_day > 0.0 and rank > best_rank:
			best_rank = rank
			best = {"kind": "mission", "place": Sects.hall_name(data, region_id, c), "per_day": per_day, "note": String(mission.get("name", id)), "contribution": contribution, "worth": roundi(float(contribution) * cv)}
	return best


## GUIDE-233: up to 2 one-time paid jobs {kind: "job", place, note, stones, items, days} for the givers here:
## good (alignment >= 0), not repeatable, no fight, doable now, paying stones or items with a sell value. Most stones first.
static func one_time_rows(c: CharacterData, data: GameData, flags: Dictionary, region_id: String, today: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var season := Calendar.season_of(today)
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if String(place.get("type", "")) != "deed_giver" or String(place.get("deed_context", "")) == "":
			continue
		var hidden := String(place.get("hidden_by_flag", ""))
		if hidden != "" and Effects.flag_active(flags, hidden, today):
			continue
		for deed in Deeds.available(data, String(place["deed_context"]), flags):
			var eff: Dictionary = deed.get("effects", {})
			if Deeds.is_repeatable(deed) or int(eff.get("alignment", 0)) < 0 or String(deed.get("enemy", "")) != "" \
					or Deeds.check(c, data, deed, flags, today) != "":
				continue
			var items: Dictionary = {}
			var stones := 0
			var worth := 0
			for id: String in eff.get("items", {}):
				var n := int(eff["items"][id])
				if id == "spirit_stone":
					stones += n
				if n > 0 and Items.sell_price(data, id, season) > 0:
					worth += n
					if id != "spirit_stone":
						items[id] = n
			if worth <= 0:
				continue
			rows.append({"kind": "job", "place": String(place.get("display_name", "")), "note": String(deed.get("name", "")), "stones": stones, "items": items, "days": maxi(1, int(deed.get("days", 1)))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["stones"]) > int(b["stones"]))
	return rows.slice(0, 2)


const FAR_GAIN := 1.5
const FAR_STAY_DAYS := 10.0


## GUIDE-232: at most one row {kind: "far", place, note, per_day, days, region} for a neighbouring region whose best
## non-craft row pays at least FAR_GAIN x this region's best after the round trip (per_day x stay / (stay + 2 x days),
## stay = FAR_STAY_DAYS). per_day is the far region's own figure. {} when none. Pure.
static func far_row(c: CharacterData, data: GameData, flags: Dictionary, region_id: String, today: int) -> Dictionary:
	var local := earning_options(c, data, flags, region_id, today)
	var local_best := float(local[0]["per_day"]) if not local.is_empty() else 0.0
	var best := {}
	var best_value := 0.0
	for route: Dictionary in Exploration.routes(c, data, region_id):
		if not bool(route["ok"]) or not Exploration.is_nearby(data, region_id, String(route["to"])):
			continue
		var days := float(route["days"])
		for row: Dictionary in earning_options(c, data, flags, String(route["to"]), today):
			if String(row["kind"]) == "craft":
				continue
			var value := float(row["per_day"]) * FAR_STAY_DAYS / (FAR_STAY_DAYS + 2.0 * days)
			if value >= FAR_GAIN * local_best and value > best_value and value > 0.0:
				best_value = value
				best = {"kind": "far", "place": "%s, %s" % [row["place"], route["name"]], "note": String(row["kind"]), "per_day": float(row["per_day"]), "days": int(days), "region": String(route["to"]), "contribution": int(row.get("contribution", 0)), "worth": int(row.get("worth", 0))}
	return best


## Journal rows: the local rows, with the far row (if any) last.
static func rows_with_far(c: CharacterData, data: GameData, flags: Dictionary, region_id: String, today: int, max_local: int = MAX_ROWS) -> Array[Dictionary]:
	var rows := earning_options(c, data, flags, region_id, today).slice(0, max_local)
	var far := far_row(c, data, flags, region_id, today)
	if not far.is_empty():
		rows.append(far)
	return rows


## Expected sell value of one visit to a table: rolls x sum(weight share x average count x sell price).
static func _table_value(c: CharacterData, data: GameData, table: Array, season: String, fortune: int) -> float:
	var usable := Exploration.gather_table_for(c, data, table, season)
	var total := 0.0
	var value := 0.0
	for entry: Dictionary in usable:
		var w := float(entry.get("weight", 1))
		total += w
		var id := String(entry.get("item", ""))
		if id != "":
			value += w * (float(entry.get("min", 1)) + float(entry.get("max", 1))) / 2.0 * float(Items.sell_price(data, id, season))
	if total <= 0.0:
		return 0.0
	var rolls := Exploration.GATHER_ROLLS + maxi(0, (fortune - 10) / 5)
	return float(rolls) * value / total


## Expected sell value of one gather trip, as GameState.gather yields it. One trip makes
## GATHER_ROLLS + (fortune-10)/5 rolls whatever its length in days (so per-day value divides by gather_days).
## Per item stack, over the number of rolls k that hit it (binomial): the herb-lore skill table raises rare
## weights, HerbLore.bonus_units adds bonus_chance units per stack, then today's weather (expected over the
## region's odds) cuts herb stacks by herb_yield_penalty or adds one with herb_bonus_chance.
static func _gather_trip_value(c: CharacterData, data: GameData, table: Array, region_id: String, today: int, season: String) -> float:
	var usable := HerbLore.skill_table(data.herb_lore, Exploration.gather_table_for(c, data, table, season), c.gather_xp)
	var total := 0.0
	for entry: Dictionary in usable:
		total += float(entry.get("weight", 1))
	if total <= 0.0:
		return 0.0
	var rolls := Exploration.GATHER_ROLLS + maxi(0, (c.attribute("fortune") - 10) / 5)
	var lore_bonus := HerbLore.bonus_chance(data.herb_lore, c.gather_xp) if c.gather_xp > 0 and not data.herb_lore.is_empty() else 0.0
	var weights: Dictionary = Weather._weights(data.regions.get(region_id, {}), today)
	if weights.is_empty():
		weights = {"clear": 1.0}
	var wsum := 0.0
	for kind: String in weights:
		wsum += float(weights[kind])
	var value := 0.0
	var top_units := 0.0  # SEASON-015: the item expected to have the most units gets the project's bonus unit
	var top_price := 0.0
	for entry: Dictionary in usable:
		var id := String(entry.get("item", ""))
		if id == "":
			continue
		var p := float(entry.get("weight", 1)) / total
		var avg := (float(entry.get("min", 1)) + float(entry.get("max", 1))) / 2.0
		var herb: bool = (data.items.get(id, {}).get("tags", []) as Array).has("herb")
		var price := float(Items.sell_price(data, id, season))
		for kind: String in weights:
			var eff: Dictionary = data.weather_effects.get(kind, {})
			var cut := float(int(eff.get("herb_yield_penalty", 0))) if herb else 0.0
			var thrive := float(eff.get("herb_bonus_chance", 0.0)) if herb else 0.0
			var units := 0.0
			var pmf := pow(1.0 - p, rolls)
			for k in range(0, rolls + 1):
				if k > 0:
					pmf *= float(rolls - k + 1) / float(k) * p / (1.0 - p) if p < 1.0 else 0.0
					var stack := maxf(0.0, float(k) * avg + lore_bonus - cut)
					if stack > 0.0:
						stack += thrive
					units += pmf * stack
			value += float(weights[kind]) / wsum * units * price
			if units > top_units:
				top_units = units
				top_price = price
	return value + SeasonTasks.gather_bonus(c, data, region_id) * top_price


## Expected value of one fishing trip, averaged over the region's weather odds today's season
## (a storm refuses casting; rain adds draws; other weather scales the bites).
static func _fishing_trip_value(c: CharacterData, data: GameData, base: Array, region_id: String, today: int, season: String) -> float:
	var weights: Dictionary = Weather._weights(data.regions.get(region_id, {}), today)
	if weights.is_empty():
		weights = {"clear": 1.0}
	var total := 0.0
	var value := 0.0
	for kind: String in weights:
		var w := float(weights[kind])
		total += w
		if Fishing.too_wild(kind):
			continue
		var table := Weather.scale_catch(Fishing.filter_weather(base, kind), Weather.fishing_multiplier(data, kind) * (1.0 + SeasonTasks.fish_bonus(c, data, region_id)))
		value += w * float(1 + Fishing.extra_draws(data, kind)) * _table_value(c, data, table, season, c.attribute("fortune"))
	return value / maxf(total, 0.001)


## The known recipe with the best margin per day among the player's professions; {} without a profession.
static func _best_craft(c: CharacterData, data: GameData) -> Dictionary:
	var best := {}
	for recipe: Dictionary in data.recipes.values():
		var prof := String(recipe.get("profession", ""))
		if prof == "" or not c.professions.has(prof):
			continue
		var id := String(recipe.get("id", ""))
		if not (bool(recipe.get("starter", false)) or c.known_recipes.has(id)) or Professions.rank_of(c, prof) < int(recipe.get("min_rank", 0)):
			continue
		var m := Alchemy.recipe_margin(data, id)
		var per_day := float(int(m["value"]) - int(m["cost"])) / float(maxi(1, int(recipe.get("days", 1))))
		if per_day > float(best.get("per_day", -INF)):
			best = {"kind": "craft", "place": "Workshop", "per_day": per_day, "note": String(recipe.get("name", id))}
	if best.is_empty() or float(best["per_day"]) <= 0.0:
		return {}
	return best


## "about N stones a day" lines for the journal, one per row.
static func lines(rows: Array[Dictionary], data: GameData = null) -> PackedStringArray:
	var out := PackedStringArray()
	for r in rows:
		if String(r["kind"]) == "job":
			var parts := PackedStringArray()
			if int(r["stones"]) > 0:
				parts.append("%d %s" % [int(r["stones"]), "stone" if int(r["stones"]) == 1 else "stones"])
			for id: String in r["items"]:
				var nm := String(data.items.get(id, {}).get("name", id)) if data != null else id
				parts.append(nm if int(r["items"][id]) == 1 else "%d %s" % [int(r["items"][id]), nm])
			out.append("Once: %s%s: %s, %d %s." % [r["note"], _paren(String(r["note"]), String(r["place"])), " + ".join(parts), int(r["days"]), "day" if int(r["days"]) == 1 else "days"])
			continue
		var n := maxi(1, roundi(float(r["per_day"])))
		var stones_word := "stone" if n == 1 else "stones"
		if String(r["kind"]) == "mission":
			out.append("Sect mission %s%s: about %d %s a day, +%d contribution (worth about %d stones at the treasury)." % [r["note"], _paren(String(r["note"]), String(r["place"])), n, stones_word, int(r["contribution"]), int(r["worth"])])
			continue
		if String(r["kind"]) == "far":
			if String(r["note"]) == "mission":
				out.append("Sect mission at %s (%d days away): about %d %s a day, +%d contribution (worth about %d stones at the treasury)." % [r["place"], int(r["days"]), n, stones_word, int(r.get("contribution", 0)), int(r.get("worth", 0))])
				continue
			var verb: String = {"gather": "Gathering", "fishing": "Fishing", "chore": "Errands"}.get(String(r["note"]), "Work")
			out.append("%s at %s (%d days away): about %d a day." % [verb, r["place"], int(r["days"]), n])
			continue
		out.append("%s%s: about %d %s a day." % [(String(r["note"]).substr(0, 1).to_upper() + String(r["note"]).substr(1)), _paren(String(r["note"]), String(r["place"])), n, stones_word])
	return out


## " (place)", or "" when the note already names the place ("... for Headman Zhou").
static func _paren(note: String, place: String) -> String:
	return "" if place == "" or note.contains(place) else " (%s)" % place
