extends TestCase
## QA-038: shop fuzz. A mid-game character holding loot of every category opens
## every merchant place of every region in the ShopScreen, switches Buy/Sell and
## every category tab and presses Sell all twice. Checks: stones gained equal the
## total the button showed, protected goods (worn gear, manuals, breakthrough
## pills, readied talismans) are never sold, the list and empty text agree.

func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _build(gs: Node) -> CharacterData:
	var c := CharacterFactory.create("Shopper", gs.data, seeded_rng(38), "male")
	c.spiritual_roots = {"fire": 70, "wood": 50}
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.stage = 3
	c.inventory = {"spirit_stone": 500}
	for item_id: String in gs.data.items:
		if item_id != "spirit_stone":
			c.add_item(item_id, 3)
	for item_id: String in gs.data.items:
		if Equipment.is_equipment(gs.data, item_id) and not c.equipment.has(Equipment.slot_of(gs.data, item_id)):
			if Equipment.equip_warning(c, gs.data, item_id) == "":
				c.equipment[Equipment.slot_of(gs.data, item_id)] = item_id
	for item_id: String in gs.data.items:
		if gs.data.items[item_id].get("combat", {}).size() > 0:
			CombatTalismans.ready_talisman(c, gs.data, item_id)
	return c


func _protected(c: CharacterData, data: GameData) -> Dictionary:
	var kept := {}
	for item_id: String in c.inventory:
		var item: Dictionary = data.items[item_id]
		if c.equipment.values().has(item_id) or c.readied_talismans.has(item_id) \
				or Items.category(item) == "Manuals & Scrolls" \
				or float(item.get("effects", {}).get("breakthrough_bonus", 0.0)) > 0.0:
			kept[item_id] = c.item_count(item_id)
	return kept


func _merchants(gs: Node) -> Array:
	var out: Array = []
	for rid: String in gs.data.regions:
		for p: Dictionary in gs.data.regions[rid].get("places", []):
			if p.get("type", "") == "merchant":
				out.append(p)
	return out


func _focus_ok(screen: ShopScreen) -> bool:
	var owner := screen.get_viewport().gui_get_focus_owner()
	return owner == null or screen.is_ancestor_of(owner)


func test_every_merchant_survives_tab_and_sell_all_fuzz() -> void:
	var gs := _gs()
	var merchants := _merchants(gs)
	assert_gt(merchants.size(), 5)
	var paid_total := 0
	for place: Dictionary in merchants:
		var c := _build(gs)
		var who := String(place.get("display_name", "?"))
		var screen := ShopScreen.new()
		(Engine.get_main_loop() as SceneTree).root.add_child(screen)
		screen.open(who, int(place.get("max_price", 0)), place.get("stock_tags", []), String(place.get("faction", "")), place.get("buy_tags", []))
		for selling in [false, true]:
			if selling and screen._sell_tab.disabled:
				continue
			screen._set_tab(selling)
			for cat: String in ShopScreen.categories_in(gs.data, screen.item_ids()):
				screen._set_category(cat)
				var ids := screen.visible_ids()
				var rows := 0
				for child in screen._list.get_children():
					if child is Button and not child.is_queued_for_deletion():
						rows += 1
				assert_eq(rows, ids.size(), "%s %s/%s: rows vs ids" % [who, "sell" if selling else "buy", cat])
				if ids.is_empty():
					assert_true(screen._selected == "", "%s: selection with empty list" % who)
		if not screen._sell_tab.disabled:
			screen._set_tab(true)
			var loot := screen._loot_ids()
			var shown := Items.bulk_sell_total(c, gs.data, loot)
			var kept := _protected(c, gs.data)
			var before := c.item_count("spirit_stone")
			paid_total += shown
			assert_gt(c.readied_talismans.size(), 0, "setup readies talismans")
			assert_gt(kept.size(), 3, "setup holds protected goods")
			screen._sell_all()
			screen._sell_all()
			assert_eq(c.item_count("spirit_stone") - before, shown, "%s: sell all paid what it showed" % who)
			for item_id: String in kept:
				assert_eq(c.item_count(item_id), int(kept[item_id]), "%s: protected %s sold" % [who, item_id])
			screen._sell_all()
			screen._sell_all()
			assert_eq(c.item_count("spirit_stone") - before, shown, "%s: second sell all paid again" % who)
			assert_false(screen._sell_all_button.visible and Items.bulk_sell_total(c, gs.data, screen._loot_ids()) == 0, "%s: sell all button with nothing to sell" % who)
		screen.close()
		screen.free()
		gs.end_session()
	assert_gt(paid_total, 0, "some merchant bought loot")
