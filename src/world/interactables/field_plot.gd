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


func _on_days_advanced(_days: int) -> void:
	queue_redraw()


func _ready() -> void:
	super()
	EventBus.player_changed.connect(queue_redraw)
	GameClock.days_advanced.connect(_on_days_advanced)


## Soil by state (bare tilled / rented with a rope marker), a plant per crop by growth stage, frost in a frozen season.
func draw_generated_art() -> bool:
	var rect := Rect2(-size / 2.0, size)
	var place := FieldPlots.place_def(GameState.data, GameState.current_region)
	var plot_key := FieldPlots.key(GameState.current_region, place) if not place.is_empty() else ""
	var today := GameClock.total_days
	var rented := not place.is_empty() and GameState.player != null and FieldPlots.rented(GameState.player, plot_key, today)
	var crops_now: Array = GameState.player.field_plots.get(plot_key, {}).get("crops", []) if not place.is_empty() and GameState.player != null else []
	var stage := -1  # GFX-143: the plot's most advanced crop (empty = bare furrows)
	for crop: Dictionary in crops_now:
		stage = maxi(stage, FieldPlots.growth_stage(int(crop["days_left"]), FieldPlots.crop_total_days(place, String(crop["item"]))))
	var no_snow := bool(GameState.data.regions.get(GameState.current_region, {}).get("map", {}).get("no_snow", false))
	var season := Calendar.season_of(GameClock.total_days)
	var lay := Scenery.plot_layout(rect, hash("%s|%s" % [plot_key, size]), season, stage, no_snow)
	var soil := color if rented else color.lightened(0.12)
	var outline: PackedVector2Array = lay["outline"]
	draw_colored_polygon(outline, soil.darkened(0.15))
	var vertical: bool = lay["vertical"]
	for row: Dictionary in lay["rows"]:
		var band: Rect2 = row["rect"]
		draw_rect(band, soil.darkened(0.4) if bool(row["dark"]) else soil.lightened(0.05))
		if bool(row["dark"]) and bool(lay["snow"]):
			draw_rect(band.grow_individual(0, -1, 0, -1) if not vertical else band.grow_individual(-1, 0, -1, 0), Color(0.92, 0.96, 1.0, 0.8))
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Color(0.16, 0.11, 0.07), 2.0)
	for strip: Rect2 in lay["border"]:  # a low wattle fence on one or two sides only
		draw_rect(strip, Color("7a5a38"))
		draw_rect(Rect2(strip.position, Vector2(strip.size.x, 1.0)) if strip.size.x > strip.size.y else Rect2(strip.position, Vector2(1.0, strip.size.y)), Color("a8814e"))
		if bool(lay["snow"]):
			draw_rect(Rect2(strip.position, Vector2(strip.size.x, 1.0)) if strip.size.x > strip.size.y else Rect2(strip.position, Vector2(1.0, strip.size.y)), Color(0.94, 0.97, 1.0))
	var cstyle: String = lay["crop_style"]
	var ccolor: Color = lay["crop_color"]
	var ch := {"sprout": 3.0, "young": 5.0, "leafy": 7.0, "ripe": 8.0}.get(cstyle, 0.0) as float
	for p: Vector2 in lay["crops"]:
		draw_rect(Rect2(p + Vector2(-1.5, -ch), Vector2(3, ch)), ccolor)
		draw_rect(Rect2(p + Vector2(-1.5, -ch), Vector2(3, 1.5)), ccolor.lightened(0.25))
	if rented:  # rope marker at the corners
		var rope := Color("c9b27a")
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
			draw_rect(Rect2(corner - Vector2(2, 2), Vector2(4, 4)), rope)
	if FieldPlots.is_frozen(place, GameClock.total_days) if not place.is_empty() else false:
		draw_rect(rect, Color(0.8, 0.9, 1.0, 0.2))
	return true


## World-pixel height of a crop by growth stage 0..3: sprouts 4-6 px, ripe about a villager's head (16).
static func crop_height(stage: int) -> float:
	return [5.0, 9.0, 14.0, 16.0][clampi(stage, 0, 3)]
