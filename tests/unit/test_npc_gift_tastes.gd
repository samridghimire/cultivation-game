## C-058: every named NPC has gift tastes, and most are satisfiable from the shops.
extends TestCase


func test_every_named_npc_likes_something() -> void:
	for npc_id in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		assert_true(not (def.get("likes", []) as Array).is_empty(), "%s likes nothing" % npc_id)


func test_a_like_never_doubles_as_a_dislike() -> void:
	for npc_id in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		for entry in def.get("likes", []):
			assert_false((def.get("dislikes", []) as Array).has(entry), "%s both likes and dislikes %s" % [npc_id, entry])


## C-284: every named NPC has >= 2 likes, at most 2 dislikes and one cheap village gift among the likes.
func test_every_named_npc_has_a_full_set_of_tastes() -> void:
	var cheap: Array = ["herb", "moon_cake", "paper_lantern", "boar_roast", "venison_broth", "food", "fish"]
	for npc_id in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		var likes: Array = def.get("likes", [])
		assert_true(likes.size() >= 2, "%s has fewer than 2 likes" % npc_id)
		assert_true((def.get("dislikes", []) as Array).size() <= 2, "%s has more than 2 dislikes" % npc_id)
		var has_cheap := false
		for entry in likes:
			if cheap.has(entry) or String(entry).ends_with("_loach") or String(entry).ends_with("_bream"):
				has_cheap = true
		assert_true(has_cheap, "%s likes no cheap village gift" % npc_id)


## C-368: a named Qingshi villager's likes include at least one gift a newcomer gets in Qingshi in spring or summer
## (a Qingshi shop's stock, a forage item or a jetty catch; likes may be item ids or tags); teachers need two.
func test_qingshi_villagers_have_gifts_within_reach() -> void:
	var region: Dictionary = {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	var regions: Array = raw["regions"] if raw is Dictionary and raw.has("regions") else raw
	for r: Dictionary in regions:
		if String(r["id"]) == "qingshi_village":
			region = r
	var entries: Array = []  # item ids or tags a newcomer can get
	for place: Dictionary in region.get("places", []):
		if place.get("festival_only", "") != "":
			continue
		entries.append_array(place.get("stock_tags", []))
		for e: Dictionary in place.get("rotating_stock", {}).get("pool", []):
			entries.append(String(e["item"]))
		for e: Dictionary in place.get("catch_table", []):
			if String(e["item"]) != "" and not e.has("requires_flag") and (not e.has("seasons") or e["seasons"].has("spring") or e["seasons"].has("summer")):
				entries.append(String(e["item"]))
	for e: Dictionary in region.get("forage", {}).get("items", []):
		if not e.has("seasons") or e["seasons"].has("spring") or e["seasons"].has("summer"):
			entries.append(String(e["item"]))
	var ids: Dictionary = {}
	for e: String in entries:
		ids[e] = true
		for item_id: String in data().items:
			if (data().items[item_id].get("tags", []) as Array).has(e):
				ids[item_id] = true
	for npc_id: String in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		if String(def.get("region", "")) != "qingshi_village":
			continue
		var reachable := 0
		for like: String in def.get("likes", []):
			var hit: bool = ids.has(like)
			if not hit:
				for item_id: String in ids:
					if data().items.has(item_id) and (data().items[item_id].get("tags", []) as Array).has(like):
						hit = true
			if hit:
				reachable += 1
		var teaches := not Npcs.teachings(npc_id, CharacterData.new(), data(), 0).is_empty()
		assert_true(reachable >= (2 if teaches else 1), "%s has %d likes within reach in Qingshi" % [npc_id, reachable])
