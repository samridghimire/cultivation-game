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
}
## Place keys that are layout, not script properties.
const LAYOUT_KEYS := ["type", "pos"]
const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const ABODE_SCRIPT := preload("res://src/world/interactables/abode.gd")
const FAMILY_HOME_SCRIPT := preload("res://src/world/interactables/family_home.gd")
## Placeholder body color of generated NPCs by gender.
const GENDER_COLORS := {"male": Color("8fb3e0"), "female": Color("e6a3c4")}

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
var _weather_kind := "clear"
## Festival stalls beside merchants (WU-097), rebuilt when the day or region changes.
var _stalls: Array[Node2D] = []
var _merchant_spots: Array[Vector2] = []

@onready var player: Player = $Player


## WU-401: day each villager last greeted (npc id -> day), the bubble showing now, modal state.
var _greeted: Dictionary = {}
var _greet_bubble: Control = null
var _greet_modal := false


func _ready() -> void:
	if not GameState.has_session():
		GameState.rng.randomize()
		GameState.start_session(CharacterFactory.create("Debug Disciple", GameState.data, GameState.rng))
	_region = GameState.data.regions.get(GameState.current_region, {})
	var map: Dictionary = _region.get("map", {})
	map_size = _vec(map.get("size", [map_size.x, map_size.y]))
	player.position = _vec(_region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0]))
	_build_season_tint()
	_build_decor()
	_refresh_ambient()
	Settings.changed.connect(_on_setting_changed)
	_build_places()
	_refresh_stalls()
	_place_at_spawn_anchor()
	_build_npcs()
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
	EventBus.ui_modal_changed.connect(func(is_open: bool):
		player.input_enabled = not is_open
		_greet_modal = is_open)
	EventBus.region_changed.connect(_on_region_changed)
	get_tree().auto_accept_quit = false


func _build_season_tint() -> void:
	_season_tint = CanvasModulate.new()
	_season = Calendar.season_of(GameClock.total_days)
	_weather_kind = Weather.of(GameState.data, GameState.current_region, GameClock.total_days)
	_season_tint.color = _tint_for(_season)
	add_child(_season_tint)
	GameClock.days_advanced.connect(_on_days_advanced)


func _on_days_advanced(_days: int) -> void:
	_refresh_stalls()
	var season := Calendar.season_of(GameClock.total_days)
	var weather := Weather.of(GameState.data, GameState.current_region, GameClock.total_days)
	if season == _season and weather == _weather_kind:
		return
	_season = season
	_weather_kind = weather
	queue_redraw()
	_refresh_ambient()
	var tween := create_tween()
	tween.tween_property(_season_tint, "color", _tint_for(season), 0.6)


## Season tint dimmed by the day's weather.
func _tint_for(season: String) -> Color:
	return Calendar.season_tint(season) * (Ambient.weather_plan(_weather_kind)["tint"] as Color)


## Rebuilds the particle layer for the region, season and "Ambient effects" setting.
func _refresh_ambient() -> void:
	if _ambient != null:
		_ambient.queue_free()
		_ambient = null
	if not Settings.get_value("ambient_effects"):
		return
	var plan := Ambient.weather_plan(_weather_kind)
	if plan["fog"]:
		_ambient = Ambient.make_fog(map_size, not Settings.get_value("reduce_motion"))
	elif plan["emitter"] == "rain":
		_ambient = Ambient.make_rain(map_size)
	elif plan["emitter"] == "snow":
		_ambient = Ambient.make_emitter("snow", map_size)
	else:
		var kind := Ambient.kind_for(_region.get("map", {}).get("ambient", {}), _season)
		if kind == "":
			return
		_ambient = Ambient.make_emitter(kind, map_size)
	add_child(_ambient)


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
	for spot in _merchant_spots:
		var stall := FestivalStall.new()
		stall.event_id = festival
		stall.position = spot
		add_child(stall)
		move_child(stall, player.get_index())
		_stalls.append(stall)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "ambient_effects":
		_refresh_ambient()
	elif key == "show_all_labels" and player != null:
		for node in get_children():
			if node is Interactable:
				(node as Interactable).refresh_label_alpha(player.position)


func _exit_tree() -> void:
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
func _on_region_changed(_region_id: String) -> void:
	if get_tree().current_scene == self:
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
	_decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y < b["pos"].y)


func _build_places() -> void:
	for place: Dictionary in _region.get("places", []):
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
		if place["type"] == "merchant":
			_merchant_spots.append(node.position + Vector2(node.size.x / 2.0 + 34.0, 12.0))
	_build_abodes()
	_build_family_home()


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
		node.position = _vec(def.get("pos", [0, 0]))
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
	var stands := Npcs.haunt_positions(neighbours, _region, GameClock.total_days, int(data.family.get("adult_age", 16)), Weather.of(data, GameState.current_region, GameClock.total_days), visitor, GameState.visit_place_for(visitor))
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
func _build_celebration_lanterns(people: Array[CharacterData], stands: Dictionary) -> void:
	var ids: Array = people.map(func(c: CharacterData) -> String: return c.id)
	var party := Folk.celebrants(GameState.world_flags, ids, GameClock.total_days)
	for id: String in ids:
		if party.has(id) and stands.has(id):
			var lanterns := CelebrationLanterns.new()
			lanterns.lantern_color = Folk.celebration_lantern(party[id])
			lanterns.position = (stands[id] as Vector2) + Vector2(0, 30)
			add_child(lanterns)
			move_child(lanterns, 0)
			return


## Labels stay on screen as the camera moves (WU-269).
func _process(_delta: float) -> void:
	var origin := get_canvas_transform().origin
	var moved := player != null and _last_label_pos.distance_to(player.position) > 8.0
	if moved:
		_last_label_pos = player.position
		_check_greetings()
		for node in get_children():
			if node is Interactable:
				(node as Interactable).refresh_label_alpha(player.position)
	if origin == _last_canvas_origin and not moved:
		return
	_last_canvas_origin = origin
	for node in get_children():
		if node is Interactable:
			(node as Interactable).camera_moved()
	_spread_on_screen()


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
	Interactable.spread_on_screen(nodes, view, occupied)


func _limit_camera() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)


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
		var flowers := ["spring", "summer"].has(Calendar.season_of(GameClock.total_days))
		var gtex := GroundTiles.ground_texture(ground_color, rid, Vector2i(ceili(map_size.x / sc), ceili(map_size.y / sc)), flowers)
		draw_texture_rect(gtex, Rect2(Vector2.ZERO, Vector2(gtex.get_size()) * sc), false)
	var path_tile := Sprites.first(["path_" + rid, "path"])
	var path_color := Color(map.get("path_color", "8a7350"))
	for r in map.get("paths", []):
		var rect := Rect2(r[0], r[1], r[2], r[3])
		if path_tile != null:
			_draw_tiled(path_tile, rect)
		else:
			var psc := float(Sprites.scale())
			var ptex := GroundTiles.path_texture(path_color, rid, Vector2i(ceili(rect.size.x / psc), ceili(rect.size.y / psc)))
			draw_texture_rect(ptex, Rect2(rect.position, Vector2(ptex.get_size()) * psc), false)
	for lm: Dictionary in map.get("landmarks", []):
		_draw_landmark(lm)
	for d in _decor:
		_draw_decor(d)
	var border_tile := Sprites.first(["border_" + rid, "border"])
	if border_tile != null:
		for strip: Rect2 in [Rect2(0, 0, map_size.x, 6), Rect2(0, map_size.y - 6, map_size.x, 6), Rect2(0, 6, 6, map_size.y - 12), Rect2(map_size.x - 6, 6, 6, map_size.y - 12)]:
			_draw_tiled(border_tile, strip)
	else:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(map.get("border", "2a3a20")), false, 6.0)


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


## One map.landmarks entry: its `landmark_<kind>` sprite scaled into the rect, else placeholder art (GFX-008).
func _draw_landmark(lm: Dictionary) -> void:
	var size := _vec(lm["size"])
	var r := Rect2(_vec(lm["pos"]) - size / 2.0, size)
	var tex := Sprites.texture("landmark_" + str(lm["kind"]))
	if tex != null:
		draw_texture_rect(tex, r, false)
		return
	if PixelLandmark.supports(str(lm["kind"])):
		var water := Color(str(lm["color"])) if lm.has("color") else Color("3f7fa8")
		var ptex := PixelLandmark.texture(str(lm["kind"]), size, water)
		var px := Vector2(ptex.get_size()) * float(Sprites.scale())
		draw_texture_rect(ptex, Rect2(Vector2(r.get_center().x - px.x / 2.0, r.end.y - px.y), px), false)
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
			while ripple < r.end.y - 6.0:
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
			draw_circle(p + Vector2(4, 6) * k, 20.0 * k, Color(0, 0, 0, 0.25))
			draw_rect(Rect2(p + Vector2(-3, 2) * k, Vector2(6, 14) * k), Color("4a3524"))
			draw_circle(p + Vector2(0, -6) * k, 18.0 * k, c)
			draw_circle(p + Vector2(-8, -2) * k, 12.0 * k, c.darkened(0.15))
			draw_circle(p + Vector2(6, -14) * k, 9.0 * k, c.lightened(0.15))
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
