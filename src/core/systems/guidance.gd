class_name Guidance
extends RefCounted
## "Next steps" hints so a player always knows what to do. Hints are plain
## strings built from existing system queries, most urgent first; no rules
## live here. Shown on the character sheet and as a HUD hint line.

## Years of life left at which the lifespan warning appears.
const LIFESPAN_WARNING_YEARS := 10
## Artifact lives at or below which recharging is suggested.
const LOW_ARTIFACT_LIVES := 1
## Highest realm index (Qi Refining) that still gets newcomer hints.
const NEWCOMER_MAX_REALM := 1
const TECHNIQUE_HINT := "Learn a technique from a manual. Merchants sell them."
const ELDER_MO_FLAG := "talked_elder_mo"
const BETTER_QI_RATIO := 1.5
const FAIR_FIGHTS_MAX := 3
const FAIR_FIGHT_MAX_RATED := 8
const FAIR_FIGHT_EXPLORE_MAX := 2
const FAIR_FIGHT_MIN_CHANCE := 0.7  # "Even" or better (Combat.label_for_chance)
const CHORE_REGION := "qingshi_village"


## Up to `limit` hints for `c`. `density` is the qi density where the player
## stands (region x sect bonus), used for the days-to-next-stage estimate.
## `people` (the NPCs, optional) enables the family hints. `flags` (world flags)
## and `region_id` drive the newcomer hints shown while Mortal or Qi Refining.
static func hints(c: CharacterData, data: GameData, density: float = 1.0, limit: int = 5, people: Dictionary = {}, flags: Dictionary = {}, region_id: String = "", today: int = -1, favor: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = []
	var years := Cultivation.years_left(c, data)
	if years <= LIFESPAN_WARNING_YEARS:
		out.append("Only %d %s of life remain. Break through to a higher realm or find a longevity treasure." % [years, "year" if years == 1 else "years"])
	if Injuries.has_any(c):
		out.append("Treat your injuries (%s): they slow your cultivation to x%s. Use a healing item or see a doctor." % [", ".join(Injuries.describe(c, data)), String.num(Injuries.cultivation_multiplier(c, data), 2)])
	if Sects.duty_days_left(c) <= Sects.DUTY_REMINDER_DAYS:
		var duty := Sects.duty_reminder(c, data)
		if duty != "":
			out.append(duty)
	if Children.is_pregnant(c):
		var days := int(c.pregnancy.get("days_left", 0))
		out.append("A child is due in %s." % Calendar.format_duration(days))
	var newcomer := _newcomer_hints(c, data, flags, region_id) if c.realm_index <= NEWCOMER_MAX_REALM else PackedStringArray()
	out.append_array(newcomer)
	var sell := _sell_hint(c, data, region_id)
	if sell != "":
		out.append(sell)
	var pointers := _pointers_hint(c, data, people, favor, region_id, today)
	if pointers != "":
		out.append(pointers)
	var untried := _untried_hint(c, data, today, people, favor, region_id)
	if untried != "":
		out.append(untried)
	var herb := herb_here_hint(c, data, region_id, today)
	if herb != "" and not out.has(herb):
		out.append(herb)
	var bitter := _bitter_rival_hint(c, data, people, flags, favor)
	if bitter != "":
		out.append(bitter)
	out.append(_cultivation_hint(c, data, density))
	var method := _method_hint(c, data)
	if method != "":
		out.append(method)
	var better_qi := _better_qi_hint(c, data, region_id, flags)
	if better_qi != "":
		out.append(better_qi)
	var lives_hint := artifact_lives_hint(c, data)
	if lives_hint != "":
		out.append(lives_hint)
	if c.realm_index > NEWCOMER_MAX_REALM:
		var sect := _sect_hint(c, data)
		if sect != "":
			out.append(sect)
	var missions := _mission_hint(c, data, flags)
	if missions != "":
		out.append(missions)
	if today >= 0:
		var lecture := _lecture_hint(c, data, today)
		if lecture != "":
			out.append(lecture)
		var delivery := Commissions.delivery_hint(c, data, today)
		if delivery != "":
			out.append(delivery)
	if c.professions.is_empty():
		out.append(_workshop_hint(c, data))
	if c.realm_index > NEWCOMER_MAX_REALM:
		var fighting := first_combat_hint(c, data, region_id)
		if fighting != "":
			out.append(fighting)
		elif c.techniques.is_empty():
			out.append(TECHNIQUE_HINT)
	for hint in [_dao_hint(c, data), _abode_hint(c, data), _family_hint(c, data, people)]:
		if hint != "":
			out.append(hint)
	if out.size() > limit:
		out.resize(limit)
	return out


## GUIDE-044: the newcomer's workshop hint names a month's pay when a Doctor profession exists.
static func _workshop_hint(c: CharacterData, data: GameData) -> String:
	if not data.professions.has("doctor"):
		return "Work at a workshop to learn a profession and earn spirit stones."
	var income: int = Professions.work_preview(c, data, "doctor", Calendar.DAYS_PER_MONTH)["income"]
	return "Work at a workshop: about %d spirit stones a month as a Doctor, or learn a craft there." % income


## RIVAL-015: a met, living, bitter rival refuses bouts; point at the amends in the NPC menu.
static func _bitter_rival_hint(c: CharacterData, data: GameData, people: Dictionary, flags: Dictionary, favor: Dictionary) -> String:
	if c.rival == "" or not flags.get(Rivals.FIRST_MEETING_FLAG, false):
		return ""
	var rival: CharacterData = people.get(c.rival)
	if rival == null or not rival.alive:
		return ""
	if Rivals.attitude(c, rival, int(favor.get(rival.id, 0)), data) != "bitter":
		return ""
	var cost := Karma.amends_cost(c, rival.id, data)
	if c.item_count("spirit_stone") >= cost:
		return "%s holds a grudge and will not cross hands with you. Make amends (%d stones) to spar again." % [rival.name, cost]
	return "%s holds a grudge and will not cross hands with you. Amends would cost %d stones." % [rival.name, cost]


## Spirit stones a merchant's buyback must reach before the "your loot is worth money" hint.
const SELL_HINT_MIN := 50
const SELL_GOODS_NAMES := {"herb": "herbs", "ore": "ore", "beast_material": "beast materials"}


## "A merchant here would pay about N spirit stones for your herbs": the best
## buyer in the region for what "sell all loot" would sell (nothing worn).
static func _sell_hint(c: CharacterData, data: GameData, region_id: String) -> String:
	if region_id == "" or not data.regions.has(region_id):
		return ""
	var best_total := 0
	var best_name := ""
	var best_goods := ""
	for place: Dictionary in data.regions[region_id].get("places", []):
		if String(place.get("type", "")) != "merchant":
			continue
		var stock: Array = place.get("stock_tags", [])
		var buy: Array = place.get("buy_tags", [])
		var ids := Items.bulk_sell_ids(c, data, stock, buy)
		var total := Items.bulk_sell_total(c, data, ids)
		if total <= best_total:
			continue
		var names: PackedStringArray = []
		for tag: String in stock + buy:
			if SELL_GOODS_NAMES.has(tag) and ids.any(func(id: String) -> bool: return Items.has_tag(data, id, [tag])):
				names.append(SELL_GOODS_NAMES[tag])
		best_total = total
		best_name = String(place.get("display_name", "A merchant"))
		best_goods = " and ".join(names.slice(0, 2)) if not names.is_empty() else "goods"
	if best_total < SELL_HINT_MIN:
		return ""
	return "The %s here would pay about %d spirit stones for your %s." % [best_name, best_total, best_goods]


## Most letters listed in the journal (WU-081).
const LETTERS_JOURNAL_MAX := 5
## Most "Ask <Name> for pointers" journal lines (GUIDE-012).
const POINTER_JOURNAL_MAX := 3
## Game days that must pass (GameClock) before "try something new" is suggested (GUIDE-007; GUIDE-041 after QA-086).
const UNTRIED_MIN_DAYS := 60
## Game days before an unvisited neighbouring region is suggested (GUIDE-014).
const UNEXPLORED_MIN_DAYS := 10
## Most "Unexplored:" journal lines (GUIDE-014).
const UNEXPLORED_JOURNAL_MAX := 2
## The craft-now hint fades after this many crafted items (GUIDE-017).
const CRAFT_HINT_MAX_CRAFTS := 5


## "Try something new" for a cultivator stuck in one loop: the first feature never
## used, judged from the life record. Not for Mortals or the first six months.
## The profession and sect nudges already exist as their own hints, so they are
## not repeated here.
static func _untried_hint(c: CharacterData, data: GameData, today: int, people: Dictionary = {}, favor: Dictionary = {}, region_id: String = "") -> String:
	var feature := _untried_feature_hint(c, data, today, people, favor, region_id)
	if feature != "":
		return feature
	if today < UNEXPLORED_MIN_DAYS or region_id == "":
		return ""
	var roads := unexplored_routes(c, data, region_id)
	if roads.is_empty():
		return ""
	return "You have never been to %s; the road from here is open." % String(roads[0]["name"])


## Open roads from `region_id` to regions the character has never visited,
## nearest first (GUIDE-014). Realm-gated routes never appear.
static func unexplored_routes(c: CharacterData, data: GameData, region_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for route: Dictionary in Exploration.routes(c, data, region_id):
		if bool(route["ok"]) and not Exploration.visited(c, String(route["to"])):
			out.append(route)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["days"] != b["days"]:
			return int(a["days"]) < int(b["days"])
		return String(a["name"]) < String(b["name"]))
	return out


static func _untried_feature_hint(c: CharacterData, data: GameData, today: int, people: Dictionary = {}, favor: Dictionary = {}, region_id: String = "") -> String:
	if c.realm_index < 1 or today < UNTRIED_MIN_DAYS:
		return ""
	if LifeStats.get_stat(c, "encounters") == 0:
		return "Explore the wilds (an explore site): fortunes, foes and strangers wait there."
	if LifeStats.get_stat(c, "items_crafted") < CRAFT_HINT_MAX_CRAFTS:
		var ready := craftable_now(c, data)
		if not ready.is_empty():
			var place := workshop_place(data, region_id)
			var recipe_name := String(data.recipes[ready[0]].get("name", ready[0]))
			if place != "":
				return "You have what %s needs: craft it at %s." % [recipe_name, place]
			return "You have what %s needs: craft it at a workshop." % recipe_name
	if LifeStats.get_stat(c, "items_crafted") == 0 and not c.known_recipes.is_empty():
		return "You know a recipe: craft it at a workshop."
	if LifeStats.get_stat(c, "realm_floors_cleared") == 0:
		var realm_ids: Array = data.secret_realms.keys()
		realm_ids.sort()
		for realm_id: String in realm_ids:
			var def: Dictionary = data.secret_realms[realm_id]
			if SecretRealms.admits(c, data, def) and SecretRealms.is_open(def, today):
				return "%s is open: delve for treasure." % String(def.get("name", realm_id))
	if not _has_sparred(c):
		var partner := _region_people(c, data, people, favor, region_id, today, "spar")
		if not partner.is_empty():
			var npc: CharacterData = partner[0]
			return "%s (%s) here would spar with you: a friendly bout trains your techniques." % [npc.name, data.realms[npc.realm_index].name]
	return ""


## Recipe ids (data order) the character could refine this moment (GUIDE-017).
static func craftable_now(c: CharacterData, data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	for recipe_id: String in data.recipes:
		if Alchemy.check(c, data, recipe_id) == "":
			out.append(recipe_id)
	return out


## A crafter hears an ingredient grows in this region (GUIDE-042): the first
## recipe (data order) of a profession taken up, known and within rank but not
## craftable now, with an ingredient short in the pack that a gather place here
## offers. When nothing here does, the same look at the regions a short walk away
## (GUIDE-046, data order). Any realm and day (a crafter can start as a Mortal).
## "" otherwise, and once the craft-now hint has faded (CRAFT_HINT_MAX_CRAFTS).
## `today >= 0` skips herbs that are out of season that day (GUIDE-048).
static func herb_here_hint(c: CharacterData, data: GameData, region_id: String, today: int = -1) -> String:
	if region_id == "" or LifeStats.get_stat(c, "items_crafted") >= CRAFT_HINT_MAX_CRAFTS:
		return ""
	if not craftable_now(c, data).is_empty():
		return ""
	var season := Calendar.season_of(today) if today >= 0 else ""
	var text := _herb_hint_in(c, data, region_id, false, season)
	if text != "":
		return text
	for other: String in data.regions:
		if other != region_id and Exploration.is_nearby(data, region_id, other):
			text = _herb_hint_in(c, data, other, true, season)
			if text != "":
				return text
	return ""


## The herb hint for the gather places of `grow_region`; `away` adds where it is.
static func _herb_hint_in(c: CharacterData, data: GameData, grow_region: String, away: bool, season: String = "") -> String:
	var here := _gatherable_items(c, data, grow_region, season)
	if here.is_empty():
		return ""
	for recipe_id: String in data.recipes:
		var recipe: Dictionary = data.recipes[recipe_id]
		var prof_id := String(recipe["profession"])
		if not c.professions.has(prof_id) or not Alchemy.knows(c, data, recipe_id):
			continue
		if int(recipe.get("min_rank", 0)) > Professions.rank_of(c, prof_id):
			continue
		for item_id: String in recipe["ingredients"]:
			if not here.has(item_id) or c.item_count(item_id) >= int(recipe["ingredients"][item_id]):
				continue
			var item_name := String(data.items[item_id].get("name", item_id))
			var text := ""
			if away:
				text = "%s grows at %s in %s, a short walk away: gather it to refine %s" % [item_name, here[item_id], _region_name(data, grow_region), String(recipe.get("name", recipe_id))]
			else:
				text = "%s grows at %s: gather it to refine %s" % [item_name, here[item_id], String(recipe.get("name", recipe_id))]
			var margin := Alchemy.recipe_margin(data, recipe_id)
			if int(margin["value"]) > int(margin["cost"]):
				return text + " (it sells for more than the ingredients cost)."
			return text + "."
	return ""


## {item_id: place display_name} for what the gather places of `region_id` can yield
## for `c` (the first place in data order wins). `season` ("" = any) skips entries
## that do not grow in it.
static func _gatherable_items(c: CharacterData, data: GameData, region_id: String, season: String = "") -> Dictionary:
	var out := {}
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if String(place.get("type", "")) != "gather":
			continue
		for entry: Dictionary in Exploration.gather_table_for(c, data, place.get("gather_table", [])):
			var item_id := String(entry.get("item", ""))
			if item_id != "" and not out.has(item_id) and Exploration.in_season(entry, season):
				out[item_id] = String(place.get("display_name", "a gather site"))
	return out


## Where `item_id` can be gathered (WU-206): the display name of the first gather
## place offering it, the current region first, then the rest in data order; a place
## in another region reads "<place> in <Region>". With `today >= 0` in-season places
## win; one that only grows it out of season reads "<place> (in <Season>)" (GUIDE-048).
## "" if no gather place yields it for `c`.
static func herb_place(c: CharacterData, data: GameData, item_id: String, region_id: String, today: int = -1) -> String:
	var order: Array = []
	if region_id != "":
		order.append(region_id)
	order.append_array(data.regions.keys())
	var season := Calendar.season_of(today) if today >= 0 else ""
	for rid: String in order:
		var here := _gatherable_items(c, data, rid, season)
		if here.has(item_id):
			return _place_in(data, String(here[item_id]), rid, region_id, "")
	if season == "":
		return ""
	for rid: String in order:
		for place: Dictionary in data.regions.get(rid, {}).get("places", []):
			if String(place.get("type", "")) != "gather":
				continue
			for entry: Dictionary in Exploration.gather_table_for(c, data, place.get("gather_table", [])):
				if String(entry.get("item", "")) == item_id:
					var seasons: Array = entry.get("seasons", [])
					var when := String(seasons[0]).capitalize() if not seasons.is_empty() else ""
					return _place_in(data, String(place.get("display_name", "a gather site")), rid, region_id, when)
	return ""


static func _place_in(data: GameData, place: String, rid: String, region_id: String, when: String) -> String:
	var text := place
	if rid != region_id:
		text += " in " + _region_name(data, rid)
	if when != "":
		text += " (in %s)" % when
	return text


## "<Workshop> in <Region>": the current region's first workshop, else the first
## region (data order) with one; "" if none (GUIDE-017).
static func workshop_place(data: GameData, region_id: String) -> String:
	var order: Array = []
	if region_id != "":
		order.append(region_id)
	order.append_array(data.regions.keys())
	for rid: String in order:
		for place: Dictionary in data.regions.get(rid, {}).get("places", []):
			if String(place.get("type", "")) == "workshop":
				return "%s in %s" % [place.get("display_name", "the workshop"), _region_name(data, rid)]
	return ""


static func _has_sparred(c: CharacterData) -> bool:
	for key: String in c.npc_action_days:
		if key.begins_with("spar:"):
			return true
	return false


## NPCs in `region_id` who pass Mentorship.check_pointers ("pointers") or
## check_spar ("spar") right now, highest favor first (then id).
static func _region_people(c: CharacterData, data: GameData, people: Dictionary, favor: Dictionary, region_id: String, today: int, kind: String) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	if region_id == "" or today < 0 or people.is_empty():
		return out
	for npc in Npcs.in_region(people, data, region_id):
		var f := int(favor.get(npc.id, 0))
		var reason := Mentorship.check_pointers(c, npc, f, data, today) if kind == "pointers" else Mentorship.check_spar(c, npc, f, data, today)
		if reason == "":
			out.append(npc)
	out.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		var fa := int(favor.get(a.id, 0))
		var fb := int(favor.get(b.id, 0))
		return fa > fb if fa != fb else a.id < b.id)
	return out


## "<Name> (<realm>) here could point out flaws in your <Tech>." (GUIDE-012).
static func _pointers_hint(c: CharacterData, data: GameData, people: Dictionary, favor: Dictionary, region_id: String, today: int) -> String:
	var mentors := _region_people(c, data, people, favor, region_id, today, "pointers")
	if mentors.is_empty():
		return ""
	var npc: CharacterData = mentors[0]
	var tech: TechniqueDef = data.techniques[Mentorship.pointer_technique(c, npc, data)]
	return "%s (%s) here could point out flaws in your %s." % [npc.name, data.realms[npc.realm_index].name, tech.name]


## Breakthrough odds (and pills that help) at a bottleneck, else qi and days to the next stage.
static func _cultivation_hint(c: CharacterData, data: GameData, density: float) -> String:
	if Cultivation.can_attempt_breakthrough(c, data):
		var next: RealmDef = data.realms[c.realm_index + 1]
		var text := "You are ready to break through to %s (%d%% chance). Attempt it at a meditation spot." % [next.name, roundi(Cultivation.breakthrough_chance(c, data) * 100)]
		var pills := breakthrough_items(c, data)
		if not pills.is_empty():
			text += " Using %s first raises the odds." % ", ".join(pills)
		elif c.breakthrough_bonus <= 0.0:
			var source := pill_source_hint(c, data)
			text += " " + source if source != "" else " Breakthrough pills raise the odds."
		if Tribulation.has_tribulation(data, c.realm_index + 1):
			text += " Success calls down a Heavenly Tribulation: ready shield talismans"
			text += ", and steel yourself against a heart demon." if Tribulation.faces_heart_demon(c, data) else "."
		return text
	if Cultivation.is_at_bottleneck(c, data):
		return "You stand at the peak of the highest realm known."
	var needed := maxf(Cultivation.qi_required(c, data) - c.qi, 0.0)
	var rate := Cultivation.qi_per_day(c, data, density)
	var eta := " (about %s of meditation here)" % Calendar.format_duration(ceili(needed / rate)) if rate > 0.0 else ""
	return "Gather %d more qi to reach the next stage%s." % [ceili(needed), eta]


## Qi density multiplier of the best place to meditate in `region_id`: the region's
## own density times its best meditation spot, or the player's abode there (seclusion).
static func best_qi_in_region(c: CharacterData, data: GameData, region_id: String, flags: Dictionary = {}) -> Dictionary:
	var region: Dictionary = data.regions.get(region_id, {})
	var base := Exploration.qi_density(data, region_id, flags)
	var best := {"region": region_id, "name": "", "density": base}
	for place: Dictionary in region.get("places", []):
		if place.get("type", "") != "meditation":
			continue
		var value := base * float(place.get("qi_density", 1.0))
		if value > float(best["density"]):
			best = {"region": region_id, "name": String(place.get("display_name", "")), "density": value}
	var seclusion := Abodes.seclusion_density(c, data, region_id)
	if seclusion > 0.0 and base * seclusion > float(best["density"]):
		best = {"region": region_id, "name": Abodes.abode_name(data, c.abode), "density": base * seclusion}
	return best


## The best meditation place in any region the player can travel to now (following
## routes whose realm requirement they meet), as {region, name, density}.
static func best_qi_reachable(c: CharacterData, data: GameData, region_id: String, flags: Dictionary = {}) -> Dictionary:
	var seen := {region_id: true}
	var queue: Array[String] = [region_id]
	var best := {}
	while not queue.is_empty():
		var here: String = queue.pop_front()
		var candidate := best_qi_in_region(c, data, here, flags)
		if best.is_empty() or float(candidate["density"]) > float(best["density"]):
			best = candidate
		for route: Dictionary in Exploration.routes(c, data, here):
			var to: String = route["to"]
			if route["ok"] and not seen.has(to):
				seen[to] = true
				queue.append(to)
	return best


## Warns when the main cultivation method is outgrown (qi gathering has fallen)
## or will be at the next breakthrough, and points at a better one.
static func _method_hint(c: CharacterData, data: GameData) -> String:
	var main_id := Techniques.main_method(c, data)
	var main_def: TechniqueDef = data.techniques.get(main_id)
	if main_def == null or main_def.max_realm == "":
		return ""
	var cap_name: String = data.realms[data.realm_index_of(main_def.max_realm)].name
	if Techniques.is_outgrown(c, data, main_id):
		var text := "Your %s teaches nothing past %s: qi gathering has fallen to x%s. Switch to a better method (techniques screen)" % [main_def.name, cap_name, String.num(data.method_over_cap_rate, 2)]
		var best := ""
		var best_rate := data.method_over_cap_rate
		for tech_id in c.techniques:
			var def: TechniqueDef = data.techniques.get(tech_id)
			if def == null or not def.is_method() or Techniques.is_outgrown(c, data, tech_id):
				continue
			var rate := Techniques.method_rate_of(c, data, tech_id)
			if rate > best_rate:
				best_rate = rate
				best = def.name
		if best != "":
			return text + " - you know the %s." % best
		text += "."
		var manual := _better_manual(c, data)
		if manual != "":
			text += " " + manual
		return text
	if Cultivation.is_at_bottleneck(c, data) and c.realm_index + 1 > data.realm_index_of(main_def.max_realm):
		return "Your %s stops at %s; find a new one before you break through." % [main_def.name, cap_name]
	return ""


## "Look for the <manual> (<source>)." for a method manual that reaches past the player's realm.
static func _better_manual(c: CharacterData, data: GameData) -> String:
	var ids: Array = data.items.keys()
	ids.sort()
	for item_id in ids:
		for tech: TechniqueDef in data.techniques.values():
			if not tech.is_method() or tech.manual_item != item_id or Techniques.knows(c, tech.id):
				continue
			if tech.max_realm != "" and data.realm_index_of(tech.max_realm) <= c.realm_index:
				continue
			var sources := Items.sources(data, item_id)
			if sources.is_empty():
				continue
			return "Look for the %s (%s)." % [String(data.items[item_id].get("name", item_id)), sources[0]]
	return ""


## A pointer to much better qi elsewhere (>= BETTER_QI_RATIO x the best spot here).
static func _better_qi_hint(c: CharacterData, data: GameData, region_id: String, flags: Dictionary = {}) -> String:
	if region_id == "" or not data.regions.has(region_id):
		return ""
	if Cultivation.is_at_bottleneck(c, data) or Cultivation.can_attempt_breakthrough(c, data):
		return ""
	var here := float(best_qi_in_region(c, data, region_id, flags)["density"])
	var best := best_qi_reachable(c, data, region_id, flags)
	if here <= 0.0 or float(best["density"]) < here * BETTER_QI_RATIO:
		return ""
	var place := String(best["name"])
	if place == "":
		place = "the grounds"
	return "Meditation at %s in %s gathers qi x%s faster than here." % [place, Exploration.region_name(data, String(best["region"])), String.num(float(best["density"]) / here, 1)]


## "Base 30% + Foundation Establishment Pill 25% + Fortune 4% = 59%." (percent rounded;
## "(capped at 99%)" when clamped). "" in the final realm.
static func chance_text(c: CharacterData, data: GameData) -> String:
	var terms := Cultivation.chance_breakdown(c, data)
	if terms.is_empty():
		return ""
	var parts: PackedStringArray = []
	var raw := 0.0
	for term in terms:
		var value := float(term["value"])
		raw += value
		var label := String(term["label"]).get_slice(" (", 0) if String(term["label"]).begins_with("Base") else String(term["label"])
		var pct := "%d%%" % roundi(absf(value) * 100)
		parts.append(("%s %s" % [label, pct]) if parts.is_empty() else ("%s %s %s" % ["+" if value >= 0.0 else "-", label, pct]))
	var text := " ".join(parts)
	text += " = %d%%." % roundi(Cultivation.breakthrough_chance(c, data) * 100)
	if raw > 0.99:
		text = text.trim_suffix(".") + " (capped at 99%)."
	elif raw < 0.01:
		text = text.trim_suffix(".") + " (at least 1%)."
	return text


## What a failed breakthrough costs, e.g. "If it fails, you lose 30 percent of
## your qi (about 1,200) and have a 12 in 100 chance of an injury." "" when not
## at the bottleneck, in the final realm, or when the next realm has a
## tribulation (the tribulation screen covers that).
static func breakthrough_risk_text(c: CharacterData, data: GameData) -> String:
	if not Cultivation.can_attempt_breakthrough(c, data) or Tribulation.has_tribulation(data, c.realm_index + 1):
		return ""
	var loss: float = data.realms[c.realm_index + 1].failure_qi_loss
	var text := "If it fails, you lose %d percent of your qi (about %s)" % [roundi(loss * 100), _commas(roundi(c.qi * loss))]
	var injury := roundi(Injuries.chance(c, data, "breakthrough_failure") * 100)
	if injury > 0:
		text += " and have a %d in 100 chance of an injury" % injury
	return text + "."


## Where to get a pill for the NEXT realm that the player is not holding, e.g.
## "A Core Forming Pill (+25%): Sold at Pill Pavilion (Fallen Star Market)." "" when
## one is held or already taken, or none has a known source.
static func pill_source_hint(c: CharacterData, data: GameData) -> String:
	if c.breakthrough_pill != "" or not breakthrough_items(c, data).is_empty():
		return ""
	var best := next_realm_pill(c, data)
	if best.is_empty():
		return ""
	var source := Items.sources(data, String(best["id"]))[0]
	var article := Text.a(String(best["name"]))  # capitalize() turns "Nine-Turn" into "Nine Turn"
	return "%s (+%d%%): %s." % [article.left(1).to_upper() + article.substr(1), roundi(float(best["effects"]["breakthrough_bonus"]) * 100), source]


## The cheapest breakthrough item (with a known buyable source) for the next
## realm, or {} in the final realm or when there is none.
static func next_realm_pill(c: CharacterData, data: GameData) -> Dictionary:
	if Cultivation.is_final_realm(c, data):
		return {}
	var next_id: String = data.realms[c.realm_index + 1].id
	var best: Dictionary = {}
	for item: Dictionary in data.items.values():
		var effects: Dictionary = item.get("effects", {})
		if String(effects.get("breakthrough_realm", "")) != next_id or float(effects.get("breakthrough_bonus", 0.0)) <= 0.0:
			continue
		if Items.sources(data, String(item["id"]))[0] == "Found exploring":
			continue
		if best.is_empty() or int(item.get("price", 0)) < int(best.get("price", 0)):
			best = item
	return best


## Shop price of the next realm's breakthrough pill, 0 when there is none.
static func next_realm_pill_price(c: CharacterData, data: GameData) -> int:
	return int(next_realm_pill(c, data).get("price", 0))


## "Save for a Foundation Establishment Pill (+25 percent): ..." in the last three stages of
## any cultivation realm while no pill is held or taken; "" otherwise.
static func pill_saving_goal(c: CharacterData, data: GameData) -> String:
	if not _pill_goal_applies(c, data):
		return ""
	var pill := next_realm_pill(c, data)
	if pill.is_empty() or not Items.sources(data, String(pill["id"]))[0].begins_with("Sold at"):
		return ""
	var price := int(pill.get("price", 0))
	var stones := c.item_count("spirit_stone")
	var have := "you can afford it now" if stones >= price else "you have %d" % stones
	return "Save for %s (+%d percent): %d stones, %s. %s." % [Text.a(String(pill["name"])), roundi(float(pill["effects"]["breakthrough_bonus"]) * 100), price, have, Items.sources(data, String(pill["id"]))[0]]


## True in the last three stages of a cultivation realm while no breakthrough pill is held or taken.
static func _pill_goal_applies(c: CharacterData, data: GameData) -> bool:
	if c.realm_index < 1 or Cultivation.is_final_realm(c, data):
		return false
	return c.stage >= data.realms[c.realm_index].stage_count() - 3 and c.breakthrough_pill == "" and breakthrough_items(c, data).is_empty()


## GUIDE-036: where to get the next realm's pill when no shop sells one (so "Save for" is silent):
## a recipe that makes it, else an auction lot, else "". One line.
static func pill_source_goal(c: CharacterData, data: GameData) -> String:
	if not _pill_goal_applies(c, data) or pill_saving_goal(c, data) != "":
		return ""
	var next_id: String = data.realms[c.realm_index + 1].id
	var pills: Array = []
	for item: Dictionary in data.items.values():
		var effects: Dictionary = item.get("effects", {})
		if String(effects.get("breakthrough_realm", "")) == next_id and float(effects.get("breakthrough_bonus", 0.0)) > 0.0:
			pills.append(item)
	pills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	var realm_name: String = data.realms[c.realm_index + 1].name
	for item: Dictionary in pills:
		for recipe: Dictionary in data.recipes.values():
			if String(recipe.get("output", {}).get("item", "")) != String(item["id"]):
				continue
			if c.professions.has(String(recipe.get("profession", ""))):
				return "Brew %s for %s (Alchemist)." % [Text.a(String(item["name"])), realm_name]
			return "Find an alchemist to brew %s for %s." % [Text.a(String(item["name"])), realm_name]
	for item: Dictionary in pills:
		for house: Dictionary in data.auction_houses.values():
			for lot: Dictionary in house.get("lot_table", []):
				if String(lot.get("item", "")) == String(item["id"]):
					var region: Dictionary = data.regions.get(String(house.get("region", "")), {})
					return "Bid for %s at the %s auction." % [Text.a(String(item["name"])), String(region.get("name", house.get("name", "")))]
	return ""


## Names of held items whose effects add a breakthrough bonus and can be used
## now (a realm-tied pill only before its own breakthrough, one per attempt).
static func breakthrough_items(c: CharacterData, data: GameData) -> PackedStringArray:
	var names: PackedStringArray = []
	for item_id in c.inventory:
		if _usable_breakthrough_item(c, data, item_id):
			names.append(String(data.items[item_id]["name"]))
	names.sort()
	return names


## Ids of the same items as `breakthrough_items`, sorted by name.
static func breakthrough_item_ids(c: CharacterData, data: GameData) -> PackedStringArray:
	var ids: Array = []
	for item_id in c.inventory:
		if _usable_breakthrough_item(c, data, item_id):
			ids.append(String(item_id))
	ids.sort_custom(func(a: String, b: String) -> bool: return String(data.items[a]["name"]) < String(data.items[b]["name"]))
	return PackedStringArray(ids)


static func _usable_breakthrough_item(c: CharacterData, data: GameData, item_id: String) -> bool:
	var effects: Dictionary = data.items.get(item_id, {}).get("effects", {})
	return c.item_count(item_id) > 0 and float(effects.get("breakthrough_bonus", 0.0)) > 0.0 and Effects.check(c, data, effects) == ""


## Rogues: which sects would take them. Members: contribution to the next rank.
static func _sect_hint(c: CharacterData, data: GameData) -> String:
	if c.is_rogue():
		var open: PackedStringArray = []
		for sect: SectDef in data.sects.values():
			if Sects.check_join(c, data, sect.id)["ok"]:
				open.append(sect.name)
		if c.realm_index == 0:
			return _mortal_sect_hint(c, data, open)
		if open.is_empty():
			return ""
		return "As a rogue cultivator you could join %s at a sect hall." % " or ".join(open)
	var sect: SectDef = data.sects[c.sect["id"]]
	var rank := int(c.sect["rank"])
	if rank + 1 >= sect.ranks.size():
		return ""
	if Sects.check_promotion(c, data) == "":
		return "The trial for %s is open. Attempt it at a sect hall." % sect.rank_name(rank + 1)
	var need := int(sect.ranks[rank + 1].get("contribution", 0)) - int(c.sect["contribution"])
	return "Earn %d more sect contribution (missions, duties) to become %s." % [maxi(need, 0), sect.rank_name(rank + 1)]


## Mortals: sects that wait for Qi Refining, and the ones that take mortals now.
## Uses a copy of the character raised to each sect's minimum realm.
static func _mortal_sect_hint(c: CharacterData, data: GameData, open: PackedStringArray) -> String:
	var later: PackedStringArray = []
	for sect: SectDef in data.sects.values():
		if Sects.check_join(c, data, sect.id)["ok"]:
			continue
		var probe := CharacterData.from_dict(c.to_dict())
		probe.realm_index = maxi(c.realm_index, data.realm_index_of(sect.min_realm))
		if Sects.check_join(probe, data, sect.id)["ok"]:
			later.append(sect.name)
	if later.is_empty():
		return "" if open.is_empty() else "As a rogue cultivator you could join %s at a sect hall." % " or ".join(open)
	var text := "Reach Qi Refining and %s will take you." % " or ".join(later)
	for sect: SectDef in data.sects.values():
		if open.has(sect.name):
			text += " %s takes mortals now%s." % [sect.name, ", but walks a demonic path" if sect.max_alignment <= 0 else ""]
	return text


## Members: how many sect missions they can take right now.
static func _mission_hint(c: CharacterData, data: GameData, flags: Dictionary = {}) -> String:
	if c.is_rogue():
		return ""
	var ready := 0
	var too_dangerous := 0
	for id: String in Sects.available_missions(c, data, flags):
		if Sects.check_mission(c, data, id, flags) != "":
			continue
		if _mission_too_dangerous(c, data, id):
			too_dangerous += 1
		else:
			ready += 1
	var text := ""
	if ready > 0:
		text = "%d sect %s ready on the mission board at a sect hall." % [ready, "mission is" if ready == 1 else "missions are"]
		if too_dangerous > 0:
			text = text.trim_suffix(".") + " (%d more %s too dangerous for you yet)." % [too_dangerous, "mission is" if too_dangerous == 1 else "missions are"]
	elif too_dangerous > 0:
		text = "The sect's missions are too dangerous for you yet; practise your techniques first."
	return text


## A mission with an enemy you would more likely lose to than beat (below Risky).
static func _mission_too_dangerous(c: CharacterData, data: GameData, mission_id: String) -> bool:
	var enemy_id := String(data.sect_missions.get(mission_id, {}).get("enemy", ""))
	if enemy_id == "" or not data.enemies.has(enemy_id):
		return false
	return mission_too_dangerous(c, data, enemy_id)


## True when the fight is below Risky at the shared rating sample count.
static func mission_too_dangerous(c: CharacterData, data: GameData, enemy_id: String) -> bool:
	if not data.enemies.has(enemy_id):
		return false
	return Combat.win_chance(c, data, data.enemies[enemy_id]) < 0.5


## Announcements for features that just became available and whose flag
## `notice_<id>` is not yet set in `flags`: [{id, text}]. The caller posts each
## once and sets the flag. `people` is the NPC table (for the rival's name);
## `clan` is the player's clan, if any (GUIDE-011).
static func unlock_notices(c: CharacterData, data: GameData, flags: Dictionary, people: Dictionary = {}, clan: ClanData = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or not c.alive:
		return out
	var stage := BodyTempering.next_stage(c, data)
	# Mortals are not yet "strong enough": the notice waits for Qi Refining.
	if not stage.is_empty() and c.realm_index >= 1:
		var realm_id := String(stage.get("min_realm", ""))
		if realm_id == "" or c.realm_index >= data.realm_index_of(realm_id):
			_add_notice(out, flags, "body_tempering", "You are strong enough to temper your body at a meditation spot.")
	if not Dao.known_ids(c, data).is_empty():
		_add_notice(out, flags, "dao", "Contemplate your glimpsed insight at a meditation spot.")
	for function_id in ["inner_world", "spirit_garden"]:
		if ArtifactFunctions.check_unlock(c, data, function_id, flags) == "":
			_add_notice(out, flags, function_id, "The Creation Artifact can unseal %s on the Artifact screen." % ArtifactFunctions.function_name(data, function_id))
	var rival := Rivals.rival_of(c, people)
	if rival != null:
		_add_notice(out, flags, "rival", "%s has named you a rival." % rival.name)
	for region_id: String in data.regions:
		if Exploration.visited(c, region_id):
			continue
		var route := _shortest_gated_route(data, region_id)
		if route.is_empty() or c.realm_index < data.realm_index_of(String(route["min_realm"])):
			continue
		_add_notice(out, flags, "road_" + region_id, "You are strong enough to travel to %s (%d days from %s)." % [Exploration.region_name(data, region_id), int(route["days"]), Exploration.region_name(data, String(route["from"]))])
	if not c.is_rogue():
		var promo_rank := Sects.next_rank(c, data)
		if promo_rank >= 0 and Sects.needs_trial(c, data) and Sects.check_promotion(c, data) == "":
			var sect: SectDef = data.sects[c.sect["id"]]
			_add_notice(out, flags, "promotion_%s_%d" % [sect.id, promo_rank], "You may challenge the %s trial at the %s hall." % [sect.rank_name(promo_rank), sect.name])
	if clan == null and Clans.check_found(c, null, data) == "":
		_add_notice(out, flags, "clan", "You can found a clan of your own at your cave abode.")
	for region_id: String in data.regions:
		if not Exploration.visited(c, region_id):
			continue
		for path_id: String in Exploration.open_deep_paths(c, data, region_id, flags):
			if String(data.encounters[path_id].get("blocked_by_flag", "")) != "":
				_add_notice(out, flags, "deep_path_" + path_id, "Your days in %s have shown you a path you had missed. Explore there again." % Exploration.region_name(data, region_id))
	for realm_id: String in data.secret_realms:
		var def: Dictionary = data.secret_realms[realm_id]
		var low := data.realm_index_of(String(def.get("min_realm", "")))
		var high := data.realm_index_of(String(def.get("max_realm", "")))
		if c.realm_index < low or c.realm_index > high or not data.regions.has(String(def.get("region", ""))):
			continue
		_add_notice(out, flags, "secret_realm_" + realm_id, "The %s admits cultivators of your realm (%s; opens every %d years)." % [def["name"], Exploration.region_name(data, String(def["region"])), int(def.get("period_years", 0))])
	return out


## The quickest route into a region that has a min_realm gate ({} when none is gated).
static func _shortest_gated_route(data: GameData, region_id: String) -> Dictionary:
	var best: Dictionary = {}
	for from_id: String in data.regions:
		for route: Dictionary in data.regions[from_id].get("routes", []):
			if route.get("to", "") != region_id or String(route.get("min_realm", "")) == "":
				continue
			if best.is_empty() or int(route.get("days", 0)) < int(best["days"]):
				best = {"from": from_id, "days": int(route.get("days", 0)), "min_realm": String(route["min_realm"])}
	return best


static func _add_notice(out: Array[Dictionary], flags: Dictionary, id: String, text: String) -> void:
	if not flags.get("notice_" + id, false):
		out.append({"id": id, "text": text})


## The first glimpsed Dao insight that can still be deepened.
static func _dao_hint(c: CharacterData, data: GameData) -> String:
	for insight_id in Dao.known_ids(c, data):
		if Dao.check_contemplate(c, data, insight_id) == "":
			return "Contemplate the %s at a meditation spot to deepen it (%s)." % [Dao.def_of(data, insight_id)["name"], Dao.progress_text(c, data, insight_id)]
	return ""


## Seclusion at the player's abode, or claiming one once they cultivate.
static func _abode_hint(c: CharacterData, data: GameData) -> String:
	if c.abode != "":
		var density := float(Abodes.get_def(data, c.abode).get("qi_density", 1.0)) * (1.0 + Abodes.array_bonus(c, data))
		return "Cultivate in seclusion at %s (qi x%s)." % [Abodes.abode_name(data, c.abode), String.num(density, 2)]
	if c.realm_index >= 1 and not data.abodes.is_empty():
		return "Claim a cave abode to cultivate in seclusion and store your treasures."
	return ""


## Trying for a child with a spouse, or courting someone when unmarried.
static func _family_hint(c: CharacterData, data: GameData, people: Dictionary) -> String:
	if people.is_empty() or Children.is_pregnant(c):
		return ""
	var spouses := Family.living_spouses(c, people)
	if spouses.is_empty():
		if c.age_years() >= int(data.family.get("adult_age", 16)):
			return "Win someone's favor with chats and gifts, then court them to start a family."
		return ""
	if not c.children.is_empty():
		return ""
	for spouse_id in spouses:
		var spouse: CharacterData = people[spouse_id]
		if Children.check_conception(c, spouse, data) == "":
			return "You could try for a child with %s at a meditation spot." % spouse.name
	return ""


## The cheapest combat-technique manual `c` could learn (GUIDE-019), or {} when
## they already know a combat technique. Prefers a merchant in `region_id`
## ({item, technique, merchant, price}); else the cheapest manual with any known
## source ({item, technique, merchant: "", price, source}).
static func first_combat_manual(c: CharacterData, data: GameData, region_id: String) -> Dictionary:
	if Techniques.knows_kind(c, data, "combat"):
		return {}
	var best: Dictionary = {}
	var places: Array = data.regions.get(region_id, {}).get("places", [])
	var anywhere: Dictionary = {}
	for tech: TechniqueDef in data.techniques.values():
		if tech.kind != "combat" or tech.manual_item == "" or not data.items.has(tech.manual_item):
			continue
		if not tech.activation.is_empty():
			continue
		if data.realm_index_of(tech.min_realm) > c.realm_index:
			continue
		var item: Dictionary = data.items[tech.manual_item]
		var price := int(item.get("price", 0))
		for place: Dictionary in places:
			if place.get("type", "") != "merchant":
				continue
			if c.alignment < int(place.get("min_alignment", -1000000)) or c.alignment > int(place.get("max_alignment", 1000000)):
				continue
			if not Items.merchant_sells(data, item, place.get("stock_tags", []), int(place.get("max_price", 0))):
				continue
			if best.is_empty() or price < int(best["price"]) or (price == int(best["price"]) and tech.manual_item < String(best["item"])):
				best = {"item": tech.manual_item, "technique": tech.id, "merchant": String(place.get("display_name", "a merchant")), "price": price}
		if Items.has_known_source(data, tech.manual_item):
			if anywhere.is_empty() or price < int(anywhere["price"]) or (price == int(anywhere["price"]) and tech.manual_item < String(anywhere["item"])):
				anywhere = {"item": tech.manual_item, "technique": tech.id, "merchant": "", "price": price, "source": Items.sources(data, tech.manual_item)[0]}
	return best if not best.is_empty() else anywhere


## "You know no fighting style..." naming where to get one, or "" (GUIDE-019).
static func first_combat_hint(c: CharacterData, data: GameData, region_id: String) -> String:
	var found := first_combat_manual(c, data, region_id)
	if found.is_empty():
		return ""
	var manual: String = data.items[found["item"]]["name"]
	var lead := "Your body art guards you, but you know no fighting style." if Techniques.knows_kind(c, data, "body") else "You know no fighting style."
	if String(found["merchant"]) != "":
		return "%s %s at the %s teaches %s for %d spirit stones." % [lead, manual, found["merchant"], data.techniques[found["technique"]].name, int(found["price"])]
	return "%s Look for the %s (%s)." % [lead, manual, found["source"]]


## "Practise <style> on the Techniques screen..." for a newcomer with a low-level fighting style, or "" (GUIDE-020).
static func practice_hint(c: CharacterData, data: GameData) -> String:
	var id := Techniques.practice_target(c, data)
	if id == "":
		return ""
	return "Practise %s on the Techniques screen: each level raises your odds in a fight (level %d now)." % [data.techniques[id].name, Techniques.level(c, id)]


## First-steps pointers for Mortal and Qi Refining players, most useful first.
static func _newcomer_hints(c: CharacterData, data: GameData, flags: Dictionary, region_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var breathing := c.techniques.is_empty() and data.techniques.has("basic_breathing")
	var technique_done := false
	if not flags.get(ELDER_MO_FLAG, false):
		if breathing:
			out.append("Ask Elder Mo in Qingshi Village where to begin; he also teaches a breathing technique.")
			technique_done = true
		else:
			out.append("Ask Elder Mo in Qingshi Village where to begin.")
	if not Cultivation.is_at_bottleneck(c, data):
		for item_id in c.inventory:
			var item: Dictionary = data.items.get(item_id, {})
			var fx: Dictionary = item.get("effects", {})
			# Never steer a newcomer toward pills that burn lifespan or taint the heart.
			var harmful := fx.has("burn_lifespan") or int(fx.get("alignment", 0)) < 0
			if c.item_count(item_id) > 0 and float(fx.get("qi", 0.0)) > 0.0 and not harmful:
				out.append("Use your %s (Inventory, I) to gather qi at once." % item["name"])
				break
	var fighting := first_combat_hint(c, data, region_id)
	if fighting != "":
		out.append(fighting)
	var practise := practice_hint(c, data)
	if practise != "":
		out.append(practise)
	if region_id == CHORE_REGION:
		for deed: Dictionary in data.deeds.values():
			if String(deed["id"]).begins_with("chore_") and not flags.get(String(deed.get("blocked_by_flag", "")), false):
				out.append("Headman Zhou has chores that pay stones and pills.")
				break
	if c.techniques.is_empty() and not technique_done:
		out.append("Elder Mo in Qingshi Village teaches a breathing technique for free." if breathing else TECHNIQUE_HINT)
	var sect := _sect_hint(c, data)
	if sect != "":
		out.append(sect)
	return out


## GUIDE-031: `hints` without the ones that only repeat the goal. The goal's capitalized words after
## its first word ("Talk to Elder Mo" -> Elder, Mo) name its subject; a hint containing all of them
## as whole words is dropped. A goal without such words drops nothing.
static func drop_goal_echoes(goal: String, hints: PackedStringArray) -> PackedStringArray:
	var text := goal.trim_prefix("Goal: ")
	var key_words: PackedStringArray = []
	var words := text.split(" ", false)
	for i in range(1, words.size()):
		var w := words[i].strip_edges()
		if w != "" and w[0] == w[0].to_upper() and w[0] != w[0].to_lower():
			key_words.append(w)
	if key_words.is_empty():
		return hints
	var kept: PackedStringArray = []
	for h in hints:
		var hint_words := h.split(" ", false)
		var echo := true
		for k in key_words:
			var found := false
			for hw in hint_words:
				if hw.trim_suffix(".").trim_suffix(",") == k:
					found = true
					break
			if not found:
				echo = false
				break
		if not echo:
			kept.append(h)
	return kept


## GUIDE-034: true when `line` repeats one of the journal's Goals lines, or is the breakthrough
## hint for the realm a "Reach <realm>" goal already names.
static func _echoes_goal(line: String, goal_lines: PackedStringArray) -> bool:
	for goal in goal_lines:
		if line == goal:
			return true
		if goal.begins_with("Reach ") and line.begins_with("You are ready to break through"):
			var subject := goal.get_slice(":", 0)
			if drop_goal_echoes(subject, PackedStringArray([line])).is_empty():
				return true
	return false


## The newcomer ladder: {text, done} in order.
static func first_goals(c: CharacterData, data: GameData, flags: Dictionary) -> Array[Dictionary]:
	var stage_3 := c.realm_index > 1 or (c.realm_index == 1 and c.stage >= 2)
	var rows: Array = [
		["Talk to Elder Mo in Qingshi Village", bool(flags.get(ELDER_MO_FLAG, false))],
		["Learn your first technique", not c.techniques.is_empty()],
		["Learn a fighting style", Techniques.knows_kind(c, data, "combat")],
		["Reach Qi Refining", c.realm_index >= 1],
		["Join a sect, or explore the wilds as a rogue", not c.is_rogue() or LifeStats.get_stat(c, "encounters") >= 5],
		["Win your first fight", LifeStats.get_stat(c, "fights_won") >= 1],
		["Reach the 3rd Layer of Qi Refining", stage_3],
	]
	var out: Array[Dictionary] = []
	for row: Array in rows:
		out.append({"text": row[0], "done": row[1]})
	return out


static func first_goals_done(c: CharacterData, data: GameData, flags: Dictionary) -> bool:
	for goal in first_goals(c, data, flags):
		if not goal["done"]:
			return false
	return true


const BEAT_REALM_FLAG := "beat_realm_"


## World flag set when the player wins a real fight against a foe of this realm.
static func beat_realm_flag(realm_id: String) -> String:
	return BEAT_REALM_FLAG + realm_id


## The Foundation Establishment ladder (FOUND-004): {text, done} in order.
static func foundation_goals(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	var rows: Array = [
		["Reach Foundation Establishment Middle", c.realm_index > 2 or (c.realm_index == 2 and c.stage >= 1)],
		["Win a fight against a Foundation foe", bool(flags.get(beat_realm_flag("foundation_establishment"), false))],
		["Claim a cave abode", c.abode != ""],
		["Temper your body to its first stage", c.body_stage >= 1],
		["Found a clan or rise to Inner Disciple", clan != null or (not c.is_rogue() and int(c.sect["rank"]) >= 2)],
	]
	var out: Array[Dictionary] = []
	for row: Array in rows:
		out.append({"text": row[0], "done": row[1]})
	return out


## True while the player is in Foundation Establishment with goals left.
static func foundation_goals_active(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> bool:
	if c.realm_index != 2:
		return false
	for goal in foundation_goals(c, data, flags, clan):
		if not goal["done"]:
			return true
	return false


## The Core Formation ladder (CORE-001): {text, done} in order.
static func core_goals(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	var core := data.realm_index_of("core_formation")
	var rows: Array = [
		["Reach Core Formation Middle", c.realm_index > core or (c.realm_index == core and c.stage >= 1)],
		["Win a fight against a Core Formation foe", bool(flags.get(beat_realm_flag("core_formation"), false))],
		["Clear a secret realm floor", LifeStats.get_stat(c, "realm_floors_cleared") >= 1],
		["Temper your body to Golden Body", c.body_stage >= 4],
	]
	var out: Array[Dictionary] = []
	for row: Array in rows:
		out.append({"text": row[0], "done": row[1]})
	return out


## True while the player is in Core Formation with goals left.
static func core_goals_active(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> bool:
	if c.realm_index != data.realm_index_of("core_formation"):
		return false
	for goal in core_goals(c, data, flags, clan):
		if not goal["done"]:
			return true
	return false


## The Nascent Soul ladder (NS-007): {text, done} in order.
static func nascent_goals(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	var nascent := data.realm_index_of("nascent_soul")
	var rows: Array = [
		["Reach Nascent Soul Middle", c.realm_index > nascent or (c.realm_index == nascent and c.stage >= 1)],
		["Win a fight against a Nascent Soul foe", bool(flags.get(beat_realm_flag("nascent_soul"), false))],
		["Claim an inheritance", LifeStats.get_stat(c, "inheritances_claimed") >= 1],
	]
	var body_stages := BodyTempering.stages(data)
	if body_stages.size() > 4:
		rows.append(["Temper your body to %s" % String(body_stages[4].get("name", "its next stage")), c.body_stage >= 5])
	var out: Array[Dictionary] = []
	for row: Array in rows:
		out.append({"text": row[0], "done": row[1]})
	return out


## True while the player is in Nascent Soul with goals left.
static func nascent_goals_active(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> bool:
	if c.realm_index != data.realm_index_of("nascent_soul"):
		return false
	for goal in nascent_goals(c, data, flags, clan):
		if not goal["done"]:
			return true
	return false


## The Soul Formation ladder (SOUL-001): {text, done} in order.
static func soul_goals(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	var soul := data.realm_index_of("soul_formation")
	var rows: Array = [
		["Reach Soul Formation Middle", c.realm_index > soul or (c.realm_index == soul and c.stage >= 1)],
		["Win a fight against a Soul Formation foe", bool(flags.get(beat_realm_flag("soul_formation"), false))],
	]
	if _has_realm_inheritance(data, "soul_formation"):
		rows.append(["Claim a Soul Formation inheritance", _claimed_realm_inheritance(data, flags, "soul_formation")])
	var body_stages := BodyTempering.stages(data)
	if body_stages.size() > 5:
		rows.append(["Temper your body to %s" % String(body_stages[5].get("name", "its next stage")), c.body_stage >= 6])
	var out: Array[Dictionary] = []
	for row: Array in rows:
		out.append({"text": row[0], "done": row[1]})
	return out


## True when some inheritance has a stage that needs `realm_id` (SOUL-002).
static func _has_realm_inheritance(data: GameData, realm_id: String) -> bool:
	return not _realm_inheritance_ids(data, realm_id).is_empty()


static func _realm_inheritance_ids(data: GameData, realm_id: String) -> Array[String]:
	var out: Array[String] = []
	var ids: Array = data.inheritances.keys()
	ids.sort()
	for id: String in ids:
		for stage: Dictionary in data.inheritances[id].get("stages", []):
			if String(stage.get("min_realm", "")) == realm_id:
				out.append(id)
				break
	return out


## True when the player has claimed any inheritance with a stage needing `realm_id`.
static func _claimed_realm_inheritance(data: GameData, flags: Dictionary, realm_id: String) -> bool:
	for id in _realm_inheritance_ids(data, realm_id):
		if Inheritances.is_claimed(id, flags):
			return true
	return false


## True while the player is in Soul Formation with goals left.
static func soul_goals_active(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> bool:
	if c.realm_index != data.realm_index_of("soul_formation"):
		return false
	for goal in soul_goals(c, data, flags, clan):
		if not goal["done"]:
			return true
	return false


## The Void Refinement ladder (VOID-001): {text, done} in order. The inheritance and body rows
## appear once data has them.
static func void_goals(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	var void_index := data.realm_index_of("void_refinement")
	var rows: Array = [
		["Reach Void Refinement Middle", c.realm_index > void_index or (c.realm_index == void_index and c.stage >= 1)],
		["Win a fight against a Void Refinement foe", bool(flags.get(beat_realm_flag("void_refinement"), false))],
	]
	if _has_realm_inheritance(data, "void_refinement"):
		rows.append(["Claim a Void Refinement inheritance", _claimed_realm_inheritance(data, flags, "void_refinement")])
	var body_stages := BodyTempering.stages(data)
	if body_stages.size() > 6:
		rows.append(["Temper your body to %s" % String(body_stages[6].get("name", "its next stage")), c.body_stage >= 7])
	var out: Array[Dictionary] = []
	for row: Array in rows:
		out.append({"text": row[0], "done": row[1]})
	return out


## True while the player is in Void Refinement with goals left.
static func void_goals_active(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> bool:
	if c.realm_index != data.realm_index_of("void_refinement"):
		return false
	for goal in void_goals(c, data, flags, clan):
		if not goal["done"]:
			return true
	return false


## The goal ladder the HUD announces from: "first" up to Qi Refining, "foundation" in Foundation
## Establishment, "core" in Core Formation, "nascent" in Nascent Soul, "soul" in Soul Formation, "void" in Void Refinement, else "". Unlike active_goal_ladder it stays put once every goal is done, so the
## last goal ticked off is still announced.
static func goal_ladder_id(c: CharacterData) -> String:
	if c.realm_index <= 1:
		return "first"
	if c.realm_index == 2:
		return "foundation"
	if c.realm_index == 3:
		return "core"
	if c.realm_index == 4:
		return "nascent"
	if c.realm_index == 5:
		return "soul"
	if c.realm_index == 6:
		return "void"
	return ""


## The goals of ladder `id` (goal_ladder_id), done or not; [] for "".
static func goal_ladder(id: String, c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	if id == "first":
		return first_goals(c, data, flags)
	if id == "foundation":
		return foundation_goals(c, data, flags, clan)
	if id == "core":
		return core_goals(c, data, flags, clan)
	if id == "nascent":
		return nascent_goals(c, data, flags, clan)
	if id == "soul":
		return soul_goals(c, data, flags, clan)
	if id == "void":
		return void_goals(c, data, flags, clan)
	var none: Array[Dictionary] = []
	return none


## The goal ladder currently shown (first, Foundation, then Core Formation goals), [] when none.
static func active_goal_ladder(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null) -> Array[Dictionary]:
	if c.realm_index <= 1 and not first_goals_done(c, data, flags):
		return first_goals(c, data, flags)
	if foundation_goals_active(c, data, flags, clan):
		return foundation_goals(c, data, flags, clan)
	if core_goals_active(c, data, flags, clan):
		return core_goals(c, data, flags, clan)
	if nascent_goals_active(c, data, flags, clan):
		return nascent_goals(c, data, flags, clan)
	if soul_goals_active(c, data, flags, clan):
		return soul_goals(c, data, flags, clan)
	if void_goals_active(c, data, flags, clan):
		return void_goals(c, data, flags, clan)
	var none: Array[Dictionary] = []
	return none


## Mid-game goals (GOAL-003), up to 3 plain lines: the next realm, the next sect
## rank (or founding a clan for a rogue) and the nearest unearned milestone.
static func goals(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData = null, density: float = 1.0) -> PackedStringArray:
	var out: PackedStringArray = []
	if not Cultivation.is_final_realm(c, data):
		var next_name: String = data.realms[c.realm_index + 1].name
		var odds := "%d percent" % roundi(Cultivation.breakthrough_chance(c, data) * 100)
		var days := Cultivation.days_to_bottleneck(c, data, density)
		if days == 0:
			out.append("Reach %s: attempt the breakthrough (%s)." % [next_name, odds])
		elif days > 0:
			out.append("Reach %s: about %s of meditation, then a breakthrough (%s)." % [next_name, Calendar.format_rough(days), odds])
		else:
			out.append("Reach %s: gather qi, then attempt a breakthrough (%s)." % [next_name, odds])
		var saving := pill_saving_goal(c, data)
		if saving == "":
			saving = pill_source_goal(c, data)
		if saving != "":
			out.append(saving)
	if not c.is_rogue():
		var rank := Sects.next_rank(c, data)
		if rank >= 0:
			var rank_name: String = (data.sects[c.sect["id"]] as SectDef).rank_name(rank)
			var need := Sects.rank_requirement_reason(c, data)
			if need != "":
				out.append("Become %s: %s" % [rank_name, need])
			elif Sects.needs_trial(c, data):
				out.append("Become %s: you can seek promotion at the sect hall." % rank_name)
	elif clan == null:
		var why := Clans.check_found(c, clan, data)
		if why != "":
			out.append("Found a clan: %s" % why)
	var craft := _profession_goal(c, data)
	if craft != "":
		out.append(craft)
	var best := ""
	var best_frac := -1.0
	for def: Dictionary in data.milestones:
		var id := String(def["id"])
		if c.milestones.has(id):
			continue
		var p := Milestones.progress(c, data, flags, clan, id)
		var frac := float(p["current"]) / float(p["target"])
		if frac > best_frac:
			best_frac = frac
			var count := Milestones.progress_text(c, data, flags, clan, id)
			best = String(def["name"]) + ((" (%s)" % count) if count != "" else "")
	if best != "":
		out.append(best)
	return out


## The next rank of the player's highest-ranked unmaxed profession (GOAL-004), or "".
static func _profession_goal(c: CharacterData, data: GameData) -> String:
	var best_id := ""
	for id: String in c.professions:
		if not data.professions.has(id) or Professions.rank_of(c, id) >= Professions.max_rank(data):
			continue
		if best_id == "" or Professions.rank_of(c, id) > Professions.rank_of(c, best_id) \
				or (Professions.rank_of(c, id) == Professions.rank_of(c, best_id) and Professions.xp_of(c, id) > Professions.xp_of(c, best_id)):
			best_id = id
	if best_id == "":
		return ""
	var def: ProfessionDef = data.professions[best_id]
	var rank := Professions.rank_of(c, best_id)
	var more := ceili(def.xp_to_next(rank) - Professions.xp_of(c, best_id))
	var how := "treat patients at a clinic" if best_id == Medicine.DOCTOR else "craft or work at a workshop"
	return "Become %s %s: %d more xp (%s)." % [data.profession_rank_names[rank + 1], def.name, more, how]


## "Where you left off" lines for a freshly loaded save (RECAP-001): who and where
## the player is, the first "Next steps" line and the first warning line if different.
static func recap(c: CharacterData, data: GameData, flags: Dictionary, today: int, region_id: String, density: float = 1.0, people: Dictionary = {}, events: Array = [], clan: ClanData = null) -> PackedStringArray:
	var out: PackedStringArray = []
	out.append("%s, %s, age %d, in %s." % [c.name, Cultivation.realm_label(c, data), c.age_years(), Exploration.region_name(data, region_id)])
	var next_step := ""
	var warning := ""
	for entry in journal(c, data, flags, today, region_id, density, people, events, clan):
		if next_step == "" and entry["section"] == "Next steps":
			next_step = String(entry["text"])
		if warning == "" and entry["tone"] == "warning":
			warning = String(entry["text"])
	if next_step != "":
		out.append(next_step)
	if warning != "" and warning != next_step:
		out.append(warning)
	# What is waiting (GUIDE-018): at most two of hunt, letter, renown.
	var waiting: PackedStringArray = []
	var hunt := Bounties.active(c, data, today)
	if not hunt.is_empty():
		var enemy: Dictionary = data.enemies.get(String(hunt.get("enemy", "")), {})
		waiting.append("You are hunting %s in %s (%d days left)." % [
			String(enemy.get("name", hunt.get("name", "your quarry"))),
			Exploration.region_name(data, String(hunt.get("region", region_id))),
			maxi(0, int(hunt["until_day"]) - today)])
	var letter := Letters.recent_line(c, today)
	if letter != "":
		waiting.append(letter)
	var best_region := ""
	for id: String in c.renown:
		if Renown.title(c, data, id) != "" and (best_region == "" or Renown.value(c, id) > Renown.value(c, best_region)):
			best_region = id
	if best_region != "":
		waiting.append("Your name is %s in %s." % [Renown.title(c, data, best_region), Exploration.region_name(data, best_region)])
	out.append_array(waiting.slice(0, 2))
	return out


## Journal entries {section, text, tone} answering "what can I do now?", in
## display order (WU-007 renders them). tone is "normal", "warning" (urgent) or
## "dim" (waiting / on cooldown). `today` is the GameClock day, `events` the live
## world events. Pure: nothing is mutated.
static func journal(c: CharacterData, data: GameData, flags: Dictionary, today: int, region_id: String, density: float = 1.0, people: Dictionary = {}, events: Array = [], clan: ClanData = null, favor: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hint_lines := hints(c, data, density, 99, people, flags, region_id, today, favor)
	var urgent := 0
	if Cultivation.years_left(c, data) <= LIFESPAN_WARNING_YEARS:
		urgent += 1
	if Injuries.has_any(c):
		urgent += 1
	# The duty reminder lives in the Sect section; keep it out of Next steps.
	var duty_line := Sects.duty_reminder(c, data) if Sects.duty_days_left(c) <= Sects.DUTY_REMINDER_DAYS else ""
	var method_line := _method_hint(c, data)
	# Newcomers only: past Qi Refining (or on saves from before the Elder Mo flag
	# and life stats) the ladder would otherwise never go away.
	if c.realm_index <= 1 and not first_goals_done(c, data, flags):
		var flagged := false
		for goal in first_goals(c, data, flags):
			var tone := "dim"
			if not goal["done"]:
				tone = "normal" if flagged else "warning"
				flagged = true
			_add(out, "First goals", ("[x] " if goal["done"] else "[ ] ") + String(goal["text"]), tone)
	if foundation_goals_active(c, data, flags, clan):
		var found_flagged := false
		for goal in foundation_goals(c, data, flags, clan):
			var found_tone := "dim"
			if not goal["done"]:
				found_tone = "normal" if found_flagged else "warning"
				found_flagged = true
			_add(out, "Foundation goals", ("[x] " if goal["done"] else "[ ] ") + String(goal["text"]), found_tone)
	if core_goals_active(c, data, flags, clan):
		var core_flagged := false
		for goal in core_goals(c, data, flags, clan):
			var core_tone := "dim"
			if not goal["done"]:
				core_tone = "normal" if core_flagged else "warning"
				core_flagged = true
			_add(out, "Core Formation goals", ("[x] " if goal["done"] else "[ ] ") + String(goal["text"]), core_tone)
	if nascent_goals_active(c, data, flags, clan):
		var nascent_flagged := false
		for goal in nascent_goals(c, data, flags, clan):
			var nascent_tone := "dim"
			if not goal["done"]:
				nascent_tone = "normal" if nascent_flagged else "warning"
				nascent_flagged = true
			_add(out, "Nascent Soul goals", ("[x] " if goal["done"] else "[ ] ") + String(goal["text"]), nascent_tone)
	if soul_goals_active(c, data, flags, clan):
		var soul_flagged := false
		for goal in soul_goals(c, data, flags, clan):
			var soul_tone := "dim"
			if not goal["done"]:
				soul_tone = "normal" if soul_flagged else "warning"
				soul_flagged = true
			_add(out, "Soul Formation goals", ("[x] " if goal["done"] else "[ ] ") + String(goal["text"]), soul_tone)
	if void_goals_active(c, data, flags, clan):
		var void_flagged := false
		for goal in void_goals(c, data, flags, clan):
			var void_tone := "dim"
			if not goal["done"]:
				void_tone = "normal" if void_flagged else "warning"
				void_flagged = true
			_add(out, "Void Refinement goals", ("[x] " if goal["done"] else "[ ] ") + String(goal["text"]), void_tone)
	var fights := fair_fights(c, data, flags, today, region_id, people, favor)
	var goal_lines: PackedStringArray = []
	if c.realm_index >= 2 or first_goals_done(c, data, flags):
		for line in goals(c, data, flags, clan, density):
			_add(out, "Goals", line, "normal")
			goal_lines.append(line)
		var gap := pill_gap_note(c, data, fights)
		if gap != "":
			_add(out, "Goals", gap, "normal")
			goal_lines.append(gap)
	var shown := 0
	for line in hint_lines:
		if duty_line != "" and line == duty_line:
			continue
		if _echoes_goal(line, goal_lines):
			continue
		_add(out, "Next steps", line, "warning" if shown < urgent or (method_line != "" and line == method_line) else "normal")
		shown += 1
	_breakthrough_entries(out, c, data, density)
	if not c.is_rogue():
		_sect_entries(out, c, data, flags, today)
	for id: String in c.deed_days:
		var deed: Dictionary = data.deeds.get(id, {})
		var left := Deeds.cooldown_left(c, deed, today)
		if left > 0:
			_add(out, "Deeds", "%s: again in %d days" % [String(deed.get("name", id)), left], "dim")
	for instance in WorldEvents.active_in(events, region_id):
		var event_id := String(instance["id"])
		var def := WorldEvents.def_of(data, event_id)
		var days_left := maxi(0, int(instance["end_day"]) - today)
		_add(out, "World events", "%s here (%d days left)" % [WorldEvents.event_name(data, event_id), days_left], "normal")
		for kind in ["tournament", "defence"]:
			if def.has(kind):
				var reason := WorldEvents.check_join(data, events, c, event_id, kind, region_id)
				_add(out, "World events", "%s: %s" % [kind.capitalize(), "you can enter" if reason == "" else reason], "normal" if reason == "" else "dim")
	_other_region_event_entries(out, c, data, today, region_id, events)
	_festival_entries(out, data, today, region_id, events)
	_opportunity_entries(out, c, data, flags, today, region_id)
	_fair_fight_entries(out, fights, c, data, region_id)
	for npc in _region_people(c, data, people, favor, region_id, today, "pointers").slice(0, POINTER_JOURNAL_MAX):
		_add(out, "Opportunities", "Ask %s for pointers (%s)" % [npc.name, _region_name(data, region_id)], "normal")
	for line in Letters.request_lines(c, data, people, today):
		_add(out, "Errands", line, "normal")
	_errand_entries(out, data, flags)
	_household_entries(out, c, data, people)
	_rival_entry(out, c, data, flags, people, favor, region_id)
	_karma_entries(out, c, data, people)
	for line in Letters.journal_lines(c, LETTERS_JOURNAL_MAX):
		_add(out, "Letters", line, "normal")
	for order in c.commissions:
		_add(out, "Commissions", Commissions.describe(c, data, order, today), "warning" if Commissions.days_left(order, today) <= 7 else "normal")
	_renown_entry(out, c, data, region_id)
	_milestone_entries(out, c, data, flags, clan)
	return out


## Journal section "Fights you can win" (GUIDE-021): fair fights, or the first-fighting-style hint when
## there are none and no combat technique is known.
static func _fair_fight_entries(out: Array[Dictionary], fights: Array[Dictionary], c: CharacterData, data: GameData, region_id: String) -> void:
	for fight in fights:
		_add(out, "Fights you can win", String(fight["text"]), "normal")
	if fights.is_empty() and not Techniques.knows_kind(c, data, "combat"):
		var hint := first_combat_hint(c, data, region_id)
		var shown := false
		for e in out:
			shown = shown or e["text"] == hint
		if hint != "" and not shown:
			_add(out, "Fights you can win", hint, "dim")


## Up to FAIR_FIGHTS_MAX fights `c` can take now with a win chance >= FAIR_FIGHT_MIN_CHANCE, best
## chance first: [{text, chance, kind}] with kind "mission" | "deed" | "bounty". Rates at most
## FAIR_FIGHT_MAX_RATED candidates (each rating is 40 simulated fights): missions, open chores, then bounties.
## GUIDE-033: with `people` (and `favor`) the living, met rival of this region is rated too (kind "rival").
static func fair_fights(c: CharacterData, data: GameData, flags: Dictionary, today: int, region_id: String, people: Dictionary = {}, favor: Dictionary = {}) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var rated := 0
	for id in Sects.available_missions(c, data, flags):
		if rated >= FAIR_FIGHT_MAX_RATED:
			break
		var mission: Dictionary = data.sect_missions[id]
		var enemy: Dictionary = data.enemies.get(String(mission.get("enemy", "")), {})
		if enemy.is_empty() or Sects.mission_cooldown_left(c, id) > 0 or Sects.check_mission(c, data, id, flags) != "":
			continue
		rated += 1
		_rate_fight(found, c, data, enemy, "mission", "Sect mission: %s" % mission["name"], _item_stones(mission.get("rewards", {})))
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if String(place.get("type", "")) != "deed_giver" or String(place.get("deed_context", "")) == "":
			continue
		var hidden := String(place.get("hidden_by_flag", ""))
		if hidden != "" and flags.get(hidden, false):
			continue
		for deed in Deeds.available(data, String(place["deed_context"]), flags):
			if rated >= FAIR_FIGHT_MAX_RATED:
				break
			var deed_enemy: Dictionary = data.enemies.get(String(deed.get("enemy", "")), {})
			if deed_enemy.is_empty() or Deeds.check(c, data, deed, flags, today) != "":
				continue
			rated += 1
			_rate_fight(found, c, data, deed_enemy, "deed", "%s: %s" % [place.get("display_name", "Chore"), deed["name"]], _item_stones(deed.get("effects", {})))
	var candidates: Array[Dictionary] = []
	var hunt := Bounties.active(c, data, today)
	if not hunt.is_empty():
		candidates.append({"bounty": hunt, "label": "Your hunt"})
	else:
		for b in Bounties.offers(c, data, today, region_id):
			var where := String(b["region"])
			if (where == region_id or Exploration.is_nearby(data, region_id, where)) and Bounties.check_take(c, data, String(b["id"]), today) == "":
				candidates.append({"bounty": b, "label": "Bounty"})
	for cand in candidates:
		if rated >= FAIR_FIGHT_MAX_RATED:
			break
		var b: Dictionary = cand["bounty"]
		var enemy: Dictionary = data.enemies.get(String(b.get("enemy", "")), {})
		if enemy.is_empty():
			continue
		rated += 1
		_rate_fight(found, c, data, enemy, "bounty", "%s: %s in %s" % [cand["label"], enemy.get("name", b["enemy"]), _region_name(data, String(b["region"]))], Bounties.paid_stones(c, data, b))
	if rated < FAIR_FIGHT_MAX_RATED and c.rival != "" and flags.get(Rivals.FIRST_MEETING_FLAG, false):
		var rival: CharacterData = people.get(c.rival)
		if rival != null and rival.alive and region_id != "" and Npcs.region_of(rival, data) == region_id \
				and Rivals.attitude(c, rival, int(favor.get(rival.id, 0)), data) != "bitter" \
				and Mentorship.check_spar(c, rival, int(favor.get(rival.id, 0)), data, today) == "":
			rated += 1
			_rate_fight(found, c, data, Mentorship.spar_enemy(rival, data), "rival", "Challenge %s" % rival.name)
	if found.size() < FAIR_FIGHTS_MAX and region_id != "":
		var explore_rated := 0
		var tags: Array = data.regions.get(region_id, {}).get("encounter_tags", [])
		for enemy_id in Exploration.eligible_fights(c, data, tags, flags, Calendar.season_of(today), region_id):
			if rated >= FAIR_FIGHT_MAX_RATED or explore_rated >= FAIR_FIGHT_EXPLORE_MAX:
				break
			var foe: Dictionary = data.enemies[enemy_id]
			rated += 1
			explore_rated += 1
			_rate_fight(found, c, data, foe, "explore", "Explore here: %s" % foe.get("name", enemy_id))
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["chance"]), float(b["chance"])):
			return float(a["chance"]) > float(b["chance"])
		return String(a["text"]) < String(b["text"]))
	return found.slice(0, FAIR_FIGHTS_MAX)


static func _rate_fight(found: Array[Dictionary], c: CharacterData, data: GameData, enemy: Dictionary, kind: String, label: String, stones: int = 0) -> void:
	var chance := Combat.win_chance(c, data, enemy)
	if chance < FAIR_FIGHT_MIN_CHANCE:
		return
	found.append({"text": "%s (%s, %d in 100)" % [label, Combat.label_for_chance(chance), roundi(chance * 100.0)], "chance": chance, "kind": kind, "enemy": String(enemy.get("name", "")), "stones": stones})


## Spirit stones in a reward/effects dict's `items`, 0 when none.
static func _item_stones(block: Dictionary) -> int:
	return int(block.get("items", {}).get("spirit_stone", 0))


## GUIDE-029: how to close the stone gap to the next realm's pill, "" unless the "Save for" goal is
## showing and the stones fall short. Names the fair fight (`fights`, from fair_fights) that pays most.
static func pill_gap_note(c: CharacterData, data: GameData, fights: Array) -> String:
	var price := next_realm_pill_price(c, data)
	var short := price - c.item_count("spirit_stone")
	if pill_saving_goal(c, data) == "" or short <= 0:
		return ""
	var best: Dictionary = {}
	for f: Dictionary in fights:
		if int(f.get("stones", 0)) > int(best.get("stones", 0)):
			best = f
	if best.is_empty():
		return "%d stones short. Bounties, sect missions and selling herbs and ore pay best." % short
	return "%d stones short. %s pays %d." % [short, String(best["text"]).get_slice(" (", 0), int(best["stones"])]


## " A fairer fight: <text>." for the best fair fight, "" when there is none or it is the foe just lost to.
static func fairer_fight_note(entries: Array, lost_enemy_name: String) -> String:
	if entries.is_empty():
		return ""
	var best: Dictionary = entries[0]
	if String(best.get("enemy", "")) == lost_enemy_name:
		return ""
	return " A fairer fight: %s." % best["text"]


static func _add(out: Array[Dictionary], section: String, text: String, tone: String) -> void:
	out.append({"section": section, "text": text, "tone": tone})


static func _region_name(data: GameData, region_id: String) -> String:
	return String(data.regions.get(region_id, {}).get("name", region_id))


## Joinable events in regions other than the current one (dim when the check fails).
static func _other_region_event_entries(out: Array[Dictionary], c: CharacterData, data: GameData, today: int, region_id: String, events: Array) -> void:
	for instance: Dictionary in events:
		var where := String(instance.get("region", ""))
		if where == region_id:
			continue
		var event_id := String(instance["id"])
		var def := WorldEvents.def_of(data, event_id)
		var days_left := maxi(0, int(instance["end_day"]) - today)
		var label := "%s in %s" % [WorldEvents.event_name(data, event_id), _region_name(data, where)]
		for kind in ["tournament", "defence"]:
			if not def.has(kind):
				continue
			var reason := WorldEvents.check_join(data, events, c, event_id, kind, where)
			_add(out, "World events", "%s: you can enter, %d days left" % [label, days_left] if reason == "" else "%s: %s" % [label, reason], "normal" if reason == "" else "dim")


## Festivals in this region or a neighbouring one.
static func _festival_entries(out: Array[Dictionary], data: GameData, today: int, region_id: String, events: Array) -> void:
	for instance: Dictionary in events:
		var event_id := String(instance["id"])
		var where := String(instance.get("region", ""))
		if WorldEvents.is_festival(data, event_id) and Exploration.is_nearby(data, region_id, where):
			_add(out, "Opportunities", "%s in %s: %d days left" % [WorldEvents.event_name(data, event_id), _region_name(data, where), maxi(0, int(instance["end_day"]) - today)], "normal")
		var activity := WorldEvents.activity_of(data, event_id)
		if where == region_id and not activity.is_empty() and not bool(instance.get("activity_done", false)):
			_add(out, "Opportunities", "Festival: %s at %s (ask a merchant; once this festival)." % [activity["name"], _region_name(data, where)], "normal")


## Children to teach, garden plots, companion beasts and pregnancies.
static func _household_entries(out: Array[Dictionary], c: CharacterData, data: GameData, people: Dictionary) -> void:
	for child_id in c.children:
		var child: CharacterData = people.get(child_id)
		if child == null or Training.check_child(c, child) != "":
			continue
		if Children.can_cultivate_yet(child, data) and Training.current(child) == "" and Training.has_options(c, child, data):
			_add(out, "Household", "%s (age %d) can be trained or taught now." % [child.name, child.age_years()], "normal")
	var ready := 0
	for plot: Dictionary in c.garden:
		if int(plot.get("days_left", 1)) <= 0:
			ready += 1
	if ready > 0:
		_add(out, "Household", "%d spirit garden plot%s ready to harvest." % [ready, "" if ready == 1 else "s"], "normal")
	var food := Beasts.best_food(c, data)
	for beast_id in c.companions:
		var beast := Beasts.beast_name(data, beast_id)
		if Beasts.outgrown_by(c, data, beast_id) >= 1.0:
			_add(out, "Household", "You have outgrown your %s; its help is fading." % beast, "dim")
		if food != "" and Beasts.check_feed(c, data, beast_id, food) == "":
			_add(out, "Household", "Your %s can be fed." % beast, "normal")
	for line in Children.describe_pregnancies(c, people):
		_add(out, "Household", line, "dim")


## "Rival: <name>, <realm> (<relation>)" once the rival has been met (RIVAL-004).
static func _rival_entry(out: Array[Dictionary], c: CharacterData, data: GameData, flags: Dictionary, people: Dictionary, favor: Dictionary = {}, region_id: String = "") -> void:
	if c.rival == "" or not flags.get(Rivals.FIRST_MEETING_FLAG, false):
		return
	var rival: CharacterData = people.get(c.rival)
	if rival == null:
		return
	if not rival.alive:
		var fallen_record := Rivals.bout_record_text(flags)
		_add(out, "Household", "Rival: %s (fallen%s)" % [rival.name, "; " + fallen_record if fallen_record != "" else ""], "dim")
		return
	var tone := "dim"
	if rival.realm_index > c.realm_index or (rival.realm_index == c.realm_index and rival.stage > c.stage):
		tone = "warning"
	elif rival.realm_index < c.realm_index or rival.stage < c.stage:
		tone = "normal"
	var feeling := Rivals.attitude_text(Rivals.attitude(c, rival, int(favor.get(rival.id, 0)), data))
	var relation := Rivals.relation_text(c, rival)
	if feeling != "":
		relation += "; " + feeling
	var record := Rivals.bout_record_text(flags)
	if record != "":
		relation += "; " + record
	# GUIDE-035: say where they are when it is not here.
	var where := Rivals.where_text(rival, data, region_id)
	_add(out, "Household", "Rival: %s, %s%s (%s)" % [rival.name, Cultivation.realm_label(rival, data), where, relation], tone)
	# RIVAL-018: say what it takes to stand against a rival a realm ahead.
	if Rivals.relation(c, rival) == "stronger":
		var realm_name := data.realms[rival.realm_index].name
		if Rivals.attitude(c, rival, int(favor.get(rival.id, 0)), data) == "bitter":
			_add(out, "Household", "Reach %s before %s comes looking for you." % [realm_name, rival.name], "dim")
		else:
			_add(out, "Household", "Reach %s to stand a chance against %s." % [realm_name, rival.name], "dim")


const KARMA_JOURNAL_MAX := 3


## GRAT-001: who owes you and who holds a grudge (section "Debts and grudges").
## The named rival's grudge is left to the rival entry.
static func _karma_entries(out: Array[Dictionary], c: CharacterData, data: GameData, people: Dictionary) -> void:
	if people.is_empty():
		return
	var ally_min := int(data.karma.get("gratitude", {}).get("ally_strike", {}).get("min_gratitude", 60))
	var repay_min := int(data.karma.get("gratitude", {}).get("repay", {}).get("min_gratitude", 40))
	var hunt_min := int(data.karma.get("hunt", {}).get("min_grudge", 40))
	for npc in _ledger_top(c.gratitude, c, people, ""):
		var value := Karma.gratitude(c, npc.id)
		var text := "%s owes you a debt of gratitude" % npc.name
		if value >= ally_min:
			var where := Npcs.region_of(npc, data)
			text += " and would join a fight at your side" + (" in " + Exploration.region_name(data, where) if where != "" else "")
		elif value >= repay_min:
			text += " and may send you gifts"
		_add(out, "Debts and grudges", text, "normal")
	for npc in _ledger_top(c.grudges, c, people, c.rival):
		var value := Karma.grudge(c, npc.id)
		var text := "%s holds %s against you" % [npc.name, Karma.grudge_word(value, data)]
		if value >= hunt_min:
			text += ". They may ambush you on the road; amends cost %d stones" % Karma.amends_cost(c, npc.id, data)
			var where := Npcs.region_of(npc, data)
			if where != "":
				text += " (in %s)" % Exploration.region_name(data, where)
			_add(out, "Debts and grudges", text, "warning")
		else:
			_add(out, "Debts and grudges", text, "dim")


## Up to KARMA_JOURNAL_MAX living NPCs with a positive `ledger` value, highest first (ties by name).
static func _ledger_top(ledger: Dictionary, c: CharacterData, people: Dictionary, skip_id: String) -> Array[CharacterData]:
	var found: Array[CharacterData] = []
	for id: String in ledger:
		var npc: CharacterData = people.get(id)
		if npc == null or not npc.alive or id == skip_id or int(ledger[id]) <= 0:
			continue
		found.append(npc)
	found.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		var va := int(ledger[a.id])
		var vb := int(ledger[b.id])
		return a.name < b.name if va == vb else va > vb)
	return found.slice(0, KARMA_JOURNAL_MAX)


## "Your sect's elder lectures this month": only while the lecture can be attended.
static func _lecture_hint(c: CharacterData, data: GameData, today: int) -> String:
	if Sects.check_lecture(c, data, today) != "":
		return ""
	return "Your sect's elder lectures this month; attend at the sect hall."


const SEASONAL_JOURNAL_MAX := 2


static func _opportunity_entries(out: Array[Dictionary], c: CharacterData, data: GameData, flags: Dictionary, today: int, region_id: String = "") -> void:
	var ready := craftable_now(c, data)
	if not ready.is_empty():
		var more := "" if ready.size() == 1 else " (and %d more)" % (ready.size() - 1)
		var place := workshop_place(data, region_id)
		_add(out, "Opportunities", "You have everything to make %s%s: craft it at %s." % [data.recipes[ready[0]].get("name", ready[0]), more, place if place != "" else "a workshop"], "normal")
	if region_id != "":
		var rumors := discovery_rumors(c, data, flags, region_id)
		if not rumors.is_empty():
			_add(out, "Opportunities", "Rumor: %s" % rumors[0], "normal")
	if region_id != "":
		var roads := unexplored_routes(c, data, region_id)
		for i in mini(roads.size(), UNEXPLORED_JOURNAL_MAX):
			_add(out, "Opportunities", "Unexplored: %s (%d days' road)" % [roads[i]["name"], roads[i]["days"]], "normal")
	if region_id != "":
		var progress := Exploration.region_progress(c, data, region_id, flags)
		if int(progress["met"]) < int(progress["total"]):
			_add(out, "Opportunities", "%s: you have seen %d of %d happenings here." % [_region_name(data, region_id), progress["met"], progress["total"]], "dim")
	if region_id != "":
		var fame := Renown.title(c, data, region_id)
		if fame != "":
			var off := roundi((1.0 - Renown.buy_multiplier(c, data, region_id)) * 100.0)
			_add(out, "Opportunities", "Your name in %s: %s (merchants give you %d%% off)." % [_region_name(data, region_id), fame, off], "normal")
		var deeper := Exploration.next_deep_path(c, data, region_id)
		if deeper >= 0:
			_add(out, "Opportunities", "%s: explored %d days. Something deeper waits after %d." % [_region_name(data, region_id), Exploration.familiarity(c, region_id), deeper], "normal")
	if today >= 0:
		var hunt := Bounties.active(c, data, today)
		if not hunt.is_empty():
			var prey: String = data.enemies.get(String(hunt["enemy"]), {}).get("name", hunt["enemy"])
			_add(out, "Opportunities", "Bounty: %s in %s (%d days left, %d stones)." % [prey, _region_name(data, String(hunt["region"])), int(hunt["until_day"]) - today, int(hunt["reward_stones"])], "normal")
		var shown_herbs := 0
		for h in Exploration.seasonal_highlights(data, Calendar.season_of(today)):
			if shown_herbs >= SEASONAL_JOURNAL_MAX:
				break
			if Exploration.visited(c, h["region"]):
				_add(out, "Opportunities", "In season: %s at %s (%s)" % [h["item_name"], h["place"], h["region_name"]], "normal")
				shown_herbs += 1
	if Sects.check_lecture(c, data, today) == "":
		var sect: SectDef = data.sects[c.sect["id"]]
		_add(out, "Opportunities", "Attend %s at the %s hall (once a month)" % [Sects.lecture_def(c, data).get("name", "the lecture"), sect.name], "normal")
	var realm_ids: Array = data.secret_realms.keys()
	realm_ids.sort()
	for realm_id: String in realm_ids:
		var def: Dictionary = data.secret_realms[realm_id]
		if not SecretRealms.admits(c, data, def) or SecretRealms.has_inherited(c, realm_id):
			continue
		var label := "%s (%s)" % [String(def.get("name", realm_id)), _region_name(data, String(def.get("region", "")))]
		if String(def.get("entry_item", "")) != "" and SecretRealms.entry_item_needed(c, data, def, today) != "":
			label += " (needs %s)" % SecretRealms.entry_item_needed(c, data, def, today)
		if SecretRealms.is_open(def, today):
			var left := SecretRealms.days_until_close(def, today)
			_add(out, "Opportunities", "%s is open: %d days left, %d/%d floors cleared" % [label, left, SecretRealms.floors_cleared(c, def, today), (def.get("floors", []) as Array).size()], "warning" if left <= 7 else "normal")
		elif SecretRealms.days_until_open(def, today) <= 60:
			_add(out, "Opportunities", "%s opens in %d days" % [label, SecretRealms.days_until_open(def, today)], "dim")
	var legacy_ids: Array = data.inheritances.keys()
	legacy_ids.sort()
	for id: String in legacy_ids:
		var def: Dictionary = data.inheritances[id]
		if Inheritances.is_claimed(id, flags) or Inheritances.is_lost(def, today, flags) or today < Inheritances.appears_day(def):
			continue
		var stage_count := (def.get("stages", []) as Array).size()
		var cleared := Inheritances.stages_cleared(c, id)
		if cleared >= stage_count:
			continue
		var text := "%s (%s): %d/%d trials passed (%s)" % [String(def.get("name", id)), _region_name(data, String(def.get("region", ""))), cleared, stage_count, Inheritances.time_left_text(def, today)]
		var reason := Inheritances.check_attempt(c, data, id, String(def.get("region", "")), today, flags)
		var tone := "dim"
		if reason == "":
			tone = "warning" if Inheritances.deadline_day(def) - today < Calendar.DAYS_PER_YEAR else "normal"
		_add(out, "Opportunities", text if reason == "" else "%s. %s" % [text, reason], tone)


static func _errand_entries(out: Array[Dictionary], data: GameData, flags: Dictionary) -> void:
	for errand: Dictionary in data.errands:
		if bool(flags.get(String(errand["asked_flag"]), false)) and not bool(flags.get(String(errand["done_flag"]), false)):
			_add(out, "Errands", String(errand["text"]), "normal")


## Expected tribulation damage at or above this share of hp + shield reads "close" (FOUND-007).
const CLOSE_CALL_SHARE := 0.9


## What the next breakthrough's Heavenly Tribulation would do to you (FOUND-005):
## {text, tone}, or {} when you are not on the last stage or the next realm has none.
static func tribulation_note(c: CharacterData, data: GameData) -> Dictionary:
	if c.realm_index + 1 >= data.realms.size() or not Tribulation.has_tribulation(data, c.realm_index + 1):
		return {}
	if c.stage + 1 < data.realms[c.realm_index].stage_count():
		return {}
	var p := Tribulation.preview(c, data, c.realm_index + 1)
	var shield := int(p["shield"])
	var text := "Heavenly Tribulation ahead: %d waves%s, likely %d damage against your %d hp%s." % [
		int(p["waves"]),
		" and a heart demon" if p["heart_demon"] else "",
		int(p["expected_damage"]),
		int(p["max_hp"]),
		" and a %d-point shield" % shield if shield > 0 else "",
	]
	var tone := "normal"
	if int(p["expected_damage"]) >= int(p["max_hp"]) + shield:
		text += " You would not survive it yet: ready a shield talisman, train a defense technique or wear better armor."
		tone = "warning"
	elif float(p["expected_damage"]) >= CLOSE_CALL_SHARE * float(int(p["max_hp"]) + shield):
		text += " It will be close: a shield talisman or better armor would make it safer."
		tone = "warning"
	return {"text": text, "tone": tone}


static func _breakthrough_entries(out: Array[Dictionary], c: CharacterData, data: GameData, density: float) -> void:
	var realm: RealmDef = data.realms[c.realm_index]
	var next_label := ""
	if c.stage + 1 < realm.stage_count():
		next_label = realm.stage_label(c.stage + 1)
	elif c.realm_index + 1 < data.realms.size():
		next_label = data.realms[c.realm_index + 1].name
	if next_label != "":
		_add(out, "Breakthrough", "Qi: %s / %s for %s" % [_commas(int(c.qi)), _commas(int(Cultivation.qi_required(c, data))), next_label], "normal")
	var trib := tribulation_note(c, data)
	if not trib.is_empty():
		_add(out, "Breakthrough", String(trib["text"]), String(trib["tone"]))
	if Cultivation.can_attempt_breakthrough(c, data):
		_add(out, "Breakthrough", "You are at a bottleneck: break through to go further.", "warning")
		var odds := chance_text(c, data)
		if odds != "":
			_add(out, "Breakthrough", "Odds now: " + odds, "normal")
		var raise := pill_source_hint(c, data)
		if raise != "":
			_add(out, "Breakthrough", "To raise them: " + raise, "normal")
	elif Cultivation.is_at_bottleneck(c, data):
		_add(out, "Breakthrough", "You stand at the peak of the highest realm known.", "normal")
	else:
		var days := Cultivation.days_to_bottleneck(c, data, density)
		if days > 0:
			_add(out, "Breakthrough", "About %s of meditation here." % Calendar.format_rough(days), "normal")
		if days >= 1 and days <= 30:
			var prepare := pill_source_hint(c, data)
			if prepare != "":
				_add(out, "Breakthrough", "Prepare: " + prepare, "dim")
	var pills: PackedStringArray = []
	for item_id in c.inventory:
		if _usable_breakthrough_item(c, data, item_id):
			pills.append("%s (held %d)" % [String(data.items[item_id]["name"]), c.item_count(item_id)])
	pills.sort()
	if not pills.is_empty():
		_add(out, "Breakthrough", "Pills that help: %s" % ", ".join(pills), "normal")
	if c.breakthrough_bonus > 0.0:
		_add(out, "Breakthrough", "Pill bonus active: +%d%%" % roundi(c.breakthrough_bonus * 100), "normal")


static func _sect_entries(out: Array[Dictionary], c: CharacterData, data: GameData, flags: Dictionary = {}, today: int = 0) -> void:
	var member := Sects.member_text(c, data)
	if member != "":
		_add(out, "Sect", "%s: %d contribution." % [member.substr(0, 1).to_upper() + member.substr(1), int(c.sect.get("contribution", 0))], "normal")
	var duty := Sects.monthly_duty(c, data)
	if duty > 0:
		var days_left := Calendar.DAYS_PER_MONTH - c.age_days % Calendar.DAYS_PER_MONTH
		_add(out, "Sect", "Monthly duty: %d / %d contribution, %d days left this month." % [Sects.duty_progress(c), duty, days_left], "warning" if Sects.duty_reminder(c, data) != "" and days_left <= 7 else "normal")
	var call_left := SectFactions.call_days_left(flags, String(c.sect.get("id", "")), today)
	if call_left >= 0:
		_add(out, "Sect", "The sect's call: %d days left" % call_left, "warning" if call_left <= 7 else "normal")
	for id in Sects.available_missions(c, data, flags):
		var name := String(data.sect_missions[id].get("name", id))
		var reason := Sects.check_mission(c, data, id, flags)
		if reason == "":
			var danger := Sects.mission_danger_text(c, data, id)
			var tail := "%d days" % int(data.sect_missions[id].get("days", 1))
			if danger != "":
				tail += ", danger: %s" % danger
			_add(out, "Sect", "Ready: %s (%s)" % [name, tail], "normal")
		elif Sects.mission_cooldown_left(c, id) > 0 and reason.begins_with("This mission is not offered again"):
			_add(out, "Sect", "%s: again in %d days" % [name, Sects.mission_cooldown_left(c, id)], "dim")


## Journal line (RENOWN-006): your renown in the current region and how far the next title is.
static func _renown_entry(out: Array[Dictionary], c: CharacterData, data: GameData, region_id: String) -> void:
	var tiers: Array = data.renown.get("tiers", [])
	if tiers.is_empty() or region_id == "":
		return
	var amount := Renown.value(c, region_id)
	var idx := Renown.tier_index(data, amount)
	var where := _region_name(data, region_id)
	if idx + 1 >= tiers.size():
		_add(out, "Milestones", "Renown in %s: %s, the highest name there is." % [where, Renown.title(c, data, region_id)], "dim")
		return
	var next: Dictionary = tiers[idx + 1]
	var current := Renown.title(c, data, region_id)
	var line := "Renown in %s: %d (%s). %d more for %s." % [where, amount, "unknown" if current == "" else current, int(next["min"]) - amount, String(next["title"])]
	var buy := float(next.get("buy_mult", 1.0))
	if buy < 1.0:
		line += " As %s, merchants there take %d percent off." % [String(next["title"]), roundi((1.0 - buy) * 100)]
	_add(out, "Milestones", line, "dim")


static func _milestone_entries(out: Array[Dictionary], c: CharacterData, data: GameData, flags: Dictionary = {}, clan: ClanData = null) -> void:
	if data.milestones.is_empty():
		return
	var earned := 0
	var pending: Array[Dictionary] = []
	for def: Dictionary in data.milestones:
		if c.milestones.has(String(def["id"])):
			earned += 1
		else:
			pending.append(def)
	_add(out, "Milestones", "Milestones: %d of %d" % [earned, data.milestones.size()], "normal")
	for def in pending.slice(0, 3):
		var count := Milestones.progress_text(c, data, flags, clan, String(def["id"]))
		_add(out, "Milestones", "%s%s: %s" % [String(def.get("name", def["id"])), "" if count == "" else " (%s)" % count, String(def.get("description", ""))], "dim")


## One line describing an Exploration.outlook(): "Mostly quiet (60%). Fights 25%: Mist Wolf (Even). Fortunes 10%."
static func outlook_text(outlook: Dictionary) -> String:
	var parts := PackedStringArray()
	var quiet := roundi(float(outlook.get("other", 0.0)) * 100)
	if quiet > 0:
		parts.append("%s (%d%%)." % ["Mostly quiet" if quiet >= 50 else "Often quiet", quiet])
	var fight := roundi(float(outlook.get("fight", 0.0)) * 100)
	if fight > 0:
		var foes := PackedStringArray()
		var evade := false
		for foe: Dictionary in outlook.get("foes", []):
			foes.append("%s (%s)" % [foe["name"], foe["danger"]])
			if foe["danger"] == "Deadly" and bool(foe.get("lethal", false)):
				evade = true
		var line := "Fights %d%%" % fight
		if not foes.is_empty():
			line += ": " + ", ".join(foes)
		if evade:
			line += " - you would sense the deadliest and slip away"
		parts.append(line + ".")
	for entry: Array in [["choice", "Crossroads"], ["fortune", "Fortunes"], ["misfortune", "Mishaps"]]:
		var pct := roundi(float(outlook.get(entry[0], 0.0)) * 100)
		if pct > 0:
			parts.append("%s %d%%." % [entry[1], pct])
	return " ".join(parts)


## One line for a meditation menu entry: expected qi, the stage reached, or the bottleneck.
static func meditation_preview(c: CharacterData, data: GameData, days: int, density: float) -> String:
	if SpiritualRoots.cultivation_multiplier(c.spiritual_roots, data) <= 0.0:
		return "Without a spiritual root, qi slips through you."
	var p := Cultivation.preview(c, data, days, density)
	if int(p["days"]) <= 0:
		return "You are at a bottleneck: meditation will not help. Attempt a breakthrough."
	if bool(p["stops_at_bottleneck"]) and int(p["days"]) < days:
		return "Your qi reaches the bottleneck after %s; then attempt a breakthrough." % Calendar.format_duration(int(p["days"]))
	var text := "About +%s qi (x%s qi here)" % [_commas(int(p["qi_gain"])), String.num(density, 1)]
	if int(p["stages_gained"]) > 0:
		text += "; you would reach %s" % p["realm_label"]
	return text + "."


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## GUIDE-015: rumor texts of undiscovered regions that can be reached now (the
## current region, or one with a travel route that passes check_travel), the
## current region first, then data order.
static func discovery_rumors(c: CharacterData, data: GameData, flags: Dictionary, region_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Array = data.regions.keys()
	ids.sort_custom(func(a, b): return a == region_id and b != region_id)
	for id in ids:
		var region: Dictionary = data.regions[id]
		if not region.has("discovery_rumor") or flags.get("discovered_" + String(id), false):
			continue
		if id != region_id and not Exploration.check_travel(c, data, region_id, id).get("ok", false):
			continue
		out.append(String(region["discovery_rumor"]))
	return out


## Safety line for a Creation Artifact that is nearly empty ("" when it is not).
static func artifact_lives_hint(c: CharacterData, data: GameData) -> String:
	if c.artifact_lives < 0 or c.artifact_lives > LOW_ARTIFACT_LIVES:
		return ""
	var cost: int = CreationArtifact.recharge_cost(c, data)
	var text: String
	if c.artifact_lives == 0:
		text = "Your Creation Artifact is empty: your next death is final. Recharge it for %d spirit stones." % cost
	else:
		text = "Your Creation Artifact holds %d %s. Recharge it for %d spirit stones before you take risks." % [c.artifact_lives, "life" if c.artifact_lives == 1 else "lives", cost]
	var held: int = c.item_count("spirit_stone")
	if held < cost:
		text += " You hold %d." % held
	return text
