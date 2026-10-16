extends SceneTree
## A new Alchemist's first six months (QA-100): a fresh character in Qingshi Village takes up
## Alchemist on day 1, then follows the top hint it can act on for 180 days: gather the herb the
## hint names, craft and sell what it can refine, fill an open commission, otherwise meditate.
## Compared with the curious first-hour newcomer (tests/sim/first_hour.gd) at the same days.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/crafter_start.gd -- [seeds] [days]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const CHECKPOINTS: Array[int] = [30, 90, 180]
const REGION := "qingshi_village"
const PROF := "alchemist"
const STUCK_WEEK_DAYS := 7

var _gs: Node
var _clock: Node


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
	var seeds := int(args[0]) if args.size() > 0 else 10
	var days := int(args[1]) if args.size() > 1 else 180
	_gs = root.get_node("GameState")
	_clock = root.get_node("GameClock")
	print("Crafter start: new Alchemist in Qingshi Village, %d seeds, %d days" % [seeds, days])
	print("  seed  d30  d90 d180  crafted  comm(got/del)  rank  renown  gather% craft% meditate%  stuck-wk (faded)  curious(d30/d90/d180)")
	var cols := {"d30": [], "d90": [], "d180": [], "crafted": [], "got": [], "delivered": [], "rank": [], "renown": [], "gather": [], "craft": [], "meditate": [], "stuck": [], "faded": [], "c30": [], "c90": [], "c180": []}
	for s in range(1, seeds + 1):
		var base: Dictionary = FirstHour.play(_gs, _clock, s, 6, true)
		var cur: Array = base["stones"]
		var r := _crafter(s, days)
		var total := float(maxi(1, r["gather_days"] + r["craft_days"] + r["meditate_days"]))
		print("  %4d %4d %4d %4d  %7d  %5d/%-5d  %4d  %6d  %6d%% %5d%% %8d%%  %8d (%5d)  %d/%d/%d" % [s, r["d30"], r["d90"], r["d180"], r["crafted"], r["got"], r["delivered"], r["rank"], r["renown"],
			100 * r["gather_days"] / total, 100 * r["craft_days"] / total, 100 * r["meditate_days"] / total, r["stuck"], r["faded"], cur[0], cur[2], cur[5]])
		for k in ["d30", "d90", "d180", "crafted", "got", "delivered", "rank", "renown", "stuck", "faded"]:
			cols[k].append(r[k])
		cols["gather"].append(100.0 * r["gather_days"] / total)
		cols["craft"].append(100.0 * r["craft_days"] / total)
		cols["meditate"].append(100.0 * r["meditate_days"] / total)
		cols["c30"].append(cur[0])
		cols["c90"].append(cur[2])
		cols["c180"].append(cur[5])
	print("  medians: stones d30/d90/d180 %d/%d/%d (curious %d/%d/%d), crafted %d, commissions got %d delivered %d, rank %d, renown %d" % [_median(cols["d30"]), _median(cols["d90"]), _median(cols["d180"]),
		_median(cols["c30"]), _median(cols["c90"]), _median(cols["c180"]), _median(cols["crafted"]), _median(cols["got"]), _median(cols["delivered"]), _median(cols["rank"]), _median(cols["renown"])])
	print("  medians: days gathering %d%% / crafting %d%% / meditating %d%%; weeks stuck (no hint, nothing to craft, nothing to deliver) median %d, max %d; of those the craft-now hint had faded (rank %d) in %d%%" % [_median(cols["gather"]), _median(cols["craft"]), _median(cols["meditate"]), _median(cols["stuck"]), cols["stuck"].max(), Guidance.CRAFT_HINT_MAX_RANK, 100 * _sum(cols["faded"]) / maxi(1, _sum(cols["stuck"]))])
	quit()


## One seeded crafter life: the counters dict.
func _crafter(seed_value: int, days: int) -> Dictionary:
	_gs.rng.seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c := CharacterFactory.create("Crafter", _gs.data, rng)
	_gs.start_session(c)
	_gs.pending_event = ""
	c.professions[PROF] = {"rank": 0, "xp": 0.0}
	Alchemy.grant_rank_recipes(c, _gs.data)
	var start: int = _clock.total_days
	var out := {"d30": 0, "d90": 0, "d180": 0, "crafted": 0, "got": 0, "delivered": 0, "rank": 0, "renown": 0, "gather_days": 0, "craft_days": 0, "meditate_days": 0, "stuck": 0, "faded": 0}
	var checkpoints := CHECKPOINTS.duplicate()
	while c.alive and _clock.total_days - start < days:
		var before: int = _clock.total_days
		_clear_pending()
		var kind := _act(c)
		if kind == "stuck":
			out["stuck"] += 1
			if Professions.rank_of(c, "alchemist") >= Guidance.CRAFT_HINT_MAX_RANK:
				out["faded"] += 1
			kind = "meditate"
		if _clock.total_days == before:  # a free action (selling, delivering) used no time: meditate the week
			kind = "meditate"
			_idle_week(c)
		out[kind + "_days"] += _clock.total_days - before
		while not checkpoints.is_empty() and _clock.total_days - start >= checkpoints[0]:
			out["d%d" % checkpoints[0]] = c.item_count("spirit_stone")
			checkpoints.pop_front()
	out["crafted"] = LifeStats.get_stat(c, "items_crafted")
	out["delivered"] = LifeStats.get_stat(c, "commissions_done")
	out["got"] = out["delivered"] + c.commissions.size()
	out["rank"] = Professions.rank_of(c, PROF)
	out["renown"] = Renown.value(c, REGION)
	return out


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
	var recipe_id := _best_craftable(c)
	if recipe_id != "":
		_gs.refine(recipe_id)
		_deliver_open(c)
		_sell_surplus(c)
		return "craft"
	if _gather_for_order(c) or _gather_hinted(c):
		return "gather"
	return "stuck" if Guidance.herb_here_hint(c, _gs.data, REGION) == "" else "meditate"


func _deliver_open(c: CharacterData) -> void:
	for i in range(c.commissions.size() - 1, -1, -1):
		if Commissions.check_deliver(c, _gs.data, i) == "":
			_gs.deliver_commission(i)


## Sells crafted output no open commission still wants.
func _sell_surplus(c: CharacterData) -> void:
	var wanted := {}
	for order in c.commissions:
		wanted[String(order["item"])] = true
	for recipe_id: String in Alchemy.known_recipes(c, _gs.data, PROF):
		var item_id := String(_gs.data.recipes[recipe_id]["output"]["item"])
		var great := String(_gs.data.recipes[recipe_id].get("great_output", {}).get("item", ""))
		for id in [item_id, great]:
			if id != "" and not wanted.has(id) and c.item_count(id) > 0:
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
		if String(recipe["profession"]) != PROF or not Alchemy.knows(c, _gs.data, recipe_id) or int(recipe.get("min_rank", 0)) > Professions.rank_of(c, PROF):
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
