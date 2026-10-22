extends SceneTree
## A new Alchemist's first six months (QA-100): a fresh character in Qingshi Village takes up
## Alchemist on day 1, then follows the top hint it can act on for 180 days: gather the herb the
## hint names, craft and sell what it can refine, fill an open commission, otherwise meditate.
## Compared with the curious first-hour newcomer (tests/sim/first_hour.gd) at the same days.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/crafter_start.gd -- [seeds] [days] [--orders] [--prof=<id>]
## QA-109: --prof=<id> follows another craft (blacksmith, talisman_master, array_master, beast_tamer; default alchemist).
## QA-108: while the top hint is GUIDE-054's "You are still a mortal" line the crafter meditates that step instead of gathering
## or crafting (--no-nudge restores the old policy for before/after runs); the medians report the realm at day 120.
## QA-117: when GUIDE-066's buy hint shows, the crafter buys the missing bought-only ingredient for one craft (--no-buy restores the old policy).
## QA-107: --orders prints every commission (roll day, item, count, reward, days allowed, whether each ingredient
## was available nearby at roll time) with its fate and why the sim did not fill it.

const FirstHour := preload("res://tests/sim/first_hour.gd")
const CHECKPOINTS: Array[int] = [30, 90, 120, 180, 365]
const REGION := "qingshi_village"
var _prof := "alchemist"  ## QA-109: --prof=<id>
const STUCK_WEEK_DAYS := 7

var _gs: Node
var _clock: Node
var _orders_mode := false
var _follow_nudge := true  ## QA-108
var _follow_buy := true  ## QA-117
var _tracked: Array[Dictionary] = []  ## QA-107: orders seen so far, with their fate
var _sold := {}  ## QA-107: item id -> units the sim sold this life
var _crafted_out := {}  ## QA-107: item id -> units crafted this life


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


func _sum(values: Array) -> int:
	var total := 0
	for v: int in values:
		total += v
	return total


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_orders_mode = args.has("--orders")
	_follow_nudge = not args.has("--no-nudge")
	_follow_buy = not args.has("--no-buy")
	for a in args:
		if String(a).begins_with("--prof="):
			_prof = String(a).substr(7)
	var nums: Array = []
	for a in args:
		if not String(a).begins_with("--"):
			nums.append(a)
	var seeds := int(nums[0]) if nums.size() > 0 else 10
	var days := int(nums[1]) if nums.size() > 1 else 180
	_gs = root.get_node("GameState")
	_clock = root.get_node("GameClock")
	print("Crafter start: new %s in Qingshi Village, %d seeds, %d days" % [_prof, seeds, days])
	print("  seed  d30  d90 d180  crafted  comm(got/del)  rank  renown  gather% craft% meditate%  stuck-wk (faded)  curious(d30/d90/d180)  realm d90 | d180 | d365 (curious)  cult-hint-steps")
	var cols := {"d30": [], "d90": [], "r120": [], "d180": [], "crafted": [], "got": [], "delivered": [], "rank": [], "renown": [], "gather": [], "craft": [], "meditate": [], "stuck": [], "faded": [], "c30": [], "c90": [], "c180": [], "d365": [], "hint": [], "post": [], "stuck_post": [], "rank_gap": []}
	for s in range(1, seeds + 1):
		var base: Dictionary = FirstHour.play(_gs, _clock, s, maxi(6, days / 30), true)
		var cur: Array = base["stones"]
		var r := _crafter(s, days)
		var total := float(maxi(1, r["gather_days"] + r["craft_days"] + r["meditate_days"]))
		var cur_realms: Array = base["realms"]
		var realm_cols := "%s | %s | %s (%s | %s | %s)" % [r["realm90"], r["realm180"], r["realm365"], _at(cur_realms, 2), _at(cur_realms, 5), _at(cur_realms, 11)]
		print("  %4d %4d %4d %4d  %7d  %5d/%-5d  %4d  %6d  %6d%% %5d%% %8d%%  %8d (%5d)  %d/%d/%d  %s  %d" % [s, r["d30"], r["d90"], r["d180"], r["crafted"], r["got"], r["delivered"], r["rank"], r["renown"],
			100 * r["gather_days"] / total, 100 * r["craft_days"] / total, 100 * r["meditate_days"] / total, r["stuck"], r["faded"], cur[0], cur[2], cur[5], realm_cols, r["cult_hint"]])
		for k in ["d30", "d90", "d180", "crafted", "got", "delivered", "rank", "renown", "stuck", "faded"]:
			cols[k].append(r[k])
		cols["gather"].append(100.0 * r["gather_days"] / total)
		cols["craft"].append(100.0 * r["craft_days"] / total)
		cols["meditate"].append(100.0 * r["meditate_days"] / total)
		cols["r120"].append(0 if r["realm120"] == "Mortal" else 1)
		cols["c30"].append(cur[0])
		cols["c90"].append(cur[2])
		cols["c180"].append(cur[5])
		cols["d365"].append(r["d365"])
		cols["hint"].append(r["cult_hint"])
		cols["post"].append(r["crafted_post"])
		cols["stuck_post"].append(r["stuck_post"])
	print("  medians: stones d30/d90/d180 %d/%d/%d (curious %d/%d/%d), crafted %d, commissions got %d delivered %d, rank %d, renown %d" % [_median(cols["d30"]), _median(cols["d90"]), _median(cols["d180"]),
		_median(cols["c30"]), _median(cols["c90"]), _median(cols["c180"]), _median(cols["crafted"]), _median(cols["got"]), _median(cols["delivered"]), _median(cols["rank"]), _median(cols["renown"])])
	print("  medians: days gathering %d%% / crafting %d%% / meditating %d%%; weeks stuck (no hint, nothing to craft, nothing to deliver) median %d, max %d; of those the craft-now hint had faded (rank %d) in %d%%" % [_median(cols["gather"]), _median(cols["craft"]), _median(cols["meditate"]), _median(cols["stuck"]), cols["stuck"].max(), Guidance.CRAFT_HINT_MAX_RANK, 100 * _sum(cols["faded"]) / maxi(1, _sum(cols["stuck"]))])
	if days > 180:
		print("  medians past day 180: stones d180 -> d365 %d -> %d, crafts in days 181-%d %d (%.1f a month), weeks stuck after d180 median %d max %d" % [_median(cols["d180"]), _median(cols["d365"]), days, _median(cols["post"]), _median(cols["post"]) / ((days - 180) / 30.0), _median(cols["stuck_post"]), cols["stuck_post"].max()])
	var never := 0
	for n: int in cols["crafted"]:
		never += 1 if n == 0 else 0
	print("  QA-117: buy hint %s; seeds that never crafted: %d of %d" % ["followed" if _follow_buy else "ignored", never, seeds])
	print("  QA-108: seeds past Mortal by day 120: %d of %d (nudge %s)" % [_sum(cols["r120"]), seeds, "followed" if _follow_nudge else "ignored"])
	print("  steps where the top hint is about cultivating or a breakthrough: median %d, max %d" % [_median(cols["hint"]), cols["hint"].max()])
	quit()


## The month-end realm label of the curious run at index i ("-" if it ended sooner).
func _at(labels: Array, i: int) -> String:
	return String(labels[i]) if i < labels.size() else "-"


## One seeded crafter life: the counters dict.
func _crafter(seed_value: int, days: int) -> Dictionary:
	_gs.rng.seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c := CharacterFactory.create("Crafter", _gs.data, rng)
	_gs.start_session(c)
	_gs.pending_event = ""
	c.professions[_prof] = {"rank": 0, "xp": 0.0}
	Alchemy.grant_rank_recipes(c, _gs.data)
	var start: int = _clock.total_days
	var out := {"d30": 0, "d90": 0, "d120": 0, "d180": 0, "crafted": 0, "got": 0, "delivered": 0, "rank": 0, "renown": 0, "gather_days": 0, "craft_days": 0, "meditate_days": 0, "stuck": 0, "faded": 0, "d365": 0, "realm90": "-", "realm120": "-", "realm180": "-", "realm365": "-", "cult_hint": 0, "crafted_post": 0, "stuck_post": 0}
	var checkpoints := CHECKPOINTS.duplicate()
	_tracked.clear()
	_sold.clear()
	_crafted_out.clear()
	while c.alive and _clock.total_days - start < days:
		var before: int = _clock.total_days
		_clear_pending()
		if _top_hint_is_cultivation(c):
			out["cult_hint"] += 1
		var crafted_before := LifeStats.get_stat(c, "items_crafted")
		var kind := _act(c)
		if _orders_mode:
			_track_orders(c, seed_value, start)
		if _clock.total_days - start >= 180:
			out["crafted_post"] += LifeStats.get_stat(c, "items_crafted") - crafted_before
		if kind == "stuck":
			out["stuck"] += 1
			if _clock.total_days - start >= 180:
				out["stuck_post"] += 1
			if Professions.rank_of(c, _prof) >= Guidance.CRAFT_HINT_MAX_RANK:
				out["faded"] += 1
			kind = "meditate"
		if _clock.total_days == before:  # a free action (selling, delivering) used no time: meditate the week
			kind = "meditate"
			_idle_week(c)
		out[kind + "_days"] += _clock.total_days - before
		while not checkpoints.is_empty() and _clock.total_days - start >= checkpoints[0]:
			out["d%d" % checkpoints[0]] = c.item_count("spirit_stone")
			if checkpoints[0] >= 90:
				out["realm%d" % checkpoints[0]] = Cultivation.realm_label(c, _gs.data)
			checkpoints.pop_front()
	out["crafted"] = LifeStats.get_stat(c, "items_crafted")
	out["delivered"] = LifeStats.get_stat(c, "commissions_done")
	out["got"] = out["delivered"] + c.commissions.size()
	out["rank"] = Professions.rank_of(c, _prof)
	out["renown"] = Renown.value(c, REGION)
	if _orders_mode:
		_track_orders(c, seed_value, start)
		for t in _tracked:
			if t["fate"] == "":
				t["fate"] = "open at end"
				t["why"] = _why(c, t)
			print(_order_line(t))
	return out


## QA-107: notes new orders in the pack and closes the ones that left it (delivered or lapsed).
func _track_orders(c: CharacterData, seed_value: int, start: int) -> void:
	var done := LifeStats.get_stat(c, "commissions_done")
	for order in c.commissions:
		var known := false
		for t in _tracked:
			if t["due"] == int(order["due_day"]) and t["recipe"] == String(order["recipe"]) and t["fate"] == "":
				known = true
		if known:
			continue
		var nearby := []
		var recipe: Dictionary = _gs.data.recipes[String(order["recipe"])]
		for ing: String in recipe["ingredients"]:
			if ing != "spirit_stone":
				nearby.append("%s:%s" % [ing, _where(c, ing)])
		_tracked.append({"seed": seed_value, "day": _clock.total_days - start, "item": String(order["item"]), "recipe": String(order["recipe"]), "count": int(order["count"]),
			"reward": int(order["reward"]), "allowed": int(order["due_day"]) - _clock.total_days, "due": int(order["due_day"]), "near": nearby,
			"sold0": int(_sold.get(String(order["item"]), 0)), "made0": int(_crafted_out.get(String(order["item"]), 0)), "fate": "", "why": "", "done0": done})
	for t in _tracked:
		if t["fate"] != "":
			continue
		var still := false
		for order in c.commissions:
			if t["due"] == int(order["due_day"]) and t["recipe"] == String(order["recipe"]):
				still = true
		if still:
			continue
		if done > int(t["done0"]) and _clock.total_days - start <= t["day"] + t["allowed"]:
			t["fate"] = "delivered d%d" % (_clock.total_days - start)
			t["done0"] = done
		else:
			t["fate"] = "lapsed d%d" % (_clock.total_days - start)
			t["why"] = _why(c, t)


## QA-107: the reason the sim did not fill an order, from what happened between its roll and now.
func _why(c: CharacterData, t: Dictionary) -> String:
	var item := String(t["item"])
	var made := int(_crafted_out.get(item, 0)) - int(t["made0"])
	var sold := int(_sold.get(item, 0)) - int(t["sold0"])
	var recipe: Dictionary = _gs.data.recipes[String(t["recipe"])]
	var per := maxi(1, int(recipe["output"].get("count", 1)))
	if made == 0:
		return "never crafted (needs %d crafts; allowed %d days)" % [ceili(float(t["count"]) / per), t["allowed"]]
	if sold > 0:
		return "crafted %d, sold %d (sim sold order goods)" % [made, sold]
	if made < int(t["count"]):
		return "crafted %d of %d, ran out of days" % [made, t["count"]]
	return "crafted %d, held %d but not delivered" % [made, c.item_count(item)]


## QA-107: where the crafter can get an ingredient: "here" (a gather place in the sim's region, with its per-gather chance),
## "nearby" (a neighbouring region or a merchant, which the sim never visits), or "nowhere".
func _where(c: CharacterData, item_id: String) -> String:
	for place: Dictionary in _gs.data.regions[REGION].get("places", []):
		if String(place.get("type", "")) != "gather":
			continue
		var total := 0.0
		var hit := 0.0
		for entry: Dictionary in Exploration.gather_table_for(c, _gs.data, place.get("gather_table", [])):
			total += float(entry.get("weight", 0))
			if String(entry.get("item", "")) == item_id:
				hit += float(entry.get("weight", 0))
		if hit > 0.0:
			return "here(%d%%/%dd)" % [roundi(100.0 * hit / total), int(place.get("gather_days", 1))]
	return "elsewhere" if Guidance.available_nearby(c, _gs.data, item_id, REGION) else "nowhere"


func _order_line(t: Dictionary) -> String:
	var market: int = int(t["count"]) * Items.sell_price(_gs.data, String(t["item"]))
	return "    order seed %d day %d: %dx %s reward %d (market %d), %d days, %s -> %s%s" % [t["seed"], t["day"], t["count"], t["item"], t["reward"], market, t["allowed"], " ".join(t["near"]), t["fate"], " (%s)" % t["why"] if t["why"] != "" else ""]


## QA-104: is the top hint here a meditation or breakthrough line?
func _top_hint_is_cultivation(c: CharacterData) -> bool:
	var hints: PackedStringArray = Guidance.hints(c, _gs.data, 1.0, 1, {}, _gs.world_flags, REGION, _clock.total_days)
	if hints.is_empty():
		return false
	var text := hints[0].to_lower()
	return text.contains("meditat") or text.contains("breakthrough") or text.contains("cultivat")


## QA-108: is the top hint GUIDE-054's "You are still a mortal" line?
func _top_hint_is_mortal_nudge(c: CharacterData) -> bool:
	var hints: PackedStringArray = Guidance.hints(c, _gs.data, 1.0, 1, {}, _gs.world_flags, REGION, _clock.total_days)
	return not hints.is_empty() and hints[0].begins_with("You are still a mortal")


## A week with nothing better to do: meditate, or at a bottleneck try the breakthrough and then walk about (exploring takes time).
func _idle_week(c: CharacterData) -> void:
	var before: int = _clock.total_days
	_gs.cultivate(STUCK_WEEK_DAYS, Guidance.best_qi_in_region(c, _gs.data, REGION, _gs.world_flags).get("density", 1.0))
	if _clock.total_days > before:
		return
	if Cultivation.can_attempt_breakthrough(c, _gs.data):
		_gs.attempt_breakthrough()
	if _clock.total_days == before and c.alive:
		_gs.explore()


## Answers whatever blocks actions (an encounter, or a threat the crafter slips away from).
func _clear_pending() -> void:
	if _gs.pending_encounter != "":
		_gs.choose_encounter(0)
	if _gs.pending_threat != "":
		_gs.face_threat(false)


## One decision: returns "gather", "craft", "meditate" or "stuck" (nothing to act on).
func _act(c: CharacterData) -> String:
	_deliver_open(c)
	if _follow_nudge and _top_hint_is_mortal_nudge(c):
		_idle_week(c)
		return "meditate"
	if _follow_nudge and c.realm_index == 0 and Cultivation.can_attempt_breakthrough(c, _gs.data):  # the nudge's next line: step into Qi Refining
		_gs.attempt_breakthrough()
		return "meditate"
	if _follow_buy and Guidance.buy_ingredient_hint(c, _gs.data, REGION) != "":
		_buy_for_hint(c)
	var recipe_id := _best_craftable(c)
	if recipe_id != "":
		var out_item := String(_gs.data.recipes[recipe_id]["output"]["item"])
		var had := c.item_count(out_item)
		_gs.refine(recipe_id)
		_crafted_out[out_item] = int(_crafted_out.get(out_item, 0)) + maxi(0, c.item_count(out_item) - had)
		_deliver_open(c)
		_sell_surplus(c)
		return "craft"
	if _gather_for_order(c) or _gather_hinted(c):
		return "gather"
	return "stuck" if Guidance.herb_here_hint(c, _gs.data, REGION) == "" else "meditate"


## QA-117: follows GUIDE-066's buy hint: buys what the first in-rank recipe lacks (bought-only, sold in this region) for one craft, stones allowing.
func _buy_for_hint(c: CharacterData) -> void:
	for prof_id: String in _gs.data.professions:
		if not c.professions.has(prof_id):
			continue
		for recipe_id: String in Alchemy.known_recipes(c, _gs.data, prof_id):
			var recipe: Dictionary = _gs.data.recipes[recipe_id]
			if int(recipe.get("min_rank", 0)) > Professions.rank_of(c, prof_id):
				continue
			var need := {}
			for ing: String in recipe["ingredients"]:
				var short: int = int(recipe["ingredients"][ing]) - c.item_count(ing)
				if ing != "spirit_stone" and short > 0:
					if Guidance.merchant_selling(_gs.data, REGION, ing) == "":
						need.clear()
						break
					need[ing] = short
			if need.is_empty():
				continue
			for ing: String in need:
				_gs.buy_item(ing, "", need[ing])
			return


func _deliver_open(c: CharacterData) -> void:
	for i in range(c.commissions.size() - 1, -1, -1):
		if Commissions.check_deliver(c, _gs.data, i) == "":
			_gs.deliver_commission(i)


## Sells crafted output no open commission still wants.
func _sell_surplus(c: CharacterData) -> void:
	var wanted := {}
	for order in c.commissions:
		wanted[String(order["item"])] = true
	for recipe_id: String in Alchemy.known_recipes(c, _gs.data, _prof):
		var item_id := String(_gs.data.recipes[recipe_id]["output"]["item"])
		var great := String(_gs.data.recipes[recipe_id].get("great_output", {}).get("item", ""))
		for id in [item_id, great]:
			if id != "" and not wanted.has(id) and c.item_count(id) > 0:
				_sold[id] = int(_sold.get(id, 0)) + c.item_count(id)
				_gs.sell_item(id, c.item_count(id))


## The craftable recipe that leaves the most stones (output value minus ingredients bought at shop price), preferring one an open order wants.
func _best_craftable(c: CharacterData) -> String:
	var best := ""
	var best_score := -1.0e9
	for recipe_id: String in Guidance.craftable_now(c, _gs.data):
		if Professions.rank_of(c, String(_gs.data.recipes[recipe_id]["profession"])) < 0:
			continue
		var recipe: Dictionary = _gs.data.recipes[recipe_id]
		var score := float(int(recipe["output"].get("count", 1)) * Items.sell_price(_gs.data, String(recipe["output"]["item"])))
		for order in c.commissions:
			if String(order["recipe"]) == recipe_id:
				score += float(order["reward"])
		if score > best_score:
			best_score = score
			best = recipe_id
	return best


## Follows GUIDE-052's order line: gathers here the first ingredient an open order still lacks. False if none.
func _gather_for_order(c: CharacterData) -> bool:
	for order in c.commissions:
		var line := Commissions.missing_line(c, _gs.data, order, REGION, _clock.total_days)
		if not line.begins_with("Needs "):
			continue
		for id: String in _gs.data.items:
			if line.begins_with("Needs %s" % String(_gs.data.items[id].get("name", ""))) and _gather_item(c, id):
				return true
	return false


## Gathers at the place in this region that yields item_id. False if there is none.
func _gather_item(_c: CharacterData, item_id: String) -> bool:
	for place: Dictionary in _gs.data.regions[REGION].get("places", []):
		if String(place.get("type", "")) != "gather":
			continue
		for entry: Dictionary in Exploration.gather_table_for(_c, _gs.data, place.get("gather_table", [])):
			if String(entry.get("item", "")) == item_id:
				_gs.gather(place["gather_table"], maxi(1, int(place.get("gather_days", 1))))
				return true
	return false


## Follows the GUIDE-042 hint: gathers at the place here that yields the first short ingredient. False if there is no hint.
func _gather_hinted(c: CharacterData) -> bool:
	if Guidance.herb_here_hint(c, _gs.data, REGION) == "":
		return false
	for recipe_id: String in _gs.data.recipes:
		var recipe: Dictionary = _gs.data.recipes[recipe_id]
		if String(recipe["profession"]) != _prof or not Alchemy.knows(c, _gs.data, recipe_id) or int(recipe.get("min_rank", 0)) > Professions.rank_of(c, _prof):
			continue
		for item_id: String in recipe["ingredients"]:
			if c.item_count(item_id) >= int(recipe["ingredients"][item_id]):
				continue
			for place: Dictionary in _gs.data.regions[REGION].get("places", []):
				if String(place.get("type", "")) != "gather":
					continue
				for entry: Dictionary in Exploration.gather_table_for(c, _gs.data, place.get("gather_table", [])):
					if String(entry.get("item", "")) == item_id:
						_gs.gather(place["gather_table"], maxi(1, int(place.get("gather_days", 1))))
						return true
	return false
