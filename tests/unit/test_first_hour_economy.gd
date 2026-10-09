extends TestCase

const Balance := preload("res://tests/sim/combat_balance.gd")
## FH-020: a newcomer in Qingshi Village can earn and craft without leaving, and every sect has a safe rank-0 mission.


func _region_places(region_id: String) -> Array:
	return data().regions.get(region_id, {}).get("places", [])


func test_some_qingshi_alchemy_recipe_is_fully_obtainable_in_village() -> void:
	var places := _region_places("qingshi_village")
	assert_gt(places.size(), 0, "qingshi_village places found")
	var obtainable := {}
	for place: Dictionary in places:
		if place.get("type", "") == "merchant":
			for id: String in Items.shop_stock(data(), int(place.get("max_price", 0)), place.get("stock_tags", [])):
				obtainable[id] = true
		elif place.get("type", "") == "gather":
			for entry: Dictionary in place.get("gather_table", []):
				if entry.get("item", "") != "" and not entry.has("min_realm"):
					obtainable[entry["item"]] = true
	var found := false
	for recipe: Variant in data().recipes.values():
		if recipe["profession"] != "alchemist" or int(recipe["min_rank"]) > 0 or not recipe.get("starter", false):
			continue
		var all_ok := true
		for ing: String in recipe["ingredients"]:
			if not obtainable.has(ing):
				all_ok = false
		found = found or all_ok
	assert_true(found, "a rank-0 starter alchemy recipe has all ingredients available in Qingshi")


func test_every_sect_has_safe_rank0_mission() -> void:
	for sect_id: String in data().sects:
		var ok := false
		for m: Variant in data().sect_missions.values():
			var sects: Array = m.get("sects", [])
			if (sects.is_empty() or sects.has(sect_id)) and int(m.get("min_rank", 0)) == 0:
				var enemy: String = m.get("enemy", "")
				if enemy == "" or not data().enemies[enemy].get("lethal", true):
					ok = true
		assert_true(ok, "%s has a safe rank-0 mission" % sect_id)


## QA-032: gate-stage-1 hunts that a bare (no extra techniques) newcomer cannot win; the typical player can.
const QA032_BARE_DEADLY := ["cull_mist_wolves", "patrol_misty_peaks", "answer_azure_call", "answer_blood_lotus_call"]

## FH-024/FH-026: missions are always fought, so a Qi Refining mission with an enemy must not
## be a likely death for the first-hour player (starter technique, Qingshi iron sword and scale armor) at
## the mission's own min_realm / min_stage.
func test_qi_refining_mission_fights_are_weak_or_even_for_newcomers() -> void:
	for m: Variant in data().sect_missions.values():
		if String(m.get("enemy", "")) == "":
			continue
		var is_early := int(m.get("min_rank", 0)) == 0 or String(m.get("min_realm", "mortal")) == "qi_refining"
		if not is_early:
			continue
		var c := new_character(31)
		c.realm_index = maxi(0, data().realm_index_of(String(m.get("min_realm", "mortal"))))
		c.stage = int(m.get("min_stage", 0))
		c.techniques["basic_breathing"] = {"level": 1, "xp": 0.0}
		c.equipment = {"weapon": "iron_sword", "armor": "iron_scale_armor"}
		var label := Combat.danger_label(c, data(), data().enemies[String(m["enemy"])])
		var gate_stage := int(m.get("min_stage", 0))
		# QA-032: a bare newcomer may find the early hunts Dangerous at their gate (never Deadly
		# unless the sect call/hunt is a listed exception); the typical-player test below is the yardstick.
		assert_true(label != "Deadly" or QA032_BARE_DEADLY.has(String(m["id"])), "%s is %s for a newcomer at its min stage" % [m["id"], label])


## QA-032: the early hunts and sect calls must be a real fight, not a walkover, for the typical
## player (simulate_combat.gd's yardstick) at their own gate: 60-95% win rate.
func test_early_hunt_missions_are_a_fair_fight_for_the_typical_player() -> void:
	for mission_id in ["cull_mist_wolves", "patrol_misty_peaks", "answer_azure_call", "answer_blood_lotus_call"]:
		var m: Dictionary = data().sect_missions[mission_id]
		var c := Balance.typical_player(data(), maxi(0, data().realm_index_of(String(m["min_realm"]))), int(m.get("min_stage", 0)))
		var rate := Balance.win_rate(c, data(), data().enemies[String(m["enemy"])], 300)
		assert_true(rate >= 0.6 and rate <= 0.95, "%s win rate %.2f should be 60-95%%" % [mission_id, rate])
