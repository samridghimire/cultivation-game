extends TestCase
## VIS-001: the player's placeholder look follows sect, alignment and realm.


func _character() -> CharacterData:
	return CharacterFactory.create("Look", data(), seeded_rng())


func test_rogue_mortal_has_default_robe_and_no_aura() -> void:
	var c := _character()
	c.sect = {}
	c.realm_index = 0
	c.alignment = 0
	var look := PlayerLook.of(c, data())
	assert_eq(look["robe"], PlayerLook.ROGUE_ROBE)
	assert_eq(look["sash"], PlayerLook.SASH_COLORS["neutral"])
	assert_eq(look["aura_rings"], 0)


func test_sect_members_wear_the_sect_robe() -> void:
	var c := _character()
	for sect: SectDef in data().sects.values():
		c.sect = {"id": sect.id, "rank": 0, "contribution": 0}
		assert_eq(PlayerLook.of(c, data())["robe"], Color(sect.robe_color), sect.id)


func test_every_sect_has_a_valid_robe_color() -> void:
	for sect: SectDef in data().sects.values():
		assert_true(Color.html_is_valid(sect.robe_color), "%s robe_color" % sect.id)


func test_sash_follows_alignment_tier() -> void:
	var c := _character()
	c.alignment = data().alignment_min
	assert_eq(PlayerLook.of(c, data())["sash"], PlayerLook.SASH_COLORS["demonic"])
	c.alignment = data().alignment_max
	assert_eq(PlayerLook.of(c, data())["sash"], PlayerLook.SASH_COLORS["righteous"])


func test_aura_grows_with_realm_and_caps() -> void:
	var c := _character()
	c.realm_index = 1
	var low := PlayerLook.of(c, data())
	assert_eq(low["aura_rings"], 1)
	assert_eq(low["aura"], PlayerLook.AURA_LOW)
	c.realm_index = 99
	var high := PlayerLook.of(c, data())
	assert_eq(high["aura_rings"], PlayerLook.MAX_AURA_RINGS)
	assert_true((high["aura"] as Color).is_equal_approx(PlayerLook.AURA_HIGH), "gold aura at the cap")


func test_rank_trim_by_sect_rank() -> void:
	var c := _character()
	c.sect = {}
	assert_eq(PlayerLook.of(c, data())["trim"].a, 0.0)
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	assert_eq(PlayerLook.of(c, data())["trim"].a, 0.0)
	for r in [1, 2, 3, 5]:
		c.sect["rank"] = r
		assert_eq(PlayerLook.of(c, data())["trim"], PlayerLook.RANK_TRIM[mini(r, 3) - 1], "rank %d" % r)


func test_pixel_figure_shows_trim_and_caches() -> void:
	var base := {"robe": Color("3060a0"), "sash": Color("9a9a9a")}
	var trimmed := base.duplicate()
	trimmed["trim"] = PlayerLook.RANK_TRIM[0]
	var a := PixelFigure.frame(base, "down", 0)
	var b := PixelFigure.frame(trimmed, "down", 0)
	assert_true(a != b)
	assert_true(PixelFigure.frame(trimmed, "down", 0) == b)
	var hem_differs := false
	for x in 16:
		if a.get_image().get_pixel(x, 17) != b.get_image().get_pixel(x, 17):
			hem_differs = true
	assert_true(hem_differs, "hem row takes the trim colour")
