class_name Earnings
extends RefCounted
## GUIDE-226: what a day is worth where the player stands. Expected spirit stones per day for each
## way to earn here (chores, gathering, fishing, crafting). Pure and deterministic: no rng, expected values only.

const MAX_ROWS := 4


## Up to MAX_ROWS rows {kind, place, per_day: float, note}, best first, for the current region.
static func earning_options(c: CharacterData, data: GameData, flags: Dictionary, region_id: String, today: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var season := Calendar.season_of(today)
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
				if stones <= 0 or Deeds.check(c, data, deed, flags, today) != "":
					continue
				var per_day := float(stones) / float(maxi(1, int(deed.get("days", 1))))
				if per_day > float(best_chore.get("per_day", 0.0)):
					best_chore = {"kind": "chore", "place": name, "per_day": per_day, "note": String(deed.get("name", ""))}
		elif kind == "gather":
			var v := _gather_trip_value(c, data, place.get("gather_table", []), region_id, today, season) / float(maxi(1, int(place.get("gather_days", 1))))
			if v > float(best_gather.get("per_day", 0.0)):
				best_gather = {"kind": "gather", "place": name, "per_day": v, "note": "gathering"}
		elif kind == "fishing":
			var base := Fishing.filter_trophy(Fishing.skill_table(Exploration.gather_table_for(c, data, Fishing.filter_flags(place.get("catch_table", []), flags), season), 0.5, c.fishing_xp), 0.5, c.fishing_xp)
			var v := _fishing_trip_value(c, data, base, region_id, today, season) * (1.0 + Fishing.bonus_chance(c.fishing_xp)) / float(maxi(1, int(place.get("gather_days", 1))))
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
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["per_day"]) > float(b["per_day"]))
	return rows.slice(0, MAX_ROWS)


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
static func lines(rows: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for r in rows:
		var n := maxi(1, roundi(float(r["per_day"])))
		out.append("%s (%s): about %d %s a day." % [String(r["note"]).capitalize() if String(r["note"]) == String(r["kind"]) else String(r["note"]), r["place"], n, "stone" if n == 1 else "stones"])
	return out
