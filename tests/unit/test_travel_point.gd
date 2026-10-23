extends TestCase
## TravelPoint.destination_note: what waits at the other end of a road (WU-319).


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
