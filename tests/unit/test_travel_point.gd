extends TestCase
## TravelPoint.destination_note: what waits at the other end of a road (WU-319).

const HUD := preload("res://src/ui/hud.gd")


func test_note_names_qi_and_best_spot() -> void:
	var c := new_character()
	var note := TravelPoint.destination_note(c, data(), "azure_peak", {})
	assert_true(note.contains("x2.5"), note)
	assert_true(note.contains("Cloud-Sea Cliff x5"), note)


func test_unvisited_region_has_no_places_list() -> void:
	var c := new_character()
	var note := TravelPoint.destination_note(c, data(), "misty_forest", {})
	assert_true(note.begins_with("Qi x"), note)
	assert_false(note.contains("Merchant") or note.contains("clinic"), note)


func test_visited_region_lists_places_under_limit() -> void:
	var c := new_character()
	c.visited_regions.append("qingshi_village")
	var note := TravelPoint.destination_note(c, data(), "qingshi_village", {})
	assert_true(note.contains("Merchant"), note)
	assert_true(note.length() < 90, note)


func test_every_note_fits_when_all_regions_visited() -> void:
	var c := new_character()
	for region_id: String in data().regions:
		c.visited_regions.append(region_id)
	for region_id: String in data().regions:
		var note := TravelPoint.destination_note(c, data(), region_id, {})
		assert_true(note.length() <= 90, "%s: %s" % [region_id, note])


## QI-003: the arrival card, travel note, map line and HUD quote one number.
func test_one_qi_number_everywhere() -> void:
	var d := data()
	var flags := {"shrine_restored": true, "shrine_incense": {"until": 99}}
	var density := Exploration.effective_density(d, "qingshi_village", flags, 10)
	assert_almost_eq(density, Exploration.qi_density(d, "qingshi_village", flags, 10), 0.0001)
	var shown := Exploration.format_density(density)
	var c := new_character()
	var sub := HUD.arrival_subtitle(c, d, "qingshi_village", density, "Calm", false)
	assert_true(sub.begins_with("Qi x%s " % shown), sub)
	var note := TravelPoint.destination_note(c, d, "qingshi_village", flags, [])
	assert_true(note.begins_with("Qi x"), note)
	assert_true(WorldMapScreen.qi_line(d, "qingshi_village", flags, []).begins_with("Qi density x%s" % shown))


func test_effective_density_includes_world_events() -> void:
	var d := data()
	var base := Exploration.effective_density(d, "qingshi_village", {}, 0)
	assert_almost_eq(base, Exploration.qi_density(d, "qingshi_village", {}, 0), 0.0001)


func test_format_density() -> void:
	assert_eq(Exploration.format_density(1.0), "1")
	assert_eq(Exploration.format_density(1.05), "1.05")
	assert_eq(Exploration.format_density(1.5), "1.5")
	assert_eq(Exploration.format_density(2.0), "2")
	assert_eq(Exploration.format_density(2.7500001), "2.75")
	assert_eq(Exploration.format_density(1.049), "1.05")
