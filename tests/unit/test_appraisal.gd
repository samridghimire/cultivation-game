extends TestCase
## ART-003a: the Creation Artifact's Appraising Eye.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _seer() -> CharacterData:
	var c := new_character()
	c.artifact_functions.append(Appraisal.FUNCTION)
	return c


func _target() -> CharacterData:
	var c := new_character()
	c.name = "Xu Lian"
	c.spiritual_roots = {"water": 80}
	c.attributes = {"constitution": 11, "comprehension": 14, "spirit": 12, "fortune": 9, "charisma": 10}
	c.realm_index = data().realm_index_of("qi_refining")
	c.stage = 2
	c.alignment = -300
	return c


func test_sealed_until_unlocked() -> void:
	var blind := new_character()
	assert_false(Appraisal.is_available(blind))
	assert_true(Appraisal.check(blind, data()).contains("sealed"))
	assert_true(Appraisal.describe_npc(blind, _target(), data()).is_empty())
	assert_true(Appraisal.describe_item(blind, data(), "iron_sword").is_empty())
	var c := _seer()
	assert_true(Appraisal.is_available(c))
	assert_eq(Appraisal.check(c, data()), "")
	var without := GameData.new()
	without.artifact = {"functions": []}
	assert_true(Appraisal.check(c, without).contains("no appraising eye"))


func test_talent_tiers_name_every_root() -> void:
	assert_true(Appraisal.talent_tiers(data()).size() >= 2)
	assert_eq(Appraisal.talent_name(data(), 0.0), "Rootless")
	assert_eq(Appraisal.talent_name(data(), 100.0), String(Appraisal.talent_tiers(data())[-1]["name"]))
	var previous := ""
	for grade: Dictionary in data().root_grades:
		var multiplier := float(grade["cultivation_multiplier"]) * (0.5 + data().root_purity_max / 100.0)
		var name := Appraisal.talent_name(data(), multiplier)
		assert_true(name != "", "no talent tier for a %s" % grade["name"])
		assert_true(name != previous or previous == "", "%s shares a tier with the grade above it" % grade["name"])
		previous = name
	var rootless := new_character()
	rootless.spiritual_roots = {}
	assert_true(Appraisal.talent_label(rootless, data()).contains("cannot cultivate"))
	assert_true(Appraisal.talent_label(_target(), data()).contains("cultivation speed"))


func test_describe_npc_reveals_hidden_stats() -> void:
	var lines := Appraisal.describe_npc(_seer(), _target(), data())
	var text := "\n".join(lines)
	assert_true(text.contains("Spiritual Root: "), text)
	assert_true(text.contains(SpiritualRoots.describe(_target().spiritual_roots, data())))
	assert_true(text.contains("Talent: "))
	assert_true(text.contains("Realm: %s" % Cultivation.realm_label(_target(), data())))
	assert_true(text.contains("years of life left"))
	assert_true(text.contains("Comprehension 14"), text)
	assert_true(text.contains("Heart: %s (-300)" % Alignment.tier_name(-300, data())), text)
	assert_true(Appraisal.describe_npc(_seer(), null, data()).is_empty())


func test_describe_item_reveals_grade_and_worth() -> void:
	var c := _seer()
	var sword := "\n".join(Appraisal.describe_item(c, data(), "iron_sword"))
	assert_true(sword.contains("Grade"), sword)
	assert_true(sword.contains("attack"), sword)
	assert_true(sword.contains("Worth: %d spirit stones" % int(data().items["iron_sword"]["price"])), sword)
	var evil := "\n".join(Appraisal.describe_item(c, data(), "blood_drinker_saber"))
	assert_true(evil.contains("lifespan"), evil)
	var talisman := "\n".join(Appraisal.describe_item(c, data(), "fire_strike_talisman"))
	assert_true(talisman.contains("strike talisman"), talisman)
	assert_true(talisman.contains("%d at your realm" % CombatTalismans.amount(data(), "fire_strike_talisman")), talisman)
	var escape := "\n".join(Appraisal.describe_item(c, data(), "thousand_li_escape_talisman"))
	assert_true(escape.contains("escape"), escape)
	var priceless := "\n".join(Appraisal.describe_item(c, data(), "spirit_stone"))
	assert_true(priceless.contains("no merchant"), priceless)
	assert_true(Appraisal.describe_item(c, data(), "no_such_item").is_empty())


func test_validation() -> void:
	assert_true(Appraisal.validate(data()).is_empty())
	assert_true(ArtifactFunctions.validate(data()).is_empty())
	var missing_tiers := GameData.new()
	missing_tiers.artifact = {"functions": [{"id": "appraisal"}]}
	assert_eq(Appraisal.validate(missing_tiers).size(), 1)
	var bad := GameData.new()
	bad.artifact = {"functions": [{"id": "appraisal", "talent_tiers": [{"min_multiplier": 1.0, "name": "High"}, {"min_multiplier": 0.5}]}]}
	assert_eq(Appraisal.validate(bad).size(), 2, "a nameless tier and a tier out of order")


func test_game_state_unlocks_and_appraises() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Appraiser", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("qi_refining")
	assert_true(Appraisal.describe_npc(c, c, gs.data).is_empty(), "sealed at the start")
	var cost := int(ArtifactFunctions.get_def(gs.data, Appraisal.FUNCTION)["unlock"]["energy"])
	c.add_item("spirit_stone", cost)
	gs.feed_artifact("spirit_stone", cost)
	gs.unlock_artifact_function(Appraisal.FUNCTION)
	assert_true(Appraisal.is_available(c))
	var npc: CharacterData = gs.npcs.values()[0]
	assert_false(Appraisal.describe_npc(c, npc, gs.data).is_empty(), "an NPC can be read")
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_true(Appraisal.is_available(gs.player), "the unsealed eye survives a save")
	gs.end_session()


## ART-003c: the appraising eye shows up in NPC Look, the inventory and shops.
func test_appraisal_surfaces_in_the_ui() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	c.inventory = {"iron_sword": 1}
	var rival: CharacterData = Rivals.rival_of(c, gs.npcs)
	var npc: Node = load("res://src/world/interactables/npc.gd").new()
	npc.npc_id = rival.id
	var posted: Array = []
	var cb := func(text: String, _cat: String) -> void: posted.append(text)
	var bus := root.get_node("EventBus")
	bus.message_posted.connect(cb)
	npc._look()
	assert_false(posted.any(func(t: String) -> bool: return t.begins_with("Appraisal:")), "sealed: nothing extra")
	c.artifact_functions.append("appraisal")
	npc._look()
	bus.message_posted.disconnect(cb)
	assert_true(posted.any(func(t: String) -> bool: return t.begins_with("Appraisal:") and t.contains("Talent:")), str(posted))
	npc.free()
	var inv := InventoryScreen.new()
	root.add_child(inv)
	inv.open()
	assert_true(inv._effects.text.contains("Appraisal: Grade"), inv._effects.text)
	inv.free()
	gs.end_session()


## ART-008: danger labels carry the odds once the eye is unsealed.
func test_danger_text_shows_odds_only_when_unsealed() -> void:
	var d := data()
	var enemy: Dictionary = d.enemies[d.enemies.keys()[0]]
	var blind := new_character()
	assert_eq(Appraisal.danger_text(blind, d, enemy), Combat.danger_label(blind, d, enemy))
	var seer := _seer()
	var text := Appraisal.danger_text(seer, d, enemy)
	assert_true(text.begins_with(Combat.danger_label(seer, d, enemy)))
	assert_true(text.contains("%"))
	var pct := int(text.get_slice("(", 1).trim_suffix("%)"))
	assert_eq(pct % 5, 0)
