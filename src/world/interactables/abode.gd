extends Interactable
## A claimable cave abode (data/regions.json region "abodes", G-010b).
## Strangers see "Claim" (Abodes.check_claim reason when disabled). The owner
## cultivates in seclusion, sets up or packs up gathering arrays (G-006b),
## tempers their body (BODY-001c), founds their clan here (FAM-005d), opens the
## storage chest (an in-menu picker) and gets the artifact anchor entries;
## owned abodes are outlined in gold, and the clan seat shows the estate's
## built buildings as small huts beside it.

const MeditationSpot := preload("res://src/world/interactables/meditation_spot.gd")

const SECLUSION_DAYS := 30

@export var abode_id := ""

## True while the menu shows the storage chest instead of the main entries.
var _chest_mode := false


func is_owned() -> bool:
	return GameState.player != null and GameState.player.abode == abode_id


func menu_options() -> Array[Dictionary]:
	# Anchor entries (Interactable.menu_options) only for the owner.
	if is_owned() and not _chest_mode:
		return super.menu_options()
	return get_options()


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	if p == null:
		return options
	if not is_owned():
		_chest_mode = false
		var cost := int(Abodes.get_def(data, abode_id).get("cost", 0))
		var reason := Abodes.check_claim(p, data, abode_id, GameState.current_region)
		var label := "Claim this abode (%d spirit stones)" % cost
		if p.abode != "" and p.abode != abode_id:
			label += ", leaving %s" % Abodes.abode_name(data, p.abode)
		options.append(_entry(label, reason, GameState.claim_abode.bind(abode_id)))
		return options
	if _chest_mode:
		return _chest_options(p, data)
	var density := Abodes.seclusion_density(p, data, GameState.current_region)
	var seat := density * ClanEstate.seat_qi_multiplier(GameState.clan, data, p.abode)
	options.append({"label": "Cultivate in seclusion (%s, qi x%s)" % [Calendar.format_duration(SECLUSION_DAYS), String.num(density, 2)], "description": GameState.meditation_preview(SECLUSION_DAYS, seat), "action": GameState.cultivate_in_seclusion.bind(SECLUSION_DAYS), "keep_open": true})
	options.append_array(_array_options(p, data))
	var temper := MeditationSpot._temper_option()
	if not temper.is_empty():
		options.append(temper)
	if GameState.clan == null:
		var found_label := "Found the %s here (%d spirit stones)" % [Clans.clan_name(p, data), int(Clans.rules(data).get("found_cost", 0))]
		options.append(_entry(found_label, Clans.check_found(p, GameState.clan, data), GameState.found_clan))
	options.append({"label": "Open the storage chest (%d / %d kinds)" % [p.abode_storage.size(), Abodes.storage_slots(p, data)], "action": _set_chest_mode.bind(true), "keep_open": true})
	return options


## "Pack up <array>" for the array set up here, then "Set up <array>" per
## carried array item with its qi bonus (Abodes.check_place_array reasons).
func _array_options(p: CharacterData, data: GameData) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if p.abode_array != "":
		options.append(_entry("Pack up the %s (+%d%% qi density)" % [_item_name(data, p.abode_array), _bonus_percent(data, p.abode_array)], "", GameState.remove_abode_array))
	for item_id in _sorted(p.inventory, data):
		if Abodes.array_def(data, item_id).is_empty():
			continue
		var label := "Set up the %s (+%d%% qi density)" % [_item_name(data, item_id), _bonus_percent(data, item_id)]
		if p.abode_array != "" and p.abode_array != item_id:
			label += ", replacing the %s" % _item_name(data, p.abode_array)
		options.append(_entry(label, Abodes.check_place_array(p, data, GameState.current_region, item_id), GameState.place_abode_array.bind(item_id)))
	return options


static func _bonus_percent(data: GameData, item_id: String) -> int:
	return roundi(float(Abodes.array_def(data, item_id).get("qi_density_bonus", 0.0)) * 100.0)


## Called by ChoiceMenu when it closes, so the next visit starts at the main entries.
func on_menu_closed() -> void:
	_chest_mode = false


## "Take out" per stored stack, then "Put away" per carried stack, then Back.
func _chest_options(p: CharacterData, data: GameData) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var region := GameState.current_region
	for item_id in _sorted(p.abode_storage, data):
		var count := int(p.abode_storage[item_id])
		options.append(_entry("Take out %s x%d" % [_item_name(data, item_id), count], "", GameState.retrieve_from_abode.bind(item_id, count)))
	for item_id in _sorted(p.inventory, data):
		var count := p.item_count(item_id)
		var reason := Abodes.check_store(p, data, region, item_id, count)
		options.append(_entry("Put away %s x%d" % [_item_name(data, item_id), count], reason, GameState.store_in_abode.bind(item_id, count)))
	options.append({"label": "Close the chest (%d / %d kinds)" % [p.abode_storage.size(), Abodes.storage_slots(p, data)], "action": _set_chest_mode.bind(false), "keep_open": true})
	return options


func _set_chest_mode(on: bool) -> void:
	_chest_mode = on


func _entry(label: String, reason: String, action: Callable) -> Dictionary:
	return {"label": label, "action": action, "disabled": reason != "", "reason": reason, "keep_open": true}


static func _sorted(items: Dictionary, data: GameData) -> Array:
	var ids: Array = items.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return _item_name(data, a).naturalnocasecmp_to(_item_name(data, b)) < 0)
	return ids


static func _item_name(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("name", item_id))


func _draw() -> void:
	super._draw()
	if is_owned():
		draw_rect(Rect2(-size / 2.0 - Vector2(4, 4), size + Vector2(8, 8)), UIStyle.ACCENT, false, 3.0)
	_draw_estate()


## The clan seat shows one small hut per built estate building (FAM-006b),
## taller the higher its level, in rows of four beside the abode.
func _draw_estate() -> void:
	var clan: ClanData = GameState.clan
	if clan == null or clan.seat != abode_id:
		return
	var built := 0
	for building_id in ClanEstate.building_ids(GameState.data):
		var lvl := ClanEstate.level(clan, building_id)
		if lvl <= 0:
			continue
		var h := 14.0 + 6.0 * lvl
		@warning_ignore("integer_division")
		var base := Vector2(size.x / 2.0 + 14.0 + 24.0 * (built % 4), size.y / 2.0 + 38.0 * (built / 4))
		built += 1
		draw_rect(Rect2(base + Vector2(0, -h), Vector2(18, h)), Color("b08a5a"))
		draw_rect(Rect2(base + Vector2(0, -h), Vector2(18, h)), PlaceArt.OUTLINE, false, 1.5)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-3, -h), base + Vector2(9, -h - 9), base + Vector2(21, -h)]), Color("5a3a2a"))
