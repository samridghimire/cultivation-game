extends TestCase
## C-403: every start region (and Misty Forest) has >= 2 named villagers who work.

const REGIONS := ["qingshi_village", "withered_bone_marsh", "azure_peak", "myriad_peaks_ridge", "fallen_star_market", "misty_forest"]


func test_each_region_has_two_workers() -> void:
	var d := data()
	for region in REGIONS:
		var n := 0
		for id in d.npcs:
			var def: Dictionary = d.npcs[id]
			var act := String(def.get("activity", ""))
			if def.get("region", "") == region and act != "" and act != "sit":
				n += 1
		assert_true(n >= 2, "%s has %d working named NPCs" % [region, n])

