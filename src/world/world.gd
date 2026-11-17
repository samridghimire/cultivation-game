extends Node2D
## The current region, built from data/regions.json: ground, paths and every
## interactable place. Travelling reloads this scene for the new region.
## Placeholder art is drawn in _draw().
## Running this scene directly (F6) starts a debug session automatically.

## Script for each place 'type' in data/regions.json.
const PLACE_SCRIPTS := {
	"meditation": preload("res://src/world/interactables/meditation_spot.gd"),
	"merchant": preload("res://src/world/interactables/merchant.gd"),
	"sect_hall": preload("res://src/world/interactables/sect_hall.gd"),
	"workshop": preload("res://src/world/interactables/workshop.gd"),
	"clinic": preload("res://src/world/interactables/clinic.gd"),
	"orphanage": preload("res://src/world/interactables/orphanage.gd"),
	"deed_giver": preload("res://src/world/interactables/deed_giver.gd"),
	"explore": preload("res://src/world/interactables/explore_site.gd"),
	"travel": preload("res://src/world/interactables/travel_point.gd"),
	"gather": preload("res://src/world/interactables/gather_site.gd"),
	"fishing": preload("res://src/world/interactables/fishing_spot.gd"),
	"field_plot": preload("res://src/world/interactables/field_plot.gd"),
	"secret_realm": preload("res://src/world/interactables/secret_realm_entrance.gd"),
	"auction": preload("res://src/world/interactables/auction_house.gd"),
	"bounty_board": preload("res://src/world/interactables/bounty_board.gd"),
	"inheritance": preload("res://src/world/interactables/inheritance_grounds.gd"),
	"shrine": preload("res://src/world/interactables/shrine.gd"),
	"well": preload("res://src/world/interactables/well.gd"),
	"coop": preload("res://src/world/interactables/coop.gd"),
}
## Place keys that are layout, not script properties.
const LAYOUT_KEYS := ["type", "pos"]
const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const ABODE_SCRIPT := preload("res://src/world/interactables/abode.gd")
const ROAMER_SCRIPT := preload("res://src/world/interactables/roamer.gd")
const FAMILY_HOME_SCRIPT := preload("res://src/world/interactables/family_home.gd")
## Placeholder body color of generated NPCs by gender.
const GENDER_COLORS := {"male": Color("8fb3e0"), "female": Color("e6a3c4")}

const CAMERA_MARGIN_TOP := 40
const CAMERA_MARGIN_BOTTOM := 60
var map_size := Vector2(1600, 1000)
## Canvas origin last seen by _process (WU-269).
var _last_canvas_origin := Vector2.INF
## Where the player stood when the name labels last faded (GFX-015).
var _last_label_pos := Vector2.INF
var _region: Dictionary = {}
## Scenery.place() output, drawn under everything else.
var _decor: Array[Dictionary] = []
## GFX-139: Scenery.undergrowth of the region's tree groves, drawn under the decor.
var _undergrowth: Array[Dictionary] = []
var _square: Dictionary = {}  ## GFX-131: Scenery.village_square of a map.square region, else empty
var _yards: Dictionary = {}  ## GFX-127: Scenery.village_yards of a map.yards region, else empty
var _market_dress: Dictionary = {}  ## GFX-126: Scenery.market_props of a map.market region, else empty
var _marsh: Dictionary = {}  ## GFX-125: Scenery.marsh_features of a bog region, else empty
## Seasonal tint (CanvasModulate only affects this canvas, not the HUD CanvasLayer).
var _season_tint: CanvasModulate
var _season := ""
var _relief: Array[Dictionary] = []  # GFX-109
var _crags: Array[Dictionary] = []  # GFX-123
var _edge: Array[Dictionary] = []  # GFX-110
var _ambient: Node
var _critters: CritterLayer  # GFX-086: hens, ducks, butterflies
var _cloud_wisps: CloudWisps  # GFX-113: drifting wisps over a mountain region (map.high.wisps)
var _mist_bands: MistBands  # GFX-091: drifting mist over misty regions
var _village_life: VillageLife
var _market_life: MarketLife  # GFX-119
var _water_life: WaterLife
var _rain_puddles: RainPuddles  ## GFX-184
var _spread_clock := 0.0  ## WU-429: seconds since the last label spread from a moving beast.
var _roamer_spread_pos := {}
var _tracks: Array[Dictionary] = []  ## WU-450: a great beast's trail of prints
var _tracks_shape := "paw"
var _clear_zones := {"rects": [] as Array[Rect2], "points": [] as Array[Vector2], "arrival": [] as Array[Vector2]}  ## GFX-062
var _weather_kind := "clear"
## The pinned weather, readable by UI that draws its own sky (the duel stage, GFX-038); "" = none.
static var pinned_weather := ""
var _forced_weather := ""  # GFX-036: screenshots/tests pin the weather here
var _lightning_timer: Timer
var _strikes := 0
## Festival stalls beside merchants (WU-097), rebuilt when the day or region changes.
var _stalls: Array[Node2D] = []
## GFX-093: bunting and lanterns around the festival square.
var _festival_decor: FestivalDecor = null
var _merchant_spots: Array[Vector2] = []
var _timed_places: Dictionary = {}  # display_name -> node, places with open_days (MARKET-002)

@onready var player: Player = $Player


## WU-401: day each villager last greeted (npc id -> day), the bubble showing now, modal state.
var _greeted: Dictionary = {}
var _greet_bubble: Control = null
var _greet_modal := false
## GFX-043: snow-day footprints behind the player (world positions, oldest first, max 12).
var _prints: Array = []
var _last_print_pos := Vector2.INF


func _ready() -> void:
	if not GameState.has_session():
		GameState.rng.randomize()
		GameState.start_session(CharacterFactory.create("Debug Disciple", GameState.data, GameState.rng))
	_region = GameState.data.regions.get(GameState.current_region, {})
	var map: Dictionary = _region.get("map", {})
	map_size = _vec(map.get("size", [map_size.x, map_size.y]))
	Interactable.ground_style = str(map.get("ground_style", "grass"))
	player.snowy = GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"  # GFX-117
	player.position = _vec(_region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0]))
	_build_season_tint()
	_build_beast_arrow()
	_build_decor()
	_refresh_ambient()
	Settings.changed.connect(_on_setting_changed)
	_build_places()
	_refresh_stalls()
	_place_at_spawn_anchor()
	_build_npcs()
	_build_roamers()
	_build_forage()
	_build_eggs()
	_build_bounds()
	_build_landmark_bodies()
	_limit_camera()
	_fit_pixel_zoom()
	get_viewport().size_changed.connect(_fit_pixel_zoom)
	_last_label_pos = player.position
	for node in get_children():
		if node is Interactable:
			(node as Interactable).refresh_label_alpha(player.position)
	_spread_on_screen()
	var hud := get_node_or_null("HUD")
	if hud != null:
		hud.hints_changed.connect(_mark_hinted.bind(hud))
		_mark_hinted(hud)
	EventBus.ui_modal_changed.connect(_on_modal_changed)
	EventBus.region_changed.connect(_on_region_changed)
	EventBus.contest_finished.connect(_on_contest_finished)
	EventBus.roamers_changed.connect(_on_roamers_changed)
	EventBus.breakthrough_attempted.connect(_on_player_realm_changed)  # WU-522
	EventBus.player_changed.connect(_on_player_changed_tags)  # WU-526: devour, pills, respawn
	EventBus.forage_changed.connect(_build_forage)
	EventBus.pickup_noted.connect(_on_pickup_noted)
	EventBus.forage_changed.connect(_build_eggs)
	get_tree().auto_accept_quit = false


func _build_season_tint() -> void:
	_season_tint = CanvasModulate.new()
	_season = Calendar.season_of(GameClock.total_days)
	_weather_kind = _weather_today()
	_season_tint.color = _tint_for(_season)
	add_child(_season_tint)
	GameClock.days_advanced.connect(_on_days_advanced)


func _on_days_advanced(_days: int) -> void:
	queue_redraw()  # WU-494: the jetty project may have moved on
	_build_roamers()
	_build_forage()
	_build_eggs()
	_refresh_stalls()
	_refresh_timed_places()
	var season := Calendar.season_of(GameClock.total_days)
	var weather := _weather_today()
	if season == _season and weather == _weather_kind:
		_refresh_puddles()  # GFX-184: yesterday's rain may have just dried
		return
	_season = season
	_weather_kind = weather
	var winter := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	for node: Node in get_children():  # GFX-114: snow caps / dormant beds follow a season change while you stay
		if node is Interactable and (node as Interactable).winter != winter:
			(node as Interactable).winter = winter
			(node as Interactable).queue_redraw()
	queue_redraw()
	_refresh_ambient()
	var tween := create_tween()
	tween.tween_property(_season_tint, "color", _tint_for(season), 0.6)


## The weather for a region and day, honouring a pinned (screenshot/test) weather.
static func weather_today(data: GameData, rid: String, day: int) -> String:
	if pinned_weather != "":
		return pinned_weather
	return Weather.of(data, rid, day)


func _weather_today() -> String:
	if _forced_weather != "":
		return _forced_weather
	return Weather.of(GameState.data, GameState.current_region, GameClock.total_days)


## Screenshots/tests only: pins the weather kind so clock advances do not replace it.
func force_weather(kind: String) -> void:
	_forced_weather = kind
	pinned_weather = kind
	_weather_kind = kind
	if _season_tint != null:
		_season_tint.color = _tint_for(_season)
	queue_redraw()
	_refresh_ambient()


## Season tint dimmed by the day's weather.
func _tint_for(season: String) -> Color:
	return Calendar.season_tint(season) * (Ambient.weather_plan(_weather_kind)["tint"] as Color)


## The region's map.mist (0..1, default 1): scales fog sheets and mist particles (GFX-044).
func _mist_strength() -> float:
	return clampf(float(_region.get("map", {}).get("mist", 1.0)), 0.0, 1.0)


## Rebuilds the particle layer for the region, season and "Ambient effects" setting.
func _refresh_ambient() -> void:
	_refresh_village_life()
	_refresh_mist_bands()
	_refresh_cloud_wisps()
	_refresh_market_life()
	if _ambient != null:
		_ambient.queue_free()
		_ambient = null
	if not Settings.get_value("ambient_effects"):
		return
	var plan := Ambient.weather_plan(_weather_kind)
	if plan["fog"]:
		_ambient = Ambient.make_fog(map_size, not Settings.get_value("reduce_motion"), _mist_strength())
	elif plan["emitter"] == "rain":
		_ambient = Ambient.make_rain(map_size)
	elif plan["emitter"] == "storm":
		_ambient = Ambient.make_storm_rain(map_size)
	elif plan["emitter"] == "snow":
		_ambient = Ambient.make_emitter("snow", map_size)
	else:
		var kind := Ambient.kind_for(_region.get("map", {}).get("ambient", {}), _season)
		if kind == "":
			return
		_ambient = Ambient.make_emitter(kind, map_size, _mist_strength())
	add_child(_ambient)
	_start_lightning()


## GFX-119: awning stalls, carts, lantern strings and shoppers of a map.market region.
func _refresh_market_life() -> void:
	if _market_life == null:
		_market_life = MarketLife.new()
		_market_life.name = "MarketLife"
		add_child(_market_life)
		move_child(_market_life, 0)
	_market_life.setup(_region, _season, _weather_kind, GameClock.total_days, not MotionFx.reduced() and bool(Settings.get_value("ambient_effects")))


## GFX-113: slow cloud wisps over the cliffs of a map.high region; off with Ambient effects, still under reduced motion.
func _refresh_cloud_wisps() -> void:
	if _cloud_wisps == null:
		_cloud_wisps = CloudWisps.new()
		_cloud_wisps.name = "CloudWisps"
		add_child(_cloud_wisps)
	var on: bool = bool(Settings.get_value("ambient_effects"))
	_cloud_wisps.setup(_region if on else {}, map_size, not MotionFx.reduced())


## GFX-091: soft mist bands above the ground, under figures; off with Ambient effects.
func _refresh_mist_bands() -> void:
	if _mist_bands == null:
		_mist_bands = MistBands.new()
		_mist_bands.name = "MistBands"
		add_child(_mist_bands)
		move_child(_mist_bands, 0)
	# Only regions that name map.mist are misty; the 1.0 default of _mist_strength() is for fog sheets.
	var on: bool = bool(Settings.get_value("ambient_effects")) and _region.get("map", {}).has("mist")
	_mist_bands.setup(GameState.current_region, MistBands.strength(_mist_strength(), _weather_kind == "fog") if on else 0.0, map_size, not MotionFx.reduced(), GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter")


## GFX-040: chimney smoke, pond ripples, jumping fish and birds, rebuilt on season/weather change.
func _refresh_village_life() -> void:
	if _village_life == null:
		_village_life = VillageLife.new()
		_village_life.name = "VillageLife"
		add_child(_village_life)
	_village_life.setup(_region, _season, _weather_kind, MotionFx.reduced(), map_size)
	if _water_life == null:
		_water_life = WaterLife.new()
		_water_life.name = "WaterLife"
		add_child(_water_life)
		move_child(_water_life, 0)  # WU-429: under the player, beasts and people
	var frozen := Fishing.is_iced(GameState.data, GameState.current_region, _season)
	_water_life.setup(_region, _weather_kind in ["rain", "storm"], frozen, MotionFx.reduced(), _season)
	_refresh_puddles()
	if _critters == null:
		_critters = CritterLayer.new()
		_critters.name = "Critters"
		add_child(_critters)
	_critters.setup(_region, _season, GameClock.total_days, bool(Settings.get_value("ambient_effects")), MotionFx.reduced())


## GFX-184: puddles and wet ground for today's weather (and yesterday's rain).
func _refresh_puddles() -> void:
	if _rain_puddles == null:
		_rain_puddles = RainPuddles.new()
		_rain_puddles.name = "RainPuddles"
		add_child(_rain_puddles)
		move_child(_rain_puddles, 1)  # GFX-184: with the ground, under the figures
	var snowy := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	var yesterday := "clear" if _forced_weather != "" else Weather.of(GameState.data, GameState.current_region, GameClock.total_days - 1)
	_rain_puddles.setup(_region, map_size, GameClock.total_days, _weather_kind, yesterday, snowy, _yards, MotionFx.reduced())


## GFX-033: a white flash every 6-14 s on storm days (none with reduce_motion).
func _start_lightning() -> void:
	if _lightning_timer != null:
		_lightning_timer.queue_free()
		_lightning_timer = null
	if _weather_kind != "storm" or not Ambient.lightning_enabled(Settings.get_value("reduce_motion")):
		return
	_lightning_timer = Timer.new()
	_lightning_timer.one_shot = true
	_lightning_timer.timeout.connect(_flash_lightning)
	add_child(_lightning_timer)
	_lightning_timer.start(Ambient.lightning_gap(GameClock.total_days, _strikes))


func _flash_lightning() -> void:
	_strikes += 1
	var layer := CanvasLayer.new()
	layer.layer = 40
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, Ambient.FLASH_ALPHA)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)
	Audio.play("lightning")
	get_tree().create_timer(Ambient.FLASH_SECONDS).timeout.connect(layer.queue_free)
	if _lightning_timer != null:
		_lightning_timer.start(Ambient.lightning_gap(GameClock.total_days, _strikes))


## Decoration only: a stall beside each merchant while a festival runs in this region.
func _refresh_stalls() -> void:
	for stall in _stalls:
		stall.queue_free()
	_stalls.clear()
	if _festival_decor != null:
		_festival_decor.queue_free()
		_festival_decor = null
	var festival := ""
	for instance: Dictionary in WorldEvents.active_in(GameState.world_events, GameState.current_region):
		if WorldEvents.is_festival(GameState.data, String(instance["id"])):
			festival = String(instance["id"])
			break
	if festival == "":
		return
	var caption := FestivalContest.crowd_caption(GameState.data, festival, _contest_open(festival))
	var spots: Array[Vector2] = []
	var decor_square: Variant = festival_square()
	if decor_square != null:
		_festival_decor = FestivalDecor.new()
		add_child(_festival_decor)
		move_child(_festival_decor, player.get_index())
		_festival_decor.setup(festival, decor_square as Vector2, Folk.festival_blockers(GameState.data, GameState.current_region), map_size)
	# GFX-085: a region with a festival_square holds its contest stall (and crowd) there.
	var square: Variant = festival_square()
	if square != null and GameState.data.world_events.get(festival, {}).has("contest"):
		spots.append(square as Vector2)
		for spot in _merchant_spots:
			spots.append(spot)
	else:
		spots.append_array(_merchant_spots)
	for i in spots.size():
		var stall := FestivalStall.new()
		stall.event_id = festival
		stall.position = spots[i]
		stall.caption = caption if i == 0 else ("" if square != null else caption)
		add_child(stall)
		move_child(stall, player.get_index())
		_stalls.append(stall)


## GFX-085: the region's festival_square in map px, or null.
func festival_square() -> Variant:
	if not _region.has("festival_square"):
		return null
	return _vec(_region["festival_square"])


## Whether `event_id` has a contest here the player has not entered this year (WU-457).
func _contest_open(event_id: String) -> bool:
	return GameState.data.world_events.get(event_id, {}).has("contest") and GameState.check_festival_contest(event_id) == ""


## The contest stall's crowd centre when a villager crowd should gather, else null (WU-457).
func _crowd_centre() -> Variant:
	var event_id := GameState.festival_contest_here()
	if event_id == "" or _stalls.is_empty() or not _contest_open(event_id):
		return null
	return _stalls[0].position + Vector2(0, 20)


## The contest was entered: the crowd goes home and the caption goes away.
func _on_contest_finished(_result: Dictionary) -> void:
	for node in get_children():
		if node is Interactable and node.get("npc_id") != null:
			remove_child(node)
			node.queue_free()
	_refresh_stalls()
	_build_npcs()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "ambient_effects":
		_refresh_ambient()
	elif key == "show_all_labels" and player != null:
		for node in get_children():
			if node is Interactable:
				(node as Interactable).refresh_label_alpha(player.position)


func _exit_tree() -> void:
	if _forced_weather != "":
		pinned_weather = ""
	if get_viewport() != null and get_viewport().size_changed.is_connected(_fit_pixel_zoom):
		get_viewport().size_changed.disconnect(_fit_pixel_zoom)
	if Settings.changed.is_connected(_on_setting_changed):
		Settings.changed.disconnect(_on_setting_changed)
	if GameClock.days_advanced.is_connected(_on_days_advanced):
		GameClock.days_advanced.disconnect(_on_days_advanced)
	if is_inside_tree():
		get_tree().auto_accept_quit = true


## Closing the window saves first (bypassing the once-a-day limit); suspending or
## losing focus saves too, rate-limited (Steam Deck sleeps rather than closes).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.autosave(true)
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		SaveManager.autosave_on_suspend()


## Travel or an artifact respawn moved the player: rebuild the world for the
## new region (only when this world is the running scene, not a preview or test).
func _on_modal_changed(is_open: bool) -> void:
	player.input_enabled = not is_open
	_greet_modal = is_open


## GFX-092: "+1 <item>" with its icon floats above the player.
func _on_pickup_noted(item_id: String, amount: int) -> void:
	if player != null:
		PickupFloat.spawn(self, GameState.data, item_id, amount, player.position)


func _on_region_changed(region_id: String) -> void:
	if get_tree().current_scene == self:
		if GameState.last_travel_from != "" and GameState.last_travel_from != region_id and GameState.player != null and GameState.player.alive:
			var data: GameData = GameState.data
			RoadCard.show_over(get_tree(), RoadCard.text_for(Exploration.region_name(data, GameState.last_travel_from), Exploration.region_name(data, region_id), GameState.last_travel_days, GameState.last_travel_snow), bool(Settings.get_value("reduce_motion")), RoadCard.detail_for(RoadCard.encounter_name(data, GameState.last_travel_road_encounter)))
			GameState.arrival_banner_pending = true  # the reloaded HUD shows the arrival once the card ends (WU-447)
		get_tree().reload_current_scene.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		if SaveManager.save_game():
			EventBus.post("Game saved.")
	elif event.is_action_pressed("quick_load"):
		if SaveManager.load_game():
			get_tree().reload_current_scene()


func _build_bounds() -> void:
	var walls := StaticBody2D.new()
	add_child(walls)
	var t := 40.0
	for rect in [
		Rect2(-t, -t, map_size.x + 2 * t, t),
		Rect2(-t, map_size.y, map_size.x + 2 * t, t),
		Rect2(-t, 0, t, map_size.y),
		Rect2(map_size.x, 0, t, map_size.y),
	]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size / 2.0
		walls.add_child(shape)


## House and well landmarks block the player (GFX-008).
func _build_landmark_bodies() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	for rect in Scenery.landmark_rects(_region, true):
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)


## Scenery is seeded from the region id, so a region always looks the same.
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameState.current_region)
	_decor = Scenery.place(_region, rng)
	_decor = SectCourt.filter_decor(_region, _decor)  # GFX-071/082: nothing grows on the gate or a travel place
	_relief = Scenery.relief_layout(_region)
	_marsh = {}
	_yards = Scenery.village_yards(_region, map_size)
	_square = Scenery.village_square(_region)
	_market_dress = Scenery.market_props(_region, map_size) if _region.get("map", {}).has("market") else {}
	if str(_region.get("map", {}).get("ground_style", "")) == "bog":
		_marsh = Scenery.marsh_features(hash(GameState.current_region + "|marsh"), map_size, Scenery.marsh_keepouts(_region))
	_edge = Scenery.edge_props(_region, map_size)
	_crags = Scenery.high_crags(_region)
	if not _crags.is_empty():  # GFX-123: nothing grows on a crag
		_decor = _decor.filter(func(d: Dictionary) -> bool:
			for it: Dictionary in _crags:
				if (it["rect"] as Rect2).grow(10.0).has_point(d["pos"]):
					return false
			return true)
	if not _relief.is_empty():  # GFX-109: nothing grows on a rock ledge or boulder
		_decor = _decor.filter(func(d: Dictionary) -> bool:
			for it: Dictionary in _relief:
				if (it["rect"] as Rect2).grow(6.0).has_point(d["pos"]):
					return false
			return true)
	_undergrowth = Scenery.undergrowth(_region, _decor)
	_undergrowth.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y < b["pos"].y)
	_decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y < b["pos"].y)


## WU-423: one beast node per Wildlife roamer of today, at a seeded spot clear of places, paths and the arrival point.
func _build_roamers() -> void:
	for node in get_children():
		if node is Roamer:
			node.queue_free()
	_clear_zones = Roamer.keep_clear_zones(_region)
	var blocked: Array[Rect2] = Scenery.landmark_rects(_region)
	for place: Dictionary in _region.get("places", []):
		var sz := _vec(place.get("size", [64, 64]))
		blocked.append(Rect2(_vec(place.get("pos", [0, 0])) - sz / 2.0, sz))
	for p: Array in _region.get("map", {}).get("paths", []):
		blocked.append(Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
	var avoid: Array[Vector2] = [_vec(_region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0]))]
	var great_spot := Vector2(-1, -1)
	for r: Dictionary in GameState.roamers_here():
		_spawn_roamer(r, blocked, avoid)
		if bool(r.get("great", false)):
			great_spot = avoid[avoid.size() - 1]
	_build_tracks(blocked, great_spot)


## GFX-075: an edge arrow on the HUD layer that points at an off-screen great beast.
func _build_beast_arrow() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var arrow := BeastArrow.new()
	arrow.hud = get_node_or_null("HUD")
	layer.add_child(arrow)
	add_child(layer)


## WU-450: the trail of prints: toward the beast's own spot on its day, toward its spawn area the day before.
func _build_tracks(blocked: Array[Rect2], great_spot: Vector2) -> void:
	_tracks = []
	var day := GameClock.total_days
	var enemy := BeastTracks.beast_for(GameState.data, GameState.player, GameState.current_region, day)
	if enemy != "":
		var spot := great_spot
		if spot.x < 0.0:
			if Wildlife.next_great_day(GameState.data, GameState.current_region, day, GameState.player.realm_index, GameState.player) == day:
				enemy = ""  # beast day, but it is down or gone: no prints
			else:
				var avoid: Array[Vector2] = [_vec(_region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0]))]
				spot = Roamer.pick_spot(GameState.current_region, day + 1, Wildlife.GREAT_SLOT, map_size, blocked, avoid, _clear_zones["rects"], _clear_zones["points"], _clear_zones["arrival"])
		if enemy != "":
			_tracks_shape = BeastTracks.shape_for(enemy)
			_tracks = BeastTracks.trail(GameState.current_region, day, map_size, spot, blocked, _clear_zones["rects"])
	queue_redraw()


## WU-426: one beast node for roamer `r`; its spot joins `avoid` so the next beast keeps its distance.
func _spawn_roamer(r: Dictionary, blocked: Array[Rect2], avoid: Array[Vector2]) -> void:
	var day := GameClock.total_days
	var slot := int(r["slot"])
	var spot := Roamer.pick_spot(GameState.current_region, day, slot, map_size, blocked, avoid, _clear_zones["rects"], _clear_zones["points"], _clear_zones["arrival"])
	avoid.append(spot)
	var node: Roamer = ROAMER_SCRIPT.new()
	node.setup(slot, String(r["enemy"]), spot, hash("%s:%d:%d:w" % [GameState.current_region, day, slot]), bool(r.get("great", false)))
	node.player_ref = player
	node.map_bounds = map_size
	node.blocked_rects = blocked
	node.arrival_points = _clear_zones["arrival"]  # WU-515
	add_child(node)
	move_child(node, player.get_index())


## WU-427: one pickup node per FORAGE-001 node of today. Spots are seeded per region and day, so a rebuild keeps
## standing pickups where they were and only adds or drops the ones whose slot changed.
func _build_forage() -> void:
	if not GameState.has_session():
		return
	var nodes := GameState.forage_here()
	var wanted := {}
	for n: Dictionary in nodes:
		wanted[int(n["slot"])] = true
	var present := {}
	for node in get_children():
		if node is ForagePickup and not node.is_queued_for_deletion():
			if wanted.has(node.slot) and not node.taken:
				present[node.slot] = true
			elif not node.taken:
				node.queue_free()
	if present.size() == nodes.size():
		return
	var blocked: Array[Rect2] = Scenery.blocked_rects(_region)
	var paths: Array[Rect2] = []
	for p: Array in _region.get("map", {}).get("paths", []):
		paths.append(Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
		blocked.erase(paths[-1])
	var trees: Array[Vector2] = []
	for d in _decor:
		if d["kind"] == "tree":
			trees.append(d["pos"])
	if _festival_decor != null:  # GFX-097: no forage inside the festival ring on festival days
		blocked.append(Rect2(_festival_decor.position, Vector2.ZERO).grow(FestivalDecor.RADIUS + 20.0))
	var avoid: Array[Vector2] = [_vec(_region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0]))]
	for node in get_children():
		if node is Roamer and not node.is_queued_for_deletion():
			avoid.append(node.home)
	var slot_count := 0
	for n: Dictionary in nodes:
		slot_count = maxi(slot_count, int(n["slot"]) + 1)
	var spots := ForagePickup.pick_spots(GameState.current_region, GameClock.total_days, slot_count,
			map_size, blocked, paths, trees, avoid)
	for n: Dictionary in nodes:
		var slot := int(n["slot"])
		if present.has(slot) or slot >= spots.size() or spots[slot].x < 0.0:
			continue
		var pickup := ForagePickup.new()
		pickup.setup(slot, String(n["item"]), int(n["amount"]), spots[slot])
		add_child(pickup)
		move_child(pickup, player.get_index())


## CRIT-001: one egg node per unpicked egg of today (the hens' spots are fixed, the eggs are seeded per day).
func _build_eggs() -> void:
	if not GameState.has_session():
		return
	var wanted := {}
	for e: Dictionary in GameState.eggs_here():
		wanted[int(e["index"])] = e
	for node in get_children():
		if node is EggPickup and not node.is_queued_for_deletion():
			if wanted.has(node.index):
				wanted.erase(node.index)
			else:
				node.queue_free()
	for index: int in wanted:
		var e: Dictionary = wanted[index]
		var item_name := String(GameState.data.items.get(String(e["item"]), {}).get("name", "Egg"))
		var egg := EggPickup.new()
		egg.setup(index, item_name, e["pos"])
		add_child(egg)
		move_child(egg, player.get_index())


## WU-522: the "· Realm" tags on far NPC labels compare against the player's realm, so refresh them after a breakthrough.
func _on_player_realm_changed(_success: bool = true, _realm_name: String = "") -> void:
	for node in get_children():
		if node is Interactable and node.has_method("refresh_short_name"):
			node.refresh_short_name()


## WU-526: refresh the far NPC realm tags whenever the player's realm or stage changed, for any reason.
var _tag_key := Vector2i(-1, -1)


func _on_player_changed_tags() -> void:
	if GameState.player == null:
		return
	var key := Vector2i(GameState.player.realm_index, GameState.player.stage)
	if key == _tag_key:
		return
	_tag_key = key
	_on_player_realm_changed()


## An engaged beast fades away; the rest stay.
func _on_roamers_changed() -> void:
	var alive := {}
	for r: Dictionary in GameState.roamers_here():
		alive[int(r["slot"])] = true
	if not alive.has(Wildlife.GREAT_SLOT) and not _tracks.is_empty() and Wildlife.next_great_day(GameState.data, GameState.current_region, GameClock.total_days, GameState.player.realm_index, GameState.player) == GameClock.total_days:
		_tracks = []  # WU-450: the beast was beaten today; its prints go with it
		queue_redraw()
	var present := {}
	var avoid: Array[Vector2] = [_vec(_region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0]))]
	for node in get_children():
		if node is Roamer and not node.is_queued_for_deletion():
			if alive.has(node.slot):
				present[node.slot] = true
				avoid.append(node.position)
			else:
				node.fade_out()
	# WU-426: a beast that appears mid-day (the bounty quarry) gets a node at once.
	var blocked: Array[Rect2] = Scenery.landmark_rects(_region)
	for place: Dictionary in _region.get("places", []):
		var sz := _vec(place.get("size", [64, 64]))
		blocked.append(Rect2(_vec(place.get("pos", [0, 0])) - sz / 2.0, sz))
	for p: Array in _region.get("map", {}).get("paths", []):
		blocked.append(Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
	for r: Dictionary in GameState.roamers_here():
		if not present.has(int(r["slot"])):
			_spawn_roamer(r, blocked, avoid)


func _build_places() -> void:
	_timed_places.clear()
	for place: Dictionary in _region.get("places", []):
		if place.has("open_days") or place.has("festival_only"):
			continue  # MARKET-002: _refresh_timed_places() adds it on its open days
		_make_place(place)
	_refresh_timed_places()
	_build_abodes()
	_build_family_home()


## MARKET-002: adds the places with `open_days` that are open today and removes the ones that closed.
func _refresh_timed_places() -> void:
	for place: Dictionary in _region.get("places", []):
		if not place.has("open_days") and not place.has("festival_only"):
			continue
		var place_name := String(place.get("display_name", ""))
		var existing: Node = _timed_places.get(place_name)
		var open := Places.is_open(place, GameClock.total_days) and Places.festival_open(place, GameState.world_events, GameState.current_region, GameClock.total_days)
		if open and existing == null:
			_timed_places[place_name] = _make_place(place)
		elif not open and existing != null:
			existing.queue_free()
			_timed_places.erase(place_name)


func _make_place(place: Dictionary) -> Interactable:
	var node: Interactable = PLACE_SCRIPTS[place["type"]].new()
	node.position = _vec(place.get("pos", [0, 0]))
	node.art_kind = place["type"]
	node.building_style = String(_region.get("map", {}).get("building_style", "thatch"))
	node.winter = GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"  # GFX-114
	for key in place:
		if LAYOUT_KEYS.has(key):
			continue
		node.set(key, _convert(place[key], node.get(key)))
	if place["type"] == "explore":
		node.art_kind = PixelPlace.explore_kind(String(place.get("look", "cave")), place.get("explore_tags", []))
		if place.get("look", "") == "woods":
			node.color = PixelPlace.woods_color(_region.get("map", {}), node.color)  # GFX-104
			if node.winter:
				node.color = PixelPlace.winter_crown(node.color)  # GFX-114
	if place["type"] == "gather":
		node.art_kind = PixelPlace.gather_kind(String(place.get("look", "patch")))
	if place["type"] == "secret_realm":
		node.art_kind = PixelPlace.realm_kind(String(place.get("look", "rift")))
	# Add before the player so the player draws on top.
	add_child(node)
	move_child(node, player.get_index())
	if place["type"] == "merchant" and not place.has("open_days") and not place.has("festival_only"):
		_merchant_spots.append(node.position + Vector2(node.size.x / 2.0 + 34.0, 12.0))
	return node


## The Family Home (FAM-011) while the player's spouses or children live here.
func _build_family_home() -> void:
	if not FamilyHome.has_home(GameState.player, GameState.npcs, GameState.data, GameState.current_region):
		return
	var home: Dictionary = _region["family_home"]
	var node: Interactable = FAMILY_HOME_SCRIPT.new()
	node.display_name = "Family Home"
	node.position = _vec(home.get("pos", [0, 0]))
	node.size = _vec(home.get("size", [90, 64]))
	node.color = Color(String(home.get("color", "c9a77a")))
	node.art_kind = "family_home"
	add_child(node)
	move_child(node, player.get_index())


## Claimable cave abodes (region "abodes", G-010b).
func _build_abodes() -> void:
	for abode: Dictionary in _region.get("abodes", []):
		var node: Interactable = ABODE_SCRIPT.new()
		node.abode_id = String(abode.get("id", ""))
		node.display_name = String(abode.get("display_name", node.abode_id))
		node.anchor_id = String(abode.get("anchor_id", ""))
		node.position = _vec(abode.get("pos", [0, 0]))
		node.size = _vec(abode.get("size", [80, 60]))
		node.color = Color(String(abode.get("color", "6f6a5a")))
		node.art_kind = "abode"
		add_child(node)
		move_child(node, player.get_index())


## After an artifact respawn the player awakens beside their anchor place.
func _place_at_spawn_anchor() -> void:
	var anchor_id := GameState.spawn_anchor
	GameState.spawn_anchor = ""
	if anchor_id == "":
		return
	for node in get_children():
		if node is Interactable and node.anchor_id == anchor_id:
			player.position = node.position + Vector2(0, node.size.y / 2.0 + 48.0)
			return


## SPOT-002: today's settled stands of the hand-placed named people here (id -> position).
func _named_stands() -> Dictionary:
	var stands := {}
	for c in Npcs.in_region(GameState.npcs, GameState.data, GameState.current_region):
		if GameState.data.npcs.has(c.id):
			stands[c.id] = SectCourt.settle_stand(GameState.npc_spot(c.id)["pos"], _region, true)
	return Npcs.settle_named(stands, _region)


## The settled stand of named person `npc_id` today (NPC nodes walk there when the day turns).
func named_stand(npc_id: String) -> Vector2:
	return _named_stands().get(npc_id, GameState.npc_spot(npc_id)["pos"])


func _build_npcs() -> void:
	var named_stands := _named_stands()  # SPOT-002
	for c in Npcs.in_region(GameState.npcs, GameState.data, GameState.current_region):
		if not GameState.data.npcs.has(c.id):
			continue  # Generated NPCs are placed by _build_generated_npcs().
		var def: Dictionary = GameState.data.npcs[c.id]
		var node: Interactable = NPC_SCRIPT.new()
		node.art_kind = "npc"
		node.npc_id = c.id
		node.display_name = "%s (%s)" % [c.name, def["title"]] if def.has("title") else c.name
		node.position = named_stands[c.id]  # FOLK-017, WU-484, SPOT-002
		node.stand_for = named_stand  # [REVIEW] the next day's spot is settled the same way
		node.size = _vec(def.get("size", [30, 30]))
		node.color = Color(def.get("color", "e6bf99"))
		add_child(node)
		move_child(node, player.get_index())
	_build_generated_npcs()
	var all: Array = get_children().filter(func(n: Node) -> bool: return n is Interactable)
	Interactable.clear_person_labels(all)  # WU-511
	Interactable.spread_labels(all)
	Interactable.clamp_labels(all, Rect2(Vector2.ZERO, map_size))
	Interactable.sync_person_labels(all)  # WU-555


## Puts the gold marker on the places the HUD's first hint names (WU-280).
func _mark_hinted(hud: Node) -> void:
	var nodes: Array = get_children().filter(func(n: Node) -> bool: return n is Interactable)
	var hint: String = hud.first_hint()
	var hit := Interactable.hinted_targets(hint, nodes, GameState.data, GameState.current_region, GameState.player)
	var region := Guidance.hinted_region(GameState.data, hint, GameState.current_region)
	for node: Interactable in nodes:
		if "hint_region" in node:
			node.hint_region = region
		node.set_hinted(hit.has(node) or _tip_target(node))


## Whether `node` is a gather site the friend's active tip points at (WU-407).
func _tip_target(node: Interactable) -> bool:
	var tip := Folk.active_tip(GameState.world_flags, GameClock.total_days)
	if tip.is_empty() or String(tip["region"]) != GameState.current_region or not "gather_table" in node:
		return false
	for entry: Dictionary in node.gather_table:
		if String(entry.get("item", "")) == String(tip["item"]):
			return true
	return false


## Generated NPCs (Npcs.spawn, no def) stand at the region's npc_spots (the
## player's family at those nearest the Family Home), colored by gender; children are
## drawn smaller.
func _build_generated_npcs() -> void:
	var data := GameState.data
	var people := Npcs.generated_in_region(GameState.npcs, data, GameState.current_region)
	# The player's family takes the spots nearest the Family Home (FAM-011).
	var family: Array[CharacterData] = []
	if FamilyHome.has_home(GameState.player, GameState.npcs, data, GameState.current_region):
		family.assign(people.filter(func(c: CharacterData) -> bool: return GameState.player.spouses.has(c.id) or GameState.player.children.has(c.id)))
		var others: Array[CharacterData] = []
		others.assign(people.filter(func(c: CharacterData) -> bool: return not family.has(c)))
		people = others
	var avoid: Array[Vector2] = []
	for place: Dictionary in _region.get("places", []):
		avoid.append(_vec(place.get("pos", [0, 0])))
	for abode: Dictionary in _region.get("abodes", []):
		avoid.append(_vec(abode.get("pos", [0, 0])))
	if _region.has("family_home"):
		avoid.append(_vec(_region["family_home"].get("pos", [0, 0])))
	var spots := Npcs.spot_positions(people.size() + family.size(), _region.get("npc_spots", []), player.position, avoid)
	for i in spots.size():  # GFX-076, WU-484: nobody stands in the gate
		spots[i] = SectCourt.settle_stand(spots[i], _region, false)
	spots = Npcs.spread_stands(spots, _region)  # FOLK-032
	if not family.is_empty():
		var split := FamilyHome.split_spots(spots, family.size(), _vec(_region["family_home"].get("pos", [0, 0])))
		spots = split[1]
		spots.append_array(split[0])
		people.append_array(family)
	var neighbours: Array[CharacterData] = []
	for c in people:
		if not family.has(c):
			neighbours.append(c)
	var visitor := GameState.visitor_today()
	var weather_today := Weather.of(data, GameState.current_region, GameClock.total_days)
	var stands := Npcs.haunt_positions(neighbours, _region, GameClock.total_days, int(data.family.get("adult_age", 16)), weather_today, visitor, GameState.visit_place_for(visitor), GameState.together_places())
	# SPOT-001: the capped place each neighbour really stands at, so their "browsing the stalls at X" line matches.
	var round_places := Npcs.haunt_places(neighbours, _region, GameClock.total_days, int(data.family.get("adult_age", 16)), weather_today, visitor, GameState.visit_place_for(visitor), GameState.together_places())
	for id: String in stands:  # WU-484: nobody on a roof or in the gate
		stands[id] = SectCourt.settle_stand(stands[id], _region, false)
	var stand_ids: Array = stands.keys()
	stand_ids.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var stand_list: Array[Vector2] = []
	for id: String in stand_ids:
		stand_list.append(stands[id])
	stand_list = Npcs.spread_stands(stand_list, _region)  # FOLK-032
	for i in stand_ids.size():
		stands[stand_ids[i]] = stand_list[i]
	var centre: Variant = _crowd_centre()
	if centre != null:
		var crowd_avoid: Array[Vector2] = avoid.duplicate()
		for stall in _stalls:  # no villager stands on a stall or under its caption
			crowd_avoid.append(stall.position)
			if stall.caption != "":
				crowd_avoid.append(stall.position + Vector2(0, -40))
		var crowd := FestivalContest.crowd_positions(centre as Vector2, neighbours.size(), crowd_avoid)
		if festival_square() != null:  # GFX-090: the square's crowd stands on the ring, off stalls and solid landmarks
			var blockers := Folk.festival_blockers(GameState.data, GameState.current_region)
			for stall in _stalls:
				blockers.append(Rect2(stall.position - Vector2(35, 30), Vector2(70, 60)))
			crowd = Folk.festival_ring(centre as Vector2 - Vector2(0, 20), mini(neighbours.size(), FestivalContest.CROWD_MAX), blockers, [player.position] as Array[Vector2])
		for k in crowd.size():
			stands[neighbours[k].id] = crowd[k]
	for i in people.size():
		var c := people[i]
		var node: Interactable = NPC_SCRIPT.new()
		node.art_kind = "npc"
		node.npc_id = c.id
		if round_places.has(c.id):
			node.set("round_place", round_places[c.id])
		node.display_name = "%s (%s)" % [c.name, Npcs.world_title(c, GameState.player, data)]
		node.short_name = Npcs.world_title_short(c, GameState.player, data)
		var adult := c.age_years() >= int(data.family.get("adult_age", 16))
		# Neighbours keep a daily round (WORLD-001); the player's family keeps its spots.
		node.position = spots[i] if family.has(c) else stands[c.id]
		node.size = Vector2(28, 28) if adult else Vector2(20, 20)
		node.color = GENDER_COLORS.get(c.gender, Color("e6bf99"))
		add_child(node)
		move_child(node, player.get_index())
	_build_celebration_lanterns(people, stands)


## GFX-023: strings of lanterns near the haunt of the first villager whose celebration is open here.
## GFX-027: plus a bow on the nearest stall or house; family members celebrate at the Family Home.
func _build_celebration_lanterns(people: Array[CharacterData], stands: Dictionary) -> void:
	var ids: Array = people.map(func(c: CharacterData) -> String: return c.id)
	var party := Folk.celebrants(GameState.world_flags, ids, GameClock.total_days)
	for id: String in ids:
		if not party.has(id):
			continue
		var at := Vector2.ZERO
		if stands.has(id):
			at = (stands[id] as Vector2) + Vector2(0, 30)
		elif _region.has("family_home") and FamilyHome.has_home(GameState.player, GameState.npcs, GameState.data, GameState.current_region):
			var home: Dictionary = _region["family_home"]
			at = _vec(home.get("pos", [0, 0])) + Vector2(0, _vec(home.get("size", [90, 64])).y / 2.0 + 30.0)
		else:
			continue
		var lanterns := CelebrationLanterns.new()
		lanterns.lantern_color = Folk.celebration_lantern(party[id])
		lanterns.position = at
		add_child(lanterns)
		move_child(lanterns, 0)
		var lm := CelebrationBow.nearest_landmark(_region.get("map", {}).get("landmarks", []), at)
		if not lm.is_empty():
			var bow := CelebrationBow.new()
			bow.ribbon_color = lanterns.lantern_color
			var size := _vec(lm["size"])
			bow.span = size.x * 0.7
			bow.position = _vec(lm["pos"]) + Vector2(0, -size.y * 0.2)
			add_child(bow)
		return


## Labels stay on screen as the camera moves (WU-269).
func _process(_delta: float) -> void:
	var origin := get_canvas_transform().origin
	if _critters != null and player != null:
		_critters.player_pos = player.position  # GFX-088
	var moved := player != null and _last_label_pos.distance_to(player.position) > 8.0
	_track_footprints()
	if moved:
		_last_label_pos = player.position
		_check_greetings()
		for node in get_children():
			if node is Interactable:
				(node as Interactable).refresh_label_alpha(player.position)
	_spread_clock += _delta
	if origin == _last_canvas_origin and not moved:
		if Interactable.respread_due(_spread_clock, _movers_moved()):
			_spread_clock = 0.0
			_spread_on_screen()
		return
	_last_canvas_origin = origin
	for node in get_children():
		if node is Interactable:
			(node as Interactable).camera_moved()
	_spread_on_screen()


## GFX-069: the farthest any beast or villager moved since the last label spread (records the new spots when
## it is past the threshold, so an idle scene costs one distance check per mover).
func _movers_moved() -> float:
	var far := 0.0
	var movers: Array[Node] = []
	for node in get_children():
		if node is Roamer or (node is Interactable and node.get("npc_id") != null):
			movers.append(node)
			var last: Vector2 = _roamer_spread_pos.get(node.get_instance_id(), Vector2(-1e6, -1e6))
			far = maxf(far, last.distance_to((node as Node2D).position))
	if far > Interactable.RESPREAD_MOVE:
		for node in movers:
			_roamer_spread_pos[node.get_instance_id()] = (node as Node2D).position
	return far


## GFX-043: on snow days drop a footprint every ~16 px of walking; the trail fades by age (redraws only on a new print).
func _track_footprints() -> void:
	if player == null or not Scenery.is_snowy(_season) or bool(_region.get("map", {}).get("no_snow", false)):
		return
	if _last_print_pos.distance_to(player.position) < 16.0:
		return
	_last_print_pos = player.position
	_prints = Scenery.add_footprint(_prints, player.position + Vector2(0, 14))
	queue_redraw()


func _draw_footprints() -> void:
	for i in _prints.size():
		var a := 0.15 + 0.5 * float(i + 1) / _prints.size()
		var p: Vector2 = _prints[i]
		draw_rect(Rect2(p + Vector2(-4, 0), Vector2(3, 4)), Color(0.45, 0.52, 0.62, a))
		draw_rect(Rect2(p + Vector2(1, 3), Vector2(3, 4)), Color(0.45, 0.52, 0.62, a))


## WU-401: a nearby generated villager who has not greeted today says their line in a bubble.
func _check_greetings() -> void:
	var candidates: Array = []
	for node in get_children():
		if node is Interactable and node.get("npc_id") != null and not GameState.data.npcs.has(node.npc_id):
			candidates.append({"id": node.npc_id, "pos": node.position})
	var day := GameClock.total_days
	var id := VillagerGreeting.pick(candidates, player.position, _greeted, day, _greet_modal, is_instance_valid(_greet_bubble))
	if id == "":
		return
	_greeted[id] = day
	GameState.receive_greeting_gift(id)
	var text := GameState.greeting_for(id)
	var req := GameState.letter_request(id)
	if not req.is_empty():
		var item_id := String(req["item"])
		text = VillagerGreeting.with_request(text, req, GameState.player.item_count(item_id), String(GameState.data.items.get(item_id, {}).get("name", item_id)))
	if text == "":
		return
	for node in get_children():
		if node is Interactable and node.get("npc_id") == id:
			_greet_bubble = VillagerGreeting.show_bubble(node, node.size.y, text, Settings.get_value("reduce_motion"))
			return


## Lifts labels that the screen-edge clamp pushed together (WU-281).
func _spread_on_screen() -> void:
	if not is_inside_tree():
		return
	var nodes: Array = get_children().filter(func(n: Node) -> bool: return n is Interactable)
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	var occupied: Array[Rect2] = []
	var chip_world := Rect2()
	var hud := get_node_or_null("HUD")
	if hud != null and hud.has_method("occupied_rects"):
		var to_world := get_canvas_transform().affine_inverse()
		for r: Rect2 in hud.occupied_rects():
			occupied.append(to_world * r)
		if hud.has_method("current_prompt_rect"):  # GFX-069: the [E] chip covers no label
			var chip: Rect2 = hud.current_prompt_rect()
			if chip.size != Vector2.ZERO:
				occupied.append(to_world * chip)
				chip_world = to_world * chip
	var gate := SectCourt.gate(_region)
	if not gate.is_empty():  # GFX-074: the gate's name board is a blocker, so the exit label moves off it
		occupied.append((SectCourt.gate_parts(gate)["stele"] as Rect2).grow(4.0))
	for node: Interactable in nodes:  # GFX-069: the target's highlight box is a blocker for the other labels
		if node.highlighted and node.visible:
			var box := Rect2(node.position - node.size / 2.0, node.size).grow(8.0)
			if not box.intersects(node.drawn_label_rect(view)):
				occupied.append(box)
	Interactable.spread_on_screen(nodes, view, occupied, player.position if player != null else Vector2.ZERO)
	_fade_labels(nodes, view, chip_world)


## WU-508: labels over the player fade to 35%; a place label under the [E] chip hides while the chip shows.
func _fade_labels(nodes: Array, view: Rect2, chip: Rect2) -> void:
	var body := LabelFade.player_rect(player.position) if player != null else Rect2()
	var alphas: Dictionary = {}
	var over_nodes: Array = []
	var over_rects: Array[Rect2] = []
	var over_pos: Array[Vector2] = []
	var place_nodes: Array = []
	for node: Interactable in nodes:
		var a := 1.0
		if node.label_drawn() and player != null:
			var r := node.drawn_label_rect(view)
			var is_npc: bool = node.get("npc_id") != null or node is Roamer
			if r.intersects(body):
				over_nodes.append(node)
				over_rects.append(r)
				over_pos.append(node.position)
			if not is_npc and not node.highlighted and LabelFade.hidden_by_chip(r, chip):
				a = 0.0
			if not is_npc:
				place_nodes.append(node)
		alphas[node] = a
	if player != null and not over_nodes.is_empty():  # WU-529: one name at a time over the player
		var kept := LabelFade.keep_nearest(over_rects, over_pos, player.position)
		for i in over_nodes.size():
			alphas[over_nodes[i]] = minf(alphas[over_nodes[i]], kept[i])
	var places: Array[Rect2] = []  # only place labels that still show make a walking name yield
	for node: Interactable in place_nodes:
		if float(alphas[node]) > 0.0:
			places.append(node.drawn_label_rect(view))
	for node: Interactable in nodes:
		var a: float = alphas[node]
		if a > 0.5 and player != null and node.label_drawn() and (node.get("npc_id") != null or node is Roamer):
			var r2 := node.drawn_label_rect(view)
			if not r2.intersects(body):
				a = minf(a, LabelFade.npc_alpha(r2, places))
		node.set_label_player_alpha(a)


func _limit_camera() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0  # WU-499: no empty band above the region (the margin strip stays painted as a fallback)
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y) + CAMERA_MARGIN_BOTTOM  # WU-472: scroll clear of the HUD bars (the border draws past the edge)


## WU-485: the four strips (top, bottom, left, right) that cover every camera-reachable area outside the map.
static func margin_rects(size: Vector2) -> Array[Rect2]:
	var side := 64.0
	var out: Array[Rect2] = [
		Rect2(-side, -CAMERA_MARGIN_TOP, size.x + 2.0 * side, CAMERA_MARGIN_TOP),
		Rect2(-side, size.y, size.x + 2.0 * side, CAMERA_MARGIN_BOTTOM),
		Rect2(-side, 0, side, size.y),
		Rect2(size.x, 0, side, size.y),
	]
	return out


## The camera zoom that makes one sprite pixel a whole number of screen pixels (GFX-009).
static func pixel_zoom(stretch: float, sprite_scale: int) -> float:
	var total := stretch * sprite_scale
	return maxf(1.0, roundf(total)) / total


func _fit_pixel_zoom() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null or not is_inside_tree():
		return
	var stretch := get_viewport().get_final_transform().get_scale().x
	camera.zoom = Vector2.ONE * pixel_zoom(stretch, Sprites.scale())


## Converts a JSON value to the type of the property it is assigned to.
func _convert(value: Variant, current: Variant) -> Variant:
	match typeof(current):
		TYPE_VECTOR2:
			return _vec(value)
		TYPE_COLOR:
			return Color(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
	return value


func _vec(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## GFX-130: path rects clover keeps off and the worn ellipses round places, in ground-texture px.
func _ground_life(map: Dictionary, sc: float) -> Dictionary:
	var avoid: Array = []
	for r in map.get("paths", []):
		avoid.append(Rect2(float(r[0]) / sc, float(r[1]) / sc, float(r[2]) / sc, float(r[3]) / sc))
	var zones := Scenery.paved_zones(map, sc)
	var worn: Array = []
	for pl in _region.get("places", []):
		var k := Npcs.place_keepout(pl)
		var e := Rect2(k.get_center() - k.size * 0.65, k.size * 1.3)
		var ok := true
		for z: Rect2 in zones:
			if z.intersects(Rect2(e.position / sc, e.size / sc)):
				ok = false
		if ok:
			worn.append(Rect2(e.position / sc, e.size / sc))
	for r in worn:
		avoid.append(r)
	return {"avoid": avoid, "worn": worn, "path_color": Color(map.get("path_color", "8a7350")), "speckle": float(map.get("speckle", 1.0))}


func _draw() -> void:
	var map: Dictionary = _region.get("map", {})
	var rid := GameState.current_region
	var ground := Sprites.first(["ground_" + rid, "ground"])
	if ground != null:
		_draw_tiled(ground, Rect2(Vector2.ZERO, map_size))
	else:
		var ground_color := Color(map.get("ground", "4d6b3c"))
		var sc := float(Sprites.scale())
		var gseason := GroundTiles.ground_season(_season, map)
		var flowers := ["Spring", "Summer"].has(_season)
		var gtex := GroundTiles.ground_texture(ground_color, rid, Vector2i(ceili(map_size.x / sc), ceili(map_size.y / sc)), flowers, gseason, str(map.get("ground_style", "grass")), Scenery.paved_zones(map, sc), float(map.get("scree_density", 1.0)), _ground_life(map, sc))
		draw_texture_rect(gtex, Rect2(Vector2.ZERO, Vector2(gtex.get_size()) * sc), false)
	_draw_square_ground()
	var path_tile := Sprites.first(["path_" + rid, "path"])
	var path_color := Color(map.get("path_color", "8a7350"))
	for r in map.get("paths", []):
		var rect := Rect2(r[0], r[1], r[2], r[3])
		if path_tile != null:
			_draw_tiled(path_tile, rect)
		else:
			var psc := float(Sprites.scale())
			var scree_road := str(map.get("ground_style", "grass")) == "scree"  # GFX-149: a mountain trail has no visible road rect
			var ptex := GroundTiles.path_texture(path_color, rid, Vector2i(ceili(rect.size.x / psc), ceili(rect.size.y / psc)), GroundTiles.ground_season(_season, map), str(map.get("ground_style", "grass")))
			if not scree_road:
				draw_texture_rect(ptex, Rect2(rect.position, Vector2(ptex.get_size()) * psc), false)
			_draw_road(rect, path_color, GroundTiles.ground_season(_season, map) == "Winter")
	_draw_yard_ground()
	_draw_market_ground()
	_draw_scree_detail(map)
	_draw_outcrop_scree(map)
	_draw_relief(map)
	_draw_crags(map)
	_draw_sect_courts()
	_draw_terrace_places()
	_draw_marsh_pools()
	for lm: Dictionary in map.get("landmarks", []):
		_draw_landmark(lm)
	_draw_field_scarecrow(map)
	_draw_marsh_life(map)
	_draw_marsh_decor()
	_draw_market_props()
	_draw_yard_props()
	_draw_square_props()
	if Scenery.is_snowy(_season) and not bool(map.get("no_snow", false)):
		for lm: Dictionary in map.get("landmarks", []):  # GFX-114: after the ponds, so the ice shows
			if lm.get("kind", "") == "jetty":
				_draw_ice_hole(Scenery.ice_hole_point(_region, lm))
	_draw_terraces()
	_draw_high_pines(map)
	_draw_footprints()
	for t: Dictionary in _tracks:
		BeastTracks.draw_print(self, t["pos"], t["angle"], _tracks_shape, t["alpha"], t["side"], GroundTiles.ground_season(_season, map) == "Winter")
	_draw_canopy_shadows()
	for u in _undergrowth:
		_draw_undergrowth(u)
	for d in _decor:
		_draw_decor(d)
	_draw_margins(map, rid)
	var border_tile := Sprites.first(["border_" + rid, "border"])
	if not _edge.is_empty():
		_draw_edge()  # GFX-110: hedge, treeline, wall, cliff or reeds instead of the border line
	elif border_tile != null:
		for strip: Rect2 in [Rect2(0, 0, map_size.x, 6), Rect2(0, map_size.y - 6, map_size.x, 6), Rect2(0, 6, 6, map_size.y - 12), Rect2(map_size.x - 6, 6, 6, map_size.y - 12)]:
			_draw_tiled(border_tile, strip)
	else:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(map.get("border", "2a3a20")), false, 6.0)


## GFX-131: the village square's packed earth (under the roads).
func _draw_square_ground() -> void:
	if _square.is_empty():
		return
	var snowy := Scenery.is_snowy(_season)
	var base := Color(_region.get("map", {}).get("path_color", "8a7350"))
	var fill := _ground_fill(base.lightened(0.04), snowy)
	var edge := fill.darkened(0.06) if snowy else base.darkened(0.14)
	var blob: PackedVector2Array = _square["blob"]
	_fill_poly(_grow_poly(blob, 3.0), edge)
	_fill_poly(blob, fill)
	for p: Dictionary in _square["patches"]:
		var sh: float = p["shade"]
		var pc := fill.lightened(0.05 * sh) if sh > 0.0 else fill.darkened(-0.1 * sh)
		_fill_poly(Scenery.ragged_outline(p["rect"], hash(str(p["rect"])), 6.0, 2.0), pc)
	for t: Rect2 in _square["tracks"]:
		_fill_poly(Scenery.ragged_outline(t, hash(str(t)), 10.0, 3.0), fill.darkened(0.06))
	var stone_tones := [Color("a8a49a"), Color("8a867c"), Color("b4b0a6")]
	for st: Dictionary in _square["stones"]:
		var sr: Rect2 = st["rect"]
		var sc: Color = stone_tones[int(st["tone"])]
		draw_rect(Rect2(sr.position + Vector2(1, 1), sr.size), sc.darkened(0.3))
		draw_rect(sr, sc)
		if snowy:
			draw_rect(Rect2(sr.position, Vector2(sr.size.x, 2)), Color(0.9, 0.93, 0.98, 0.7))
	var tuft := Color("3f5a2e") if snowy else Color("5d8a3e")
	for tf: Rect2 in _square["tufts"]:
		draw_rect(tf, tuft if not snowy else Color("6a5a40"))


## GFX-133: winter ground fills match the snow round them (<= 12% lightness apart), else the packed-earth colour.
func _ground_fill(earth: Color, snowy: bool) -> Color:
	if not snowy:
		return earth
	var ground := Color(_region.get("map", {}).get("ground", "4d6b3c"))
	return ground.lerp(GroundTiles.SNOW, GroundTiles.WINTER_SNOW).darkened(0.05)


func _fill_poly(poly: PackedVector2Array, color: Color) -> void:
	if poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
		draw_colored_polygon(poly, color)


## A polygon pushed `by` px away from its centroid (cheap outline halo).
func _grow_poly(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for v in poly:
		c += v
	c /= float(maxi(poly.size(), 1))
	var out := PackedVector2Array()
	for v in poly:
		out.append(v + (v - c).normalized() * by)
	return out


## GFX-131: the old tree with its stone ring, benches and the lantern post.
func _draw_square_props() -> void:
	if _square.is_empty():
		return
	var snowy := Scenery.is_snowy(_season)
	for pr: Dictionary in _square["props"]:
		var r: Rect2 = pr["rect"]
		if str(pr["kind"]) == "bench":
			draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 4)), Color("a07a48"))
			draw_rect(Rect2(r.position + Vector2(2, 6), Vector2(2, 4)), Color("5a4228"))
			draw_rect(Rect2(r.end - Vector2(4, 4), Vector2(2, 4)), Color("5a4228"))
			if snowy:
				draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(r.size.x, 2)), Color(0.93, 0.95, 1.0, 0.85))
		else:
			draw_rect(Rect2(r.position + Vector2(3, 6), Vector2(2, r.size.y - 6)), Color("4a3524"))
			draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(8, 7)), Color("c8442a"))
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(4, 3)), Color("f2d24b"))
	var t: Dictionary = _square["tree"]
	if t.is_empty():
		return
	var tp: Vector2 = t["pos"]
	for i in 12:
		var a := TAU * float(i) / 12.0
		draw_rect(Rect2(tp + Vector2(cos(a) * 18.0, sin(a) * 9.0 + 14.0) - Vector2(3, 2), Vector2(6, 4)), Color("a8a49a") if i % 2 else Color("8a867c"))
	_draw_tree(tp, 1.9, Color(_region.get("map", {}).get("decor", {}).get("tree_color", "2e5a2a")), "round")


## GFX-127: footpaths to the doors and packed-earth yards (walked-earth colours, snowy tint in Winter).
func _draw_yard_ground() -> void:
	if _yards.is_empty():
		return
	var snowy := Scenery.is_snowy(_season)
	var base := Color(_region.get("map", {}).get("path_color", "8a7350"))
	var fill := _ground_fill(base.lightened(0.06), snowy)
	var edge := fill.darkened(0.05) if snowy else base.darkened(0.12)
	for y: Dictionary in _yards["yards"]:
		_fill_poly(_grow_poly(y["outline"], 2.0), edge)
		_fill_poly(y["outline"], fill)
	for f: Dictionary in _yards["footpaths"]:
		draw_rect((f["rect"] as Rect2).grow(1.0), edge)
	for f: Dictionary in _yards["footpaths"]:
		draw_rect(f["rect"], fill)


## GFX-127: woodpiles, water jars, vegetable rows, washing lines and benches beside the houses.
func _draw_yard_props() -> void:
	if _yards.is_empty():
		return
	var snowy := Scenery.is_snowy(_season)
	for p: Dictionary in _yards["props"]:
		var r: Rect2 = p["rect"]
		draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x, 3)), Color(0, 0, 0, 0.25))
		match str(p["kind"]):
			"woodpile":
				for i in 3:
					draw_rect(Rect2(r.position + Vector2(0, i * 4), Vector2(r.size.x, 4)), Color("8a6238") if i % 2 else Color("a07a48"))
					draw_rect(Rect2(r.position + Vector2(0, i * 4), Vector2(r.size.x, 4)), Color("4a3220"), false, 1.0)
			"water_jar":
				draw_rect(Rect2(r.position + Vector2(1, 2), Vector2(8, 10)), Color("8a5a3a"))
				draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(6, 3)), Color("5a3a24"))
			"veg_row":
				draw_rect(r, Color("4a3624"))
				for row in 3:
					var yy := r.position.y + 3.0 + row * 6.0
					for k in 6:
						var xx := r.position.x + 3.0 + k * 6.0
						if snowy:
							draw_rect(Rect2(xx, yy, 4, 3), Color(0.93, 0.95, 1.0))
						else:
							var autumn := _season == "Autumn"
							draw_rect(Rect2(xx, yy, 4, 4), Color("c8742a") if autumn and k % 2 else (Color("8a6a3a") if autumn else (Color("6f9a4a") if k % 2 else Color("8cb860"))))
			"washing_line":
				draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(2, r.size.y - 2)), Color("5a3a24"))
				draw_rect(Rect2(r.end - Vector2(2, r.size.y - 2), Vector2(2, r.size.y - 2)), Color("5a3a24"))
				draw_line(r.position + Vector2(1, 3), Vector2(r.end.x - 1.0, r.position.y + 3.0), Color("3a2a1a"), 1.0)
				if not snowy:
					for k in 3:
						draw_rect(Rect2(r.position.x + 6.0 + k * 11.0, r.position.y + 4.0, 7, 9), Color("e8e4d8") if k != 1 else Color("9ab0c8"))
			_:
				draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 4)), Color("a07a48"))
				draw_rect(Rect2(r.position + Vector2(2, 6), Vector2(2, 4)), Color("5a4228"))
				draw_rect(Rect2(r.end - Vector2(4, 4), Vector2(2, 4)), Color("5a4228"))
		if snowy and str(p["kind"]) != "washing_line":
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.93, 0.95, 1.0, 0.85))


## GFX-126: block cobbles, packed-earth patches and the scorched ring around a crater (under roads' neighbours, over the ground).
func _draw_market_ground() -> void:
	if _market_dress.is_empty():
		return
	var snowy := Scenery.is_snowy(_season)
	var base := Color(_region.get("map", {}).get("ground", "6b6250"))
	for r: Rect2 in _market_dress["patches"]:
		draw_rect(r, base.lightened(0.1).blend(Color(0.55, 0.45, 0.3, 0.5)) if not snowy else Color(0.45, 0.42, 0.38, 0.35))  # GFX-158: bare earth showing through the snow
	for r: Rect2 in _market_dress["cobbles"]:
		draw_rect(r, base.darkened(0.2) if not snowy else Color(0.8, 0.83, 0.9, 0.7))
	var paveb := Color(_region.get("map", {}).get("path_color", "9c917a"))
	var fl_i := 0
	for fr: Rect2 in (_market_dress.get("courts", []) as Array) + (_market_dress.get("lanes", []) as Array):  # GFX-174: flagstone courts and cobbled lanes
		fl_i += 1
		var fcol := paveb.darkened(0.05) if not snowy else Color(0.8, 0.82, 0.88)
		draw_rect(fr, fcol)
		var fh := hash("%s|court|%d" % [_region.get("id", ""), fl_i])
		var cy := fr.position.y + 5.0
		var row := 0
		while cy < fr.end.y - 2.0:  # joints: a staggered brick bond of flagstones
			draw_rect(Rect2(fr.position.x, cy, fr.size.x, 1), fcol.darkened(0.2))
			var cx := fr.position.x + float((fh >> (row % 8)) % 9) + (5.0 if row % 2 == 1 else 0.0)
			while cx < fr.end.x - 2.0:
				draw_rect(Rect2(cx, cy, 1, minf(10.0, fr.end.y - cy)), fcol.darkened(0.2))
				cx += 12.0 + float((fh + row) % 5)
			cy += 10.0
			row += 1
		draw_rect(fr, fcol.darkened(0.3), false, 1.0)
	var avenue: Rect2 = _market_dress.get("avenue", Rect2())
	if avenue.size.x > 0.0:
		var road := Color(_region.get("map", {}).get("path_color", "9c917a"))
		draw_rect(avenue, road.darkened(0.12))
		var n := 0
		for sl: Rect2 in _market_dress["avenue_slabs"]:
			n += 1
			var c := Scenery.paving_shade(road, hash("%s|av|%d" % [_region.get("id", ""), n])).lightened(0.06)
			draw_rect(sl.grow(-0.5), c if not snowy else c.lerp(Color(0.9, 0.92, 0.97), 0.6))
			draw_rect(sl, road.darkened(0.22), false, 1.0)
	var ring: PackedVector2Array = _market_dress.get("ring", PackedVector2Array())
	if ring.size() >= 3:
		if snowy:  # GFX-165: a shallow snow bowl: one opaque fill, darker far lip, lit near lip, broken soot rim
			var centre := Vector2.ZERO
			for pt: Vector2 in ring:
				centre += pt
			centre /= float(ring.size())
			var snow := Color(0.84, 0.84, 0.85)  # GFX-168: neutral snow a shade darker than the ground, no blue tint
			draw_colored_polygon(ring, snow.darkened(0.1))
			var near := PackedVector2Array()
			for pt: Vector2 in ring:
				near.append(centre.lerp(pt, 0.88) + Vector2(0, 4))
			draw_colored_polygon(near, snow.lightened(0.05))
			for fi in ring.size():  # soot only where the ground shows through (about a third of the rim)
				var hv := hash("%s|soot|%d" % [_region.get("id", ""), fi])
				if hv % 3 == 0:
					var p0 := ring[fi]
					var p1 := ring[(fi + 1) % ring.size()]
					draw_line(p0, p1, Color(0.16, 0.13, 0.13), 3.0)
		else:  # GFX-168: opaque scorched earth over the avenue's end, with a soot rim
			var cc := Vector2.ZERO  # GFX-171: raised rim, brown slope rings, umber floor, cracks, small glow
			for pt: Vector2 in ring:
				cc += pt
			cc /= float(ring.size())
			var rad := minf(ring_bounds_size(ring).x, ring_bounds_size(ring).y) * 0.5
			var rid := hash("%s|rings" % _region.get("id", ""))
			var rings := Scenery.crater_rings(rad, rid, base)
			for rg: Dictionary in rings:
				var poly := PackedVector2Array()
				for pt: Vector2 in ring:
					poly.append(cc + (pt - cc) * float(rg["frac"]) + (rg["shift"] as Vector2))
				draw_colored_polygon(poly, rg["color"])
			var lip := PackedVector2Array()  # lit upper-left lip over the rim, shadow lower-right inside
			for pt: Vector2 in ring:
				lip.append(pt)
			lip.append(ring[0])
			draw_polyline(lip, base.lightened(0.3), 2.0)
			var floor_col: Color = rings[rings.size() - 1]["color"]
			for k in 7:
				var a := TAU * (float(k) + float(rid % 5) * 0.1) / 7.0
				var d := Vector2(cos(a), sin(a))
				draw_line(cc + d * rad * 0.22, cc + d * rad * (0.62 + 0.1 * float((rid >> k) % 3)), floor_col.darkened(0.2), 1.0)
			draw_circle(cc, 7.0, Color(0.9, 0.45, 0.15, 0.35))
			draw_circle(cc, 3.5, Color(1.0, 0.7, 0.3, 0.8))
	for s: Dictionary in ([] if snowy else _market_dress["scorch"]):  # GFX-165: no translucent scorch layers over the snow bowl
		for o: PackedVector2Array in s.get("outlines", []):
			draw_colored_polygon(o, Color(0.08, 0.05, 0.04, 0.12))
	for fl: Rect2 in _market_dress.get("rim_flags", []):  # GFX-171: loose flags round the rim
		var fc := Color(_region.get("map", {}).get("path_color", "9c917a")).darkened(0.1)
		draw_rect(fl, fc if not snowy else fc.lerp(Color(0.9, 0.92, 0.97), 0.55))
		draw_rect(fl, fc.darkened(0.3), false, 1.0)
	for sh: Rect2 in _market_dress.get("shards", []):  # GFX-171: star-iron shards: grey-blue with a 1px glint
		draw_rect(sh, Color("6b7890"))
		draw_rect(Rect2(sh.position + Vector2(1, 1), Vector2(1, 1)), Color("d6ecff"))


func ring_bounds_size(poly: PackedVector2Array) -> Vector2:
	var lo := poly[0]
	var hi := poly[0]
	for pt: Vector2 in poly:
		lo = lo.min(pt)
		hi = hi.max(pt)
	return hi - lo


## GFX-126: barrels, crates and sacks beside the stalls.
func _draw_market_props() -> void:
	if _market_dress.is_empty():
		return
	for f: Dictionary in _market_dress.get("fence", []):  # GFX-134: low rope fence round the crater plaza
		var posts: Array = f["posts"]
		for i in posts.size():
			var pr: Rect2 = posts[i]
			if i > 0:
				var prev: Rect2 = posts[i - 1]
				draw_line(prev.position + Vector2(2, 2), pr.position + Vector2(2, 2), Color("b89a68"), 1.0)
			draw_rect(pr, Color("5a4228"))
			draw_rect(Rect2(pr.position, Vector2(pr.size.x, 2)), Color("a07a48"))
	_draw_market_earth()
	for p: Dictionary in _market_dress["props"]:
		var r: Rect2 = p["rect"]
		draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x, 3)), Color(0, 0, 0, 0.25))
		match str(p["kind"]):
			"barrel":
				draw_rect(r, Color("7a5230"))
				draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(r.size.x, 1)), Color("3a2a1a"))
				draw_rect(Rect2(r.position + Vector2(0, 7), Vector2(r.size.x, 1)), Color("3a2a1a"))
			"crate":
				draw_rect(r, Color("a07a48"))
				draw_rect(r, Color("5a4228"), false, 1.0)
				draw_line(r.position, r.end, Color("5a4228"), 1.0)
			_:
				draw_rect(Rect2(r.position + Vector2(1, 2), r.size - Vector2(2, 2)), Color("c8b88a"))
				draw_rect(Rect2(r.position + Vector2(3, 0), Vector2(4, 3)), Color("a89868"))
		if Scenery.is_snowy(_season):
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.93, 0.95, 1.0, 0.85))


## GFX-155: cart ruts, kerb stones, loose flags and straw wisps on a market's packed earth.
func _draw_market_earth() -> void:
	var snowy := Scenery.is_snowy(_season)
	for line: PackedVector2Array in _market_dress.get("ruts", []):
		draw_polyline(line, Color(0.12, 0.09, 0.05, 0.28) if not snowy else Color(0.42, 0.42, 0.46, 0.45), 2.0)  # GFX-158: grey slush in winter
	for k: Rect2 in _market_dress.get("kerbs", []):
		draw_rect(k, Color("2e2b24"))  # GFX-158: 1 px dark edge, stone fill, 1 px lit top
		draw_rect(k.grow(-1.0), Color("8a8472"))
		draw_rect(Rect2(k.position + Vector2(1, 1), Vector2(maxf(k.size.x - 2.0, 1.0), 1)), Color("b4ad98"))
		if snowy:
			draw_rect(Rect2(k.position + Vector2(1, 0), Vector2(maxf(k.size.x - 2.0, 1.0), 2)), Color(0.93, 0.95, 1.0, 0.8))
	for f: Dictionary in _market_dress.get("loose_flags", []):
		var fr: Rect2 = f["rect"]
		var col := Color("8d8774") if not snowy else Color("b8bcc2")
		if f["tilt"]:
			draw_colored_polygon(PackedVector2Array([fr.position + Vector2(1, 0), fr.position + Vector2(fr.size.x, 2), fr.end - Vector2(1, 0), fr.position + Vector2(0, fr.size.y - 2)]), col)
		else:
			draw_rect(fr, col)
		draw_rect(Rect2(fr.position + Vector2(0, fr.size.y - 1), Vector2(fr.size.x, 1)), Color("4e4a3e"))
	for s: Vector2 in _market_dress.get("straw", []):
		draw_line(s, s + Vector2(5, -1), Color("c9b46a"), 1.0)
		draw_line(s + Vector2(1, 2), s + Vector2(6, 1), Color("b39c52"), 1.0)


## GFX-125: shallow pools of a bog (pale ice with a crack in winter, ripples in rain). Drawn under the landmarks.
func _draw_marsh_pools() -> void:
	var winter := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	for m: Dictionary in _marsh.get("mud", []):  # GFX-136: dark mud patches
		var mp: PackedVector2Array = m["pts"]
		var mr: Rect2 = m["rect"]
		draw_colored_polygon(mp, Color("232a1c") if not winter else Color("5a6068"))
		draw_colored_polygon(Scenery.ragged_outline(mr.grow(-5.0), hash(str(mr)) + 1, 6.0, 3.0), Color("2e3624") if not winter else Color("6c737a"))
		if winter:
			for i in range(0, mp.size() - 1, 3):
				draw_line(mp[i], mp[i + 1], Color(0.94, 0.97, 1.0, 0.8), 1.0)
	for m: Dictionary in _marsh.get("mud", []):  # GFX-177: a wet sheen on the peat
		var mr2: Rect2 = m["rect"]
		var sc := mr2.get_center() + Vector2(-mr2.size.x * 0.12, -mr2.size.y * 0.1)
		draw_line(sc - Vector2(mr2.size.x * 0.18, 0), sc + Vector2(mr2.size.x * 0.1, -1), Color(0.75, 0.85, 0.85, 0.28 if not winter else 0.5), 1.0)
		draw_line(sc + Vector2(-mr2.size.x * 0.05, 4), sc + Vector2(mr2.size.x * 0.2, 3), Color(0.75, 0.85, 0.85, 0.18 if not winter else 0.35), 1.0)
	for pool: Dictionary in _marsh.get("pools", []):
		var pts: PackedVector2Array = pool["pts"]
		var c: Vector2 = pool["center"]
		var r: Rect2 = pool["rect"]
		var rim := PackedVector2Array()
		for q in pts:
			rim.append(c + (q - c) * 1.14)
		if winter:  # frozen grey ice with a snow edge
			draw_colored_polygon(rim, Color("e8eef4"))
			draw_colored_polygon(pts, Color("9aa6b0"))
			var sheen := PackedVector2Array()
			for q in pts:
				sheen.append(c + (q - c) * 0.6)
			draw_colored_polygon(sheen, Color("aab5be"))
			draw_line(c + Vector2(-r.size.x * 0.25, -2), c + Vector2(r.size.x * 0.1, 3), Color("737f8a"), 1.0)
			draw_line(c + Vector2(r.size.x * 0.1, 3), c + Vector2(r.size.x * 0.22, -4), Color("737f8a"), 1.0)
			continue
		draw_colored_polygon(rim, Color("2a3322"))  # murky mud bank
		draw_colored_polygon(pts, Color("2b4a3a"))
		var hi := PackedVector2Array()
		for q in pts:
			hi.append(c + (q - c) * 0.55 + Vector2(-3, -2))
		draw_colored_polygon(hi, Color("3a5a45"))
		draw_line(c + Vector2(-r.size.x * 0.2, -r.size.y * 0.12), c + Vector2(-r.size.x * 0.02, -r.size.y * 0.16), Color(0.7, 0.85, 0.9, 0.3), 1.0)
		if _weather_kind in ["rain", "storm"]:
			for off in [Vector2(-10, 2), Vector2(8, -4)]:
				draw_arc(c + off, 4.0, 0.0, TAU, 12, Color(0.8, 0.9, 0.95, 0.4), 1.0)


## GFX-136: half-sunk bones and dead trees/stumps of the marsh (after the landmarks).
func _draw_marsh_decor() -> void:
	var winter := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	for b: Dictionary in _marsh.get("bones", []):
		var at: Vector2 = b["pos"]
		var d := Vector2(cos(float(b["angle"])), sin(float(b["angle"]))) * float(b["len"]) * 0.5
		draw_line(at - d, at + d, Color("d8d0b8"), 3.0)
		draw_circle(at - d, 2.0, Color("d8d0b8"))
		draw_circle(at + d, 2.0, Color("d8d0b8"))
		draw_line(at - d + Vector2(0, 2), at + d + Vector2(0, 2), Color(0.1, 0.12, 0.08, 0.5), 1.0)
	for t: Dictionary in _marsh.get("dead", []):
		var p: Vector2 = t["pos"]
		if bool(t["stump"]):
			_draw_blob_shade(p + Vector2(0, 5), 18.0)
			draw_rect(Rect2(p + Vector2(-5, -8), Vector2(10, 12)), Color("2a1f16"))
			draw_rect(Rect2(p + Vector2(-5, -9), Vector2(10, 3)), Color("5a4630"))
			if winter:
				draw_rect(Rect2(p + Vector2(-6, -11), Vector2(12, 3)), Color("f4f8ff"))
		else:
			var h: float = t["h"]
			var lean: float = t["lean"]
			_draw_blob_shade(p + Vector2(0, 5), 20.0)
			draw_line(p, p + Vector2(lean, -h), Color("2a1f16"), 3.0)
			draw_line(p + Vector2(lean * 0.5, -h * 0.5), p + Vector2(lean * 0.5 + 12.0, -h * 0.75), Color("3b3a2c"), 2.0)
			draw_line(p + Vector2(lean * 0.7, -h * 0.7), p + Vector2(lean * 0.7 - 10.0, -h * 0.9), Color("3b3a2c"), 2.0)
			if winter:
				draw_rect(Rect2(p + Vector2(lean - 3.0, -h - 2.0), Vector2(6, 3)), Color("f4f8ff"))


## GFX-125: lily pads on the pools and the bog's ponds, then reed clumps (snow caps in winter).
func _draw_marsh_life(map: Dictionary) -> void:
	if _marsh.is_empty():
		return
	var winter := GroundTiles.ground_season(_season, map) == "Winter"
	var pads: Array[Dictionary] = []
	for pool: Dictionary in _marsh["pools"]:
		pads.append_array(pool["lilies"])
	for lm: Dictionary in map.get("landmarks", []):
		if lm.get("kind", "") == "pond":
			var sz := _vec(lm["size"])
			pads.append_array(Scenery.pond_lilies(Rect2(_vec(lm["pos"]) - sz / 2.0, sz), hash(str(lm["pos"])), 4))
	var gs := GroundTiles.ground_season(_season, map)
	var reed_col := Color("6f7f3e")  # GFX-177: green-brown by default, rust in autumn, pale in winter
	if gs == "Autumn":
		reed_col = Color("a8683a")
	elif gs == "Winter":
		reed_col = Color("9a9a68")
	for f: Dictionary in _marsh.get("fringe", []):
		var fb: Vector2 = f["pos"]
		var fh: float = f["h"]
		var fl: float = f["lean"]
		draw_line(fb, fb + Vector2(fl, -fh), reed_col, 1.0)
		draw_line(fb + Vector2(2, 0), fb + Vector2(2 - fl * 0.5, -fh * 0.7), reed_col.darkened(0.15), 1.0)
		draw_line(fb + Vector2(-2, 0), fb + Vector2(-2 + fl, -fh * 0.6), reed_col.lightened(0.1), 1.0)
		if winter:
			draw_rect(Rect2(fb + Vector2(fl - 1.0, -fh - 1.0), Vector2(3, 2)), Color("f4f8ff"))
	if not winter:
		var leaf_col := Color("8a5a2a") if gs == "Autumn" else Color("6a5a30")
		for lf: Dictionary in _marsh.get("leaves", []):
			var la: float = lf["angle"]
			var ld := Vector2(cos(la), sin(la)) * 2.5
			draw_line(lf["pos"] - ld, lf["pos"] + ld, leaf_col, 2.0)
		for mw: Dictionary in _marsh.get("mist", []):  # low mist wisps over the water
			var mp: Vector2 = mw["pos"]
			var mwid: float = mw["w"]
			draw_line(mp + Vector2(-mwid * 0.5, 0), mp + Vector2(mwid * 0.3, -1), Color(0.85, 0.9, 0.88, 0.14), 3.0)
			draw_line(mp + Vector2(-mwid * 0.2, 5), mp + Vector2(mwid * 0.5, 4), Color(0.85, 0.9, 0.88, 0.1), 2.0)
	if not winter:
		for pad: Dictionary in pads:
			var pr: float = pad["r"]
			draw_circle(pad["pos"], pr, Color("4f8a45"))
			draw_circle(pad["pos"] + Vector2(1, -1), pr * 0.45, Color("6fae5a"))
	for clump: Dictionary in _marsh["reeds"]:
		var at: Vector2 = clump["pos"]
		_draw_blob_shade(at + Vector2(0, 3), 18.0)
		for st: Dictionary in clump["stalks"]:
			var base := at + Vector2(float(st["dx"]), 0.0)
			var top := base + Vector2(float(st["dx"]) * 0.15, -float(st["h"]))
			draw_line(base, top, Color("6f7f3e") if not winter else Color("8a8a5a"), 1.0)
			draw_rect(Rect2(top + Vector2(-1, -4), Vector2(2, 5)), Color("6b4a2a"))
			if winter:
				draw_rect(Rect2(top + Vector2(-2, -5), Vector2(4, 2)), Color("f4f8ff"))


## GFX-110: the strips past the map edge show the region's own ground, darkening toward the outer edge (WU-485: no engine grey).
func _draw_margins(map: Dictionary, rid: String) -> void:
	var sc := float(Sprites.scale())
	var ground_color := Color(map.get("ground", "4d6b3c"))
	var gseason := GroundTiles.ground_season(_season, map)
	var style := str(map.get("ground_style", "grass"))
	var strips := margin_rects(map_size)
	for i in strips.size():
		var m: Rect2 = strips[i]
		var tex := GroundTiles.ground_texture(ground_color, rid + "|margin%d" % i, Vector2i(ceili(m.size.x / sc), ceili(m.size.y / sc)), false, gseason, style, [], float(map.get("scree_density", 1.0)))
		draw_texture_rect(tex, Rect2(m.position, Vector2(tex.get_size()) * sc), false)
		var bands := 8
		for b in bands:
			var a := 0.08 + 0.09 * float(b)  # rising toward the outer edge
			var f0 := float(b) / bands
			var f1 := float(b + 1) / bands
			var r: Rect2
			match i:
				0: r = Rect2(m.position.x, m.end.y - m.size.y * f1, m.size.x, m.size.y * (f1 - f0) + 1.0)  # top: outer edge is the top
				1: r = Rect2(m.position.x, m.position.y + m.size.y * f0, m.size.x, m.size.y * (f1 - f0) + 1.0)
				2: r = Rect2(m.end.x - m.size.x * f1, m.position.y, m.size.x * (f1 - f0) + 1.0, m.size.y)
				_: r = Rect2(m.position.x + m.size.x * f0, m.position.y, m.size.x * (f1 - f0) + 1.0, m.size.y)
			draw_rect(r, Color(0, 0, 0, a))


## GFX-110: draws the code-drawn edge props (Scenery.edge_props).
func _draw_edge() -> void:
	var px := float(Sprites.scale())
	var winter := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	for it: Dictionary in _edge:
		var r: Rect2 = it["rect"]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(it["seed"])
		var c := r.get_center()
		match it["kind"]:
			"hedge":
				_draw_hedge_prop(it, rng, winter)
			"treeline":
				var rad := minf(r.size.x, r.size.y) * 0.5 + px * 2.0
				var leaf := Color("2c5a3a").darkened(rng.randf_range(0.0, 0.3))
				draw_rect(Rect2(c.x - px, c.y + rad * 0.4, px * 2.0, rad * 0.6), Color("4a3524"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -rad), c + Vector2(rad * 0.8, rad * 0.5), c + Vector2(-rad * 0.8, rad * 0.5)]), leaf)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -rad * 0.9), c + Vector2(rad * 0.3, rad * 0.1), c + Vector2(-rad * 0.5, rad * 0.1)]), leaf.lightened(0.2))
				if winter:
					draw_rect(Rect2(c.x - px, c.y - rad, px * 2.0, px * 2.0), Color("e8eef4"))
			"wall":
				var stone := Color("8a8478").darkened(rng.randf_range(0.0, 0.15))
				draw_rect(r, stone.darkened(0.4))
				var inner := r.grow(-px)
				draw_rect(inner, stone)
				if it["side"] < 2:
					draw_rect(Rect2(inner.position, Vector2(inner.size.x, px * 2.0)), stone.lightened(0.25))
					draw_line(Vector2(inner.position.x + inner.size.x * 0.5, inner.position.y + px * 2.0), Vector2(inner.position.x + inner.size.x * 0.5, inner.end.y), stone.darkened(0.35), px)
				else:
					draw_rect(Rect2(inner.position, Vector2(px * 2.0, inner.size.y)), stone.lightened(0.25))
					draw_line(Vector2(inner.position.x + px * 2.0, inner.position.y + inner.size.y * 0.5), Vector2(inner.end.x, inner.position.y + inner.size.y * 0.5), stone.darkened(0.35), px)
			"cliff":
				_draw_rock_mass(r, int(it["seed"]), int(it["side"]), float(it.get("h", 1.0)), _rock_color(), winter)
			"reeds":
				var stalk := Color("7a8a4a").darkened(rng.randf_range(0.0, 0.3))
				for n in 3:
					var x := r.position.x + rng.randf_range(0.0, r.size.x)
					var y := r.position.y + rng.randf_range(0.0, r.size.y)
					draw_line(Vector2(x, y + px * 6.0), Vector2(x + rng.randf_range(-px, px), y - px * 4.0), stalk, px)
					if n == 0:
						draw_rect(Rect2(x - px * 0.5, y - px * 7.0, px, px * 3.0), Color("5a3a22"))


## GFX-180: one hedge prop as layered woodland: darker back blobs toward the map edge, lighter front blobs, and now and then a
## small tree, a flowering shrub or a rock at the foot. At most ~6 draw calls per blob group.
func _draw_hedge_prop(it: Dictionary, rng: RandomNumberGenerator, winter: bool) -> void:
	var px := float(Sprites.scale())
	var r: Rect2 = it["rect"]
	var side: int = it["side"]
	var seed_value: int = it["seed"]
	var decor: Dictionary = _region.get("map", {}).get("decor", {})
	var base := Color(str(decor.get("tree_color", "2e5a2a")))
	var look := Scenery.tree_look(_season, seed_value, base, "round", false)
	var leaf: Color = base.lightened(0.12) if bool(look["bare"]) else look["canopy"]
	leaf = leaf.darkened(rng.randf_range(0.0, 0.18))
	var variant := Scenery.hedge_variant(seed_value)
	var blobs := Scenery.hedge_blobs(r, seed_value, side)
	for b in blobs:
		if int(b["layer"]) == 0:
			draw_circle(b["pos"], float(b["radius"]), leaf.darkened(0.35))
	for b in blobs:
		if int(b["layer"]) == 1:
			var p: Vector2 = b["pos"]
			var rad: float = b["radius"]
			draw_circle(p + Vector2(px, px * 2.0), rad, leaf.darkened(0.5))
			draw_circle(p, rad, leaf)
			draw_circle(p + Vector2(-px * 2.0, -px * 2.0), rad * 0.5, leaf.lightened(0.22))
			if winter:
				draw_rect(Rect2(p + Vector2(-px * 3.0, -rad * 0.8), Vector2(px * 6.0, px * 2.0)), Color("e8eef4"))
	var foot: Vector2 = blobs[blobs.size() - 1]["pos"]
	match variant:
		"tree":
			_draw_tree(r.get_center() - Vector2(0, 6.0 * px) if side != 1 else r.get_center() + Vector2(0, 2.0 * px), 0.8, base, "round")
		"flower":
			var gs := GroundTiles.ground_season(_season, _region.get("map", {}))
			if gs == "Spring" or gs == "Summer":
				for n in 4:
					var o := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-6.0, 6.0))
					draw_rect(Rect2(foot + o, Vector2(px, px)), Color("e8a0b8") if n % 2 == 0 else Color("f4f0e6"))
		"rock":
			draw_colored_polygon(Scenery.flat_stone(foot + Vector2(0, 4.0 * px), 5.0 * px, seed_value), _rock_color())


## GFX-111: the region's rock colour (decor.rock_color).
func _rock_color() -> Color:
	return Color(String(_region.get("map", {}).get("decor", {}).get("rock_color", "8a939c")))


## GFX-111: a rock mass with a jagged silhouette facing into the map: shaded face, cracks, a lit lip along the
## top silhouette only, pebbles in front. `side` 0 top, 1 bottom, 2 left, 3 right edge (landmark cliffs use 1).
func _draw_rock_mass(r: Rect2, seed_value: int, side: int, h: float, rock: Color, snowy: bool) -> void:
	var px := float(Sprites.scale())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var horizontal := side < 2
	var length := r.size.x if horizontal else r.size.y
	var depth := (r.size.y if horizontal else r.size.x) * h
	length += px * 3.0  # neighbours overlap a few px, so no seams show
	var u0 := (r.position.x if horizontal else r.position.y) - px * 1.5
	var local := Scenery.jagged_outline(Rect2(0, 0, length, depth), seed_value, maxi(5, int(length / 6.0)), minf(depth * 0.35, 10.0))
	var pts := PackedVector2Array()
	for p in local:
		match side:
			0: pts.append(Vector2(u0 + p.x, r.end.y - p.y))
			1: pts.append(Vector2(u0 + p.x, r.position.y + (r.size.y - depth) + p.y))
			2: pts.append(Vector2(r.end.x - p.y, u0 + p.x))
			_: pts.append(Vector2(r.position.x + (r.size.x - depth) + p.y, u0 + p.x))
	var shade := rock.darkened(0.3 + rng.randf_range(0.0, 0.1))
	draw_colored_polygon(pts, shade)
	var c := (pts[0] + pts[pts.size() - 1]) * 0.5
	for k in rng.randi_range(1, 2):
		var t := rng.randf_range(0.2, 0.8)
		var tip: Vector2 = pts[1 + int(t * (pts.size() - 3))]
		draw_line(tip, tip.lerp(c, rng.randf_range(0.5, 0.9)) + Vector2(px * 2.0, 0), shade.darkened(0.4), px)
	var rim := pts.slice(1, pts.size() - 1)
	draw_polyline(rim, rock.lightened(0.25), px * 2.0)
	if snowy:
		draw_polyline(rim, Color("e8eef4"), px * 3.0)
	for k in rng.randi_range(0, 2):
		var q: Vector2 = rim[rng.randi_range(0, rim.size() - 1)]
		var off := Vector2(0, -px * 3.0) if side == 1 else (Vector2(0, px * 3.0) if side == 0 else (Vector2(px * 3.0, 0) if side == 2 else Vector2(-px * 3.0, 0)))
		draw_rect(Rect2(q + off, Vector2(px * 2.0, px * 2.0)), rock.darkened(0.15))


## GFX-109: rock ledges (lit top, dark face, cracks), boulder clusters and snow drifts, in crisp scaled pixels.
func _draw_relief(map: Dictionary) -> void:
	if _relief.is_empty():
		return
	var px := float(Sprites.scale())
	var ground := Color(map.get("ground", "4d6b3c"))
	var rock := Color(String(map.get("decor", {}).get("rock_color", "a3adb5")))
	var gseason := GroundTiles.ground_season(_season, map)
	var winter := gseason == "Winter"
	var snow_col := Color("e8eef4")
	for it: Dictionary in _relief:
		var r: Rect2 = it["rect"]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(it["seed"])
		match it["kind"]:
			"ledge":
				_draw_rock_band(r, int(it["seed"]), rock, winter, px)
			"boulders":
				var bi := 0
				for n in rng.randi_range(3, 5):
					var rad := rng.randf_range(8.0, 16.0)
					var c := r.position + Vector2(rng.randf_range(rad, maxf(r.size.x - rad, rad)), rng.randf_range(rad, maxf(r.size.y - rad, rad)))
					var rsd := rng.randi()
					draw_colored_polygon(Scenery.flat_stone(c + Vector2(1.0, 3.0), rad, rsd), Color(0, 0, 0, 0.3))
					var body := Scenery.flat_stone(c, rad, rsd)  # GFX-166: flat irregular slate stones with a dark foot, not balls
					draw_colored_polygon(Scenery.flat_stone(c + Vector2(0, 2.0), rad, rsd), rock.darkened(0.55))
					draw_colored_polygon(body, rock.darkened(0.22))
					var lit := PackedVector2Array()
					for q in body:
						lit.append(c + (q - c) * 0.6 + Vector2(-0.12, -0.35) * rad * 0.5)
					draw_colored_polygon(lit, rock.darkened(0.05))
					var ring := body.duplicate()
					ring.append(body[0])
					draw_polyline(ring, rock.darkened(0.45), 1.0)
					if winter:
						draw_colored_polygon(Scenery.flat_stone(c + Vector2(0, -rad * 0.25), rad * 0.55, rsd + 1), snow_col)
					bi += 1
			"drift":
				var look := Scenery.drift_look(gseason, int(it["seed"]))
				if not bool(look["show"]):
					continue
				var sc: Vector2 = look["scale"]
				var dr := Rect2(r.position.x, r.end.y - r.size.y * sc.y, r.size.x * sc.x, r.size.y * sc.y)
				var dcol: Color = look["color"]
				dcol.a = float(look["alpha"])
				for lr in Scenery.drift_lumps(dr, maxi(int(look["lumps"]), 1), int(it["seed"])):
					_draw_drift_mound(lr, int(it["seed"]) + int(lr.position.x), dcol, winter)


## GFX-145: a rock band: ragged top and bottom edges that taper at both ends, a lit top face over two darker strata
## split by dark crack lines, a contact shadow, and (in winter) a snow cap that follows the jagged top plus snow pockets.
func _draw_rock_band(r: Rect2, seed_value: int, rock: Color, winter: bool, px: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := maxi(6, int(r.size.x / 12.0))
	var steps := Scenery.ledge_steps(seed_value)
	var heights: Array = steps["heights"]
	var lit_step: Array[bool] = []
	var top: Array[Vector2] = []
	var bot: Array[Vector2] = []
	for i in n + 1:
		var t := float(i) / float(n)
		var taper := clampf(minf(t, 1.0 - t) / 0.15, 0.0, 1.0)  # 0 at the ends, 1 from 15% in
		var squeeze := (1.0 - taper) * r.size.y * 0.3
		var x := r.position.x + r.size.x * t
		var si := mini(int(t * float(heights.size())), heights.size() - 1)  # GFX-150: stepped silhouette
		var drop := r.size.y * (1.0 - float(heights[si])) * 0.7
		top.append(Vector2(x, r.position.y + squeeze + drop + rng.randf() * minf(px * 3.0, r.size.y * 0.2)))
		lit_step.append(bool(steps["rising"][si]))
		var ty := top[top.size() - 1].y
		bot.append(Vector2(x, maxf(r.end.y - squeeze - rng.randf() * minf(px * 2.0, r.size.y * 0.15), ty + maxf(r.size.y * 0.3, 4.0))))
	var face := rock.darkened(0.38)
	var shadow := PackedVector2Array()
	for b in bot:
		shadow.append(b + Vector2(0, 2.0))
	for i in range(top.size() - 1, -1, -1):
		shadow.append(top[i] + Vector2(0, 2.0))
	var body := PackedVector2Array()
	for t_pt in top:
		body.append(t_pt)
	for i in range(bot.size() - 1, -1, -1):
		body.append(bot[i])
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	var gsh := PackedVector2Array()  # GFX-150: a darker blob of shadow on the ground below the ledge
	for i in bot.size():
		gsh.append(bot[i] + Vector2(0, 2.0 + 4.0 * sin(PI * float(i) / float(bot.size() - 1))))
	for i in range(bot.size() - 1, -1, -1):
		gsh.append(bot[i] + Vector2(0, 1.0))
	draw_colored_polygon(gsh, Color(0, 0, 0, 0.18))
	draw_colored_polygon(body, face)
	var fracs := [0.0, 0.3, 0.65, 1.0]
	var shades := [rock.lightened(0.12), face.lightened(0.06), face.darkened(0.15)]
	for s in 3:
		var strip := PackedVector2Array()
		for i in top.size():
			strip.append(top[i].lerp(bot[i], fracs[s]))
		for i in range(top.size() - 1, -1, -1):
			strip.append(top[i].lerp(bot[i], fracs[s + 1]))
		draw_colored_polygon(strip, shades[s])
		if s == 0:  # the lit top facet only on the rising steps
			for i in range(top.size() - 1):
				if lit_step[i] and lit_step[i + 1]:
					draw_colored_polygon(PackedVector2Array([top[i], top[i + 1], top[i + 1].lerp(bot[i + 1], 0.3), top[i].lerp(bot[i], 0.3)]), rock.lightened(0.12))
				else:
					draw_colored_polygon(PackedVector2Array([top[i], top[i + 1], top[i + 1].lerp(bot[i + 1], 0.3), top[i].lerp(bot[i], 0.3)]), face.lightened(0.04))
		if s > 0:
			var crack := PackedVector2Array()
			for i in top.size():
				crack.append(top[i].lerp(bot[i], fracs[s]) + Vector2(0, rng.randf_range(-0.8, 0.8)))
			draw_polyline(crack, face.darkened(0.3), 1.0)
	for c in rng.randi_range(1, 2):  # vertical cracks
		var i := rng.randi_range(1, maxi(top.size() - 2, 1))
		draw_line(top[i].lerp(bot[i], 0.2), top[i].lerp(bot[i], 0.8) + Vector2(px, 0), face.darkened(0.5), 1.0)
	var lit_edge := PackedVector2Array()  # GFX-166: a lit top edge along the whole step, loose stones at the foot
	for t_pt in top:
		lit_edge.append(t_pt + Vector2(0, 0.5))
	draw_polyline(lit_edge, rock.lightened(0.3), 1.5)
	for fs: Dictionary in Scenery.ledge_foot_stones(r.position.x + r.size.x * 0.1, r.end.x - r.size.x * 0.1, r.end.y, seed_value):
		var fp: Vector2 = fs["pos"]
		var fr := float(fs["radius"])
		draw_colored_polygon(Scenery.flat_stone(fp + Vector2(0, 1.0), fr, int(fs["seed"])), face.darkened(0.4))
		draw_colored_polygon(Scenery.flat_stone(fp, fr, int(fs["seed"])), rock.darkened(0.12))
	if winter:
		var cap := PackedVector2Array()
		for t_pt in top:
			cap.append(t_pt + Vector2(0, -1.0))
		for i in range(top.size() - 1, -1, -1):
			cap.append(top[i] + Vector2(0, 2.5 + rng.randf() * 1.5))
		draw_colored_polygon(cap, Color("e8eef4"))
		for k in rng.randi_range(1, 3):
			var i2 := rng.randi_range(1, maxi(top.size() - 2, 1))
			var pc := top[i2].lerp(bot[i2], rng.randf_range(0.4, 0.7))
			draw_colored_polygon(Scenery.rock_polygon(pc, rng.randf_range(3.0, 5.0), rng.randi()), Color("e8eef4"))


## GFX-145: sparse pebble clusters and faint lighter slope bands on a scree map (under the decor, clear of paths and places).
func _draw_scree_detail(map: Dictionary) -> void:
	if str(map.get("ground_style", "")) != "scree":
		return
	var rock := Color(String(map.get("decor", {}).get("rock_color", "a3adb5")))
	var keep: Array[Rect2] = []
	for pr in map.get("paths", []):
		keep.append(Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3])).grow(6.0))
	for p: Dictionary in _region.get("places", []) + _region.get("abodes", []):
		var pos: Array = p.get("pos", [0, 0])
		var sz: Array = p.get("size", [64, 64])
		var psize := Vector2(float(sz[0]), float(sz[1]))
		keep.append(Rect2(Vector2(float(pos[0]), float(pos[1])) - psize / 2.0, psize).grow(8.0))
	var patch_col := {"lichen": Color("7d8a6c"), "rust": Color("8c6a52"), "shale": Color("565e68")}
	for pt: Dictionary in Scenery.ridge_patches(_region, keep):  # GFX-159: lichen clumps and shale plates (GFX-150 patches)
		_draw_ridge_patch(pt, patch_col[pt["kind"]])
	for b: Dictionary in Scenery.scree_bands(_region):
		var br: Rect2 = b["rect"]
		var skip := false
		for k in keep:
			if k.intersects(br):
				skip = true
				break
		if not skip:
			draw_colored_polygon(Scenery.ragged_outline(br, int(b["seed"]), 24.0, 8.0), Color(rock.lightened(0.2), 0.07))
	for c: Dictionary in Scenery.scree_clusters(_region, keep):  # GFX-159: 2-3 px stones, lit top row, dark foot, no near-white
		var rng := RandomNumberGenerator.new()
		rng.seed = int(c["seed"])
		for i in int(c["count"]):
			var q: Vector2 = ((c["center"] as Vector2) + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-6.0, 6.0))).floor()
			var sw := float(rng.randi_range(2, 3))
			var tone := rock.darkened(rng.randf_range(0.05, 0.3))
			draw_rect(Rect2(q + Vector2(0, sw - 1.0), Vector2(sw, 1.0)), tone.darkened(0.45))
			draw_rect(Rect2(q, Vector2(sw, sw - 1.0)), tone)
			draw_rect(Rect2(q, Vector2(sw, 1.0)), tone.lightened(0.18))


## GFX-179: a fan of grey scree below each crag, rock ledge and boulder cluster (lighter at the tip) with a short contact
## shadow at the foot; snow-covered in winter. Drawn under the rocks.
func _draw_outcrop_scree(map: Dictionary) -> void:
	if str(map.get("ground_style", "")) != "scree":
		return
	var anchors: Array[Rect2] = []
	for it: Dictionary in _crags:
		if it["kind"] == "crag":
			anchors.append(it["rect"])
	for it: Dictionary in _relief:
		if it["kind"] == "ledge" or it["kind"] == "boulders":
			anchors.append(it["rect"])
	if anchors.is_empty():
		return
	var rock := Color(String(map.get("decor", {}).get("rock_color", "a3adb5")))
	var winter := GroundTiles.ground_season(_season, map) == "Winter"
	for fan: Dictionary in Scenery.outcrop_fans(GameState.current_region, anchors):
		var length := float(fan["length"])
		var o: Vector2 = fan["origin"]
		for pb: Vector3 in Scenery.fan_pebbles(fan):
			var tip := clampf((pb.y - o.y) / maxf(length, 1.0), 0.0, 1.0)
			var tone := rock.darkened(0.25 - 0.3 * tip)
			if winter:
				tone = tone.lerp(Color("e8eef4"), 0.75)
			var q := Vector2(pb.x, pb.y).floor()
			draw_rect(Rect2(q, Vector2(pb.z, maxf(pb.z - 1.0, 1.0))), tone)
		var foot := Scenery.shadow_blob(Vector2(o.x, o.y + 1.0), Vector2(float(fan["spread"]) * 0.7, 4.0), int(fan["seed"]))
		draw_colored_polygon(foot, Color(0, 0, 0, 0.2))


## GFX-159: a ridge patch: lichen = clumps of small greenish spots, rust = soft smudge, shale = angular dark plates with a lit edge.
func _draw_ridge_patch(pt: Dictionary, col: Color) -> void:
	var pc: Vector2 = pt["center"]
	var rx := float(pt["rx"])
	var ry := float(pt["ry"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pt["seed"])
	match String(pt["kind"]):
		"lichen":
			for clump in rng.randi_range(3, 5):
				var cc := pc + Vector2(rng.randf_range(-rx, rx), rng.randf_range(-ry, ry)) * 0.7
				for k in rng.randi_range(6, 11):
					var q := (cc + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-6.0, 6.0))).floor()
					var sz := float(rng.randi_range(1, 2))
					draw_rect(Rect2(q, Vector2(sz + 1.0, sz)), Color(col.lightened(0.1) if k % 3 == 0 else col, 0.75))
		"shale":
			for plate in rng.randi_range(3, 5):
				var cc := pc + Vector2(rng.randf_range(-rx, rx), rng.randf_range(-ry, ry)) * 0.6
				var w := rng.randf_range(14.0, 28.0)
				var h := rng.randf_range(6.0, 11.0)
				var poly := PackedVector2Array([cc + Vector2(-w * 0.5, h * 0.3), cc + Vector2(-w * 0.3, -h * 0.5), cc + Vector2(w * 0.4, -h * 0.4), cc + Vector2(w * 0.5, h * 0.2), cc + Vector2(w * 0.1, h * 0.5)])
				draw_colored_polygon(poly, Color(col.darkened(0.1), 0.6))
				draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2]]), Color(col.lightened(0.35), 0.7), 1.0)
		_:  # GFX-164: rust = 3-6 small irregular reddish-brown spots, never a soft rect
			for spot in rng.randi_range(3, 6):
				var cc := pc + Vector2(rng.randf_range(-rx, rx), rng.randf_range(-ry, ry)) * 0.7
				var sr := rng.randf_range(2.0, 4.5)
				draw_colored_polygon(Scenery.rock_polygon(cc, sr, rng.randi()), Color(col, 0.85))
				draw_rect(Rect2(cc + Vector2(-sr * 0.4, -sr * 0.8), Vector2(sr * 0.8, 1.0)), Color(col.lightened(0.2), 0.8))


## GFX-147/GFX-160: "terrace" gather places as wide flat hillside bands: soil toned from the region ground, ends fading into the
## slope, short crop tufts in 2-3 staggered rows (every 3rd in the place colour), snow on the band tops in winter. No dark rim.
func _draw_terrace_places() -> void:
	var snowy := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	var ground := Color(String(_region.get("map", {}).get("ground", "4d6b3c")))
	for place: Dictionary in _region.get("places", []):
		if String(place.get("type", "")) != "gather" or String(place.get("look", "")) != "terrace":
			continue
		var sz := _vec(place.get("size", [130, 80]))
		var r := Rect2(_vec(place["pos"]) - sz / 2.0, sz)
		var tint := Color(String(place.get("color", "9aa8d0")))
		var seed_value := int(r.position.x) * 31 + int(r.position.y) * 17
		var bands := Scenery.terrace_bands(r, seed_value)
		var plant := Scenery.crop_color(String(GroundTiles.ground_season(_season, _region.get("map", {}))))
		var variant := Scenery.terrace_variant(String(place.get("display_name", "")))
		var plant_cols := Scenery.terrace_plant_colors(variant, plant, tint)
		for i in bands.size():
			var poly := bands[i]
			var earth := Scenery.terrace_earth(ground, i, snowy)
			if variant == "scorched" and i == 1:  # GFX-173: one scorched step
				earth = earth.darkened(0.35)
			var left: float = poly[0].x
			var right: float = poly[poly.size() / 2 - 1].x
			var colors := PackedColorArray()
			for q in poly:
				colors.append(Color(earth, Scenery.terrace_end_alpha(q.x, left, right)))
			draw_polygon(poly, colors)
			var half := poly.size() / 2
			# a slightly darker earth lip under the band (earth tone, not a dark outline)
			var lip := PackedVector2Array()
			var lip_cols := PackedColorArray()
			for q in range(half, poly.size()):
				lip.append(poly[q] + Vector2(0, -2.0))
				lip_cols.append(Color(earth.darkened(0.35), 0.85 * Scenery.terrace_end_alpha(poly[q].x, left, right)))
			draw_polyline_colors(lip, lip_cols, 4.0)  # GFX-167: the riser under each band's lit top
			for crop: Dictionary in Scenery.terrace_crops(poly, seed_value + i * 101):
				var p: Vector2 = crop["pos"]
				if snowy:  # GFX-166: only the tinted tufts show through the snow, as small buried humps
					if bool(crop["tinted"]):
						draw_rect(Rect2(p.x, p.y - 1.0, 3.0, 2.0), Color("e9f1f8"))
				else:
					var col: Color = plant_cols[0] if bool(crop["tinted"]) else plant_cols[1]
					if variant == "scorched" and i != 1:
						col = tint.lerp(plant, 0.25) if bool(crop["tinted"]) else plant.darkened(0.1)
					draw_rect(Rect2(p.x, p.y - 2.0, 2.0, 3.0), col)
					draw_rect(Rect2(p.x + 2.0, p.y - 3.0, 2.0, 3.0), col.lightened(0.25 if variant != "scorched" else 0.1))
					if variant == "orchid":  # a violet heart in each bloom
						draw_rect(Rect2(p.x + 2.0, p.y - 3.0, 1.0, 1.0), Color("a678d8"))
			if not snowy:  # GFX-166: a lit top edge on each band so the steps read on a dark slope
				var lit_cols := PackedColorArray()
				var lit_top := poly.slice(0, half)
				for q in lit_top:
					lit_cols.append(Color(earth.lightened(0.3), 0.8 * Scenery.terrace_end_alpha(q.x, left, right)))
				draw_polyline_colors(lit_top, lit_cols, 1.5)
			if snowy:
				var top_cols := PackedColorArray()
				var top := poly.slice(0, half)
				for q in top:
					top_cols.append(Color(0.95, 0.98, 1.0, 0.9 * Scenery.terrace_end_alpha(q.x, left, right)))
				draw_polyline_colors(top, top_cols, 2.0)
		if variant == "scorched" and bands.size() > 1:  # GFX-173: a lightning split through the steps
			var b0 := bands[0]
			var bl := bands[bands.size() - 1]
			var split := Scenery.lightning_split(b0[b0.size() / 4], bl[bl.size() - 1 - bl.size() / 4], seed_value)
			draw_polyline(split, Color("1c1a18"), 3.0)
			draw_polyline(split, Color("f2e48a") if not snowy else Color("dfe8f0"), 1.0)
		elif variant == "orchid":  # a wisp of mist drifting over the lower steps
			var mrng := RandomNumberGenerator.new()
			mrng.seed = seed_value
			for k in 4:
				var mc := Vector2(r.position.x + sz.x * (0.2 + 0.2 * float(k)) + mrng.randf_range(-6.0, 6.0), r.end.y - sz.y * 0.3 + mrng.randf_range(-6.0, 6.0))
				draw_circle(mc, mrng.randf_range(8.0, 13.0), Color(0.92, 0.95, 1.0, 0.16))


## GFX-068: the paved court of each sect hall and the mountain gate (no collision; drawn under the places).
func _draw_sect_courts() -> void:
	var snowy := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	for place: Dictionary in _region.get("places", []):
		if SectCourt.is_sect_hall(place):
			var hall := Rect2(_vec(place["pos"]) - _vec(place.get("size", [64, 64])) / 2.0, _vec(place.get("size", [64, 64])))
			var court := SectCourt.court_rect(place, _region)
			SectCourt.draw_court(self, hall, court, snowy, SectCourt.court_style(place))
			if SectCourt.court_style(place) == "planks":  # GFX-148: a short jetty toward the nearest pool
				var pool_rects: Array[Rect2] = []
				for pool: Dictionary in _marsh.get("pools", []):
					pool_rects.append(pool["rect"])
				for board: Rect2 in Scenery.platform_jetty(court, pool_rects):
					draw_rect(board, Color("6e5636") if not snowy else Color("c9d3da"))
					draw_rect(board, Color("2b2118"), false, 1.0)
			var high: Variant = _region.get("map", {}).get("high", null)
			if high is Dictionary and bool(high.get("rail", false)):
				SectCourt.draw_rail(self, court, snowy)
	var g := SectCourt.gate(_region)
	if not g.is_empty():
		SectCourt.draw_gate(self, g, ThemeDB.fallback_font)


## Tiles `tile` at the sprite scale over `area`, clipping the last row and column (GFX-006).
func _draw_tiled(tile: Texture2D, area: Rect2) -> void:
	var step := tile.get_size() * float(Sprites.scale())
	if step.x <= 0.0 or step.y <= 0.0:
		return
	var y := area.position.y
	while y < area.end.y:
		var h := minf(step.y, area.end.y - y)
		var x := area.position.x
		while x < area.end.x:
			var w := minf(step.x, area.end.x - x)
			var src := Rect2(Vector2.ZERO, Vector2(w / step.x * tile.get_width(), h / step.y * tile.get_height()))
			draw_texture_rect_region(tile, Rect2(x, y, w, h), src)
			x += step.x
		y += step.y


## GFX-079: stone steps down a slope (walkable): pale treads with a dark riser line under each, side kerbs.
func _draw_steps(r: Rect2) -> void:
	# GFX-151: 5-8 deep treads, a lit front edge and a shadow under each, widening toward the bottom, no side rails.
	var winter := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	var treads := SectCourt.stair_treads(r)
	draw_rect(r.grow(2.0), Color("5f686e"))
	for i in treads.size():
		var t: Dictionary = treads[i]
		var tr: Rect2 = t["rect"]
		draw_rect(tr, Color("b4bcc0") if i % 2 == 0 else Color("a9b2b6"))
		draw_rect(t["tread"], Color("dde3e6"))
		draw_rect(t["shadow"], Color("6f787e"))
		if winter:
			draw_rect(Rect2(tr.position.x, tr.position.y + 2.0, tr.size.x, 2.0), Color(0.95, 0.98, 1.0, 0.8))
	# GFX-113: stone lanterns on both sides, every other tread, in a high (map.high) region.
	if _region.get("map", {}).get("high", null) is Dictionary:
		var ly := r.position.y + 10.0
		while ly < r.end.y - 6.0:
			for lx in [r.position.x - 14.0, r.end.x + 14.0]:
				draw_rect(Rect2(lx - 5.0, ly + 8.0, 10.0, 4.0), Color("5f686e"))
				draw_rect(Rect2(lx - 3.0, ly - 1.0, 6.0, 9.0), Color("8d959b"))
				draw_rect(Rect2(lx - 6.0, ly - 8.0, 12.0, 7.0), Color("b4bcc0"))
				draw_rect(Rect2(lx - 3.0, ly - 6.0, 6.0, 3.0), Color("f2c75c"))
			ly += 56.0


## GFX-167: one drift as a low mound: a soft shadow along the lower edge, a body a shade under the ground snow and a lit crest
## along the top only (never a flat pure-white bar).
func _draw_drift_mound(r: Rect2, seed_value: int, col: Color, winter: bool) -> void:
	var shadow := Scenery.shadow_blob(Vector2(r.get_center().x, r.end.y + 1.0), Vector2(r.size.x * 0.55, maxf(r.size.y * 0.3, 2.5)), seed_value)
	draw_colored_polygon(shadow, Color(0.35, 0.42, 0.55, 0.28 if winter else 0.18))
	var body := Scenery.drift_mound(r, seed_value)
	draw_colored_polygon(body, col.darkened(0.04))
	var crest := Scenery.drift_mound(Rect2(r.position.x + r.size.x * 0.12, r.position.y, r.size.x * 0.76, r.size.y * 0.7), seed_value + 3)
	draw_colored_polygon(crest, Color(col.lightened(0.5), col.a * 0.55))


## GFX-123: crags (lit top face over a dark cliff face) and wind-streaked snow drifts of a map.high region.
func _draw_crags(map: Dictionary) -> void:
	if _crags.is_empty():
		return
	var px := float(Sprites.scale())
	var rock := Color(String(map.get("decor", {}).get("rock_color", "a3adb5")))
	var winter := GroundTiles.ground_season(_season, map) == "Winter"
	for it: Dictionary in _crags:
		var r: Rect2 = it["rect"]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(it["seed"])
		if it["kind"] == "crag":
			var outline := Scenery.crag_outline(r, int(it["seed"]))
			var foot := Scenery.shadow_blob(Vector2(r.get_center().x, r.end.y + 2.0), Vector2(r.size.x * 0.55, 6.0), int(it["seed"]))
			draw_colored_polygon(foot, Color(0, 0, 0, 0.22))
			draw_colored_polygon(outline, rock.darkened(0.45))
			# a lit top-left facet: the upper left part of the silhouette
			var lit := PackedVector2Array()
			var mid_x := r.position.x + r.size.x * 0.55
			lit.append(outline[1])
			for i in range(2, outline.size() - 2):
				if outline[i].x <= mid_x:
					lit.append(outline[i])
			lit.append(Vector2(mid_x, r.position.y + r.size.y * 0.5))
			lit.append(Vector2(outline[1].x, r.position.y + r.size.y * 0.55))
			if lit.size() >= 3:
				draw_colored_polygon(lit, rock.lightened(0.05))
			for c in rng.randi_range(1, 2):
				var cx := r.position.x + rng.randf_range(0.2, 0.8) * r.size.x
				draw_line(Vector2(cx, r.position.y + r.size.y * 0.3), Vector2(cx + px * 2.0, r.end.y - px * 2.0), rock.darkened(0.65), px)
			var ring := outline.duplicate()
			ring.append(outline[0])
			draw_polyline(ring, rock.darkened(0.7), px)
			if winter:
				draw_polyline(PackedVector2Array(outline.slice(2, outline.size() - 2)), Color("e8eef4"), px * 2.0)
		else:
			var look := Scenery.drift_look(GroundTiles.ground_season(_season, map), int(it["seed"]))  # GFX-153: remnants outside winter
			if not bool(look["show"]):
				continue
			var sc: Vector2 = look["scale"]
			var dr := Rect2(r.position.x, r.end.y - r.size.y * sc.y, r.size.x * sc.x, r.size.y * sc.y)
			var a := 0.95 if winter else float(look["alpha"]) * 0.8
			var dcol: Color = look["color"]
			var parts: Array[Rect2] = Scenery.drift_lumps(dr, int(look["lumps"]), int(it["seed"]))
			for pr in parts:
				_draw_drift_mound(pr, int(it["seed"]) + int(pr.position.x), Color(0.91, 0.94, 0.97, a) if winter else Color(dcol, a), winter)


## GFX-113: pines leaning out over the top cliffs of a map.high region (Scenery.high_pines).
func _draw_high_pines(map: Dictionary) -> void:
	var base := Color(str(map.get("decor", {}).get("tree_color", "2e5a2a")))
	var snowy := Scenery.is_snowy(_season) and not bool(map.get("no_snow", false))
	for p: Dictionary in Scenery.high_pines(_region):
		draw_set_transform(p["pos"], float(p["lean"]) * 0.28, Vector2.ONE)
		_draw_tree_pine(Vector2.ZERO, 1.15, base, snowy)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## GFX-079: a cloud-sea band: layered pale translucent bands with rounded puffs; static (it never moves).
func _draw_clouds(r: Rect2) -> void:
	if _region.get("map", {}).get("high", null) is Dictionary:
		# GFX-113: a pale cloud sea behind the landmark, fading downward.
		for k in 6:
			draw_rect(Rect2(r.position.x, r.end.y + float(k) * 10.0, r.size.x, 10.0), Color(0.93, 0.97, 1.0, 0.30 - 0.05 * k))
	for layer in 3:
		var band := Rect2(r.position.x, r.position.y + r.size.y * layer / 3.0, r.size.x, r.size.y / 3.0 + 4.0)
		draw_rect(band, Color(0.92, 0.96, 1.0, 0.16 + 0.07 * layer))
		var x := r.position.x + 30.0 * layer
		var k := 0
		while x < r.end.x:
			var puff := 26.0 + float((k * 37 + layer * 19) % 24)
			draw_circle(Vector2(x, band.position.y + 4.0), puff * 0.5, Color(0.95, 0.98, 1.0, 0.14 + 0.05 * layer))
			x += 90.0 + float((k * 53) % 40)
			k += 1


## One map.landmarks entry: its `landmark_<kind>` sprite scaled into the rect, else placeholder art (GFX-008).
func _draw_landmark(lm: Dictionary) -> void:
	var size := _vec(lm["size"])
	var r := Rect2(_vec(lm["pos"]) - size / 2.0, size)
	var tex := Sprites.texture("landmark_" + str(lm["kind"]))
	if tex != null:
		draw_texture_rect(tex, r, false)
		return
	if lm["kind"] == "pine" and String(lm.get("tree_kind", "pine")) != "pine":
		# GFX-046: a landmark tree of another kind (a dead tree in the marsh), drawn by the decor tree painters.
		var tree_base := Color(str(_region.get("map", {}).get("decor", {}).get("tree_color", "2e5a2a")))
		_draw_tree(Vector2(r.get_center().x, r.end.y - 16.0), 1.2, tree_base, String(lm["tree_kind"]))
		return
	if lm["kind"] == "jetty":
		_draw_jetty(lm)
		return
	if lm["kind"] == "steps":
		_draw_steps(r)
		return
	if lm["kind"] == "clouds":
		_draw_clouds(r)
		return
	if lm["kind"] == "cliff":
		# GFX-111: landmark cliffs use the same rock template as the edge props, not the brown timber palette.
		_draw_rock_mass(r, hash(str(lm["pos"])), 1, 1.0, _rock_color(), Scenery.is_snowy(_season) and not bool(_region.get("map", {}).get("no_snow", false)))
		return
	if lm["kind"] == "field" and _region.get("map", {}).has("market"):
		_draw_planter(r)  # GFX-126: a herb planter box, not a farm field
		return
	if lm["kind"] == "field":
		_draw_field(r)  # GFX-140: tilled earth with furrows and seasonal crops
		return
	if PixelLandmark.supports(str(lm["kind"])):
		var water := Color(str(lm["color"])) if lm.has("color") else Color(String(PlaceLooks.WATER_TINTS.get(String(_region.get("map", {}).get("water", "clear")), "3f7fa8")))
		var frozen := Fishing.is_iced(GameState.data, GameState.current_region, _season)
		if lm["kind"] == "house":
			var li: int = (_region.get("map", {}).get("landmarks", []) as Array).find(lm)
			if _yards.get("roof", {}).has(li):
				water = _yards["roof"][li]  # GFX-127: a house takes its roof colour through the tint
		var shape: Dictionary = {}
		if lm["kind"] == "pond":
			shape = {"seed": hash(str(lm["pos"]))}  # GFX-135: a ragged, per-pond shoreline
		elif lm["kind"] == "stream":
			var horizontal := size.x >= size.y
			var sz2 := Vector2(PixelLandmark.pixel_size("stream", size)) * float(Sprites.scale())
			var reeds := "" if Scenery.is_snowy(_season) else ("9a6a2a" if _season == "Autumn" else "4f7a3a")
			shape = {"seed": hash(str(lm["pos"])), "spans": Scenery.stream_spans(_region, lm), "origin": (r.get_center().x - sz2.x / 2.0) if horizontal else (r.end.y - sz2.y), "reeds": reeds}
			# GFX-178: the texture holds the whole swing of the bed, STREAM_AMP either side of the landmark rect.
			size = size + (Vector2(0.0, Scenery.STREAM_AMP * 2.0) if horizontal else Vector2(Scenery.STREAM_AMP * 2.0, 0.0))
		var ptex := PixelLandmark.texture(str(lm["kind"]), size, water, frozen, MotionFx.reduced(), String(_region.get("map", {}).get("building_style", "thatch")), String(_region.get("map", {}).get("water", "clear")), shape)
		var px := Vector2(ptex.get_size()) * float(Sprites.scale())
		if lm["kind"] == "house":
			PlaceArt.contact_shadow(self, Vector2(r.get_center().x, r.end.y), px.x)
		var origin := Vector2(r.get_center().x - px.x / 2.0, r.end.y - px.y)
		draw_texture_rect(ptex, Rect2(origin, px), false)
		_draw_season_overlay(str(lm["kind"]), origin, r, ptex.get_size())
		if lm["kind"] == "stream":
			_draw_bridges(r)
		return
	match lm["kind"]:
		"house":
			var roof_h := r.size.y * 0.55
			draw_rect(Rect2(r.position.x + 6, r.position.y + roof_h - 6, r.size.x - 12, r.size.y - roof_h + 6), Color("c9b48a"))
			draw_rect(Rect2(r.position.x + r.size.x / 2.0 - 8, r.end.y - 26, 16, 26), Color("4a3524"))
			draw_rect(Rect2(r.position.x + 14, r.end.y - 36, 14, 14), Color("3a2f26"))
			var roof := PackedVector2Array([
				Vector2(r.position.x - 4, r.position.y + roof_h),
				Vector2(r.position.x + 10, r.position.y + roof_h - 6),
				Vector2(r.position.x + 24, r.position.y),
				Vector2(r.end.x - 24, r.position.y),
				Vector2(r.end.x - 10, r.position.y + roof_h - 6),
				Vector2(r.end.x + 4, r.position.y + roof_h),
			])
			draw_colored_polygon(roof, Color("5a4638"))
			for i in 4:
				var y := r.position.y + roof_h * (i + 1) / 5.0
				draw_line(Vector2(r.position.x + 6, y), Vector2(r.end.x - 6, y), Color("3f3128"), 2.0)
		"field":
			draw_rect(r, Color("6e5636"))
			var y := r.position.y + 8.0
			while y < r.end.y - 4.0:
				draw_line(Vector2(r.position.x + 6, y), Vector2(r.end.x - 6, y), Color("9ab34f"), 4.0)
				y += 14.0
			draw_rect(r, Color("4a3a24"), false, 2.0)
		"pond":
			draw_set_transform(r.get_center(), 0.0, Vector2(1.0, r.size.y / r.size.x))
			draw_circle(Vector2.ZERO, r.size.x / 2.0 + 5.0, Color("8a9a70"))
			var water := Color(str(lm["color"])) if lm.has("color") else Color("3f7fa8")
			draw_circle(Vector2.ZERO, r.size.x / 2.0, water)
			draw_circle(Vector2(-r.size.x * 0.12, -r.size.x * 0.08), r.size.x * 0.22, water.lightened(0.25))
			draw_set_transform(Vector2.ZERO)
		"fence":
			for y in [r.position.y + 6.0, r.end.y - 6.0]:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("7a5a3a"), 3.0)
			var x := r.position.x
			while x <= r.end.x:
				draw_rect(Rect2(x - 2, r.position.y, 4, r.size.y), Color("5a4028"))
				x += 20.0
		"well":
			draw_circle(r.get_center(), minf(r.size.x, r.size.y) / 2.0, Color("7d7a72"))
			draw_circle(r.get_center(), minf(r.size.x, r.size.y) / 2.0 - 6.0, Color("23323f"))
		"wall":
			draw_rect(r, Color("8a8478"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, minf(5.0, r.size.y))), Color("b8b2a2"))
			draw_rect(Rect2(r.position.x, r.end.y - minf(4.0, r.size.y), r.size.x, minf(4.0, r.size.y)), Color("5f5a50"))
			draw_rect(r, Color("4a463e"), false, 2.0)
		"cliff":
			draw_rect(r, Color("6e7078"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color("8b8e96"))
			draw_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.3, r.size.x, r.size.y * 0.3), Color("3f4148"))
			var cx := r.position.x + 14.0
			while cx < r.end.x - 6.0:
				draw_line(Vector2(cx, r.position.y + 3.0), Vector2(cx - 6.0, r.end.y - 3.0), Color("4d5058"), 2.0)
				cx += 38.0
		"stream":
			draw_rect(r, Color("3f7fa8"))
			draw_rect(r, Color("2e6488"), false, 2.0)
			var ripple := r.position.y + 12.0
			while MotionFx.reduced() and ripple < r.end.y - 6.0:
				draw_line(Vector2(r.get_center().x - r.size.x * 0.25, ripple), Vector2(r.get_center().x + r.size.x * 0.25, ripple), Color("8cc4e0"), 2.0)
				ripple += 46.0
			_draw_bridges(r)
		"lantern":
			var c := r.get_center()
			draw_circle(c - Vector2(0, r.size.y * 0.3), 20.0, Color(1.0, 0.8, 0.4, 0.18))
			draw_rect(Rect2(c.x - 1.5, c.y - r.size.y * 0.1, 3, r.size.y * 0.6), Color("4a3524"))
			draw_rect(Rect2(c.x - 6, c.y - r.size.y * 0.5, 12, 11), Color("c0392b"))
			draw_rect(Rect2(c.x - 3, c.y - r.size.y * 0.5 + 3, 6, 5), Color("f2c35b"))
		"pine":
			var c := r.get_center()
			draw_rect(Rect2(c.x - 3, r.end.y - 12, 6, 12), Color("4a3524"))
			for i in 3:
				var w := r.size.x * (0.55 + 0.22 * i)
				var top := r.position.y + r.size.y * 0.2 * i
				draw_colored_polygon(PackedVector2Array([Vector2(c.x, top), Vector2(c.x - w / 2.0, top + r.size.y * 0.42), Vector2(c.x + w / 2.0, top + r.size.y * 0.42)]), Color("1f3d2a").lightened(0.06 * i))
		"stall":
			draw_rect(Rect2(r.position.x + 4, r.position.y + r.size.y * 0.4, r.size.x - 8, r.size.y * 0.6), Color("7a5a3a"))
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.4), Color("b5493a"))
			var sx := r.position.x
			var flip := false
			while sx < r.end.x:
				if flip:
					draw_rect(Rect2(sx, r.position.y, minf(10.0, r.end.x - sx), r.size.y * 0.4), Color("e8dcc0"))
				flip = not flip
				sx += 10.0
			draw_rect(Rect2(r.position.x + 8, r.position.y + r.size.y * 0.55, r.size.x - 16, 6), Color("c9a24a"))


## GFX-126: a raised herb box with a wooden rim and a few sprigs (snow-capped in Winter).
func _draw_planter(r: Rect2) -> void:
	var snowy := Scenery.is_snowy(_season)
	var look := Scenery.planter_look(_season)
	draw_rect(Rect2(r.position + Vector2(2, r.size.y - 4), Vector2(r.size.x, 6)), Color(0, 0, 0, 0.22))
	draw_rect(r, look["rim"])
	var inner := r.grow(-5.0 if snowy else -4.0)
	draw_rect(inner, look["fill"])
	if snowy:  # GFX-128: dark dead stalks poke through the snow
		var sx := inner.position.x + 6.0
		var n := 0
		while sx < inner.end.x - 4.0:
			var top := inner.position.y + 5.0 + float((n * 7) % 9)
			draw_rect(Rect2(sx, top, 2, inner.end.y - top - 3.0), Color("3a2e22"))
			draw_rect(Rect2(sx - 2, top + 3.0, 2, 1), Color("3a2e22"))
			draw_rect(Rect2(sx + 2, top + 1.0, 2, 1), Color("3a2e22"))
			sx += 11.0
			n += 1
	if not snowy:
		var x := inner.position.x + 5.0
		while x < inner.end.x - 3.0:
			var y := inner.position.y + 5.0
			while y < inner.end.y - 3.0:
				draw_rect(Rect2(x, y, 3, 3), Color("6f9a4a") if int(x + y) % 3 else Color("8cb860"))
				y += 9.0
			x += 9.0
	draw_rect(r, Color("4a3624"), false, 2.0)


## GFX-037: snow caps on roofs and pines, an ice rim on ponds, crop rows on the field, by `_season`.
func _draw_season_overlay(kind: String, origin: Vector2, r: Rect2, pix: Vector2) -> void:
	var sc := float(Sprites.scale())
	var snow := Color("f4f8ff")
	var winter := Scenery.is_snowy(_season)
	match kind:
		"house":
			if winter:
				for i in 4:
					var inset := 13 - i
					draw_rect(Rect2(origin + Vector2(1 + inset, 3 + i) * sc, Vector2(48 - 2 * inset, 1) * sc), snow)
		"stall":
			if winter:
				draw_rect(Rect2(origin + Vector2(0, 0), Vector2(40, 2) * sc), snow)
		"fence":
			if winter:
				draw_rect(Rect2(origin, Vector2(pix.x, 1) * sc), snow)
		"well":
			if winter:
				draw_rect(Rect2(origin + Vector2(pix.x * 0.2, 0) * sc, Vector2(pix.x * 0.6, 2) * sc), snow)
		"jetty", "dock":
			if winter:
				draw_rect(Rect2(origin, Vector2(pix.x, 1) * sc), snow)
		"pine":
			if winter:
				for i in 3:
					for j in 3:
						var half := (j + 2 + i) / 2 + 1
						draw_rect(Rect2(origin + Vector2(10 - half, i * 6 + j) * sc, Vector2(half * 2, 1) * sc), snow)
		"pond":
			pass  # GFX-135: the frozen texture carries its own snow drifts


## GFX-140: a tilled field: ragged earth, furrow rows along the long side, and the season's crop on the dark rows
## (sprouts, tall green with a few flowers, golden with sheaves, bare furrows with snow in the troughs).
func _draw_field(r: Rect2) -> void:
	var no_snow := bool(_region.get("map", {}).get("no_snow", false))
	var lay := Scenery.field_layout(r, int(r.position.x) * 31 + int(r.position.y) * 17, _season, no_snow)
	var look: Dictionary = lay["look"]
	var vertical: bool = lay["vertical"]
	var outline: PackedVector2Array = lay["outline"]
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_colored_polygon(outline, Color("6e5636"))
	for row: Dictionary in lay["rows"]:
		var band: Rect2 = row["rect"]
		if bool(row["dark"]):
			draw_rect(band, Color("4f3c24"))
			if look["snow"]:
				draw_rect(band.grow_individual(0, -1, 0, -1) if not vertical else band.grow_individual(-1, 0, -1, 0), Color(0.92, 0.96, 1.0, 0.8))
		else:
			draw_rect(band, Color("85693f"))
	draw_polyline(closed, Color("3a2b18"), 2.0)
	var style: String = look["style"]
	var color: Color = look["color"]
	var n := 0
	for p: Vector2 in lay["crops"]:
		n += 1
		if style == "sprout":
			draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 4)), color)
			draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 1)), color.lightened(0.2))
		else:
			var h := 5.0 if style == "golden" else 7.0
			draw_rect(Rect2(p + Vector2(-1.5, -h), Vector2(3, h)), color)
			draw_rect(Rect2(p + Vector2(-1.5, -h), Vector2(3, 1.5)), color.lightened(0.2))
			if style == "tall" and n % 6 == 0:
				draw_rect(Rect2(p + Vector2(-1, -h - 2), Vector2(2, 2)), Color("f2e07a") if n % 12 == 0 else Color("f4f4ee"))
	if look["sheaves"]:
		for k in 3:
			var sp := r.position + Vector2(r.size.x * (0.25 + 0.25 * k), r.size.y * (0.35 + 0.3 * (k % 2)))
			draw_rect(Rect2(sp, Vector2(6, 9)), Color("e8c86a"))
			draw_rect(Rect2(sp + Vector2(0, 6), Vector2(6, 3)), Color("8a5a2a"))


## GFX-140: a scarecrow beside the biggest field of a village (map.yards), on its free right-hand side.
func _draw_field_scarecrow(map: Dictionary) -> void:
	if not bool(map.get("yards", false)):
		return
	var best := Rect2()
	for lm: Dictionary in map.get("landmarks", []):
		if str(lm.get("kind", "")) == "field":
			var sz := _vec(lm["size"])
			if sz.x * sz.y > best.size.x * best.size.y:
				best = Rect2(_vec(lm["pos"]) - sz / 2.0, sz)
	if best.size != Vector2.ZERO:
		_draw_scarecrow(Vector2(best.end.x + 12.0, best.get_center().y))


## GFX-140: a scarecrow (post, crossbar, straw head and hat) standing at `base`.
func _draw_scarecrow(base: Vector2) -> void:
	draw_rect(Rect2(base + Vector2(-1, -26), Vector2(3, 26)), Color("6a4a2a"))
	draw_rect(Rect2(base + Vector2(-11, -20), Vector2(23, 3)), Color("6a4a2a"))
	draw_rect(Rect2(base + Vector2(-9, -17), Vector2(5, 6)), Color("c9a24a"))
	draw_rect(Rect2(base + Vector2(6, -17), Vector2(5, 6)), Color("c9a24a"))
	draw_circle(base + Vector2(0, -30), 5.0, Color("e0c27a"))
	draw_rect(Rect2(base + Vector2(-8, -36), Vector2(17, 3)), Color("8a6a3a"))
	draw_rect(Rect2(base + Vector2(-4, -41), Vector2(9, 5)), Color("8a6a3a"))


## GFX-046: the jetty runs out from the shore into its pond (Scenery.jetty_layout); darker posts stand in the water.
func _draw_jetty(lm: Dictionary) -> void:
	var lay := Scenery.jetty_layout(_region, lm)
	var r: Rect2 = lay["rect"]
	var size := _vec(lm["size"])
	var winter := Scenery.is_snowy(_season)
	var toward: int = -1 if int(lay.get("toward_water", 0)) == 0 else int(lay["toward_water"])
	var look := Scenery.jetty_stage_look(_jetty_stage())  # WU-494: the village project builds it up in stages
	var vertical := bool(lay["vertical"])
	var frac: float = look["frac"]
	var full := r
	# The planked part keeps the shore end; the water end stays bare posts until built.
	if frac < 1.0:
		var keep := (r.size.y if vertical else r.size.x) * frac
		var from_water_low := toward < 0
		if vertical:
			r = Rect2(r.position.x, r.end.y - keep if from_water_low else r.position.y, r.size.x, keep)
		else:
			r = Rect2(r.end.x - keep if from_water_low else r.position.x, r.position.y, keep, r.size.y)
	if frac > 0.0:
		if vertical:
			_draw_jetty_vertical(r, toward, winter)
		else:
			var ptex := PixelLandmark.texture("jetty", size)
			var sc := float(Sprites.scale())
			var px := Vector2(ptex.get_size()) * sc
			var src_w := ptex.get_width() * frac
			var dst := Rect2(r.position.x, r.get_center().y - px.y / 2.0, px.x * frac, px.y)
			if frac >= 1.0:
				dst = Rect2(r.get_center() - px / 2.0, px)
			var shore_right := toward < 0
			draw_texture_rect_region(ptex, dst, Rect2(ptex.get_width() - src_w if shore_right else 0.0, 0, src_w, ptex.get_height()))
			if winter:
				draw_rect(Rect2(dst.position, Vector2(dst.size.x, sc)), Color("f4f8ff"))
	if bool(look["gaps"]):
		var gap := Color("4a3524")
		if vertical:
			var y := r.position.y + 6.0
			while y < r.end.y:
				draw_rect(Rect2(r.position.x + 2.0, y, r.size.x - 4.0, 3.0), gap)
				y += 14.0
		else:
			var x := r.position.x + 6.0
			while x < r.end.x:
				draw_rect(Rect2(x, r.position.y + 3.0, 3.0, r.size.y - 6.0), gap)
				x += 14.0
	var post := Color("2e2218")
	for post_rect: Rect2 in Scenery.jetty_posts(_region, lm, _jetty_stage()):  # WU-500: only posts in or at the water
		draw_rect(post_rect, post)
	if bool(look["lantern"]):  # a lantern post at the shore end
		var shore := Vector2(full.get_center().x, full.end.y if toward < 0 else full.position.y) if vertical else Vector2(full.end.x if toward < 0 else full.position.x, full.get_center().y)
		draw_rect(Rect2(shore + Vector2(-1, -22), Vector2(3, 22)), Color("5a4028"))
		draw_rect(Rect2(shore + Vector2(-4, -30), Vector2(9, 9)), Color("d9503a"))
		draw_rect(Rect2(shore + Vector2(-2, -28), Vector2(5, 5)), Color("f4d27a"))


## WU-502: the terrace project's stage (0..3) in its own region; -1 anywhere else or with no session.
func _terrace_stage() -> int:
	if not GameState.has_session():
		return -1
	var idx := SeasonTasks.project_index(GameState.data, "terraces")
	if idx < 0 or String(SeasonTasks.project_list(GameState.data)[idx].get("region", "")) != GameState.current_region:
		return -1
	return SeasonTasks.project_stage(GameState.player, GameState.data, idx)


## WU-502: stone edging, stepped terrace rows (lit top edge, dark face), tidy herb lines and a water channel round the
## Herb Slope place (the one tagged "terraces"), by Scenery.terrace_look. The herb bed itself is drawn over the middle.
func _draw_terraces() -> void:
	var stage := _terrace_stage()
	if stage <= 0:
		return
	var look := Scenery.terrace_look(stage)
	for place: Dictionary in _region.get("places", []):
		if not (place.get("tags", []) as Array).has("terraces"):
			continue
		var size := Vector2(float(place["size"][0]), float(place["size"][1]))
		var r := Rect2(_vec(place["pos"]) - size / 2.0, size).grow(8.0)
		var winter := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
		var soil := Color("6b5236") if not winter else Color("8c8f94")
		var lit := Color("b8a37a") if not winter else Color("e8eef4")
		var rows: int = look["rows"]
		if rows > 0:
			var rh := r.size.y / float(rows)
			for i in rows:
				var band := Rect2(r.position.x + float(i) * 6.0, r.position.y + float(i) * rh, r.size.x - float(i) * 12.0, rh)
				draw_rect(band, soil.darkened(0.15 * float(rows - 1 - i)))
				draw_rect(Rect2(band.position, Vector2(band.size.x, 3.0)), lit)  # lit stone lip
				draw_rect(Rect2(band.position.x, band.position.y + 3.0, band.size.x, 3.0), soil.darkened(0.5))  # shadow face
				if look["herbs"]:
					var x := band.position.x + 8.0
					while x < band.end.x - 8.0:
						draw_rect(Rect2(x, band.position.y + rh * 0.55, 4.0, 5.0), Color("5fae4a") if not winter else Color("9fb0a0"))
						x += 12.0
		if look["edging"]:
			var stone := Color("9a9a92")
			var x2 := r.position.x
			while x2 < r.end.x:
				draw_rect(Rect2(x2, r.end.y - 3.0, 6.0, 4.0), stone)
				draw_rect(Rect2(x2 + 3.0, r.position.y - 1.0, 6.0, 4.0), stone.lightened(0.15))
				x2 += 9.0
		if look["channel"]:
			draw_rect(Rect2(r.end.x + 1.0, r.position.y + 2.0, 4.0, r.size.y - 4.0), Color("4f8fc0" if not winter else "b8d4e6"))


## WU-494: the Village Pond Jetty's project stage (0..3) in its own region; -1 (plain whole jetty) anywhere else or with no session.
func _jetty_stage() -> int:
	if not GameState.has_session():
		return -1
	var idx := SeasonTasks.project_index(GameState.data, "jetty")
	if idx < 0 or String(SeasonTasks.project_list(GameState.data)[idx].get("region", "")) != GameState.current_region:
		return -1
	return SeasonTasks.project_stage(GameState.player, GameState.data, idx)


## GFX-049: a north-south jetty: boards run across the walkway (3 px with 1 px gaps), dark side rails, and the
## posts at the water end. At least 18 px wide; `toward` < 0 means the water is at the north end.
## GFX-114: a dark-blue hole in the ice with a white rim where you fish from a jetty on a frozen pond.
func _draw_ice_hole(at: Vector2) -> void:
	if at == Vector2.INF:
		return
	PlaceArt.ellipse(self, at, Vector2(11, 7), Color("1b2a3c"))  # GFX-116: dark ring, then the white rim, then the water
	PlaceArt.ellipse(self, at, Vector2(10, 6), Color("f4f8ff"))
	PlaceArt.ellipse(self, at, Vector2(7.5, 4.5), Color("1f3a5c"))
	PlaceArt.ellipse(self, at + Vector2(-1.5, -1.5), Vector2(3, 1.5), Color("3c6a9a"))
	PlaceArt.ellipse(self, at + Vector2(15, 3), Vector2(6, 3.5), Color("dfe9f4"))  # a small snow mound beside it
	PlaceArt.ellipse(self, at + Vector2(14, 2), Vector2(4.5, 2.5), Color("ffffff"))


func _draw_jetty_vertical(r: Rect2, toward: int, winter: bool) -> void:
	var w := maxf(18.0, r.size.x)
	var box := Rect2(r.get_center().x - w / 2.0, r.position.y, w, r.size.y)
	var plank := Color("a07a4c")
	var gap := Color("4a3524")
	var rail := Color("5a4028")
	draw_rect(box, plank)
	var y := box.position.y
	while y < box.end.y:
		draw_rect(Rect2(box.position.x, y + 3.0, box.size.x, 1.0), gap)
		y += 4.0
	draw_rect(Rect2(box.position.x, box.position.y, 2.0, box.size.y), rail)
	draw_rect(Rect2(box.end.x - 2.0, box.position.y, 2.0, box.size.y), rail)
	if winter:
		draw_rect(Rect2(box.position.x + 2.0, box.position.y, box.size.x - 4.0, 2.0), Color("f4f8ff"))
	var tip_y := box.position.y if toward < 0 else box.end.y
	for dy: float in [2.0, 14.0]:
		var yy := tip_y + (dy if toward < 0 else -dy)
		draw_rect(Rect2(box.position.x - 2.0, yy - 2.0, 4.0, 4.0), gap.darkened(0.3))
		draw_rect(Rect2(box.end.x - 2.0, yy - 2.0, 4.0, 4.0), gap.darkened(0.3))


## Planks across a stream where `crossing` (its overlap with `path_rect`) is, laid along the path's direction.
## GFX-112: the road surface (ruts, slabs, planks, puddles, tufts) over one path rect.
func _draw_road(rect: Rect2, base: Color, snowy: bool) -> void:
	var rmap: Dictionary = _region.get("map", {})
	if str(rmap.get("ground_style", "grass")) == "bog" and str(rmap.get("water", "clear")) == "murky":
		var vseed := hash("%s|%s|bogroad" % [_region.get("id", ""), rect])
		var vertical := rect.size.x < rect.size.y
		var bed := Scenery.bog_bed_rect(rect)  # GFX-156: a raised, wobbling bed with mud verges either side, never a full-width floor
		var verge := Color(0.82, 0.86, 0.9, 0.85) if snowy else base.darkened(0.3)
		draw_colored_polygon(Scenery.ragged_outline(rect, vseed, 3.0, 2.0), verge)
		draw_colored_polygon(Scenery.bog_bed_polygon(rect, vseed + 1), Color("34475a") if snowy else _bog_water().darkened(0.3))  # winter: dark ice, never open water
		for pud: Rect2 in Scenery.bog_puddles(rect, vseed + 2):
			draw_rect(pud, Color("34475a") if snowy else _bog_water().darkened(0.15))
		if snowy:
			var crng := RandomNumberGenerator.new()
			crng.seed = hash("%s|%s|ice" % [_region.get("id", ""), rect])
			var along := (bed.size.y if vertical else bed.size.x)
			var cp := 0.0
			while cp < along - 8.0:
				var across := crng.randf_range(1.0, (bed.size.x if vertical else bed.size.y) - 2.0)
				var clen := crng.randf_range(6.0, 14.0)
				var a := bed.position + (Vector2(across, cp) if vertical else Vector2(cp, across))
				var b := a + (Vector2(crng.randf_range(-2.0, 2.0), clen) if vertical else Vector2(clen, crng.randf_range(-2.0, 2.0)))
				draw_line(a, b, Color("b9cde0"), 1.0)
				cp += crng.randf_range(10.0, 26.0)
	if str(rmap.get("ground_style", "")) == "scree":  # GFX-164: a darker grit verge (snow banked in winter) with a wobbling edge under the trail bed
		var gdark := Color(String(rmap.get("ground", "6b6b6b")))
		var vseed2 := hash("%s|%s|screeverge" % [_region.get("id", ""), rect])
		var verge_pts := Scenery.trail_edge_polygon(rect, vseed2, 1.5, 3.0)  # GFX-167: both verge edges wobble, not a straight band
		draw_colored_polygon(verge_pts, Color(0.86, 0.9, 0.95, 0.9) if snowy else gdark.darkened(0.22))
		var road := Scenery.stone_road(rect, vseed2 + 1)  # GFX-172: a wandering bed (+-4 px) with irregular flagstones, earth gaps and a verge
		var bed_col := Color("dfe6ee") if snowy else Scenery.scree_bed_color(gdark)
		draw_colored_polygon(road["bed"], bed_col.darkened(0.1) if not snowy else bed_col)
		for st: Dictionary in road["stones"]:
			var spts: PackedVector2Array = st["poly"]
			var sh: float = st["shade"]
			var sc := base.lightened(0.05 * sh) if sh >= 0.0 else base.darkened(-0.07 * sh)
			if snowy:
				sc = sc.lerp(Color("dfe6ee"), 0.55)
			draw_colored_polygon(spts, sc)
			var ctr := Vector2.ZERO
			for sp in spts:
				ctr += sp
			ctr /= float(spts.size())
			for si in spts.size():
				var e0 := spts[si]
				var e1 := spts[(si + 1) % spts.size()]
				var em := (e0 + e1) * 0.5 - ctr
				if em.y + em.x * 0.5 > 0.5:
					draw_line(e0, e1, base.darkened(0.28), 1.0)
				elif em.y < -0.5 and snowy:
					draw_line(e0, e1, Color(0.93, 0.95, 1.0, 0.85), 1.0)
				elif em.y < -0.5:
					draw_line(e0, e1, sc.lightened(0.12), 1.0)
		if snowy:  # trampled grey-brown slush along the middle instead of grey blocks
			var slush := Scenery.trail_edge_polygon(rect, vseed2 + 2, minf(rect.size.y if rect.size.x >= rect.size.y else rect.size.x, 60.0) * 0.33, 2.0)
			draw_colored_polygon(slush, Color(0.5, 0.47, 0.43, 0.75))
	if bool(rmap.get("moss_path", false)):  # GFX-170: moss on the stones, grass tufts at both edges
		var mseed := hash("%s|%s|moss" % [_region.get("id", ""), rect])
		var moss := Color("5f7d52") if not snowy else Color("6f8466")
		for mr: Rect2 in Scenery.moss_patches(rect, mseed):
			draw_rect(mr, Color(moss, 0.55 if snowy else 0.7))
		var tuft := Color(map_grass_color()).darkened(0.1)
		for tf: Dictionary in Scenery.verge_tufts(rect, mseed):
			var tp: Vector2 = (tf["pos"] as Vector2).floor()
			var th: float = float(tf["h"])
			draw_line(tp, tp + Vector2(0, -th), tuft, 1.0)
			draw_line(tp + Vector2(1, 0), tp + Vector2(2, -th + 1.0), tuft.lightened(0.12), 1.0)
	for t: Dictionary in Scenery.path_tiles(_region, rect, _weather_kind, snowy):
		var r: Rect2 = t["rect"]
		var shade: float = t["shade"]
		var c := base
		match str(t["kind"]):
			"grit":
				pass  # GFX-167: the bed is one wobbling polygon drawn before the tiles
			"flag_poly":
				continue  # GFX-172: scree flagstones come from Scenery.stone_road
				c = Scenery.paving_shade(base, hash("%s|%d|%d" % [_region.get("id", ""), int(r.position.x), int(r.position.y)]))
				if snowy and str(rmap.get("ground_style", "")) == "scree":
					c = c.lerp(Color("dfe6ee"), 0.55)  # GFX-167: flags half buried in snow
				var pts: PackedVector2Array = t["points"]
				draw_colored_polygon(pts, c)
				for pi in 4:  # a lit top: the lower and right edges get the dark line
					if pi == 1 or pi == 2:
						draw_line(pts[pi], pts[(pi + 1) % 4], base.darkened(0.25), 1.0)
				if snowy:
					draw_line(pts[0], pts[1], Color(0.93, 0.95, 1.0, 0.85), 2.0)
			"slab":
				if str(rmap.get("ground_style", "")) == "scree":
					continue  # GFX-172: scree flagstones come from Scenery.stone_road
				var tr: Rect2 = t["rect"]
				c = Scenery.paving_shade(base, hash("%s|%d|%d" % [_region.get("id", ""), int(tr.position.x), int(tr.position.y)]))
				if t["flag"] == "gap":  # GFX-122: a worn, lighter slab, never a dark hole
					c = base.lightened(0.07)
				if t["flag"] == "main":
					c = c.lightened(0.1)  # GFX-126: worn pale street slabs
				if snowy and str(rmap.get("ground_style", "")) == "scree":
					c = c.lerp(Color("dfe6ee"), 0.55)  # GFX-167: flags half buried in snow
				draw_rect(r, c)
				if str(rmap.get("ground_style", "")) == "scree":  # GFX-149: a lit top, dark line on the lower and right edges only
					draw_line(Vector2(r.position.x, r.end.y - 0.5), Vector2(r.end.x, r.end.y - 0.5), base.darkened(0.25), 1.0)
					draw_line(Vector2(r.end.x - 0.5, r.position.y), Vector2(r.end.x - 0.5, r.end.y), base.darkened(0.25), 1.0)
				else:
					draw_rect(r, base.darkened(0.2), false, 1.0)
				if t["flag"] == "crack":
					draw_line(r.position + Vector2(2, 2), r.end - Vector2(2, 2), base.darkened(0.4), 1.0)
			"plank":
				c = Color("7a5a38").lightened(0.06 * shade) if shade >= 0.0 else Color("7a5a38").darkened(-0.1 * shade)
				if t["flag"] == "missing":  # GFX-146: a rotted-away board shows murky water, never black
					draw_rect(r, _bog_water().darkened(0.3))
					continue
				if t["flag"] == "dark":
					c = c.darkened(0.15)
				draw_rect(r, c)
				draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)) if r.size.x >= r.size.y else Rect2(r.position, Vector2(1.0, r.size.y)), c.lightened(0.15))
				if posmod(hash(Vector2i(r.position)), 23) == 0:  # GFX-177: a post sunk in mud at intervals
					var pp := r.position + Vector2(0, r.size.y)
					draw_rect(Rect2(pp + Vector2(-1, -1), Vector2(5, 3)), Color(0.14, 0.17, 0.1, 0.8))
					draw_rect(Rect2(pp + Vector2(0, -4), Vector2(3, 6)), Color("3a2a1a"))
					draw_rect(Rect2(pp + Vector2(0, -4), Vector2(3, 1)), Color("6a5030"))
				if snowy and shade > -0.3:  # GFX-152: a snow cap on most boards
					draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)) if rect.size.x >= rect.size.y else Rect2(r.position, Vector2(2.0, r.size.y)), Color(0.93, 0.95, 1.0, 0.85))
			"mud":
				pass  # GFX-156: the verge is one ragged fill drawn before the tiles
			"stub":
				draw_rect(r, Color("7a5a38").darkened(0.3))
			"piling":
				draw_rect(r, Color("2b2118"))
			"rut", "edge":
				draw_rect(r, base.darkened(0.45 if t["flag"] == "gutter" else (0.15 if t["flag"] == "slush" else (0.22 if t["kind"] == "rut" else 0.12))))
			"puddle":
				draw_rect(r, Color(0.5, 0.6, 0.7, 0.7) if t["flag"] == "sky" else Color(0.2, 0.26, 0.3, 0.8))
			"pebble":
				draw_rect(r, base.lightened(0.18) if shade > 0.0 else base.darkened(0.3))
			"print":
				draw_rect(r, base.darkened(0.15))
			"tuft":
				var g := Color(map_grass_color())
				var tc := g.lightened(0.1) if shade > 0.0 else g
				var tf := str(t["flag"])
				if tf == "bent" or tf == "seed":  # GFX-162: reed tuft shapes along the marsh road verge
					var tb := r.position + Vector2(r.size.x * 0.5, r.size.y)
					draw_line(tb, tb + Vector2(0, -4), tc, 1.0)
					draw_line(tb + Vector2(-1, 0), tb + Vector2(-2, -3), tc, 1.0)
					if tf == "bent":
						draw_line(tb + Vector2(0, -4), tb + Vector2(2, -4), tc, 1.0)
					else:
						draw_rect(Rect2(tb + Vector2(-1, -6), Vector2(2, 3)), Color("6b4a2a"))
				else:
					draw_rect(r, tc)
		if snowy and str(t["kind"]) in ["edge", "tuft", "slab"]:
			var cap := Color(0.93, 0.95, 1.0, 0.8)
			if t["flag"] == "main" and rect.size.x < rect.size.y:  # GFX-128: no rungs across a north-south street
				draw_rect(Rect2(r.position, Vector2(minf(2.0, r.size.x), r.size.y)), Color(cap, 0.45))
			else:
				draw_rect(Rect2(r.position, Vector2(r.size.x, minf(2.0, r.size.y))), cap)
	if str(rmap.get("ground_style", "grass")) in ["grass", "litter"] or (str(rmap.get("ground_style", "")) == "bog" and str(rmap.get("water", "clear")) != "murky"):
		var gcol := Color(map_grass_color())
		var snow := Color(0.93, 0.95, 1.0)
		for v: Rect2 in Scenery.road_verge(rect, hash("%s|%s|verge" % [_region.get("id", ""), rect]), _region):
			if rect.encloses(v):
				draw_rect(v, snow if snowy else gcol)
			else:
				draw_rect(v, base)
				if snowy:  # a 2-4 px snow bank along the verge
					draw_colored_polygon(Scenery.snow_bank(v, hash("%s|%s|bank" % [_region.get("id", ""), v])), Color(snow, 0.9))


## GFX-146: the murky region water colour (boardwalk gaps and missing boards show it, darkened by the caller).
func _bog_water() -> Color:
	return Color(String(PlaceLooks.WATER_TINTS.get(String(_region.get("map", {}).get("water", "clear")), "3f7fa8")))


func map_grass_color() -> String:
	return str(_region.get("map", {}).get("decor", {}).get("grass_color", "4f7a3a"))


## The plank bridge wherever a path crosses the stream `r`.
func _draw_bridges(r: Rect2) -> void:
	for pr: Array in _region.get("map", {}).get("paths", []):
		var path_rect := Rect2(pr[0], pr[1], pr[2], pr[3])
		if path_rect.intersects(r):
			_draw_bridge(r.intersection(path_rect), path_rect)


func _draw_bridge(crossing: Rect2, path_rect: Rect2) -> void:
	var span := crossing.grow(4.0)
	draw_rect(span, Color("8a6a44"))
	var along_x := path_rect.size.x >= path_rect.size.y
	var pos := span.position.x if along_x else span.position.y
	var end := span.end.x if along_x else span.end.y
	while pos < end:
		if along_x:
			draw_line(Vector2(pos, span.position.y), Vector2(pos, span.end.y), Color("5a4028"), 2.0)
		else:
			draw_line(Vector2(span.position.x, pos), Vector2(span.end.x, pos), Color("5a4028"), 2.0)
		pos += 8.0
	draw_rect(span, Color("4a3524"), false, 2.0)


## GFX-037/041: a tree by season and kind (round, pine, willow, dead, bamboo).
func _draw_tree(p: Vector2, k: float, base: Color, kind: String = "round") -> void:
	var seed_value := int(p.x) * 7 + int(p.y) * 13
	var blossoms_ok: bool = bool(_region.get("map", {}).get("decor", {}).get("blossoms", true))
	var look := Scenery.tree_look(_season, seed_value, base, kind, blossoms_ok)
	var c: Color = look["canopy"]
	var ground_season := GroundTiles.ground_season(_season, _region.get("map", {}))
	if Scenery.tree_shadow(ground_season, bool(look["bare"])) == "foot":
		_draw_foot_shadow(p, k, ground_season == "Winter")
	else:
		_draw_tree_shade(p, k, kind)
	if look["bare"]:
		_draw_tree_bare(p, k, c, bool(look["snow"]), kind == "dead")
		return
	match kind:
		"pine":
			_draw_tree_pine(p, k, c, bool(look["snow"]))
		"bamboo":
			_draw_tree_bamboo(p, k, c)
		"willow":
			_draw_tree_round(p, k, c, look, seed_value)
			for i in 6:
				var sx := (i - 2.5) * 6.0
				var len := 14.0 + fposmod(seed_value * (i + 3), 9.0)
				draw_line(p + Vector2(sx, -4) * k, p + Vector2(sx * 1.1, -4.0 + len) * k, c.darkened(0.2), 1.0)
		_:
			_draw_tree_round(p, k, c, look, seed_value)


## GFX-163: a small flat ground-tinted shade ellipse of the given width.
func _draw_blob_shade(c: Vector2, w: float) -> void:
	var ground := Color(String(_region.get("map", {}).get("ground", "4d6b3c")))
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(c + Vector2(cos(a) * w / 2.0, sin(a) * w * 0.2))
	draw_colored_polygon(pts, Color(ground.darkened(0.55), 0.22))


## GFX-163: a flattened ellipse at the trunk foot, offset for the light, ground darkened (no grey bubble).
func _draw_tree_shade(p: Vector2, k: float, kind: String) -> void:
	var ground := Color(String(_region.get("map", {}).get("ground", "4d6b3c")))
	var w := Scenery.shadow_width(kind, k) * (0.7 if kind == "round" else 1.0)  # GFX-183: follows the trunk
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(p + Vector2(4, 15) * k + Vector2(cos(a) * w / 2.0, sin(a) * w * 0.2))
	draw_colored_polygon(pts, Color(ground.darkened(0.55), 0.22))


## GFX-049: bare trees get a flat ellipse at the trunk foot (ground shade darkened), not a round dark blot.
func _draw_foot_shadow(p: Vector2, k: float, snow: bool = false) -> void:
	var ground := Color(String(_region.get("map", {}).get("ground", "4d6b3c")))
	if snow:  # GFX-114: a snow-blue foot, not a dark coin on white
		ground = Color("9fb0c2")
	var w := 22.0 * k
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(p + Vector2(0, 15) * k + Vector2(cos(a) * w / 2.0, sin(a) * w * 0.15))
	draw_colored_polygon(pts, Color(ground, 0.35) if snow else Color(ground.darkened(0.45), 0.22))


func _draw_tree_round(p: Vector2, k: float, c: Color, look: Dictionary, seed_value: int) -> void:
	var lay := Scenery.round_tree_layout(seed_value)  # GFX-183: trunk, 3-5 lobes, lit rim, seeded size/lean
	var q: float = k * float(lay["scale"])
	var lean: float = float(lay["lean"])
	var tw: float = float(lay["trunk_w"])
	var th: float = float(lay["trunk_h"])
	var bark := Color("4a3524")
	var foot := p + Vector2(lean * 0.5, 16.0 * q)
	draw_rect(Rect2(foot + Vector2(-tw / 2.0, -th * q), Vector2(tw, th * q)), bark)
	draw_rect(Rect2(foot + Vector2(-tw / 2.0, -th * q), Vector2(maxf(1.0, tw * 0.4), th * q)), bark.lightened(0.18))
	var lobes: Array = lay["lobes"]
	for lobe: Dictionary in lobes:  # the dark underside first
		var lc: Vector2 = lobe["c"]
		draw_circle(p + (lc + Vector2(lean, 1.5)) * q, float(lobe["r"]) * q, c.darkened(0.3))
	for i in lobes.size():
		var lobe: Dictionary = lobes[i]
		var lc: Vector2 = lobe["c"]
		draw_circle(p + (lc + Vector2(lean, 0.0)) * q, float(lobe["r"]) * q, c.darkened(0.12 * float(i % 2)))
	for lobe: Dictionary in lobes:  # a lit top-left rim
		var lc: Vector2 = lobe["c"]
		draw_arc(p + (lc + Vector2(lean, 0.0)) * q, float(lobe["r"]) * q - 1.0, PI * 1.05, PI * 1.6, 8, c.lightened(0.25), 2.0)
	for i in int(look["blossoms"]):
		var o := Vector2(fposmod(seed_value * (i + 3), 29.0) - 14.0, fposmod(seed_value * (i + 5), 25.0) - 22.0)
		draw_rect(Rect2(p + o * k, Vector2(3, 3)), Color("f6c6dc"))
	for i in int(look["leaves"]):  # fallen leaves on the ground under the tree
		var o := Vector2(fposmod(seed_value * (i + 2), 37.0) - 18.0, 15.0 + fposmod(seed_value * (i + 7), 6.0))
		draw_rect(Rect2(p + o * k, Vector2(3, 2)), c.darkened(0.1))


func _draw_tree_bare(p: Vector2, k: float, c: Color, snowy: bool, broken_stub: bool) -> void:
	if not _marsh.is_empty() and not snowy:  # GFX-125: a root shadow and a little standing water at the foot
		draw_set_transform(p + Vector2(0, 16) * k, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 14.0 * k, Color(0.05, 0.1, 0.1, 0.4))
		draw_circle(Vector2(5, 0) * k, 8.0 * k, Color(0.12, 0.26, 0.28, 0.8))
		draw_set_transform(Vector2.ZERO)
	# Dead trees (broken_stub): a darker trunk with a 1 px pale bark highlight so they read on dark bog.
	draw_rect(Rect2(p + Vector2(-3, 2) * k, Vector2(6, 14) * k), Color("2a1f16") if broken_stub else Color("4a3524"))
	if broken_stub:
		draw_rect(Rect2(p + Vector2(-3, 2) * k, Vector2(1, 14 * k)), Color("b3a684"))
	for tip: Vector2 in [Vector2(-14, -22), Vector2(0, -30), Vector2(13, -20), Vector2(-8, -12), Vector2(8, -10)]:
		draw_line(p + Vector2(0, 2) * k, p + tip * k, c, 2.0)
		if snowy:
			draw_rect(Rect2(p + tip * k - Vector2(3, 3), Vector2(6, 3)), Color("f4f8ff"))
	if broken_stub:
		draw_line(p + Vector2(0, 8) * k, p + Vector2(-10, 3) * k, c.darkened(0.2), 3.0)


func _draw_tree_pine(p: Vector2, k: float, c: Color, snowy: bool) -> void:
	draw_rect(Rect2(p + Vector2(-2, 4) * k, Vector2(4, 12) * k), Color("3a2a1c"))
	for tier in 3:
		var top := -34.0 + tier * 11.0
		var half := 8.0 + tier * 5.0
		var pts := PackedVector2Array([p + Vector2(0, top) * k, p + Vector2(half, top + 16.0) * k, p + Vector2(-half, top + 16.0) * k])
		draw_colored_polygon(pts, c.darkened(0.05 * tier))
		draw_line(p + Vector2(0, top) * k, p + Vector2(-half, top + 16.0) * k, c.lightened(0.2), 1.5)
		if snowy:
			draw_line(p + Vector2(-half * 0.5, top + 8.0) * k, p + Vector2(half * 0.5, top + 8.0) * k, Color("f4f8ff"), 2.0)


func _draw_tree_bamboo(p: Vector2, k: float, c: Color) -> void:
	var stalk := c.lightened(0.25)
	for i in 4:
		var x := (i - 1.5) * 6.0
		var h := 26.0 + float((i * 7) % 4) * 6.0
		draw_line(p + Vector2(x, 12) * k, p + Vector2(x, 12.0 - h) * k, stalk, 2.0)
		var y := 6.0
		while y < h:
			draw_rect(Rect2(p + Vector2(x - 2, 12.0 - y) * k, Vector2(4, 1)), stalk.darkened(0.3))
			y += 6.0
		draw_line(p + Vector2(x, 12.0 - h) * k, p + Vector2(x + 5, 15.0 - h) * k, c, 2.0)
		draw_line(p + Vector2(x, 12.0 - h) * k, p + Vector2(x - 5, 15.0 - h) * k, c, 2.0)


## GFX-139: ferns, bushes, mushroom clusters and fallen logs under a grove; snow-covered mounds in winter.
## GFX-186: one merged dark under-canopy shadow per canopy mass (a few overlapping soft ellipses), under the trunks.
func _draw_canopy_shadows() -> void:
	var seen := {}
	var ground := Color(String(_region.get("map", {}).get("ground", "4d6b3c")))
	var snowy := Scenery.is_snowy(_season) and not bool(_region.get("map", {}).get("no_snow", false))
	var col := Color("7f90a4") if snowy else ground.darkened(0.6)
	for d: Dictionary in _decor:
		if not d.has("canopy") or seen.has(d["canopy"]):
			continue
		seen[d["canopy"]] = true
		var c: Vector2 = d["grove_centre"]
		var r: float = d["grove_radius"]
		for layer in 3:
			var rr := r * (1.25 - 0.2 * float(layer))
			var pts := PackedVector2Array()
			for i in 28:
				var a := TAU * float(i) / 28.0
				pts.append(c + Vector2(6, 16) + Vector2(cos(a) * rr, sin(a) * rr * 0.62))
			draw_colored_polygon(pts, Color(col, 0.13))


func _draw_undergrowth(u: Dictionary) -> void:
	var p: Vector2 = u["pos"]
	var k: float = u["scale"]
	var sgn := -1.0 if bool(u.get("flip", false)) else 1.0
	var snowy := Scenery.is_snowy(_season) and not bool(_region.get("map", {}).get("no_snow", false))
	var leaf := Color(String(_region.get("map", {}).get("decor", {}).get("grass_color", "35603f"))).darkened(0.1)
	match String(u["kind"]):
		"fern":
			if snowy:
				draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 3) * k, p + Vector2(-3, -3) * k, p + Vector2(3, -3) * k, p + Vector2(6, 3) * k]), Color("e4ecf2"))
				draw_line(p + Vector2(-5, 3) * k, p + Vector2(5, 3) * k, Color("a9b8c6"), 1.5)
			else:
				for a in [-0.9, -0.45, 0.0, 0.45, 0.9]:
					draw_line(p, p + Vector2(sin(a) * 9.0 * sgn, -cos(a) * 9.0) * k, leaf.lightened(0.1 * absf(a)), 1.5)
		"bush":
			var col := Color("e4ecf2") if snowy else leaf.darkened(0.1)
			draw_circle(p + Vector2(-4, 0) * k, 5.0 * k, col)
			draw_circle(p + Vector2(4, 0) * k, 5.5 * k, col.lightened(0.08))
			draw_circle(p + Vector2(0, -3) * k, 5.0 * k, col.lightened(0.15))
		"mushroom":
			if snowy:
				draw_circle(p, 4.0 * k, Color("dbe5ee"))
				draw_circle(p + Vector2(5, 1) * k, 3.0 * k, Color("e8eff5"))
			else:
				for o: Vector2 in [Vector2(-4, 0), Vector2(3, 1), Vector2(0, -3)]:
					draw_line(p + o * k, p + (o + Vector2(0, 3)) * k, Color("e8e0cc"), 1.5)
					draw_circle(p + o * k, 2.2 * k, Color("b8553a"))
		"reed":
			var rc := Color("d8ecf2") if snowy else leaf.lightened(0.05)
			for x in [-4.0, 0.0, 4.0]:
				draw_line(p + Vector2(x, 4) * k, p + Vector2(x * 0.8 * sgn, -11.0 + absf(x)) * k, rc, 1.5)
			if not snowy:
				draw_rect(Rect2(p + Vector2(-1.5, -14) * k, Vector2(3, 5) * k), Color("6a4a30"))
		"stone":
			var sc := Color("e4ecf2") if snowy else Color("8a8780")
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 3) * k, p + Vector2(-4, -3) * k, p + Vector2(3, -4) * k, p + Vector2(7, 3) * k]), sc)
			draw_line(p + Vector2(-4, -3) * k, p + Vector2(3, -4) * k, sc.lightened(0.3), 1.5)
		"log":
			var a := p + Vector2(-13, 0) * k * sgn
			var b := p + Vector2(13, 2) * k * sgn
			draw_line(a, b, Color("4a3524"), 6.0 * k)
			draw_line(a + Vector2(0, -2), b + Vector2(0, -2), Color("6a4e34"), 2.0 * k)
			draw_circle(b, 3.0 * k, Color("8a6a46"))
			if snowy:
				draw_line(a + Vector2(0, -3.5 * k), b + Vector2(0, -3.5 * k), Color("eef3f7"), 3.0 * k)


func _draw_decor(d: Dictionary) -> void:
	var p: Vector2 = d["pos"]
	var k: float = d["scale"]
	var c: Color = d["color"]
	var tex := Sprites.texture("decor_" + str(d["kind"]))
	if tex != null:
		var z := float(maxi(1, roundi(Sprites.scale() * k)))
		var sz := tex.get_size() * z
		draw_texture_rect(tex, Rect2(p - Vector2(sz.x / 2.0, sz.y), sz), false)
		return
	match d["kind"]:
		"tree":
			_draw_tree(p, k, c, String(d.get("tree_kind", "round")))
		"rock":
			var pts := PackedVector2Array([Vector2(-12, 6), Vector2(-9, -5), Vector2(-1, -9), Vector2(10, -4), Vector2(12, 6)])
			for i in pts.size():
				pts[i] = p + pts[i] * k
			draw_colored_polygon(pts, c)
			draw_line(p + Vector2(-9, -5) * k, p + Vector2(-1, -9) * k, c.lightened(0.3), 2.0)
		"grass":
			for x in [-4.0, 0.0, 4.0]:
				draw_line(p + Vector2(x, 4) * k, p + Vector2(x * 1.6, -5 + absf(x) * 0.5) * k, c, 1.5)
		"flower":
			var fl := Scenery.flower_look(_season, c, hash(p))
			if fl["kind"] == "glint":  # GFX-128: no pink blooms on the snow, just a frost glint
				draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), fl["color"])
				draw_rect(Rect2(p + Vector2(-2, 0), Vector2(4, 1)), Color(fl["color"], 0.45))
				return
			draw_line(p, p + Vector2(0, 6) * k, Color("4f7a3a") if _season != "Autumn" else Color("7a6a3a"), 1.5)
			for i in 5:
				draw_circle(p + Vector2.from_angle(TAU * i / 5.0) * 3.0 * k, 2.2 * k, fl["color"])
			draw_circle(p, 1.6 * k, Color("f2d24b"))
