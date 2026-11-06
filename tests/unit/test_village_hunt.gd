extends TestCase
## WILD-016: VillageHunt window math and ally.

func _gd() -> GameData:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data


func test_season_start() -> void:
	assert_eq(VillageHunt.season_start(189), 180)
	assert_eq(VillageHunt.season_start(180), 180)
	assert_eq(VillageHunt.season_start(269), 180)
	assert_eq(VillageHunt.season_start(270), 270)
	assert_eq(VillageHunt.season_start(0), 0)


func test_window_and_flags() -> void:
	var gd := _gd()
	assert_eq(VillageHunt.window_start(gd, "qingshi_village", 200), 189)
	assert_eq(VillageHunt.window_start(gd, "misty_forest", 200), -1, "no market there")
	var flags := {}
	assert_true(VillageHunt.active(gd, "qingshi_village", 189, flags))
	assert_true(VillageHunt.active(gd, "qingshi_village", 191, flags))
	assert_false(VillageHunt.active(gd, "qingshi_village", 192, flags))
	assert_true(VillageHunt.active(gd, "qingshi_village", 360 + 9, flags), "spring: the stag")
	VillageHunt.mark_done(flags, 190)
	assert_false(VillageHunt.active(gd, "qingshi_village", 190, flags))
	assert_true(VillageHunt.active(gd, "qingshi_village", 279, flags), "winter day 10 is a new season")


func test_ally_and_validate() -> void:
	var gd := _gd()
	var c := CharacterData.new()
	var a := VillageHunt.ally(c, gd, 0.15)
	assert_true(int(a["damage"]) >= 1)
	assert_eq(VillageHunt.validate(gd).size(), 0)
	assert_true(VillageHunt.notice(gd, "qingshi_village", 190).contains("mist fox"))


## WILD-017: calendar entry, hunter, notice.
func test_calendar_hunt_and_hunter() -> void:
	var gd := _gd()
	var flags := {}
	var e := VillageHunt.calendar_entry(gd, "qingshi_village", 189, flags)
	assert_eq(String(e.get("kind", "")), "hunt")
	assert_true(String(e["text"]).begins_with("Village hunt ("))
	assert_true(VillageHunt.calendar_entry(gd, "qingshi_village", 190, flags).is_empty(), "only on the hunt day")
	assert_true(VillageHunt.calendar_entry(gd, "misty_forest", 189, flags).is_empty(), "no hunt there")
	VillageHunt.mark_done(flags, 189)
	assert_true(VillageHunt.calendar_entry(gd, "qingshi_village", 189, flags).is_empty(), "done")
	var up := VillageCalendar.upcoming(gd, {}, {}, [], "qingshi_village", 188, 3, null, {})
	var found := false
	for x: Dictionary in up:
		if String(x["kind"]) == "hunt":
			found = true
	assert_true(found, "upcoming lists the hunt")
	var rem := VillageCalendar.reminders(gd, {}, {}, [], "qingshi_village", 188, null, {})
	assert_true(" ".join(rem).contains("Village hunt"), "reminder the day before")
	var npc := CharacterData.new()
	npc.id = "villager_x"
	npc.name = "Old Bo"
	npc.home_region = "qingshi_village"
	var npcs := {"villager_x": npc}
	assert_true(VillageHunt.hunter_of(npcs, gd, "qingshi_village") == null, "no flag, no hunter")
	gd.npcs["villager_x"] = {"id": "villager_x", "hunter": true}
	assert_true(VillageHunt.hunter_of(npcs, gd, "qingshi_village") == npc)
	assert_true(VillageHunt.notice(gd, "qingshi_village", 190, npcs).contains("Hunter Old Bo leads the village hunters"))
	npc.alive = false
	assert_true(VillageHunt.hunter_of(npcs, gd, "qingshi_village") == null, "dead hunters do not lead")
	gd.npcs.erase("villager_x")


## C-309: every season has a hunt quarry on its first market day, led by a named hunter.
func test_every_season_has_a_quarry() -> void:
	var gd := _gd()
	var want := ["fog_antler_stag", "wild_boar", "mist_fox", "den_wolf"]
	for i in 4:
		var day := i * 90
		var ws := VillageHunt.window_start(gd, "qingshi_village", day)
		assert_true(ws >= day and ws < day + 90, "market day in season %d" % i)
		assert_eq(VillageHunt.quarry(gd, "qingshi_village", ws), want[i])
	var hunters := 0
	for n: Dictionary in gd.npcs.values():
		if n.get("region") == "qingshi_village" and bool(n.get("hunter", false)):
			hunters += 1
	assert_eq(hunters, 1)
