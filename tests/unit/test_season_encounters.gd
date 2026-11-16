extends TestCase
## C-376: every season has newcomer-reachable seasonal encounters, so the year feels different.

const NEWCOMER_TAGS: Array[String] = ["village", "forest", "wild", "road"]
const NEW_IDS: Array[String] = [
	"village_spring_kite_day", "road_spring_swollen_ford", "village_summer_firefly_night", "village_summer_hailstorm",
	"village_autumn_persimmon_harvest", "wild_autumn_migrating_geese", "forest_winter_frozen_pond", "road_winter_snowbound_traveller",
]


func test_each_season_has_two_newcomer_season_encounters() -> void:
	for season: String in ["spring", "summer", "autumn", "winter"]:
		var n := 0
		for id: String in NEW_IDS:
			var e: Dictionary = data().encounters[id]
			if (e["seasons"] as Array).has(season):
				n += 1
		assert_eq(n, 2, "%s has two new season encounters" % season)
		var reachable := 0
		for e: Dictionary in data().encounters.values():
			if not (e.get("seasons", []) as Array).has(season):
				continue
			if data().realm_index_of(String(e.get("min_realm", "mortal"))) > data().realm_index_of("qi_refining"):
				continue
			for t: String in e.get("tags", []):
				if NEWCOMER_TAGS.has(t):
					reachable += 1
					break
		assert_true(reachable >= 2, "%s has >= 2 newcomer-reachable season encounters (%d)" % [season, reachable])


func test_new_season_encounters_are_small_and_once_only() -> void:
	for id: String in NEW_IDS:
		var e: Dictionary = data().encounters[id]
		assert_true(String(e["text"]).length() <= 420, "%s text fits" % id)
		assert_true(String(e.get("scene", "")) != "" and String(e.get("figure", "")) != "", "%s has a scene and a figure" % id)
		assert_true(String(e.get("blocked_by_flag", "")) != "", "%s happens once" % id)
		assert_false(e.has("min_realm") and data().realm_index_of(String(e["min_realm"])) > data().realm_index_of("qi_refining"), "%s is for newcomers" % id)
		assert_eq((e["choices"] as Array).size(), 2, "%s has two choices" % id)
		for choice: Dictionary in e["choices"]:
			var fx: Dictionary = choice.get("effects", {})
			assert_eq(String(fx.get("set_flag", "")), String(e["blocked_by_flag"]), "%s choice sets its flag" % id)
			assert_true(int(fx.get("villager_favor", 0)) <= 3, "%s favor stays small" % id)
			assert_true(int(fx.get("items", {}).get("spirit_stone", 0)) <= 10, "%s stones stay small" % id)
