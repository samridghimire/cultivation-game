extends TestCase
## QA-034: every Guidance hint must be actionable: named sects admit the player (or
## are only promised for a later realm), named people live where the hint says,
## named keys are bound, and a pill the hint points at can be afforded.

const SEEDS := [1, 2, 3, 4, 5]


func _profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for gender: String in data().names.get("given_names", {}).keys():
		for s: int in SEEDS:
			var c := CharacterFactory.create("Tester Han", data(), seeded_rng(s), gender)
			out.append({"label": "fresh %s seed %d" % [gender, s], "c": c, "region": "qingshi_village", "flags": {}})
	var rogue := new_character()
	rogue.realm_index = 1
	rogue.stage = 2
	out.append({"label": "QR3 rogue", "c": rogue, "region": "qingshi_village", "flags": {"talked_elder_mo": true}})
	var disciple := new_character()
	disciple.realm_index = 1
	disciple.stage = 2
	for sect: SectDef in data().sects.values():
		if Sects.check_join(disciple, data(), sect.id)["ok"]:
			Sects.join(disciple, data(), sect.id)
			break
	out.append({"label": "QR3 disciple", "c": disciple, "region": "qingshi_village", "flags": {"talked_elder_mo": true}})
	return out


func _sect_names_in(text: String) -> Array[SectDef]:
	var found: Array[SectDef] = []
	for sect: SectDef in data().sects.values():
		if text.contains(sect.name):
			found.append(sect)
	return found


func test_hints_are_actionable() -> void:
	var d := data()
	for p: Dictionary in _profiles():
		var c: CharacterData = p["c"]
		var label: String = p["label"]
		for h: String in Guidance.hints(c, d, 1.0, 99, {}, p["flags"], p["region"]):
			_check_sects(c, d, h, label)
			_check_people(d, h, label)
			_check_keys(h, label)
			_check_pill(c, d, h, label)


func _check_sects(c: CharacterData, d: GameData, h: String, label: String) -> void:
	if not c.is_rogue():
		return
	var named := _sect_names_in(h)
	if named.is_empty():
		return
	for sect in named:
		var ok: bool = Sects.check_join(c, d, sect.id)["ok"]
		if h.contains("will take you"):
			# Promised for Qi Refining: must be true for a character who reached it.
			var probe := CharacterData.from_dict(c.to_dict())
			probe.realm_index = maxi(c.realm_index, d.realm_index_of(sect.min_realm))
			ok = ok or Sects.check_join(probe, d, sect.id)["ok"]
			if h.contains(sect.name + " takes mortals now"):
				ok = Sects.check_join(c, d, sect.id)["ok"]
		assert_true(ok, "%s: hint names %s but it will not admit you: %s" % [label, sect.name, h])


func _check_people(d: GameData, h: String, label: String) -> void:
	var re := RegEx.create_from_string("(?:Ask|Talk to) ([A-Z][\\w ]+?) in ([A-Z][\\w ]+?)(?: where|\\.|,)")
	for m in re.search_all(h):
		var found := false
		for npc: Dictionary in d.npcs.values() if d.npcs is Dictionary else d.npcs:
			if String(npc.get("name", "")) == m.get_string(1):
				var region: Dictionary = d.regions.get(String(npc.get("region", "")), {})
				found = String(region.get("name", "")) == m.get_string(2)
		assert_true(found, "%s: hint names %s in %s but they are not there: %s" % [label, m.get_string(1), m.get_string(2), h])
	if h.contains("Headman Zhou"):
		var region: Dictionary = d.regions.get(Guidance.CHORE_REGION, {})
		var here: bool = region.get("places", []).any(func(pl: Dictionary) -> bool: return pl.get("display_name", "") == "Headman Zhou")
		assert_true(here, label + ": Headman Zhou is not in " + Guidance.CHORE_REGION)


func _check_keys(h: String, label: String) -> void:
	if h.contains("Inventory, I)"):
		assert_true(InputConfig.KEYS["toggle_inventory"].has(KEY_I), label + ": inventory is not bound to I: " + h)


func _check_pill(c: CharacterData, d: GameData, h: String, label: String) -> void:
	if not h.contains("Sold at"):
		return
	for item: Dictionary in d.items.values():
		var item_name := String(item.get("name", ""))
		if item_name != "" and h.contains(item_name + " (+") and Items.sources(d, String(item["id"]))[0].begins_with("Sold at"):
			assert_true(c.item_count("spirit_stone") >= int(item.get("price", 0)) or c.realm_index > 1, "%s: hint sends you to buy %s (%d) beyond your means: %s" % [label, item_name, int(item.get("price", 0)), h])
