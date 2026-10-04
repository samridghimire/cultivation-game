extends TestCase
## FAM-007b: bloodlines shown on the character sheet, in the family list and
## in an NPC's "Look" description.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_bonus_text_lists_each_bonus() -> void:
	assert_eq(CharacterSheet.bloodline_bonus_text(data(), "azure_dragon"), "+15% cultivation speed, +10% attack")
	assert_eq(CharacterSheet.bloodline_bonus_text(data(), "black_tortoise"), "+10% health, +20% defense")
	assert_eq(CharacterSheet.bloodline_bonus_text(data(), "nope"), "")


func test_family_links_show_kin_bloodlines() -> void:
	var me := new_character()
	var child := new_character(7)
	child.id = "kid"
	child.name = "Lin Bao"
	child.bloodline = "azure_dragon"
	me.children.append(child.id)
	var lines := Family.describe_links(me, {child.id: child}, data())
	assert_true(lines[0].contains("Azure Dragon Bloodline (dormant until"), lines[0])
	child.bloodline = ""
	assert_false(Family.describe_links(me, {child.id: child}, data())[0].contains("Bloodline"))


func test_look_shows_only_awakened_bloodlines() -> void:
	var npc := new_character(9)
	npc.bloodline = "white_tiger"
	assert_false(Npcs.describe(npc, data()).contains("White Tiger"), "dormant bloodlines are hidden")
	npc.bloodline_awakened = true
	assert_true(Npcs.describe(npc, data()).contains("bearing the awakened White Tiger Bloodline"), Npcs.describe(npc, data()))


func test_character_sheet_shows_player_bloodline() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	var sheet := CharacterSheet.new()
	sheet._rebuild()
	assert_false(sheet._text.text.contains("Bloodline:"))
	c.bloodline = "white_tiger"
	c.bloodline_awakened = true
	sheet._rebuild()
	assert_true(sheet._text.text.contains("Bloodline: White Tiger Bloodline (awakened)"), sheet._text.text)
	assert_true(sheet._text.text.contains("Grants: +15% attack, +10% speed"))
	sheet.free()
