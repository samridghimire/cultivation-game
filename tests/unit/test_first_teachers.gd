## C-414: every start region has a local basic_breathing teacher and a mortal fighting style, both in dialogue.
extends TestCase

const START_REGIONS: Array = ["qingshi_village", "misty_forest", "withered_bone_marsh", "fallen_star_market", "azure_peak", "myriad_peaks_ridge"]


## Technique ids the named villagers of `region` teach through a dialogue choice.
func _taught_in(region: String) -> Array:
	var out: Array = []
	for npc_id: String in data().npcs:
		var def: Dictionary = data().npcs[npc_id]
		if String(def.get("region", "")) != region:
			continue
		var dlg: Dictionary = data().dialogues.get(String(def.get("dialogue", "")), {})
		for node: Variant in dlg.get("nodes", {}).values():
			for choice: Variant in (node as Dictionary).get("choices", []):
				var tech: String = String((choice as Dictionary).get("effects", {}).get("learn_technique", ""))
				if tech != "":
					out.append(tech)
	return out


func test_every_start_region_has_a_breathing_teacher() -> void:
	for region: String in START_REGIONS:
		assert_true(_taught_in(region).has("basic_breathing"), "%s has no local basic_breathing teacher" % region)


func test_every_start_region_has_a_mortal_fighting_style() -> void:
	for region: String in START_REGIONS:
		var found := false
		for tech_id: String in _taught_in(region):
			var tech: Variant = data().techniques.get(tech_id)
			if tech != null and tech.kind == "combat" and tech.min_realm == "mortal":
				found = true
		# A pedlar who sells the Iron Fist manual counts too.
		if not found and JSON.stringify(data().regions[region]).contains("manual_iron_fist"):
			found = true
		assert_true(found, "%s has no local mortal fighting style" % region)


## GUIDE-286: outside Qingshi the first-technique goal names the local teacher (free), not a manual purchase.
func test_goal_names_the_local_teacher() -> void:
	var c := CharacterData.new()
	c.realm_index = 1
	c.techniques = {}
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var names := {"withered_bone_marsh": "Old Monster Gui", "myriad_peaks_ridge": "Wen Qingxu", "azure_peak": "Hermit Gu"}
	for region: String in names:
		assert_eq(Guidance.local_first_teacher(c, data(), region, flags), names[region], region)
		assert_eq(Guidance.hud_goal_text(c, data(), flags, region, 10), "Learn your first technique: ask %s (free)" % names[region], region)
	assert_eq(Guidance.hud_goal_text(c, data(), flags, data().start_region, 10), "Learn your first technique", "Qingshi unchanged")


func test_known_breathing_gets_the_old_line() -> void:
	var c := CharacterData.new()
	c.realm_index = 1
	c.techniques = {"basic_breathing": {"level": 1, "xp": 0.0}}
	assert_eq(Guidance.local_first_teacher(c, data(), "myriad_peaks_ridge", {}), "")


## C-417: Misty Forest's charcoal burner sells the Iron Fist manual (15 stones) beside cheap forest goods.
func test_misty_forest_stall_sells_the_fist_manual() -> void:
	var stall: Dictionary = {}
	for place: Dictionary in data().regions["misty_forest"].get("places", []):
		if String(place.get("display_name", "")) == "Charcoal Burner's Stall":
			stall = place
	assert_false(stall.is_empty(), "stall exists")
	var ids: Array = Items.shop_stock(data(), int(stall.get("max_price", 0)), stall.get("stock_tags", []))
	assert_true(ids.has("manual_iron_fist"), "sells the manual")
	assert_eq(int(data().items["manual_iron_fist"]["price"]), 15)
	assert_true(ids.size() >= 3, "also cheap goods")
