extends SceneTree
## Profession income sim (QA-093): what does a profession pay in the first years? A Qi Refining
## player with attribute 10 spends WORK_DAYS days a week for `months` months on one profession
## and each week picks the best of: Professions.work, crafting and selling its best known recipe
## (materials bought and output sold at shop prices), and filling the open commission
## (Commissions). In the game only professions outside Workshop.CRAFTS can Work (the Doctor);
## the five crafting professions get three rows instead (QA-097, "odd jobs" from QA-101 is the PROF-004
## workshop option: Professions.work a month at a time, no crafting): "bought" buys every ingredient at
## the shop price, "gathered" gathers them at the best open gather place for each ingredient and
## counts those days as spent (ingredients no place yields are bought). Next to each profession a
## gatherer and a sect-mission player (fight-free missions) spend the same days. Stones are net of
## what the player buys.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/profession_income.gd -- [seeds] [months] [--breakdown]
## --breakdown (QA-105) adds, for each crafter's "gathered" run, per month: days spent gathering / crafting, units
## gathered, units the crafts used, stones from selling crafted goods, what those gathered units would
## have fetched sold raw (Items.sell_price, half price), and the crafted sale price against its uncapped
## half-price value (the sell cap).

const WORK_DAYS := 3
const WEEK := 7
const QUARTER_WEEKS := 13
## Stones in hand at the start (a newcomer can afford a first batch of materials).
const START_STONES := 50
const SECT_ID := "myriad_treasure_pavilion"
const KINDS: Array[String] = ["work", "craft", "commission"]
## Mirrors Workshop.CRAFTS: these professions cannot Work in the game.
const CRAFTERS: Array[String] = ["alchemist", "blacksmith", "talisman_master", "array_master", "beast_tamer"]

var _sell_prices := {}
## Days of Professions.work not yet paid out: work() truncates its income per call, so 3-day
## blocks pay 0 at work_income 5-7; the player works in whole months (see Follow-ups in the commit).
var _banked_work := 0
## "bought" or "gathered" while a crafter is simulated, "" otherwise.
var _variant := ""
var _rates := {}
## QA-105 breakdown counters for the run in progress (see _print_breakdown).
var _stats := {}


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var breakdown := args.has("--breakdown")
	var nums: Array[String] = []
	for a in args:
		if not a.begins_with("--"):
			nums.append(a)
	var seeds := int(nums[0]) if nums.size() > 0 else 5
	var months := int(nums[1]) if nums.size() > 1 else 24
	var data := GameData.load_from_dir()
	print("Profession income: Qi Refining, attribute 10, %d days a week for %d months, seeds 1-%d" % [WORK_DAYS, months, seeds])
	var weeks := months * Calendar.DAYS_PER_MONTH / WEEK
	var rows: Array[Dictionary] = []
	for prof_id: String in data.professions:
		if CRAFTERS.has(prof_id):
			rows.append(_average(data, prof_id, seeds, weeks, "bought"))
			rows.append(_average(data, prof_id, seeds, weeks, "gathered"))
			rows.append(_average(data, prof_id, seeds, weeks, "odd jobs"))
		else:
			rows.append(_average(data, prof_id, seeds, weeks))
	rows.append(_average(data, "_gather", seeds, weeks))
	rows.append(_average(data, "_sect", seeds, weeks))
	print("%-26s %s | rank  work craft  comm | per day" % ["", " ".join(_quarter_heads(weeks))])
	for row: Dictionary in rows:
		var quarters: PackedStringArray = []
		for q: float in row["quarters"]:
			quarters.append("%5.1f" % q)
		# Shares of the positive profession stones (a broke crafter nets ~0 or less: no shares then).
		var total := maxf(0.0, float(row["work"])) + maxf(0.0, float(row["craft"])) + maxf(0.0, float(row["commission"]))
		var share := "  -    -     -"
		if not row["id"].begins_with("_") and total >= 1.0:
			share = "%4d%% %4d%% %4d%%" % [100 * maxf(0.0, float(row["work"])) / total, 100 * maxf(0.0, float(row["craft"])) / total, 100 * maxf(0.0, float(row["commission"])) / total]
		print("%-26s %s | %4.1f %s | %5.2f" % [row["name"], " ".join(quarters), row["rank"], share, float(row["total"]) / (weeks * WORK_DAYS)])
	print("(stones a week by quarter, then the rank reached and the share of positive profession stones from work / crafting / commissions, blank when a broke crafter netted under 1 stone; per day = stones per day spent)")
	if breakdown:
		_print_breakdown(data, seeds, months, weeks)
	quit()


## QA-105: where the days and herbs of a gathered crafter go (means over seeds, per month).
func _print_breakdown(data: GameData, seeds: int, months: int, weeks: int) -> void:
	print("Gathered crafters, per month (mean of %d seeds): days gathering / crafting, units gathered / used by crafts, crafted-sale stones, same units sold raw, avg crafted price vs uncapped half price" % seeds)
	for prof_id: String in CRAFTERS:
		var sum := {}
		for s in range(1, seeds + 1):
			_life(data, prof_id, s, weeks, "gathered")
			for k: String in _stats:
				sum[k] = float(sum.get(k, 0.0)) + float(_stats[k]) / seeds / months
		var sold := maxf(float(sum.get("sold_units", 0.0)), 0.001)
		print("%-16s gather %5.1f d  craft %5.1f d | gathered %5.1f  used %5.1f | crafted sales %6.1f  raw %6.1f | price %5.2f vs uncapped %5.2f (capped %3d%% of units)" % [
			data.professions[prof_id].name, sum.get("gather_days", 0.0), sum.get("craft_days", 0.0),
			sum.get("gathered_units", 0.0), sum.get("used_units", 0.0), sum.get("sale_stones", 0.0),
			sum.get("raw_value", 0.0), float(sum.get("sale_stones", 0.0)) / sold,
			float(sum.get("uncapped", 0.0)) / sold, 100.0 * float(sum.get("capped_units", 0.0)) / sold])


func _quarter_heads(weeks: int) -> PackedStringArray:
	var heads: PackedStringArray = []
	for q in weeks / QUARTER_WEEKS:
		heads.append("  Q%d " % (q + 1))
	return heads


func _average(data: GameData, who: String, seeds: int, weeks: int, variant: String = "") -> Dictionary:
	var sum := {"id": who, "name": who, "quarters": [], "rank": 0.0, "work": 0.0, "craft": 0.0, "commission": 0.0, "total": 0.0}
	for q in weeks / QUARTER_WEEKS:
		sum["quarters"].append(0.0)
	if data.professions.has(who):
		sum["name"] = data.professions[who].name + ((" (%s)" % variant) if variant != "" else "")
	elif who == "_gather":
		sum["name"] = "(gatherer)"
	else:
		sum["name"] = "(sect missions)"
	for s in range(1, seeds + 1):
		var res := _life(data, who, s, weeks, variant)
		for q in res["quarters"].size():
			sum["quarters"][q] += res["quarters"][q] / seeds
		for k in ["rank", "work", "craft", "commission", "total"]:
			sum[k] += float(res[k]) / seeds
	return sum


func _new_player(data: GameData, rng: RandomNumberGenerator) -> CharacterData:
	var c := CharacterFactory.create("Sim", data, rng)
	for attr_def: Dictionary in data.attributes:
		c.attributes[String(attr_def["id"])] = 10
	c.realm_index = data.realm_index_of("qi_refining")
	c.age_days = 18 * Calendar.DAYS_PER_YEAR
	c.add_item("spirit_stone", START_STONES)
	return c


## One seeded run: {quarters: stones a week per quarter, rank, work, craft, commission, total}.
func _life(data: GameData, who: String, seed_value: int, weeks: int, variant: String = "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c := _new_player(data, rng)
	_variant = variant
	_rates.clear()
	_stats = {}
	var res := {"quarters": [], "rank": 0, "work": 0, "craft": 0, "commission": 0, "total": 0}
	if data.professions.has(who):
		c.professions[who] = {"rank": 0, "xp": 0.0}
		Alchemy.grant_rank_recipes(c, data)
	elif who == "_sect":
		Sects.join(c, data, SECT_ID)
	var gather := _best_gather(c, data) if who == "_gather" else {}
	var budget := 0.0
	_banked_work = 0
	var quarter_sum := 0
	for week in weeks:
		c.age_days += WEEK
		if week % 4 == 0 and data.professions.has(who):
			Commissions.roll(c, data, rng, c.age_days)
			Commissions.expire(c, c.age_days)
		budget += WORK_DAYS
		var week_start := c.item_count("spirit_stone")
		while budget >= 1.0:
			var before := c.item_count("spirit_stone")
			var spent := 1.0
			var kind := ""
			if who == "_gather":
				spent = _gather(c, data, gather, rng)
			elif who == "_sect":
				spent = _sect_mission(c, data, budget)
			else:
				var pick := _pick(c, data, who, int(budget))
				kind = String(pick["kind"])
				spent = _do(c, data, who, pick, int(budget), rng)
			if spent <= 0.0:
				break
			budget -= spent
			var gained := c.item_count("spirit_stone") - before
			res["total"] += gained
			if kind != "":
				res[kind] += gained
		if who != "_gather" and who != "_sect":
			res["rank"] = Professions.rank_of(c, who)
		quarter_sum += c.item_count("spirit_stone") - week_start
		if (week + 1) % QUARTER_WEEKS == 0:
			res["quarters"].append(float(quarter_sum) / QUARTER_WEEKS)
			quarter_sum = 0
	return res


func _sell_price(data: GameData, item_id: String) -> int:
	if not _sell_prices.has(item_id):
		_sell_prices[item_id] = Items.sell_price(data, item_id)
	return _sell_prices[item_id]


func _material_cost(data: GameData, recipe_id: String) -> int:
	var cost := 0
	var ingredients: Dictionary = data.recipes[recipe_id]["ingredients"]
	for item_id: String in ingredients:
		cost += int(data.items[item_id].get("price", 0)) * int(ingredients[item_id])
	return cost


func _craftable(c: CharacterData, data: GameData, prof_id: String) -> Array[String]:
	var ids: Array[String] = []
	for recipe_id in Alchemy.known_recipes(c, data, prof_id):
		if Professions.rank_of(c, prof_id) >= int(data.recipes[recipe_id].get("min_rank", 0)):
			ids.append(recipe_id)
	return ids


## The best option for the next `days` days: {kind, per_day, recipe, order}.
func _pick(c: CharacterData, data: GameData, prof_id: String, days: int) -> Dictionary:
	var def: ProfessionDef = data.professions[prof_id]
	var best := {"kind": "", "per_day": -1.0e9, "recipe": "", "order": -1}
	if not CRAFTERS.has(prof_id) or _variant == "odd jobs":
		best = {"kind": "work", "per_day": def.work_income * (Professions.rank_of(c, prof_id) + 1) / float(Calendar.DAYS_PER_MONTH), "recipe": "", "order": -1}
	if _variant == "odd jobs":
		return best  # PROF-004: a month of Professions.work at the workshop, no crafting
	var stones := c.item_count("spirit_stone")
	for recipe_id in _craftable(c, data, prof_id):
		var recipe: Dictionary = data.recipes[recipe_id]
		var cost := _material_cost(data, recipe_id)
		var extra_days := 0.0
		if _variant == "gathered":
			var plan := _gather_plan(c, data, recipe_id)
			cost = int(plan["cost"])
			extra_days = float(plan["days"])
		var chance := Alchemy.success_chance(c, data, recipe_id)
		var out_count := int(recipe["output"].get("count", 1))
		var rdays := maxf(1.0, float(recipe.get("days", 1))) + extra_days
		if cost > stones:
			continue
		var per_day := (chance * out_count * _sell_price(data, String(recipe["output"]["item"])) - cost) / rdays
		if per_day > float(best["per_day"]):
			best = {"kind": "craft", "per_day": per_day, "recipe": recipe_id, "order": -1}
		for i in c.commissions.size():
			var order: Dictionary = c.commissions[i]
			if order["recipe"] != recipe_id:
				continue
			var crafts := ceilf(float(order["count"]) / out_count / maxf(chance, 0.05))
			if cost * crafts > stones:
				continue
			var net := (float(order["reward"]) - cost * crafts) / (crafts * rdays)
			if net > float(best["per_day"]):
				best = {"kind": "commission", "per_day": net, "recipe": recipe_id, "order": i}
	return best


## Does the chosen action; returns the days it used.
func _do(c: CharacterData, data: GameData, prof_id: String, pick: Dictionary, days: int, rng: RandomNumberGenerator) -> float:
	if pick["kind"] == "":
		return 0.0
	if pick["kind"] == "work":
		_banked_work += days
		if _banked_work >= Calendar.DAYS_PER_MONTH:
			Professions.work(c, data, prof_id, _banked_work)
			_banked_work = 0
		return days
	var recipe_id: String = pick["recipe"]
	var recipe: Dictionary = data.recipes[recipe_id]
	var ingredients: Dictionary = recipe["ingredients"]
	var gather_days := 0.0
	if _variant == "gathered":
		gather_days = _gather_for(c, data, recipe_id, rng)
	for item_id: String in ingredients:
		Items.buy(c, data, item_id, maxi(0, int(ingredients[item_id]) - c.item_count(item_id)))
	var result := Alchemy.refine(c, data, recipe_id, rng)
	if not result["ok"]:
		return gather_days
	for item_id: String in ingredients:
		_stat("used_units", int(ingredients[item_id]))
	_stat("craft_days", maxf(1.0, float(result["days"])))
	var item_id: String = result["item"]
	if pick["kind"] == "craft":
		if result["count"] > 0:
			_sell(c, data, item_id, int(result["count"]))
	elif pick["order"] >= 0 and pick["order"] < c.commissions.size() and Commissions.check_deliver(c, data, int(pick["order"])) == "":
		Commissions.deliver(c, data, int(pick["order"]))
	return gather_days + maxf(1.0, float(result["days"]))


func _stat(key: String, amount: float) -> void:
	_stats[key] = float(_stats.get(key, 0.0)) + amount


## Items.sell minus the per-sale recipe scan.
func _sell(c: CharacterData, data: GameData, item_id: String, count: int) -> void:
	for order in c.commissions:
		if order["item"] == item_id:
			return  # keep it for the order
	var price := _sell_price(data, item_id) * count
	_stat("sold_units", count)
	_stat("sale_stones", price)
	var uncapped := int(int(data.items[item_id].get("price", 0)) * Items.SELL_RATE)
	_stat("uncapped", uncapped * count)
	if uncapped > _sell_price(data, item_id):
		_stat("capped_units", count)
	c.add_item(item_id, -count)
	c.add_item("spirit_stone", price)
	LifeStats.record_stones(c, price)


## Gather places the player can walk to (a route into the region is open at their realm):
## [{table, days}], tables already filtered by realm.
func _open_places(c: CharacterData, data: GameData) -> Array[Dictionary]:
	var places: Array[Dictionary] = []
	for region: Dictionary in data.regions.values():
		var open := false
		for other: Dictionary in data.regions.values():
			for route: Dictionary in other.get("routes", []):
				if String(route.get("to", "")) == String(region["id"]) and c.realm_index >= data.realm_index_of(String(route.get("min_realm", "mortal"))):
					open = true
		if not open:
			continue
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "gather":
				places.append({"table": Exploration.gather_table_for(c, data, place.get("gather_table", [])), "days": maxi(1, int(place.get("gather_days", 1)))})
	return places


## Expected units of `item_id` per day at the best open gather place: {per_day, table, days}.
func _item_rate(c: CharacterData, data: GameData, item_id: String) -> Dictionary:
	if _rates.has(item_id):
		return _rates[item_id]
	var best := {"per_day": 0.0}
	for place: Dictionary in _open_places(c, data):
		var total := 0.0
		var units := 0.0
		for entry: Dictionary in place["table"]:
			total += float(entry.get("weight", 0.0))
			if String(entry.get("item", "")) == item_id:
				units += float(entry["weight"]) * (int(entry.get("min", 1)) + int(entry.get("max", 1))) / 2.0
		# Exploration.gather rolls GATHER_ROLLS times per visit.
		var per_day := units / maxf(total, 0.001) * Exploration.GATHER_ROLLS / float(place["days"])
		if per_day > float(best["per_day"]):
			best = {"per_day": per_day, "table": place["table"], "days": place["days"]}
	_rates[item_id] = best
	return best


## What a gathered batch of `recipe_id` costs: {cost: stones for ingredients no place yields,
## days: expected gathering days for the rest}.
func _gather_plan(c: CharacterData, data: GameData, recipe_id: String) -> Dictionary:
	var cost := 0
	var days := 0.0
	var ingredients: Dictionary = data.recipes[recipe_id]["ingredients"]
	for item_id: String in ingredients:
		var need := maxi(0, int(ingredients[item_id]) - c.item_count(item_id))
		var rate := _item_rate(c, data, item_id)
		if float(rate["per_day"]) > 0.0:
			days += need / float(rate["per_day"])
		else:
			cost += int(data.items[item_id].get("price", 0)) * need
	return {"cost": cost, "days": days}


## Gathers (at the best place for each ingredient) until the batch is in hand; returns the days spent.
## Ingredients no place yields are left for the shop purchase in _do.
func _gather_for(c: CharacterData, data: GameData, recipe_id: String, rng: RandomNumberGenerator) -> float:
	var spent := 0.0
	var ingredients: Dictionary = data.recipes[recipe_id]["ingredients"]
	for item_id: String in ingredients:
		var rate := _item_rate(c, data, item_id)
		if float(rate["per_day"]) <= 0.0:
			continue
		var guard := 0
		while c.item_count(item_id) < int(ingredients[item_id]) and guard < 200:
			guard += 1
			var found := Exploration.gather(c, rate["table"], rng)
			for found_id: String in found:
				c.add_item(found_id, int(found[found_id]))
				_stat("gathered_units", int(found[found_id]))
				_stat("raw_value", int(found[found_id]) * _sell_price(data, found_id))
			spent += float(rate["days"])
			_stat("gather_days", float(rate["days"]))
	return spent


func _best_gather(c: CharacterData, data: GameData) -> Dictionary:
	var best := {}
	for place: Dictionary in _open_places(c, data):
		var table: Array = place["table"]
		var total := 0.0
		var value := 0.0
		for entry: Dictionary in table:
			total += float(entry.get("weight", 0.0))
			if String(entry.get("item", "")) != "":
				value += float(entry["weight"]) * (int(entry.get("min", 1)) + int(entry.get("max", 1))) / 2.0 * _sell_price(data, String(entry["item"]))
		var per_day := value / maxf(total, 0.001) / float(place["days"])
		if per_day > float(best.get("per_day", 0.0)):
			best = {"table": table, "days": place["days"], "per_day": per_day}
	return best


func _gather(c: CharacterData, data: GameData, gather: Dictionary, rng: RandomNumberGenerator) -> float:
	if gather.is_empty():
		return 0.0
	var found := Exploration.gather(c, gather["table"], rng)
	for item_id: String in found:
		var price := _sell_price(data, item_id) * int(found[item_id])
		if price > 0:
			c.add_item("spirit_stone", price)
			LifeStats.record_stones(c, price)
	return float(gather["days"])


## One fight-free sect mission that fits in `budget` days (items bought at shop price).
func _sect_mission(c: CharacterData, data: GameData, budget: float) -> float:
	for mission_id in Sects.available_missions(c, data):
		var mission: Dictionary = data.sect_missions[mission_id]
		if String(mission.get("enemy", "")) != "" or float(mission.get("days", 1)) > budget or Sects.mission_cooldown_left(c, mission_id) > 0:
			continue
		var needed: Dictionary = mission.get("requires", {}).get("items", {})
		for item_id: String in needed:
			Items.buy(c, data, item_id, maxi(0, int(needed[item_id]) - c.item_count(item_id)))
		if Sects.check_mission(c, data, mission_id) != "":
			continue
		var result := Sects.complete_mission(c, data, mission_id, {})
		if result["ok"]:
			for item_id: String in c.inventory.keys():
				if item_id != "spirit_stone" and c.item_count(item_id) > 0 and not data.items[item_id].has("effects"):
					_sell(c, data, item_id, c.item_count(item_id))
			return float(result["days"])
	return 0.0
