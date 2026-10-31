extends Interactable
## A rentable village field (FARM-001): rent it, plant a carried herb, harvest when ripe.
## The rules and numbers live in FieldPlots and the place's regions.json entry.


func get_options() -> Array[Dictionary]:
	var data := GameState.data
	var place := FieldPlots.place_def(data, GameState.current_region)
	if place.is_empty():
		return []
	var plot_key := FieldPlots.key(GameState.current_region, place)
	var today := GameClock.total_days
	var info := "\n".join(FieldPlots.describe(GameState.player, data, place, plot_key, today))
	var weather := Weather.of(data, GameState.current_region, today)
	var dry := FieldPlots.dry_note(GameState.player, place, plot_key, today, weather)
	if dry != "":
		info = dry + "\n" + info
	var options: Array[Dictionary] = []
	var rent_reason := FieldPlots.check_rent(GameState.player, place, plot_key, today)
	var rent_label := "Rent the field (%d stones, %s)" % [int(place["rent"]), Calendar.format_duration(int(place["rent_days"]))]
	options.append({"label": rent_label, "description": info, "action": GameState.rent_field, "disabled": rent_reason != "", "reason": rent_reason, "keep_open": true})
	for item_id in FieldPlots.plantable(place):
		if GameState.player.item_count(item_id) < 1:
			continue
		var reason := FieldPlots.check_plant(GameState.player, data, place, plot_key, item_id, today)
		var name := String(data.items.get(item_id, {}).get("name", item_id))
		var note := FieldPlots.season_note(place, item_id)
		var label := "Plant %s" % name if FieldPlots.in_season(place, item_id, today) or note == "" else "Plant %s (%s)" % [name, note]
		options.append({"label": label, "description": info, "action": GameState.plant_field.bind(item_id), "disabled": reason != "", "reason": reason, "keep_open": true})
	var water_reason := FieldPlots.check_water(GameState.player, place, plot_key, today, weather)
	options.append({"label": "Water the field", "icon": HudIcons.tool_glyph("watering_can"), "description": info, "action": GameState.water_field, "disabled": water_reason != "", "reason": water_reason, "keep_open": true})
	var nourish_reason := FieldPlots.check_nourish(GameState.player, place, plot_key, today)
	options.append({"label": "Nourish with qi (%d qi)" % FieldPlots.nourish_cost(place), "description": info, "action": GameState.nourish_field, "disabled": nourish_reason != "", "reason": nourish_reason, "keep_open": true})
	if int(place.get("expand_cost", 0)) > 0 and not bool(GameState.player.field_plots.get(plot_key, {}).get("expanded", false)):
		var expand_reason := FieldPlots.check_expand(GameState.player, place, plot_key, today)
		options.append({"label": "Enlarge the field (%d stones, %d plots)" % [int(place["expand_cost"]), int(place["max_plots"])], "icon": HudIcons.tool_glyph("hoe"), "description": info, "action": GameState.expand_field, "disabled": expand_reason != "", "reason": expand_reason, "keep_open": true})
	for crop: Dictionary in GameState.player.field_plots.get(plot_key, {}).get("crops", []):
		if int(crop["days_left"]) <= 0:
			options.append({"label": "Harvest", "description": info, "action": GameState.harvest_field, "keep_open": true})
			break
	return options


func _ready() -> void:
	super()
	EventBus.player_changed.connect(queue_redraw)
	GameClock.days_advanced.connect(func(_days: int) -> void: queue_redraw())


## Soil by state (bare tilled / rented with a rope marker), a plant per crop by growth stage, frost in a frozen season.
func draw_generated_art() -> bool:
	var rect := Rect2(-size / 2.0, size)
	var place := FieldPlots.place_def(GameState.data, GameState.current_region)
	var plot_key := FieldPlots.key(GameState.current_region, place) if not place.is_empty() else ""
	var today := GameClock.total_days
	var rented := not place.is_empty() and GameState.player != null and FieldPlots.rented(GameState.player, plot_key, today)
	var soil := color if rented else color.lightened(0.12)
	draw_rect(rect, soil)
	draw_rect(rect, Color(0.16, 0.11, 0.07), false, 2.0)
	for i in 4:
		var y := rect.position.y + 8.0 + i * (size.y - 14.0) / 3.0
		draw_line(Vector2(rect.position.x + 4.0, y), Vector2(rect.end.x - 4.0, y), soil.darkened(0.3), 2.0)
	if place.is_empty() or GameState.player == null:
		return true
	if rented:  # rope marker along the edges
		var rope := Color("c9b27a")
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
			draw_rect(Rect2(corner - Vector2(2, 2), Vector2(4, 4)), rope)
		draw_line(rect.position + Vector2(2, 2), Vector2(rect.end.x - 2, rect.position.y + 2), rope, 1.0)
		draw_line(Vector2(rect.position.x + 2, rect.end.y - 2), rect.end - Vector2(2, 2), rope, 1.0)
	var crops: Array = GameState.player.field_plots.get(plot_key, {}).get("crops", [])
	var slots := maxi(1, int(place.get("plots", 1)))
	for i in mini(crops.size(), slots):
		var crop: Dictionary = crops[i]
		var base := Vector2(rect.position.x + size.x * (i + 1.0) / (slots + 1.0), rect.position.y + size.y * 0.65)
		var total := FieldPlots.crop_total_days(place, String(crop["item"]))
		_draw_crop(base, FieldPlots.growth_stage(int(crop["days_left"]), total), String(crop["item"]))
	if FieldPlots.is_frozen(place, today):
		draw_rect(rect, Color(0.8, 0.9, 1.0, 0.3))
	return true


func _draw_crop(base: Vector2, stage: int, item_id: String) -> void:
	var px := float(Sprites.scale())  # GFX-033: line weights and the fruit follow the pixel scale
	var green := Color("8fd16a") if stage < 2 else Color("5fae44")
	var height: float = crop_height(stage)
	draw_line(base, base + Vector2(0, -height), green, px)
	if stage >= 1:
		draw_line(base + Vector2(0, -height * 0.5), base + Vector2(-5, -height * 0.8), green, px)
		draw_line(base + Vector2(0, -height * 0.5), base + Vector2(5, -height * 0.8), green, px)
	if stage >= 2:
		draw_line(base + Vector2(0, -height * 0.8), base + Vector2(-7, -height), green, px)
		draw_line(base + Vector2(0, -height * 0.8), base + Vector2(7, -height), green, px)
	if stage == 3:
		var tint: Color = ItemIcon.TINTS[absi(item_id.hash()) % ItemIcon.TINTS.size()]
		draw_rect(Rect2(base + Vector2(-px, -height - 2 * px), Vector2(2 * px + 1, 2 * px + 1)), tint)


## World-pixel height of a crop by growth stage 0..3: sprouts 4-6 px, ripe about a villager's head (16).
static func crop_height(stage: int) -> float:
	return [5.0, 9.0, 14.0, 16.0][clampi(stage, 0, 3)]
