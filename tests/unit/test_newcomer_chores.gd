extends TestCase
## C-402: every repeatable chore fight a newcomer is offered (no requirement, not a rescue) rates Easy (>= 0.7)
## for a day-7 Mortal with no style and starter gear, and each early region keeps at least one.

const REGION_CHORES: Dictionary = {
	"qingshi_village": "chore_drive_off_boar",
	"misty_forest": "chore_chase_lunch_monkeys",
	"fallen_star_market": "chore_clear_yard_dogs",
	"azure_peak": "chore_drive_stair_goats",
	"withered_bone_marsh": "chore_scrape_boardwalk_leeches",
	"myriad_peaks_ridge": "chore_scatter_cairn_crows",
}


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_every_newcomer_chore_fight_rates_easy() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Newcomer", gs.data, seeded_rng(9))
	gs.start_session(c)
	for id: String in gs.data.deeds:
		var deed: Dictionary = gs.data.deeds[id]
		if not id.begins_with("chore_") or not deed.has("enemy") or not Dictionary(deed.get("requires", {})).is_empty():
			continue
		var foe: Dictionary = gs.data.enemies[String(deed["enemy"])]
		var odds := Combat.win_chance(c, gs.data, foe)
		assert_true(odds >= 0.7, "%s (%s) rates %.2f for a newcomer, needs >= 0.7" % [id, deed["enemy"], odds])
	gs.end_session()


func test_each_early_region_keeps_a_fight_chore() -> void:
	var gs := _root().get_node("GameState")
	for region: String in REGION_CHORES:
		var deed: Dictionary = gs.data.deeds.get(REGION_CHORES[region], {})
		assert_true(deed.has("enemy"), "%s keeps fight chore %s" % [region, REGION_CHORES[region]])
	gs.end_session()
