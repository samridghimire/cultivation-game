extends SceneTree
## Renowned-request pay (QA-080, QA-084): for every encounter with `min_renown`, its best
## choice's spirit stones (and items' resale value) next to the median weekly
## gather income of the regions sharing its tags, at the encounter's min realm, a week of
## the best-paying profession's work (rank 1, attribute 10) and the median net stones of the
## sect missions open at that realm. The ratio is against the best of the three, and the
## last column is the pay that would be 1.5x a week of that best income.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/renowned_pay.gd

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var data := GameData.load_from_dir()
	print("== Renowned requests vs a week of gathering")
	var work := _best_work_week(data)
	print("work week (rank 1, attribute 10): %.1f stones (%s)" % [work[0], work[1]])
	print("%-26s %-18s %-6s %-7s %-6s %-8s %-6s %-6s %-7s %s" % ["encounter", "realm", "pay", "gather", "work", "mission", "ratio", "vs-gat", "rec1.5x", "region"])
	for e: Dictionary in data.encounters.values():
		if not e.has("min_renown"):
			continue
		var realm_id := String(e.get("min_realm", "mortal"))
		var c := CharacterData.new()
		c.realm_index = data.realm_index_of(realm_id)
		var pay := _pay(e, data)
		var mission := _median_mission(data, c.realm_index)
		for rid: String in data.regions:
			var region: Dictionary = data.regions[rid]
			var shared := false
			for t in e.get("tags", []):
				if t in region.get("encounter_tags", []):
					shared = true
			if not shared:
				continue
			var week := _median_week(c, data, region)
			var best := maxf(week, maxf(float(work[0]), mission))
			print("%-26s %-18s %-6.0f %-7.0f %-6.0f %-8.0f %-6.2f %-6.2f %-7.0f %s" % [e["id"], realm_id, pay, week, work[0], mission, pay / maxf(best, 0.001), pay / maxf(week, 0.001), best * 1.5, rid])
	quit()


## Stones plus resale value of the items in the best-paying choice (or effects).
func _pay(e: Dictionary, data: GameData) -> float:
	var best := _effects_value(e.get("effects", {}), data)
	for ch: Dictionary in e.get("choices", []):
		best = maxf(best, _effects_value(ch.get("effects", {}), data))
	return best


func _effects_value(fx: Dictionary, data: GameData) -> float:
	var v := 0.0
	for id: String in fx.get("items", {}):
		var n := int(fx["items"][id])
		v += n * (1.0 if id == "spirit_stone" else float(Items.sell_price(data, id)))
	return v


func _median_week(c: CharacterData, data: GameData, region: Dictionary) -> float:
	var vals: Array[float] = []
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
		vals.append(value / maxf(total, 0.001) / maxi(1, int(place.get("gather_days", 1))) * 7.0)
	if vals.is_empty():
		return 0.0
	vals.sort()
	return vals[vals.size() / 2]


## [stones for 7 days of the best-paying profession at rank 1 / attribute 10, its id].
func _best_work_week(data: GameData) -> Array:
	var best := 0.0
	var best_id := ""
	for pid: String in data.professions:
		var c := CharacterData.new()
		c.attributes[data.professions[pid].primary_attribute] = 10
		c.professions[pid] = {"rank": 1, "xp": 0.0}
		var r := Professions.work(c, data, pid, 7)
		if float(r["income"]) > best:
			best = float(r["income"])
			best_id = pid
	return [best, best_id]


## Median net stones (rewards valued like gathered items, minus handed-in items)
## of the sect missions whose min_realm is at or below `realm_index`.
func _median_mission(data: GameData, realm_index: int) -> float:
	var vals: Array[float] = []
	for m: Dictionary in data.sect_missions.values():
		if data.realm_index_of(String(m.get("min_realm", "mortal"))) > realm_index:
			continue
		var v := _effects_value(m.get("rewards", {}), data)
		for id: String in m.get("requires", {}).get("items", {}):
			v -= int(m["requires"]["items"][id]) * float(Items.sell_price(data, id))
		vals.append(v)
	if vals.is_empty():
		return 0.0
	vals.sort()
	return vals[vals.size() / 2]
