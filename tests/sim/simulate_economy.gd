extends SceneTree
## Economy sim (QA-006): runs N lives per profession with a cultivator who
## works their profession one month in every `work_every` months and
## cultivates the rest. Spirit stones come from Professions.work; they are
## spent on artifact lives (CreationArtifact.recharge after violent deaths,
## rolled at `deaths_per_century`) and on the breakthrough pill for the next
## major realm (BREAKTHROUGH_PILLS) when the cultivator reaches a bottleneck.
## Reports per profession: realm reached, stones earned, pills bought vs
## bottlenecks faced without one, lives bought and the dearest recharge, and
## lives that ended for good (artifact empty) or of old age.
## QA-006b: with sources "all" (the default) income months rotate between the
## profession (work, or crafting for resale at Items.sell_price per G-005e if
## that pays more), gathering herbs/ores to sell (best reachable gather place)
## and, for a sect disciple (`sect`, joined once accepted; "none" stays rogue),
## fight-free sect missions (required items bought only while they cost at most
## MAX_STONES_PER_CONTRIBUTION). Disciples draw the stipend, pass rank trials
## as soon as eligible (optimistic) and buy breakthrough pills with
## contribution when the sect shop has them. Spending: surplus stones beyond
## the next pill buy gear once per major realm, and injuries with over a month
## left are healed at a clinic when that leaves the next pill's price. Sources
## "work" reproduces the QA-006 run.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_economy.gd -- [lives] [work_every] [deaths_per_century] [seed] [all|work] [sect_id|none]

const START_AGE_YEARS := 16
const STEP_DAYS := 30
## Next realm id -> the pill a sensible cultivator buys before breaking into it.
const BREAKTHROUGH_PILLS := {
	"foundation_establishment": "foundation_establishment_pill",
	"core_formation": "core_forming_pill",
	"nascent_soul": "nascent_soul_pill",
	"soul_formation": "soul_formation_pill",
}
## Heal an injury at a clinic when more than this many days of it are left.
const CLINIC_MIN_DAYS := 30
## Sect missions whose items must be bought are skipped above this price per
## point of contribution (a Core Forming Pill is ~3300 contribution or 3000 stones).
const MAX_STONES_PER_CONTRIBUTION := 1.0
const INCOME_KINDS: Array[String] = ["work", "craft", "gather", "sect"]

var sources := "all"
var sect_id := "none"


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lives := int(args[0]) if args.size() > 0 else 50
	var work_every := int(args[1]) if args.size() > 1 else 4
	var deaths_per_century := float(args[2]) if args.size() > 2 else 3.0
	var seed_value := int(args[3]) if args.size() > 3 else 1
	sources = args[4] if args.size() > 4 else "all"
	sect_id = args[5] if args.size() > 5 else "myriad_treasure_pavilion"
	var data := GameData.load_from_dir()
	if sources == "work":
		sect_id = "none"
	print("Economy sim: %d lives per profession, income 1 month in %d, %.1f violent deaths per century, seed %d, sources %s, sect %s" % [lives, work_every, deaths_per_century, seed_value, sources, sect_id])
	for pill_realm: String in BREAKTHROUGH_PILLS:
		var pill: String = BREAKTHROUGH_PILLS[pill_realm]
		print("  %s costs %d spirit stones" % [data.items[pill]["name"], int(data.items[pill]["price"])])
	for prof_id: String in data.professions:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var totals := {}
		for n in lives:
			_add(totals, _simulate_life(data, prof_id, work_every, deaths_per_century, rng))
		_report(data, prof_id, totals, lives)
	quit()


## One life; returns counters (see _report).
func _simulate_life(data: GameData, prof_id: String, work_every: int, deaths_per_century: float, rng: RandomNumberGenerator) -> Dictionary:
	var c := CharacterFactory.create("Sim", data, rng)
	c.age_days = START_AGE_YEARS * Calendar.DAYS_PER_YEAR
	CreationArtifact.ensure(c, data)
	var stats := {"earned": 0, "pills": 0, "no_pill": 0, "recharges": 0, "max_recharge": 0, "final_deaths": 0, "final_age": 0, "old_age": 0, "realm": 0, "rank": 0, "stones_left": 0, "gear": 0, "clinic": 0, "sect_rank": 0, "contribution": 0, "contribution_pills": 0, "pill_stones_at_peak": 0}
	for kind in INCOME_KINDS:
		stats["months_" + kind] = 0
		stats["stones_" + kind] = 0
	for pill_realm: String in BREAKTHROUGH_PILLS:
		stats["faced_" + pill_realm] = 0
		stats["first_pill_" + pill_realm] = 0
	var death_chance := deaths_per_century / 100.0 / (Calendar.DAYS_PER_YEAR / float(STEP_DAYS))
	var month := 0
	var income_months := 0
	var geared_realm := -1
	while true:
		if Cultivation.years_left(c, data) <= 0:
			stats["old_age"] = 1
			break
		if sect_id != "none" and c.is_rogue() and Sects.check_join(c, data, sect_id)["ok"]:
			Sects.join(c, data, sect_id)
		if Cultivation.can_attempt_breakthrough(c, data):
			_note_peak_savings(c, data, stats)
			_buy_pill(c, data, stats)
			Cultivation.attempt_breakthrough(c, data, rng)
			_heal(c, data, stats)
		elif c.realm_index >= data.realms.size() - 1 and Cultivation.is_at_bottleneck(c, data):
			break
		elif month % work_every == 0:
			var before := c.item_count("spirit_stone")
			var kind := _earn(c, data, prof_id, income_months, rng)
			var gained := c.item_count("spirit_stone") - before
			stats["months_" + kind] += 1
			stats["stones_" + kind] += gained
			stats["earned"] += maxi(0, gained)
			income_months += 1
		else:
			Cultivation.cultivate(c, data, STEP_DAYS)
		month += 1
		c.age_days += STEP_DAYS
		Injuries.pass_days(c, STEP_DAYS)
		if not c.is_rogue():
			var before_stipend := c.item_count("spirit_stone")
			Sects.month_end(c, data)
			stats["stones_sect"] += c.item_count("spirit_stone") - before_stipend
			while Sects.check_promotion(c, data) == "":
				Sects.pass_trial(c, data)  # optimistic: every trial is won
		if c.realm_index > geared_realm:
			geared_realm = c.realm_index
			_buy_gear(c, data, stats)
		if rng.randf() < death_chance:
			if not CreationArtifact.can_respawn(c):
				stats["final_deaths"] = 1
				stats["final_age"] = c.age_years()
				break
			CreationArtifact.respawn(c, data)
		_recharge(c, data, stats)
	stats["realm"] = c.realm_index
	stats["rank"] = Professions.rank_of(c, prof_id)
	stats["stones_left"] = c.item_count("spirit_stone")
	if not c.is_rogue():
		stats["sect_rank"] = int(c.sect["rank"])
		stats["contribution"] = int(c.sect["contribution"])
	return stats


## Buys and swallows the pill for the next realm if there is one and it is
## affordable; otherwise counts a bottleneck faced without it.
func _buy_pill(c: CharacterData, data: GameData, stats: Dictionary) -> void:
	var next_id: String = data.realms[c.realm_index + 1].id
	var pill: String = BREAKTHROUGH_PILLS.get(next_id, "")
	if pill == "" or c.breakthrough_bonus > 0.0:
		return
	var first: bool = stats["faced_" + next_id] == 0
	if first:
		stats["faced_" + next_id] = 1
	var via_sect: bool = Sects.check_purchase(c, data, pill) == "" and Sects.buy_with_contribution(c, data, pill)["ok"]
	if via_sect:
		stats["contribution_pills"] += 1
	if (via_sect or Items.buy(c, data, pill)["ok"]) and Items.use(c, data, pill, {})["ok"]:
		stats["pills"] += 1
		if first:
			stats["first_pill_" + next_id] = 1
	else:
		stats["no_pill"] += 1


## An empty artifact is refilled first; spare stones (beyond the next pill's
## price) top it back up to the starting lives.
func _recharge(c: CharacterData, data: GameData, stats: Dictionary) -> void:
	var starting := int(data.artifact.get("starting_lives", 3))
	while c.artifact_lives < starting:
		var cost := CreationArtifact.recharge_cost(c, data)
		var reserve := 0 if c.artifact_lives == 0 else _next_pill_price(c, data)
		if c.item_count("spirit_stone") < cost + reserve or not CreationArtifact.recharge(c, data)["ok"]:
			return
		stats["recharges"] += 1
		stats["max_recharge"] = maxi(stats["max_recharge"], cost)


## Before the first attempt at Core Formation, notes whether the stones saved
## alone would buy the Core Forming Pill (QA-006b's question).
func _note_peak_savings(c: CharacterData, data: GameData, stats: Dictionary) -> void:
	var next_id: String = data.realms[c.realm_index + 1].id
	if next_id == "core_formation" and stats["faced_core_formation"] == 0 and c.item_count("spirit_stone") >= int(data.items["core_forming_pill"]["price"]):
		stats["pill_stones_at_peak"] = 1


## One income month, rotating profession -> gathering -> sect missions (the
## last only for a disciple). Returns the kind done.
func _earn(c: CharacterData, data: GameData, prof_id: String, income_months: int, rng: RandomNumberGenerator) -> String:
	var turn := income_months % (2 if c.is_rogue() else 3)
	if sources == "all" and turn == 1:
		var gather := _best_gather(c, data)
		if not gather.is_empty():
			_gather_month(c, data, gather["table"], int(gather["days"]), rng)
			return "gather"
	if sources == "all" and turn == 2:
		_sect_missions(c, data)
		return "sect"
	var work_value := float(data.professions[prof_id].work_income * (Professions.rank_of(c, prof_id) + 1))
	var craft := _best_recipe(c, data, prof_id) if sources == "all" else {}
	if float(craft.get("per_day", 0.0)) * STEP_DAYS > work_value:
		_craft_month(c, data, String(craft["id"]), rng)
		return "craft"
	Professions.work(c, data, prof_id, STEP_DAYS)
	return "work"


## Spirit stones the ingredients of `recipe_id` cost at shop prices.
func _material_cost(data: GameData, recipe_id: String) -> int:
	var cost := 0
	var ingredients: Dictionary = data.recipes[recipe_id]["ingredients"]
	for item_id in ingredients:
		cost += int(data.items[item_id].get("price", 0)) * int(ingredients[item_id])
	return cost


## The known, rank-allowed recipe of `prof_id` with the best expected resale
## profit per day: {id, per_day}, or {} if none turns a profit.
func _best_recipe(c: CharacterData, data: GameData, prof_id: String) -> Dictionary:
	var best := {}
	for recipe_id in Alchemy.known_recipes(c, data, prof_id):
		var recipe: Dictionary = data.recipes[recipe_id]
		if Professions.rank_of(c, prof_id) < int(recipe.get("min_rank", 0)):
			continue
		var cost := _material_cost(data, recipe_id)
		if cost > c.item_count("spirit_stone"):
			continue
		var output: Dictionary = recipe["output"]
		var revenue := Alchemy.success_chance(c, data, recipe_id) * int(output.get("count", 1)) * Items.sell_price(data, String(output["item"]))
		var per_day := (revenue - cost) / maxf(1.0, float(recipe.get("days", 1)))
		if per_day > 0.0 and per_day > float(best.get("per_day", 0.0)):
			best = {"id": recipe_id, "per_day": per_day}
	return best


## A month of buying materials, refining `recipe_id` and selling the output.
func _craft_month(c: CharacterData, data: GameData, recipe_id: String, rng: RandomNumberGenerator) -> void:
	var recipe: Dictionary = data.recipes[recipe_id]
	var days_left := STEP_DAYS
	while days_left >= int(recipe.get("days", 1)):
		var ingredients: Dictionary = recipe["ingredients"]
		if c.item_count("spirit_stone") < _material_cost(data, recipe_id):
			break
		for item_id in ingredients:
			Items.buy(c, data, item_id, int(ingredients[item_id]))
		var result := Alchemy.refine(c, data, recipe_id, rng)
		if not result["ok"]:
			break
		if result["count"] > 0:
			Items.sell(c, data, result["item"], result["count"])
		days_left -= maxi(1, int(result["days"]))


## The gather place (any region the cultivator may travel to) with the best
## expected resale per day: {table, days, per_day}.
func _best_gather(c: CharacterData, data: GameData) -> Dictionary:
	var best := {}
	for region: Dictionary in data.regions.values():
		if not _can_reach(c, data, String(region["id"])):
			continue
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") != "gather":
				continue
			var table := Exploration.gather_table_for(c, data, place.get("gather_table", []))
			var total := 0.0
			var value := 0.0
			for entry: Dictionary in table:
				total += float(entry.get("weight", 0.0))
				if String(entry.get("item", "")) != "":
					value += float(entry["weight"]) * (int(entry.get("min", 1)) + int(entry.get("max", 1))) / 2.0 * Items.sell_price(data, String(entry["item"]))
			var days := maxi(1, int(place.get("gather_days", 1)))
			var per_day := value / maxf(total, 0.001) / days
			if per_day > float(best.get("per_day", 0.0)):
				best = {"table": table, "days": days, "per_day": per_day}
	return best


## Whether some route into `region_id` is open at `c`'s realm.
func _can_reach(c: CharacterData, data: GameData, region_id: String) -> bool:
	for other: Dictionary in data.regions.values():
		for route: Dictionary in other.get("routes", []):
			if String(route.get("to", "")) == region_id and c.realm_index >= data.realm_index_of(String(route.get("min_realm", "mortal"))):
				return true
	return false


## A month of gathering from `table` and selling everything found.
func _gather_month(c: CharacterData, data: GameData, table: Array, days: int, rng: RandomNumberGenerator) -> void:
	for i in STEP_DAYS / days:
		var found := Exploration.gather(c, table, rng)
		for item_id in found:
			c.add_item(item_id, found[item_id])
			Items.sell(c, data, item_id, found[item_id])


## A month of fight-free sect missions (items bought at shop price when the
## cultivator lacks them), as many as the days and cooldowns allow.
func _sect_missions(c: CharacterData, data: GameData) -> void:
	var days_left := STEP_DAYS
	for mission_id in Sects.available_missions(c, data):
		var mission: Dictionary = data.sect_missions[mission_id]
		if String(mission.get("enemy", "")) != "" or int(mission.get("days", 1)) > days_left:
			continue
		var needed: Dictionary = mission.get("requires", {}).get("items", {})
		var cost := 0
		for item_id in needed:
			cost += maxi(0, int(needed[item_id]) - c.item_count(item_id)) * int(data.items[item_id].get("price", 0))
		if cost > int(mission.get("contribution", 0)) * MAX_STONES_PER_CONTRIBUTION or Sects.mission_cooldown_left(c, mission_id) > 0:
			continue
		for item_id in needed:
			var short := int(needed[item_id]) - c.item_count(item_id)
			if short > 0:
				Items.buy(c, data, item_id, short)
		if Sects.check_mission(c, data, mission_id) != "":
			continue
		var result := Sects.complete_mission(c, data, mission_id, {})
		if result["ok"]:
			days_left -= int(result["days"])
			for item_id in c.inventory.keys():
				if item_id != "spirit_stone" and c.item_count(item_id) > 0 and not data.items[item_id].has("effects"):
					Items.sell(c, data, item_id, c.item_count(item_id))


## Once per major realm: the priciest gear per slot that the stones beyond the
## next pill (and a full artifact) can pay for, if better than what is worn.
func _buy_gear(c: CharacterData, data: GameData, stats: Dictionary) -> void:
	for slot in ["weapon", "armor"]:
		var surplus := c.item_count("spirit_stone") - _next_pill_price(c, data)
		var worn := int(data.items.get(String(c.equipment.get(slot, "")), {}).get("price", 0))
		var best := ""
		for item: Dictionary in data.items.values():
			var price := int(item.get("price", 0))
			if Equipment.slot_of(data, item["id"]) != slot or price <= worn or price > surplus or not Items.merchant_sells(data, item, item.get("tags", [])):
				continue
			if best == "" or price > int(data.items[best]["price"]):
				best = item["id"]
		if best != "" and Items.buy(c, data, best)["ok"]:
			stats["gear"] += int(data.items[best]["price"])
			var old := Equipment.equip(c, data, best)
			if old != "":
				Items.sell(c, data, old)


## Heals injuries with more than CLINIC_MIN_DAYS left at a clinic, if affordable.
func _heal(c: CharacterData, data: GameData, stats: Dictionary) -> void:
	for injury_id in c.injuries.keys():
		if int(c.injuries[injury_id]) > CLINIC_MIN_DAYS and c.item_count("spirit_stone") - Medicine.clinic_cost(c, data, injury_id) >= _next_pill_price(c, data):
			var result := Medicine.visit_clinic(c, data, injury_id)
			if result["ok"]:
				stats["clinic"] += int(result["cost"])


func _next_pill_price(c: CharacterData, data: GameData) -> int:
	for i in range(c.realm_index + 1, data.realms.size()):
		var pill: String = BREAKTHROUGH_PILLS.get(data.realms[i].id, "")
		if pill != "":
			return int(data.items[pill]["price"])
	return 0


func _add(totals: Dictionary, stats: Dictionary) -> void:
	for key: String in stats:
		if key == "max_recharge":
			totals[key] = maxi(int(totals.get(key, 0)), int(stats[key]))
		else:
			totals[key] = int(totals.get(key, 0)) + int(stats[key])


func _report(data: GameData, prof_id: String, totals: Dictionary, lives: int) -> void:
	var avg := func(key: String) -> float: return float(totals[key]) / lives
	var realm_name: String = data.realms[roundi(avg.call("realm"))].name
	var final_age := float(totals["final_age"]) / maxi(totals["final_deaths"], 1)
	print("%s (rank %.1f at the end): avg final realm %.2f (~%s); earned %d, left %d stones" % [
		data.professions[prof_id].name, avg.call("rank"), avg.call("realm"), realm_name,
		roundi(avg.call("earned")), roundi(avg.call("stones_left"))])
	for pill_realm: String in BREAKTHROUGH_PILLS:
		print("    %s: %d/%d lives reached the bottleneck, %d could afford the pill on the first attempt" % [
			data.realms[data.realm_index_of(pill_realm)].name, totals["faced_" + pill_realm], lives, totals["first_pill_" + pill_realm]])
	print("    pills %d, attempts without a pill %d; lives bought %d (dearest %d); ended for good %d (avg age %d), old age %d" % [
		totals["pills"], totals["no_pill"], totals["recharges"], totals["max_recharge"],
		totals["final_deaths"], roundi(final_age), totals["old_age"]])
	if sources == "work":
		return
	var parts: PackedStringArray = []
	for kind in INCOME_KINDS:
		parts.append("%s %d mo / %d stones" % [kind, totals["months_" + kind], totals["stones_" + kind]])
	print("    income (all lives): %s" % ", ".join(parts))
	print("    spent: gear %d, clinic %d; savings alone covered the Core Forming Pill at the Foundation peak for %d/%d; pills bought with contribution %d; avg sect rank %.1f, contribution %d" % [
		totals["gear"], totals["clinic"], totals["pill_stones_at_peak"], totals["faced_core_formation"], totals["contribution_pills"], avg.call("sect_rank"), roundi(avg.call("contribution"))])
