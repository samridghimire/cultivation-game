extends Interactable
## A claimable cave abode (data/regions.json region "abodes", G-010b).
## Strangers see "Claim" (Abodes.check_claim reason when disabled). The owner
## cultivates in seclusion, opens the storage chest (an in-menu picker) and
## gets the artifact anchor entries; owned abodes are outlined in gold.

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
	options.append({"label": "Cultivate in seclusion (%s, qi x%s)" % [Calendar.format_duration(SECLUSION_DAYS), String.num(density, 2)], "action": GameState.cultivate_in_seclusion.bind(SECLUSION_DAYS), "keep_open": true})
	options.append({"label": "Open the storage chest (%d / %d kinds)" % [p.abode_storage.size(), Abodes.storage_slots(p, data)], "action": _set_chest_mode.bind(true), "keep_open": true})
	return options


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
	if reason != "":
		label += " (%s)" % reason
	return {"label": label, "action": action, "disabled": reason != "", "keep_open": true}


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
		# A small doorway marks a dwelling.
		draw_rect(Rect2(Vector2(-8, size.y / 2.0 - 22), Vector2(16, 22)), color.darkened(0.6))
