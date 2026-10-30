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
	var options: Array[Dictionary] = []
	var rent_reason := FieldPlots.check_rent(GameState.player, place, plot_key, today)
	var rent_label := "Rent the field (%d stones, %s)" % [int(place["rent"]), Calendar.format_duration(int(place["rent_days"]))]
	options.append({"label": rent_label, "description": info, "action": GameState.rent_field, "disabled": rent_reason != "", "reason": rent_reason, "keep_open": true})
	for item_id in FieldPlots.plantable(place):
		if GameState.player.item_count(item_id) < 1:
			continue
		var reason := FieldPlots.check_plant(GameState.player, data, place, plot_key, item_id, today)
		var name := String(data.items.get(item_id, {}).get("name", item_id))
		options.append({"label": "Plant %s" % name, "description": info, "action": GameState.plant_field.bind(item_id), "disabled": reason != "", "reason": reason, "keep_open": true})
	for crop: Dictionary in GameState.player.field_plots.get(plot_key, {}).get("crops", []):
		if int(crop["days_left"]) <= 0:
			options.append({"label": "Harvest", "description": info, "action": GameState.harvest_field, "keep_open": true})
			break
	return options


func _ready() -> void:
	super()
	EventBus.player_changed.connect(queue_redraw)


## Tilled earth with furrows, and a sprout (or a full plant when ripe) for each crop.
func draw_generated_art() -> bool:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, color)
	draw_rect(rect, Color(0.16, 0.11, 0.07), false, 2.0)
	for i in 4:
		var y := rect.position.y + 8.0 + i * (size.y - 14.0) / 3.0
		draw_line(Vector2(rect.position.x + 4.0, y), Vector2(rect.end.x - 4.0, y), color.darkened(0.3), 2.0)
	var place := FieldPlots.place_def(GameState.data, GameState.current_region)
	if place.is_empty() or GameState.player == null:
		return true
	var crops: Array = GameState.player.field_plots.get(FieldPlots.key(GameState.current_region, place), {}).get("crops", [])
	for i in crops.size():
		var base := Vector2(rect.position.x + size.x * (i + 1.0) / (crops.size() + 1.0), 0.0)
		var ripe := int(crops[i]["days_left"]) <= 0
		var green := Color("6fbf4a") if ripe else Color("8fd16a")
		var height := 14.0 if ripe else 6.0
		draw_line(base, base + Vector2(0, -height), green, 3.0)
		draw_line(base + Vector2(0, -height * 0.6), base + Vector2(-5, -height), green, 2.0)
		draw_line(base + Vector2(0, -height * 0.6), base + Vector2(5, -height), green, 2.0)
	return true
