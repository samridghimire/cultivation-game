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


## QA-036: family guidance. A married Qi Refining character with a child and a clan.
func _household(child_age: int, rootless: bool) -> Dictionary:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	c.age_days = 25 * Calendar.DAYS_PER_YEAR
	var people := {}
	var spouse := Npcs.spawn(people, d, seeded_rng(), {"gender": "female" if c.gender == "male" else "male", "region": "qingshi_village"})
	spouse.age_days = 24 * Calendar.DAYS_PER_YEAR
	Family.marry(c, spouse, Family.ranks(d, c.gender)[0])
	var child := Npcs.spawn(people, d, seeded_rng(), {"region": "qingshi_village"})
	child.age_days = child_age * Calendar.DAYS_PER_YEAR
	if rootless:
		child.spiritual_roots = {}
	c.children.append(child.id)
	return {"c": c, "people": people, "spouse": spouse, "child": child}


func _family_lines(c: CharacterData, people: Dictionary, flags: Dictionary = {}) -> Array[String]:
	var d := data()
	var out: Array[String] = []
	for h: String in Guidance.hints(c, d, 1.0, 99, people, flags, "qingshi_village"):
		out.append(h)
	for e: Dictionary in Guidance.journal(c, d, flags, 100, "qingshi_village", 1.0, people):
		if e.get("section", "") == "Household":
			out.append(String(e.get("text", "")))
	return out


func test_household_lines_name_real_people_and_possible_actions() -> void:
	var d := data()
	for age: int in [0, 3, 6, 10, 14, 18, 30]:
		for rootless: bool in [false, true]:
			var h := _household(age, rootless)
			var c: CharacterData = h["c"]
			var people: Dictionary = h["people"]
			var child: CharacterData = h["child"]
			var label := "child age %d rootless %s" % [age, rootless]
			for line in _family_lines(c, people):
				if line.contains(child.name):
					# Training/teaching claims: the child must be able to take some training or lesson.
					if line.contains("trained or taught"):
						var can := false
						for id: String in Training.assignments(d):
							can = can or Training.check_assign(c, child, id, "alchemist", d) == ""
						for tech_id: String in c.techniques.keys():
							can = can or Training.check_teach(c, child, tech_id, d) == ""
						assert_true(can, "%s: '%s' but nothing can be done" % [label, line])
				if line.contains("try for a child with"):
					assert_true(line.contains((h["spouse"] as CharacterData).name), label + ": " + line)
					assert_eq(Children.check_conception(c, h["spouse"], d), "", label + ": conception blocked: " + line)
