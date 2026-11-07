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
## Seasonal tint (CanvasModulate only affects this canvas, not the HUD CanvasLayer).
var _season_tint: CanvasModulate
var _season := ""
var _ambient: Node
var _critters: CritterLayer  # GFX-086: hens, ducks, butterflies
var _mist_bands: MistBands  # GFX-091: drifting mist over misty regions
var _village_life: VillageLife
var _water_life: WaterLife
var _spread_clock := 0.0  ## WU-429: seconds since the last label spread from a moving beast.
var _roamer_spread_pos := {}
var _tracks: Array[Dictionary] = []  ## WU-450: a great beast's trail of prints
var _tracks_shape := "paw"
var _clear_zones := {"rects": [] as Array[Rect2], "points": [] as Array[Vector2]}  ## GFX-062
var _weather_kind := "clear"
## The pinned weather, readable by UI that draws its own sky (the duel stage, GFX-038); "" = none.
static var pinned_weather := ""
var _forced_weather := ""  # GFX-036: screenshots/tests pin the weather here
var _lightning_timer: Timer
var _strikes := 0
## Festival stalls beside merchants (WU-097), rebuilt when the day or region changes.
var _stalls: Array[Node2D] = []
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
	_build_roamers()
	_build_forage()
	_build_eggs()
	_refresh_stalls()
	_refresh_timed_places()
	var season := Calendar.season_of(GameClock.total_days)
	var weather := _weather_today()
	if season == _season and weather == _weather_kind:
		return
	_season = season
	_weather_kind = weather
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


## GFX-091: soft mist bands above the ground, under figures; off with Ambient effects.
func _refresh_mist_bands() -> void:
	if _mist_bands == null:
		_mist_bands = MistBands.new()
		_mist_bands.name = "MistBands"
		add_child(_mist_bands)
		move_child(_mist_bands, 0)
	# Only regions that name map.mist are misty; the 1.0 default of _mist_strength() is for fog sheets.
	var on: bool = bool(Settings.get_value("ambient_effects")) and _region.get("map", {}).has("mist")
	_mist_bands.setup(GameState.current_region, _mist_strength() if on else 0.0, map_size, not MotionFx.reduced())


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
	var frozen := Scenery.is_snowy(_season) and not bool(_region.get("map", {}).get("no_snow", false))
	_water_life.setup(_region, _weather_kind in ["rain", "storm"], frozen, MotionFx.reduced())
	if _critters == null:
		_critters = CritterLayer.new()
		_critters.name = "Critters"
		add_child(_critters)
	_critters.setup(_region, _season, GameClock.total_days, bool(Settings.get_value("ambient_effects")), MotionFx.reduced())


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
	var festival := ""
	for instance: Dictionary in WorldEvents.active_in(GameState.world_events, GameState.current_region):
		if WorldEvents.is_festival(GameState.data, String(instance["id"])):
			festival = String(instance["id"])
			break
	if festival == "":
		return
	var caption := FestivalContest.crowd_caption(GameState.data, festival, _contest_open(festival))
	var spots: Array[Vector2] = []
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
				spot = Roamer.pick_spot(GameState.current_region, day + 1, Wildlife.GREAT_SLOT, map_size, blocked, avoid, _clear_zones["rects"], _clear_zones["points"])
		if enemy != "":
			_tracks_shape = BeastTracks.shape_for(enemy)
			_tracks = BeastTracks.trail(GameState.current_region, day, map_size, spot, blocked, _clear_zones["rects"])
	queue_redraw()


## WU-426: one beast node for roamer `r`; its spot joins `avoid` so the next beast keeps its distance.
func _spawn_roamer(r: Dictionary, blocked: Array[Rect2], avoid: Array[Vector2]) -> void:
	var day := GameClock.total_days
	var slot := int(r["slot"])
	var spot := Roamer.pick_spot(GameState.current_region, day, slot, map_size, blocked, avoid, _clear_zones["rects"], _clear_zones["points"])
	avoid.append(spot)
	var node: Roamer = ROAMER_SCRIPT.new()
	node.setup(slot, String(r["enemy"]), spot, hash("%s:%d:%d:w" % [GameState.current_region, day, slot]), bool(r.get("great", false)))
	node.player_ref = player
	node.map_bounds = map_size
	node.blocked_rects = blocked
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
	for key in place:
		if LAYOUT_KEYS.has(key):
			continue
		node.set(key, _convert(place[key], node.get(key)))
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


func _build_npcs() -> void:
	for c in Npcs.in_region(GameState.npcs, GameState.data, GameState.current_region):
		if not GameState.data.npcs.has(c.id):
			continue  # Generated NPCs are placed by _build_generated_npcs().
		var def: Dictionary = GameState.data.npcs[c.id]
		var node: Interactable = NPC_SCRIPT.new()
		node.art_kind = "npc"
		node.npc_id = c.id
		node.display_name = "%s (%s)" % [c.name, def["title"]] if def.has("title") else c.name
		node.position = GameState.npc_spot(c.id)["pos"]  # FOLK-017
		node.size = _vec(def.get("size", [30, 30]))
		node.color = Color(def.get("color", "e6bf99"))
		add_child(node)
		move_child(node, player.get_index())
	_build_generated_npcs()
	var all: Array = get_children().filter(func(n: Node) -> bool: return n is Interactable)
	Interactable.spread_labels(all)
	Interactable.clamp_labels(all, Rect2(Vector2.ZERO, map_size))


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
	var gate := SectCourt.gate(_region)
	for i in spots.size():  # GFX-076: nobody stands in the gate
		spots[i] = SectCourt.nudge_off_gate(spots[i], gate)
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
	var stands := Npcs.haunt_positions(neighbours, _region, GameClock.total_days, int(data.family.get("adult_age", 16)), Weather.of(data, GameState.current_region, GameClock.total_days), visitor, GameState.visit_place_for(visitor), GameState.together_places())
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
		node.display_name = "%s (%s)" % [c.name, Npcs.world_title(c, GameState.player, data)]
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
	var hud := get_node_or_null("HUD")
	if hud != null and hud.has_method("occupied_rects"):
		var to_world := get_canvas_transform().affine_inverse()
		for r: Rect2 in hud.occupied_rects():
			occupied.append(to_world * r)
		if hud.has_method("current_prompt_rect"):  # GFX-069: the [E] chip covers no label
			var chip: Rect2 = hud.current_prompt_rect()
			if chip.size != Vector2.ZERO:
				occupied.append(to_world * chip)
	var gate := SectCourt.gate(_region)
	if not gate.is_empty():  # GFX-074: the gate's name board is a blocker, so the exit label moves off it
		occupied.append((SectCourt.gate_parts(gate)["stele"] as Rect2).grow(4.0))
	for node: Interactable in nodes:  # GFX-069: the target's highlight box is a blocker for the other labels
		if node.highlighted and node.visible:
			var box := Rect2(node.position - node.size / 2.0, node.size).grow(8.0)
			if not box.intersects(node.drawn_label_rect(view)):
				occupied.append(box)
	Interactable.spread_on_screen(nodes, view, occupied, player.position if player != null else Vector2.ZERO)


func _limit_camera() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = -CAMERA_MARGIN_TOP
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y) + CAMERA_MARGIN_BOTTOM  # WU-472: scroll clear of the HUD bars (the border draws past the edge)


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
		var gtex := GroundTiles.ground_texture(ground_color, rid, Vector2i(ceili(map_size.x / sc), ceili(map_size.y / sc)), flowers, gseason, str(map.get("ground_style", "grass")), Scenery.paved_zones(map, sc), float(map.get("scree_density", 1.0)))
		draw_texture_rect(gtex, Rect2(Vector2.ZERO, Vector2(gtex.get_size()) * sc), false)
	var path_tile := Sprites.first(["path_" + rid, "path"])
	var path_color := Color(map.get("path_color", "8a7350"))
	for r in map.get("paths", []):
		var rect := Rect2(r[0], r[1], r[2], r[3])
		if path_tile != null:
			_draw_tiled(path_tile, rect)
		else:
			var psc := float(Sprites.scale())
			var ptex := GroundTiles.path_texture(path_color, rid, Vector2i(ceili(rect.size.x / psc), ceili(rect.size.y / psc)), GroundTiles.ground_season(_season, map), str(map.get("ground_style", "grass")))
			draw_texture_rect(ptex, Rect2(rect.position, Vector2(ptex.get_size()) * psc), false)
	_draw_sect_courts()
	for lm: Dictionary in map.get("landmarks", []):
		_draw_landmark(lm)
	_draw_footprints()
	for t: Dictionary in _tracks:
		BeastTracks.draw_print(self, t["pos"], t["angle"], _tracks_shape, t["alpha"], t["side"], GroundTiles.ground_season(_season, map) == "Winter")
	for d in _decor:
		_draw_decor(d)
	var border_tile := Sprites.first(["border_" + rid, "border"])
	if border_tile != null:
		for strip: Rect2 in [Rect2(0, 0, map_size.x, 6), Rect2(0, map_size.y - 6, map_size.x, 6), Rect2(0, 6, 6, map_size.y - 12), Rect2(map_size.x - 6, 6, 6, map_size.y - 12)]:
			_draw_tiled(border_tile, strip)
	else:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(map.get("border", "2a3a20")), false, 6.0)


## GFX-068: the paved court of each sect hall and the mountain gate (no collision; drawn under the places).
func _draw_sect_courts() -> void:
	var snowy := GroundTiles.ground_season(_season, _region.get("map", {})) == "Winter"
	for place: Dictionary in _region.get("places", []):
		if SectCourt.is_sect_hall(place):
			var hall := Rect2(_vec(place["pos"]) - _vec(place.get("size", [64, 64])) / 2.0, _vec(place.get("size", [64, 64])))
			SectCourt.draw_court(self, hall, SectCourt.court_rect(place, _region), snowy, SectCourt.court_style(_region))
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
	draw_rect(r, Color("9aa3a8"))
	var y := r.position.y
	var i := 0
	while y < r.end.y:
		var h := minf(14.0, r.end.y - y)
		draw_rect(Rect2(r.position.x, y, r.size.x, h), Color("b4bcc0") if i % 2 == 0 else Color("a5aeb2"))
		draw_rect(Rect2(r.position.x, y + h - 3.0, r.size.x, 3.0), Color("6f787e"))
		y += 14.0
		i += 1
	draw_rect(Rect2(r.position.x - 4.0, r.position.y, 4.0, r.size.y), Color("5f686e"))
	draw_rect(Rect2(r.end.x, r.position.y, 4.0, r.size.y), Color("5f686e"))


## GFX-079: a cloud-sea band: layered pale translucent bands with rounded puffs; static (it never moves).
func _draw_clouds(r: Rect2) -> void:
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
	if PixelLandmark.supports(str(lm["kind"])):
		var water := Color(str(lm["color"])) if lm.has("color") else Color("3f7fa8")
		var frozen := Scenery.is_snowy(_season) and not bool(_region.get("map", {}).get("no_snow", false))
		var ptex := PixelLandmark.texture(str(lm["kind"]), size, water, frozen, MotionFx.reduced())
		var px := Vector2(ptex.get_size()) * float(Sprites.scale())
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
			if winter:
				var pts := PackedVector2Array()
				for k in 33:
					var a := TAU * k / 32.0
					pts.append(r.get_center() + Vector2(cos(a) * r.size.x / 2.0, sin(a) * r.size.y / 2.0))
				draw_polyline(pts, Color(0.92, 0.97, 1.0, 0.9), 3.0)
		"field":
			var crop := Scenery.crop_color(_season)
			var y := 2
			while y < int(pix.y) - 2:
				if crop.a > 0.0:
					draw_rect(Rect2(origin + Vector2(3, y + 1) * sc, Vector2(pix.x - 6, 2) * sc), crop)
				else:
					draw_rect(Rect2(origin + Vector2(2, y) * sc, Vector2(pix.x - 4, 3) * sc), Color(0.92, 0.96, 1.0, 0.6))  # GFX-055: snow-covered furrows
				y += 4


## GFX-046: the jetty runs out from the shore into its pond (Scenery.jetty_layout); darker posts stand in the water.
func _draw_jetty(lm: Dictionary) -> void:
	var lay := Scenery.jetty_layout(_region, lm)
	var r: Rect2 = lay["rect"]
	var size := _vec(lm["size"])
	var winter := Scenery.is_snowy(_season)
	if bool(lay["vertical"]):
		_draw_jetty_vertical(r, int(lay["toward_water"]), winter)
	else:
		var ptex := PixelLandmark.texture("jetty", size)
		var sc := float(Sprites.scale())
		var px := Vector2(ptex.get_size()) * sc
		draw_texture_rect(ptex, Rect2(r.get_center() - px / 2.0, px), false)
		if winter:
			draw_rect(Rect2(r.position, Vector2(px.x, sc)), Color("f4f8ff"))
	if bool(lay["on_water"]):
		var post := Color("2e2218")
		var toward: int = int(lay["toward_water"])
		for off: float in [-9.0, 9.0]:
			var tip := r.get_center()
			if bool(lay["vertical"]):
				tip = Vector2(r.get_center().x + off, r.position.y + 2.0 if toward < 0 else r.end.y - 2.0)
			else:
				tip = Vector2(r.position.x + 2.0 if toward < 0 else r.end.x - 2.0, r.get_center().y + off)
			draw_rect(Rect2(tip - Vector2(3, 3), Vector2(6, 6)), post)


## GFX-049: a north-south jetty: boards run across the walkway (3 px with 1 px gaps), dark side rails, and the
## posts at the water end. At least 18 px wide; `toward` < 0 means the water is at the north end.
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
	if look["bare"]:
		_draw_foot_shadow(p, k)
	else:
		draw_circle(p + Vector2(4, 6) * k, 20.0 * k, Color(0, 0, 0, 0.25))
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


## GFX-049: bare trees get a flat ellipse at the trunk foot (ground shade darkened), not a round dark blot.
func _draw_foot_shadow(p: Vector2, k: float) -> void:
	var ground := Color(String(_region.get("map", {}).get("ground", "4d6b3c")))
	var w := 22.0 * k
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(p + Vector2(0, 15) * k + Vector2(cos(a) * w / 2.0, sin(a) * w * 0.15))
	draw_colored_polygon(pts, Color(ground.darkened(0.45), 0.22))


func _draw_tree_round(p: Vector2, k: float, c: Color, look: Dictionary, seed_value: int) -> void:
	draw_rect(Rect2(p + Vector2(-3, 2) * k, Vector2(6, 14) * k), Color("4a3524"))
	draw_circle(p + Vector2(0, -6) * k, 18.0 * k, c)
	draw_circle(p + Vector2(-8, -2) * k, 12.0 * k, c.darkened(0.15))
	draw_circle(p + Vector2(6, -14) * k, 9.0 * k, c.lightened(0.15))
	for i in int(look["blossoms"]):
		var o := Vector2(fposmod(seed_value * (i + 3), 29.0) - 14.0, fposmod(seed_value * (i + 5), 25.0) - 22.0)
		draw_rect(Rect2(p + o * k, Vector2(3, 3)), Color("f6c6dc"))
	for i in int(look["leaves"]):
		var o := Vector2(fposmod(seed_value * (i + 2), 37.0) - 18.0, 8.0 + fposmod(seed_value * (i + 7), 9.0))
		draw_rect(Rect2(p + o * k, Vector2(3, 2)), c.darkened(0.1))


func _draw_tree_bare(p: Vector2, k: float, c: Color, snowy: bool, broken_stub: bool) -> void:
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
			draw_line(p, p + Vector2(0, 6) * k, Color("4f7a3a"), 1.5)
			for i in 5:
				draw_circle(p + Vector2.from_angle(TAU * i / 5.0) * 3.0 * k, 2.2 * k, c)
			draw_circle(p, 1.6 * k, Color("f2d24b"))
