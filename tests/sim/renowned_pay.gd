extends SceneTree
## Renowned-request pay (QA-080): for every encounter with `min_renown`, its best
## choice's spirit stones (and items' resale value) next to the median weekly
## gather income of the regions sharing its tags, at the encounter's min realm.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/renowned_pay.gd

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var data := GameData.load_from_dir()
	print("== Renowned requests vs a week of gathering")
	print("%-26s %-18s %-8s %-8s %-8s %-7s" % ["encounter", "realm", "pay", "week", "ratio", "region"])
	for e: Dictionary in data.encounters.values():
		if not e.has("min_renown"):
			continue
		var realm_id := String(e.get("min_realm", "mortal"))
		var c := CharacterData.new()
		c.realm_index = data.realm_index_of(realm_id)
		var pay := _pay(e, data)
		for rid: String in data.regions:
			var region: Dictionary = data.regions[rid]
			var shared := false
			for t in e.get("tags", []):
				if t in region.get("encounter_tags", []):
					shared = true
			if not shared:
				continue
			var week := _median_week(c, data, region)
			print("%-26s %-18s %-8.0f %-8.0f %-8.2f %s" % [e["id"], realm_id, pay, week, pay / maxf(week, 0.001), rid])
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
