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
	out.append(_cultivation_hint(c, data, density))
	var method := _method_hint(c, data)
	if method != "":
		out.append(method)
	var better_qi := _better_qi_hint(c, data, region_id)
	if better_qi != "":
		out.append(better_qi)
	if c.artifact_lives >= 0 and c.artifact_lives <= LOW_ARTIFACT_LIVES:
		out.append("Your Creation Artifact holds %d %s. Recharge it for %d spirit stones before you take risks." % [c.artifact_lives, "life" if c.artifact_lives == 1 else "lives", CreationArtifact.recharge_cost(c, data)])
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
		out.append("Work at a workshop to learn a profession and earn spirit stones.")
	if c.techniques.is_empty() and c.realm_index > NEWCOMER_MAX_REALM:
		out.append(TECHNIQUE_HINT)
	for hint in [_dao_hint(c, data), _abode_hint(c, data), _family_hint(c, data, people)]:
		if hint != "":
			out.append(hint)
	if out.size() > limit:
		out.resize(limit)
	return out


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


## Most "Ask <Name> for pointers" journal lines (GUIDE-012).
const POINTER_JOURNAL_MAX := 3
## Game days that must pass (GameClock) before "try something new" is suggested (GUIDE-007).
const UNTRIED_MIN_DAYS := 180
## Game days before an unvisited neighbouring region is suggested (GUIDE-014).
const UNEXPLORED_MIN_DAYS := 10
## Most "Unexplored:" journal lines (GUIDE-014).
const UNEXPLORED_JOURNAL_MAX := 2


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
static func best_qi_in_region(c: CharacterData, data: GameData, region_id: String) -> Dictionary:
	var region: Dictionary = data.regions.get(region_id, {})
	var base := Exploration.qi_density(data, region_id)
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
static func best_qi_reachable(c: CharacterData, data: GameData, region_id: String) -> Dictionary:
	var seen := {region_id: true}
	var queue: Array[String] = [region_id]
	var best := {}
	while not queue.is_empty():
		var here: String = queue.pop_front()
		var candidate := best_qi_in_region(c, data, here)
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
static func _better_qi_hint(c: CharacterData, data: GameData, region_id: String) -> String:
	if region_id == "" or not data.regions.has(region_id):
		return ""
	if Cultivation.is_at_bottleneck(c, data) or Cultivation.can_attempt_breakthrough(c, data):
		return ""
	var here := float(best_qi_in_region(c, data, region_id)["density"])
	var best := best_qi_reachable(c, data, region_id)
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


## Where to get a pill for the NEXT realm that the player is not holding, e.g.
## "A Core Forming Pill (+25%): Sold at Pill Pavilion (Fallen Star Market)." "" when
## one is held or already taken, or none has a known source.
static func pill_source_hint(c: CharacterData, data: GameData) -> String:
	if Cultivation.is_final_realm(c, data) or c.breakthrough_pill != "" or not breakthrough_items(c, data).is_empty():
		return ""
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
	if best.is_empty():
		return ""
	var source := Items.sources(data, String(best["id"]))[0]
	var article := Text.a(String(best["name"]))  # capitalize() turns "Nine-Turn" into "Nine Turn"
	return "%s (+%d%%): %s." % [article.left(1).to_upper() + article.substr(1), roundi(float(best["effects"]["breakthrough_bonus"]) * 100), source]


## Names of held items whose effects add a breakthrough bonus and can be used
## now (a realm-tied pill only before its own breakthrough, one per attempt).
static func breakthrough_items(c: CharacterData, data: GameData) -> PackedStringArray:
	var names: PackedStringArray = []
	for item_id in c.inventory:
		if _usable_breakthrough_item(c, data, item_id):
			names.append(String(data.items[item_id]["name"]))
	names.sort()
	return names


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
	var ready := Sects.available_missions(c, data, flags).filter(func(id: String) -> bool: return Sects.check_mission(c, data, id, flags) == "").size()
	if ready == 0:
		return ""
	return "%d sect %s ready on the mission board at a sect hall." % [ready, "mission is" if ready == 1 else "missions are"]


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


## The newcomer ladder: {text, done} in order.
static func first_goals(c: CharacterData, data: GameData, flags: Dictionary) -> Array[Dictionary]:
	var stage_3 := c.realm_index > 1 or (c.realm_index == 1 and c.stage >= 2)
	var rows: Array = [
		["Talk to Elder Mo", bool(flags.get(ELDER_MO_FLAG, false))],
		["Learn your first technique", not c.techniques.is_empty()],
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
			out.append("Reach %s: about %d days of meditation, then a breakthrough (%s)." % [next_name, days, odds])
		else:
			out.append("Reach %s: gather qi, then attempt a breakthrough (%s)." % [next_name, odds])
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
	if c.realm_index >= 2 or first_goals_done(c, data, flags):
		for line in goals(c, data, flags, clan, density):
			_add(out, "Goals", line, "normal")
	var shown := 0
	for line in hint_lines:
		if duty_line != "" and line == duty_line:
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
	for npc in _region_people(c, data, people, favor, region_id, today, "pointers").slice(0, POINTER_JOURNAL_MAX):
		_add(out, "Opportunities", "Ask %s for pointers (%s)" % [npc.name, _region_name(data, region_id)], "normal")
	_errand_entries(out, data, flags)
	_household_entries(out, c, data, people)
	for order in c.commissions:
		_add(out, "Commissions", Commissions.describe(c, data, order, today), "warning" if Commissions.days_left(order, today) <= 7 else "normal")
	_milestone_entries(out, c, data, flags, clan)
	return out


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


## "Your sect's elder lectures this month": only while the lecture can be attended.
static func _lecture_hint(c: CharacterData, data: GameData, today: int) -> String:
	if Sects.check_lecture(c, data, today) != "":
		return ""
	return "Your sect's elder lectures this month; attend at the sect hall."


const SEASONAL_JOURNAL_MAX := 2


static func _opportunity_entries(out: Array[Dictionary], c: CharacterData, data: GameData, flags: Dictionary, today: int, region_id: String = "") -> void:
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
		var text := "%s (%s): %d/%d trials passed" % [String(def.get("name", id)), _region_name(data, String(def.get("region", ""))), cleared, stage_count]
		var reason := Inheritances.check_attempt(c, data, id, String(def.get("region", "")), today, flags)
		_add(out, "Opportunities", text if reason == "" else "%s. %s" % [text, reason], "normal" if reason == "" else "dim")


static func _errand_entries(out: Array[Dictionary], data: GameData, flags: Dictionary) -> void:
	for errand: Dictionary in data.errands:
		if bool(flags.get(String(errand["asked_flag"]), false)) and not bool(flags.get(String(errand["done_flag"]), false)):
			_add(out, "Errands", String(errand["text"]), "normal")


static func _breakthrough_entries(out: Array[Dictionary], c: CharacterData, data: GameData, density: float) -> void:
	var realm: RealmDef = data.realms[c.realm_index]
	var next_label := ""
	if c.stage + 1 < realm.stage_count():
		next_label = realm.stage_label(c.stage + 1)
	elif c.realm_index + 1 < data.realms.size():
		next_label = data.realms[c.realm_index + 1].name
	if next_label != "":
		_add(out, "Breakthrough", "Qi: %s / %s for %s" % [_commas(int(c.qi)), _commas(int(Cultivation.qi_required(c, data))), next_label], "normal")
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
			_add(out, "Breakthrough", "About %d days of meditation here." % days, "normal")
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
