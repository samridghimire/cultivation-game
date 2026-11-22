## C-415: every named start-region villager has >= 2 valid tend_lines of their own (FOLK-043 format).
extends TestCase

const START_REGIONS: Array = ["qingshi_village", "misty_forest", "withered_bone_marsh", "fallen_star_market", "azure_peak", "myriad_peaks_ridge"]


func test_start_region_villagers_have_their_own_tend_lines() -> void:
	var seen := 0
	for npc_id: String in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		if not START_REGIONS.has(String(def.get("region", ""))):
			continue
		seen += 1
		var lines: Array = def.get("tend_lines", [])
		assert_true(lines.size() >= 2 and lines.size() <= 3, "%s needs 2-3 tend_lines" % npc_id)
		for l: Variant in lines:
			assert_true(l is String and String(l).length() >= 1 and String(l).length() <= 140, "%s has a bad tend line" % npc_id)
	assert_true(seen >= 18, "expected the named start-region villagers")
