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


## C-368/C-374: in every season a named Qingshi villager's likes include at least one gift a newcomer gets in Qingshi
## (a Qingshi shop's stock, a forage item or a jetty catch in that season; likes may be item ids or tags); teachers need two.
func test_qingshi_villagers_have_gifts_within_reach() -> void:
	var region: Dictionary = {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	var regions: Array = raw["regions"] if raw is Dictionary and raw.has("regions") else raw
	for r: Dictionary in regions:
		if String(r["id"]) == "qingshi_village":
			region = r
	for pass_index: int in 2:
		# C-375: pass 1 ignores weather-gated catches and forage; autumn villagers need >= 2 likes that way
		var dry: bool = pass_index == 1
		for season: String in (["autumn"] if dry else ["spring", "summer", "autumn", "winter"]):
			_check_qingshi_season(region, season, dry)


func _check_qingshi_season(region: Dictionary, season: String, dry: bool) -> void:
	var entries: Array = []  # item ids or tags a newcomer can get this season
	for place: Dictionary in region.get("places", []):
		if place.get("festival_only", "") != "":
			continue
		entries.append_array(place.get("stock_tags", []))
		for e: Dictionary in place.get("rotating_stock", {}).get("pool", []):
			entries.append(String(e["item"]))
		for e: Dictionary in place.get("catch_table", []):
			if String(e["item"]) != "" and not e.has("requires_flag") and (not e.has("seasons") or e["seasons"].has(season)) and (not e.has("weather") or (not dry and (region["weather"][season] as Dictionary).has_all(e["weather"]))):
				entries.append(String(e["item"]))
		for e: Dictionary in place.get("gather_table", []):
			if String(e["item"]) != "" and (not e.has("seasons") or e["seasons"].has(season)):
				entries.append(String(e["item"]))
	for e: Dictionary in region.get("forage", {}).get("items", []):
		if (not e.has("seasons") or e["seasons"].has(season)) and (not e.has("weather") or (not dry and (region["weather"][season] as Dictionary).has_all(e["weather"]))):
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
		assert_true(reachable >= (2 if (teaches or dry) else 1), "%s has %d likes within reach in Qingshi in %s%s" % [npc_id, reachable, season, " without rain" if dry else ""])


## C-373: each regional teacher (Peddler Hei, Bai, Ye, Qian) has at least two likes a newcomer can get in their own
## region in spring or summer (shop stock or tag, rotating pool, catch table or forage; likes may be item ids or tags).
func test_regional_teachers_have_gifts_within_reach() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	var regions: Array = raw["regions"] if raw is Dictionary and raw.has("regions") else raw
	for pair: Array in [["peddler_hei", "withered_bone_marsh"], ["disciple_bai", "azure_peak"], ["alchemist_ye", "myriad_peaks_ridge"], ["broker_qian", "fallen_star_market"]]:
		var region: Dictionary = {}
		for r: Dictionary in regions:
			if String(r["id"]) == String(pair[1]):
				region = r
		var entries: Array = []
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
		var reachable := 0
		for like: String in data().npcs[pair[0]].get("likes", []):
			var hit: bool = entries.has(like)
			for item_id: String in data().items:
				if entries.has(item_id) and (item_id == like or (data().items[item_id].get("tags", []) as Array).has(like)):
					hit = true
			if hit:
				reachable += 1
		assert_true(reachable >= 2, "%s has %d likes within reach in %s" % [pair[0], reachable, pair[1]])


## C-384: table-driven over the four away-from-home teachers and all four seasons: each has >= 2 distinct likes a newcomer
## can get in their own region that season (shop stock tag, rotating pool, catch or gather table without a flag gate, forage).
func test_regional_teachers_have_gifts_in_every_season() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))
	var regions: Array = raw["regions"] if raw is Dictionary and raw.has("regions") else raw
	var table: Array = [["peddler_hei", "withered_bone_marsh"], ["disciple_bai", "azure_peak"], ["alchemist_ye", "myriad_peaks_ridge"], ["broker_qian", "fallen_star_market"]]
	for pair: Array in table:
		var region: Dictionary = {}
		for r: Dictionary in regions:
			if String(r["id"]) == String(pair[1]):
				region = r
		for season: String in ["spring", "summer", "autumn", "winter"]:
			var entries: Array = []
			for place: Dictionary in region.get("places", []):
				if place.get("festival_only", "") != "":
					continue
				entries.append_array(place.get("stock_tags", []))
				for e: Dictionary in place.get("rotating_stock", {}).get("pool", []):
					entries.append(String(e["item"]))
				for table_key: String in ["catch_table", "gather_table"]:
					for e: Dictionary in place.get(table_key, []):
						if String(e["item"]) != "" and not e.has("requires_flag") and (not e.has("seasons") or e["seasons"].has(season)):
							entries.append(String(e["item"]))
			for e: Dictionary in region.get("forage", {}).get("items", []):
				if not e.has("seasons") or e["seasons"].has(season):
					entries.append(String(e["item"]))
			var reachable := 0
			for like: String in data().npcs[pair[0]].get("likes", []):
				var hit: bool = entries.has(like)
				for item_id: String in data().items:
					if entries.has(item_id) and (item_id == like or (data().items[item_id].get("tags", []) as Array).has(like)):
						hit = true
				if hit:
					reachable += 1
			assert_true(reachable >= 2, "%s has %d likes within reach in %s in %s" % [pair[0], reachable, pair[1], season])


## C-393: each first-hour fighting-style teacher has a once-only favor errand (favor >= 10, a `result` line) under their own
## deed_context, so the favor gap to their lesson closes in about a week.
func test_every_style_teacher_has_a_favor_errand() -> void:
	for npc_id: String in ["hunter_ma", "xiao_ling", "peddler_hei", "disciple_bai", "alchemist_ye", "broker_qian"]:
		var context: String = String(data().npcs[npc_id].get("deed_context", ""))
		var found := false
		for deed_id: String in data().deeds:
			var deed: Dictionary = data().deeds[deed_id]
			if String(deed.get("context", "")) == context and deed.get("once", false) and (deed.get("favor", {}) as Dictionary).get(npc_id, 0) >= 10 and int(deed.get("days", 9)) <= 2 and String(deed.get("result", "")) != "":
				found = true
		assert_true(found, "%s has no once-only favor errand (>= 10 favor, <= 2 days)" % npc_id)
