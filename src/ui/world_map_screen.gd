class_name WorldMapScreen
extends PanelContainer
## Modal world map (information only; travel still happens at travel points).
## Every region in data/regions.json is a focusable node placed by its
## `map_pos`; routes are drawn between them with their travel days. The panel
## on the right describes the focused region and how to reach it from here.
## Colored dots under a region mark what is yours there or happening there
## (UI-008b): your sect hall, abode, family, artifact anchors, secret realms
## and world events; the details list them.

signal closed

const HudScript := preload("res://src/ui/hud.gd")
const CANVAS_SIZE := Vector2(640, 460)
const NODE_HEIGHT := 40.0
## Room kept round the node centres: left/right, top, bottom (the bottom holds the glyph row).
const MARGIN := Vector4(84, 26, 30, 56)
const GLYPH_SIZE := 24.0
const DANGER_NAMES: PackedStringArray = ["Safe", "Low", "Moderate", "High", "Deadly"]
const ROUTE_COLOR := Color(0.3, 0.2, 0.12, 0.85)
const LOCKED_COLOR := Color(0.7, 0.14, 0.1, 0.9)
## GFX-108: paper and ink of the painted map.
const PAPER_COLOR := Color(0.87, 0.8, 0.64)
const INK_COLOR := Color(0.2, 0.13, 0.08)
const SEAL_COLOR := Color(0.74, 0.12, 0.1)
## Mark kind -> dot color (see region_marks).
const MARK_COLORS := {
	"sect": Color("6fa8e8"),
	"abode": Color("e8c76a"),
	"family": Color("e6a3c4"),
	"anchor": Color("7fe0d0"),
	"secret_realm": Color("b58ae8"),
	"event": Color("e85a4a"),
	"discovery": Color("f2f0a0"),
	"letter": Color("f0b27a"),
	"rival": Color("d9694f"),
	"bounty": UIStyle.DANGER_COLORS["Risky"],
}

var _canvas: Control
var _name: Label
var _info: Label
var _description: Label
var _hint_note: Label
var _goal_region := ""  # WU-439: the region the first unfinished road goal points to
var _hint_region := ""  # WU-316: the region the HUD's first hint points to
var _places: Label
var _you: Label  # WU-528
var _shops: Label
var _heads: Dictionary = {}  ## WU-528: block name -> its heading label
const SHOP_CAP := 5
const PLACE_CAP := 8
var _marks: Label
var _foes: RichTextLabel
var _routes: Label
var _today: Label
var _close_button: Button
var _selected := ""
var _positions: Dictionary = {}
var _rects: Dictionary = {}


func _init() -> void:
	var temp := UIStyle.panel()
	add_theme_stylebox_override("panel", temp.get_theme_stylebox("panel"))
	temp.free()
	custom_minimum_size = Vector2(1020, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("World Map", 24, UIStyle.ACCENT))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	_canvas = Control.new()
	_canvas.custom_minimum_size = CANVAS_SIZE
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_map)
	columns.add_child(_canvas)

	# The details scroll so long region notes never push the screen past a
	# Steam Deck's height.
	var details_scroll := ScrollContainer.new()
	details_scroll.custom_minimum_size = Vector2(340, CANVAS_SIZE.y)
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(details_scroll)
	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(320, 0)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	details_scroll.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = UIStyle.label("", 15, Color(0.75, 0.75, 0.75))
	details.add_child(_info)
	_hint_note = _wrapped(UIStyle.label("", 16, UIStyle.ACCENT))
	details.add_child(_hint_note)
	_description = _wrapped(UIStyle.label("", 16))
	details.add_child(_description)
	_today = _block(details, "Today", Color(0.8, 0.9, 0.8))
	_you = _block(details, "You here", Color(0.85, 0.85, 0.85))
	_shops = _block(details, "Shops", Color(0.85, 0.85, 0.85))
	_places = _block(details, "Places", Color(0.85, 0.85, 0.85))
	_foes = RichTextLabel.new()
	_foes.bbcode_enabled = true
	_foes.fit_content = true
	_foes.scroll_active = false
	_foes.add_theme_font_size_override("normal_font_size", 15)
	_foes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_foes)
	_marks = _wrapped(UIStyle.label("", 15, Color(0.85, 0.85, 0.95)))
	details.add_child(_marks)
	_routes = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["progress"]))
	details.add_child(_routes)
	details.add_child(_wrapped(UIStyle.label("Red roads need a higher realm. Travel at a region's gate. Dots: blue sect hall, gold abode, pink family, teal anchor, purple secret realm, red world event. Row under a name: weather, coin market open today, paw beasts roam (gold: a great beast), leaf forage by the path.", 14, Color(0.6, 0.6, 0.6))))

	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.region_changed.connect(_on_region_changed_rebuild)
	EventBus.player_changed.connect(_on_player_changed_details)


## WU-528: a headed block (accent heading + wrapped body); returns the body label.
func _block(parent: VBoxContainer, title: String, color: Color) -> Label:
	var blk := UIStyle.block(title, PackedStringArray(), color)
	blk.name = title.replace(" ", "") + "Block"
	parent.add_child(blk)
	_heads[title] = blk.get_child(0)
	var body := blk.get_child(1) as Label
	body.name = title.replace(" ", "") + "Body"
	return body


func _set_block(title: String, body: Label, text: String) -> void:
	body.text = text
	body.visible = text != ""
	(_heads[title] as Label).visible = text != ""


## WU-528: "Shop name · good, good +N" per merchant, at most SHOP_CAP then "+N more shops".
static func shop_rows(data: GameData, region_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var total := 0
	for p: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if String(p.get("type", "")) != "merchant":
			continue
		total += 1
		if out.size() >= SHOP_CAP:
			continue
		var goods := Guidance.merchant_goods_list(p)
		var text := ", ".join(goods.slice(0, 2)) if not goods.is_empty() else "pills and sundries"
		if goods.size() > 2:
			text += " +%d" % (goods.size() - 2)
		out.append("%s · %s" % [p.get("display_name", "Merchant"), text])
	if total > SHOP_CAP:
		out.append("+%d more shops" % (total - SHOP_CAP))
	return out


## WU-528: names joined by commas, at most `cap` then "+N more".
static func capped_list(names: PackedStringArray, cap: int = PLACE_CAP) -> String:
	if names.size() <= cap:
		return ", ".join(names)
	return "%s +%d more" % [", ".join(names.slice(0, cap)), names.size() - cap]


func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_selected = GameState.current_region
	_hint_region = _read_hint_region()
	_goal_region = goal_region_for(GameState.player, GameState.data, GameState.world_flags, GameClock.total_days)
	_rebuild()
	visible = true
	_focus_selected.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## WU-316: the region the HUD's first hint names ("" when it names none, or the screen has no HUD).
func _read_hint_region() -> String:
	var node := get_parent()
	while node != null and not node.has_method("first_hint"):
		node = node.get_parent()
	if node == null:
		return ""
	return Guidance.hinted_region(GameState.data, String(node.call("first_hint")), GameState.current_region)


## WU-316: "Your hint points here." on the region the first hint names (never the current one), else "".
static func hint_note(data: GameData, hint: String, current_region: String, region_id: String) -> String:
	if region_id != current_region and Guidance.hinted_region(data, hint, current_region) == region_id:
		return "Your hint points here."
	return ""


## WU-439: the road-goal region, only while road goals are active.
static func goal_region_for(c: CharacterData, data: GameData, flags: Dictionary, today: int) -> String:
	if not Guidance.road_goals_active(c, data, flags):
		return ""
	return Guidance.road_goal_region(c, data, flags, today)


## WU-439: a one-line lure for a place you have not been, from what a traveller could have heard.
static func lure_line(data: GameData, region_id: String) -> String:
	var region: Dictionary = data.regions.get(region_id, {})
	if not (region.get("roamers", {}) as Dictionary).get("great", {}).is_empty():
		return "A great beast walks here."
	for def: Dictionary in data.secret_realms.values() + data.inheritances.values():
		if String(def.get("region", "")) == region_id:
			return "Ruins are said to lie here."
	for p: Dictionary in region.get("places", []):
		if p.get("type", "") in ["secret_realm", "inheritance"]:
			return "Ruins are said to lie here."
	return "Danger: " + danger_name(data, region_id)


## Region id -> position as 0..1 fractions of the map. Uses `map_pos` when set;
## other regions are spread around an ellipse so new content always shows up.
static func layout(data: GameData) -> Dictionary:
	var result := {}
	var unplaced: Array = []
	for region: Dictionary in data.regions.values():
		var pos: Array = region.get("map_pos", [])
		if pos.size() == 2:
			result[region["id"]] = Vector2(float(pos[0]), float(pos[1]))
		else:
			unplaced.append(region["id"])
	for i in unplaced.size():
		var angle := TAU * float(i) / unplaced.size() - PI / 2.0
		result[unplaced[i]] = Vector2(0.5, 0.5) + Vector2(cos(angle) * 0.4, sin(angle) * 0.38)
	return result


## GFX-059: the box of a region node, wide enough for the whole name (min 110 wide, 40 high).
static func node_rect(region_name: String, center: Vector2, font: Font, font_size: int) -> Rect2:
	var w := maxf(110.0, font.get_string_size(region_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 24.0)
	return Rect2(center - Vector2(w, NODE_HEIGHT) / 2.0, Vector2(w, NODE_HEIGHT))


## GFX-059: the node box plus the glyph row under it (what must stay clear of other nodes).
static func node_footprint(rect: Rect2) -> Rect2:
	return Rect2(rect.position, rect.size + Vector2(0, GLYPH_SIZE + 4.0))


## GFX-061: colours of a node box: an opaque backing so routes never show through, and a dimmer
## (but still readable) border and text for places not yet visited.
static func node_colors(unexplored: bool) -> Dictionary:
	if unexplored:
		return {"bg": Color(0.82, 0.77, 0.66, 0.97), "border": Color(0.52, 0.46, 0.36), "text": Color(0.36, 0.31, 0.25)}
	return {"bg": Color(0.93, 0.88, 0.74, 0.97), "border": Color(0.3, 0.2, 0.12), "text": Color(0.14, 0.09, 0.05)}


## GFX-061: WCAG-style contrast ratio between two colours.
static func contrast_ratio(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var ch := PackedFloat32Array()
	for v: float in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


## GFX-061: the part of segment a-b outside both rects (a lies in rect_a, b in rect_b): the
## returned two points sit 1 px outside the rects. Empty if the rects leave no room.
static func clip_to_rects(a: Vector2, b: Vector2, rect_a: Rect2, rect_b: Rect2) -> PackedVector2Array:
	var t0 := _exit_t(a, b, rect_a)
	var t1 := 1.0 - _exit_t(b, a, rect_b)
	if t0 >= t1:
		return PackedVector2Array()
	return PackedVector2Array([a.lerp(b, t0), a.lerp(b, t1)])


## Fraction along from->to where the segment has left `rect` (plus ~1 px), 0 if it starts outside.
static func _exit_t(from: Vector2, to: Vector2, rect: Rect2) -> float:
	if not rect.has_point(from):
		return 0.0
	var len := from.distance_to(to)
	if len < 0.001:
		return 1.0
	var lo := 0.0
	var hi := 1.0
	for i in 24:
		var mid := (lo + hi) / 2.0
		if rect.grow(1.0).has_point(from.lerp(to, mid)):
			lo = mid
		else:
			hi = mid
	return hi


## GFX-059: node centre in canvas pixels for a 0..1 layout fraction.
static func center_of(fraction: Vector2) -> Vector2:
	var lo := Vector2(MARGIN.x, MARGIN.y)
	var hi := CANVAS_SIZE - Vector2(MARGIN.x, MARGIN.w)
	return lo + fraction * (hi - lo)


## WU-530: centre of a route's day label: the route's midpoint, slid along the route (0.35 / 0.65,
## then further) until the label rect (size) overlaps no region box and no label already placed.
static func day_label_pos(a: Vector2, b: Vector2, boxes: Array[Rect2], taken: Array[Rect2], size: Vector2 = Vector2(36, 22)) -> Vector2:
	for t: float in [0.5, 0.35, 0.65, 0.25, 0.75, 0.42, 0.58]:
		var c := a.lerp(b, t)
		var rect := Rect2(c - size / 2.0, size).grow(2.0)
		if not boxes.any(func(n: Rect2) -> bool: return n.intersects(rect)) and not taken.any(func(n: Rect2) -> bool: return n.intersects(rect)):
			return c
	return a.lerp(b, 0.5)


## Text lines for the focused region: route from the current region (or
## "You are here"), then every road out of it with days and realm gates.
static func route_lines(c: CharacterData, data: GameData, from_id: String, region_id: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	if region_id == from_id:
		lines.append("You are here.")
	else:
		var check := Exploration.check_travel(c, data, from_id, region_id)
		if check["ok"]:
			lines.append("Direct road from here: %s." % Calendar.format_duration(int(check["days"])))
		else:
			lines.append(String(check["reason"]))
	lines.append("Roads:")
	for route in Exploration.routes(c, data, region_id):
		var line := "  %s, %s" % [route["name"], Calendar.format_duration(route["days"])]
		if not route["ok"]:
			line += " (%s)" % route["reason"]
		lines.append(line)
	return lines


## Names of the places in a region (travel points left out).
## Explored days, happenings seen and the next deeper path of a visited region (WU-074);
## empty for regions never visited.
static func familiarity_lines(c: CharacterData, data: GameData, region_id: String, current_region: String, flags: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	if is_unexplored(c, region_id, current_region):
		return out
	var days := Exploration.familiarity(c, region_id)
	out.append("Explored %d day%s" % [days, "" if days == 1 else "s"])
	var progress := Exploration.region_progress(c, data, region_id, flags)
	if Exploration.mastered(c, data, region_id, flags, GameClock.total_days):
		out.append("Mastered: you know every path here.")
	elif int(progress["total"]) > 0:
		out.append("Seen %d of %d happenings" % [progress["met"], progress["total"]])
	var deep := Exploration.next_deep_path(c, data, region_id)
	if deep >= 0:
		out.append("Deeper paths after %d days" % deep)
	return out


static func place_names(data: GameData, region_id: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if place.get("type", "") != "travel":
			names.append(String(place.get("display_name", place.get("type", ""))))
	return names


## WU-346: "Cave abode: Waterfall Cave, 300 stones, qi x1.5" for an abode in `region_id` the player has not claimed, else "".
static func abode_line(c: CharacterData, data: GameData, region_id: String) -> String:
	for abode_id: String in Abodes.in_region(data, region_id):
		if c.abode == abode_id:
			continue
		var def := Abodes.get_def(data, abode_id)
		return "Cave abode: %s, %d stones, qi x%s" % [Abodes.abode_name(data, abode_id), int(def.get("cost", 0)), String.num(float(def.get("qi_density", 1.0)), 2)]
	return ""


## Regions never visited (WU-061); the region you stand in always counts as visited.
static func is_unexplored(c: CharacterData, region_id: String, current_region: String) -> bool:
	return region_id != current_region and not Exploration.visited(c, region_id)


## Secret-realm timing on a map mark (WU-114): "open, closes in ..." or "opens in ...".
static func realm_when(def: Dictionary, total_days: int) -> String:
	if SecretRealms.is_open(def, total_days):
		return "open, closes in %s" % Calendar.format_duration(SecretRealms.days_until_close(def, total_days))
	return "opens in %s" % Calendar.format_duration(SecretRealms.days_until_open(def, total_days))


## What `c` has or what is going on in `region_id`: [{kind, text}] with kind
## a MARK_COLORS key. `people` are the NPCs, `events` the active world events,
## `flags` the world flags (an unexplored discovery hint needs them).
static func region_marks(c: CharacterData, data: GameData, people: Dictionary, events: Array, total_days: int, region_id: String, current_region: String = "", flags: Dictionary = {}) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	if is_unexplored(c, region_id, current_region):
		return marks
	var region: Dictionary = data.regions.get(region_id, {})
	if not c.is_rogue() and (region.get("places", []) as Array).any(func(p: Dictionary) -> bool: return p.get("type", "") == "sect_hall"):
		marks.append({"kind": "sect", "text": "A hall of the %s (missions, rank)" % (data.sects[c.sect["id"]] as SectDef).name})
	if c.abode != "" and String(data.abodes.get(c.abode, {}).get("region", "")) == region_id:
		marks.append({"kind": "abode", "text": "Your abode: %s" % Abodes.abode_name(data, c.abode)})
	var family: PackedStringArray = []
	for person_id in c.spouses + c.children:
		var person: CharacterData = people.get(person_id)
		if person != null and person.alive and Npcs.region_of(person, data) == region_id:
			family.append(person.name)
	if not family.is_empty():
		marks.append({"kind": "family", "text": "Family: %s" % ", ".join(family)})
	var rival := Rivals.rival_of(c, people)
	if rival != null and flags.get(Rivals.FIRST_MEETING_FLAG, false) and Npcs.region_of(rival, data) == region_id:
		marks.append({"kind": "rival", "text": "Your rival: %s (%s)" % [rival.name, Rivals.relation_text(c, rival)]})
	for i in c.anchors.size():
		if String(data.anchors.get(c.anchors[i], {}).get("region", "")) == region_id:
			var tag := " (respawn point)" if i == c.anchors.size() - 1 else ""
			marks.append({"kind": "anchor", "text": "Artifact anchor: %s%s" % [CreationArtifact.anchor_name(data, c.anchors[i]), tag]})
	for def: Dictionary in data.secret_realms.values():
		if String(def.get("region", "")) != region_id:
			continue
		marks.append({"kind": "secret_realm", "text": "Secret realm: %s (%s)" % [def.get("name", def["id"]), realm_when(def, total_days)]})
	if Exploration.visited(c, region_id) and not Exploration.discovery_for(c, data, region_id, flags).is_empty():
		marks.append({"kind": "discovery", "text": "Something here waits to be found. Explore."})
	for instance in WorldEvents.active_in(events, region_id):
		var enter := ""
		if region_id == current_region and HudScript.region_event_suffix(data, [instance], region_id, c).contains("(you can enter)"):
			enter = " (you can enter)"
		marks.append({"kind": "event", "text": "%s (%s left)%s" % [WorldEvents.active_label(data, instance["id"]), Calendar.format_duration(maxi(0, int(instance["end_day"]) - total_days)), enter]})
	for req in Letters.requests_in_region(c, data, people, region_id, total_days):
		marks.append({"kind": "letter", "text": "Letter: %s asked for %d %s (%d days left)" % [req["name"], req["count"], Items.item_plural(data, String(req["item_id"]), int(req["count"])), req["days_left"]]})
	marks.append_array(bounty_marks(c, data, total_days, region_id))
	return marks


## Bounty marks (WU-147): your hunt in its region, else up to 2 hunts you could take here.
static func bounty_marks(c: CharacterData, data: GameData, total_days: int, region_id: String) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	var hunt := Bounties.active(c, data, total_days)
	if not hunt.is_empty():
		if String(hunt["region"]) == region_id:
			marks.append({"kind": "bounty", "text": "Your hunt: %s (%s left)" % [_enemy_name(data, String(hunt["enemy"])), Calendar.format_duration(maxi(0, int(hunt["until_day"]) - total_days))]})
		return marks
	for b: Dictionary in Bounties.offers(c, data, total_days, region_id):
		if marks.size() >= 2:
			break
		if String(b["region"]) == region_id and Bounties.check_take(c, data, String(b["id"]), total_days) == "":
			marks.append({"kind": "bounty", "text": "Bounty: %s, %d stones" % [_enemy_name(data, String(b["enemy"])), Bounties.paid_stones(c, data, b)]})
	return marks


## WU-428: names of the stalls (places with open_days) of a region that are open on `day`.
static func open_markets(data: GameData, region_id: String, day: int) -> PackedStringArray:
	var out := PackedStringArray()
	for place: Dictionary in data.regions.get(region_id, {}).get("places", []):
		if place.has("open_days") and Places.is_open(place, day):
			out.append(String(place.get("display_name", place.get("type", ""))))
	return out


## WU-428: how many beasts roam a region today (its roamers plus your bounty quarry).
static func roamer_count(c: CharacterData, data: GameData, region_id: String, day: int, flags: Dictionary) -> int:
	var n := Wildlife.roamers(data, region_id, day, c.realm_index, flags).size()
	if not Wildlife.bounty_roamer(c, data, region_id, day, flags).is_empty():
		n += 1
	return n


## WU-430: the name of the great beast walking a region today ("" when none).
static func great_name(c: CharacterData, data: GameData, region_id: String, day: int, flags: Dictionary) -> String:
	var g := Wildlife.great_roamer(c, data, region_id, day, flags)
	return "" if g.is_empty() else Wildlife.display_name(data, String(g["enemy"]), true)


## WU-428: "Today: rain, market at Travelling Market Stall, 3 beasts roam." ("" for a region never visited).
static func today_line(c: CharacterData, data: GameData, region_id: String, current_region: String, day: int, flags: Dictionary) -> String:
	if is_unexplored(c, region_id, current_region):
		return ""
	var parts := PackedStringArray([Weather.of(data, region_id, day)])
	var markets := open_markets(data, region_id, day)
	if not markets.is_empty():
		parts.append("market at " + " and ".join(markets))
	var great := great_name(c, data, region_id, day, flags)
	var beasts := roamer_count(c, data, region_id, day, flags)
	if great != "":
		parts.append("the %s walks here" % great)
	if beasts > 0:
		parts.append("%d beast%s roam%s" % [beasts, "" if beasts == 1 else "s", "s" if beasts == 1 else ""])
	var text := ", ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1) + "."


## WU-433: unpicked forage today in a region ([] for a region never visited).
static func forage_entries(c: CharacterData, data: GameData, region_id: String, current_region: String, day: int, flags: Dictionary) -> Array[Dictionary]:
	if is_unexplored(c, region_id, current_region):
		return []
	return Foraging.unpicked(data, region_id, day, c.realm_index, flags)


## WU-433: "By the path today: Village Mugwort x2, Morning Dew Mushroom." ("" when nothing is left or never visited).
static func forage_line(c: CharacterData, data: GameData, region_id: String, current_region: String, day: int, flags: Dictionary) -> String:
	var entries := forage_entries(c, data, region_id, current_region, day, flags)
	if entries.is_empty():
		return ""
	return "By the path today: %s." % Foraging.summary(data, entries)


static func _enemy_name(data: GameData, enemy_id: String) -> String:
	return String(data.enemies.get(enemy_id, {}).get("name", enemy_id))


## Foes met while exploring the current region, as BBCode with each danger colored (WU-030).
static func foes_bbcode(foes: Array) -> String:
	var parts := PackedStringArray()
	for foe: Dictionary in foes:
		var danger := String(foe["danger"])
		parts.append("[color=#%s]%s (%s)[/color]" % [UIStyle.danger_color(danger).to_html(false), foe["name"], danger])
	return "" if parts.is_empty() else "You may meet: " + ", ".join(parts)


## "Qi density x2.75 (the valley guardian's seed)": the region's qi with the reasons its flags enrich it.
## With `c` the weather for their root counts too, so the map quotes the HUD's and the travel note's number (QI-003).
static func qi_line(data: GameData, region_id: String, flags: Dictionary, events: Array, c: CharacterData = null) -> String:
	var qi := Exploration.effective_density(data, region_id, flags, GameClock.total_days, events, c)
	var text := "Qi density x%s" % Exploration.format_density(qi)
	var reasons := Exploration.qi_flag_reasons(data, region_id, flags, GameClock.total_days)
	if not reasons.is_empty():
		text += " (%s)" % ", ".join(reasons)
	return text


## "Your name here: Respected" when the player holds a renown title in the region, else "".
static func renown_note(c: CharacterData, data: GameData, region_id: String) -> String:
	var t := Renown.title(c, data, region_id)
	return "" if t == "" else "Your name here: " + t


## "3d": the days a route takes this character, shortened by a flying sword (TRAV-007).
## `snow_days` is the weather's extra days on a route leaving here (GameState.journey_days).
static func route_days_label(c: CharacterData, data: GameData, route: Dictionary, snow_days: int = 0) -> String:
	return "%dd" % (Exploration.travel_days(c, data, int(route.get("days", 1))) + snow_days)


static func danger_name(data: GameData, region_id: String) -> String:
	var danger := int(data.regions.get(region_id, {}).get("danger", 0))
	return DANGER_NAMES[clampi(danger, 0, DANGER_NAMES.size() - 1)]


func _rebuild() -> void:
	var data := GameState.data
	for child in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	_positions.clear()
	_rects.clear()
	var fractions := layout(data)
	var font := ThemeDB.fallback_font
	var ids := fractions.keys()
	ids.sort()
	for region_id in ids:
		var center := center_of(fractions[region_id])
		var label := Exploration.region_name(data, region_id)
		var unexplored := is_unexplored(GameState.player, region_id, GameState.current_region)
		if region_id == GameState.current_region:
			label = "* " + label
		var rect := node_rect(label, center, font, 14)
		_positions[region_id] = center
		_rects[region_id] = rect
		var b := Button.new()
		b.name = region_id
		b.text = label
		b.add_theme_font_size_override("font_size", 14)
		if unexplored:
			b.text += "\nUnexplored"
			b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.position = rect.position
		b.size = rect.size
		b.toggle_mode = true
		b.button_pressed = region_id == _selected
		if region_id == GameState.current_region:
			b.add_theme_color_override("font_color", SEAL_COLOR)
			b.add_theme_color_override("font_focus_color", SEAL_COLOR)
		_style_node(b, unexplored, region_id == GameState.current_region)
		b.focus_entered.connect(_select.bind(region_id))
		b.pressed.connect(_select.bind(region_id))
		_canvas.add_child(b)
	_canvas.queue_redraw()
	_show_details()


## GFX-059: ground colour of a region's land blob from its map.ground_style.
static func land_color(region: Dictionary) -> Color:
	match String(region.get("map", {}).get("ground_style", "")):
		"scree":
			return Color(0.62, 0.64, 0.68)
		"bog":
			return Color(0.42, 0.45, 0.24)
		"paved":
			return Color(0.74, 0.65, 0.45)
		"litter":
			return Color(0.28, 0.5, 0.3)
	return Color(0.4, 0.6, 0.32)


## GFX-108: the terrain vignette kind of a region from its encounter_tags.
static func terrain_kind(region: Dictionary) -> String:
	var tags: Array = region.get("encounter_tags", [])
	for pair: Array in [["city", "market"], ["village", "village"], ["marsh", "marsh"], ["mountain", "peaks"], ["forest", "forest"]]:
		if tags.has(pair[0]):
			return pair[1]
	return "hills"


## GFX-108: the painted parchment: paper, brush-stroke grid, border, and a terrain vignette per region.
func _draw_land(data: GameData) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), PAPER_COLOR)
	var grid := Color(0.6, 0.5, 0.34, 0.16)
	for gx in range(40, int(CANVAS_SIZE.x), 80):
		_canvas.draw_line(Vector2(gx, 6), Vector2(gx, CANVAS_SIZE.y - 6), grid, 1.0)
	for gy in range(40, int(CANVAS_SIZE.y), 80):
		_canvas.draw_line(Vector2(6, gy), Vector2(CANVAS_SIZE.x - 6, gy), grid, 1.0)
	_canvas.draw_rect(Rect2(Vector2.ONE, CANVAS_SIZE - Vector2(2, 2)), Color(0.36, 0.25, 0.14), false, 2.0)
	var ids := _positions.keys()
	ids.sort()
	for region_id: String in ids:
		var region: Dictionary = data.regions[region_id]
		var r: Rect2 = _rects[region_id]
		var faded := is_unexplored(GameState.player, region_id, GameState.current_region)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(region_id)
		var kind := terrain_kind(region)
		for k in 7:
			var side := -1.0 if k % 2 == 0 else 1.0
			var p := r.get_center() + Vector2(side * (r.size.x / 2.0 + rng.randf_range(10, 48)), rng.randf_range(-22, 22))
			if k >= 5:
				p = r.get_center() + Vector2(rng.randf_range(-r.size.x / 2.0, r.size.x / 2.0), -r.size.y / 2.0 - rng.randf_range(10, 20))
			_draw_vignette(kind, p, rng.randf_range(0.8, 1.2), faded)


## GFX-108: one small terrain mark at p (ink-and-wash colours, paler when unexplored).
func _draw_vignette(kind: String, p: Vector2, sc: float, faded: bool) -> void:
	var al := 0.45 if faded else 0.95
	var ink := Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, al)
	match kind:
		"village":
			var w := 12.0 * sc
			_canvas.draw_rect(Rect2(p + Vector2(-w / 2.0, 0), Vector2(w, 7.0 * sc)), Color(0.72, 0.6, 0.42, al))
			_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-w / 2.0 - 3, 1), p + Vector2(0, -7.0 * sc), p + Vector2(w / 2.0 + 3, 1)]), Color(0.5, 0.24, 0.16, al))
		"forest":
			_canvas.draw_rect(Rect2(p + Vector2(-1, 4), Vector2(2, 5)), ink)
			_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-6.0 * sc, 5), p + Vector2(0, -9.0 * sc), p + Vector2(6.0 * sc, 5)]), Color(0.16, 0.36, 0.2, al))
		"marsh":
			_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 2), p + Vector2(-3, -2), p + Vector2(5, -2), p + Vector2(10, 2), p + Vector2(3, 5), p + Vector2(-5, 5)]), Color(0.38, 0.5, 0.5, al * 0.8))
			_canvas.draw_line(p + Vector2(-2, 2), p + Vector2(-2, -9.0 * sc), ink, 1.5)
			_canvas.draw_rect(Rect2(p + Vector2(-3.5, -12.0 * sc), Vector2(3, 5)), Color(0.4, 0.24, 0.1, al))
		"peaks":
			var h := 12.0 * sc
			_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-h, h * 0.6), p + Vector2(0, -h), p + Vector2(h, h * 0.6)]), Color(0.5, 0.5, 0.54, al))
			_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-h * 0.3, -h * 0.4), p + Vector2(0, -h), p + Vector2(h * 0.3, -h * 0.4)]), Color(0.97, 0.96, 0.92, al))
		"market":
			_canvas.draw_rect(Rect2(p + Vector2(-6, 0), Vector2(12, 6)), Color(0.55, 0.4, 0.22, al))
			_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 1), p + Vector2(-6, -5), p + Vector2(6, -5), p + Vector2(8, 1)]), Color(0.78, 0.22, 0.16, al))
		_:
			_canvas.draw_arc(p, 8.0 * sc, PI, TAU, 10, Color(0.4, 0.5, 0.28, al), 2.0)


## GFX-108: a dotted ink road from a to b (dots every 9 px).
func _draw_dotted(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(1, int(a.distance_to(b) / 9.0))
	for i in n + 1:
		_canvas.draw_circle(a.lerp(b, float(i) / n), 2.2, col)


func _style_node(b: Button, unexplored: bool, current: bool) -> void:
	var col := node_colors(unexplored)
	var text: Color = SEAL_COLOR if current else col["text"]
	for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col["bg"]
		sb.border_color = col["border"]
		sb.set_border_width_all(1 if unexplored else 2)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(3)
		if state != "normal":
			sb.bg_color = (col["bg"] as Color).lightened(0.12)
			sb.border_color = UIStyle.ACCENT
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state, sb)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, text)


func _draw_map() -> void:
	var data := GameState.data
	if data == null:
		return
	_draw_land(data)
	var font := ThemeDB.fallback_font
	var node_rects: Array[Rect2] = []
	for r: Rect2 in _rects.values():
		node_rects.append(node_footprint(r))
	var drawn := {}
	var taken: Array[Rect2] = []
	for region_id in _positions:
		for route: Dictionary in data.regions[region_id].get("routes", []):
			var to: String = route.get("to", "")
			var key := [region_id, to] if region_id < to else [to, region_id]
			if drawn.has(key) or not _positions.has(to):
				continue
			drawn[key] = true
			var a: Vector2 = _positions[region_id]
			var b: Vector2 = _positions[to]
			var seg := clip_to_rects(a, b, node_footprint(_rects[region_id]), node_footprint(_rects[to]))
			if seg.size() == 2:
				_draw_dotted(seg[0], seg[1], LOCKED_COLOR if _route_gated(data, region_id, to) else ROUTE_COLOR)
			var snow := Weather.travel_extra_days(data, GameState.current_region, GameClock.total_days) if region_id == GameState.current_region else 0
			var days := route_days_label(GameState.player, data, route, snow)
			var size := font.get_string_size(days, HORIZONTAL_ALIGNMENT_LEFT, -1, 14) + Vector2(10, 4)
			var centre := day_label_pos(a, b, node_rects, taken, size)
			var pos := centre - size / 2.0
			taken.append(Rect2(pos, size))
			_canvas.draw_rect(Rect2(pos, size), Color(0.96, 0.92, 0.8))
			_canvas.draw_rect(Rect2(pos, size), INK_COLOR, false, 1.0)
			_canvas.draw_string(font, pos + Vector2(5, size.y - 5), days, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK_COLOR)
	for region_id in _positions:
		var rect: Rect2 = _rects[region_id]
		if is_unexplored(GameState.player, region_id, GameState.current_region):  # WU-530: dotted border
			var rc := rect.grow(2.0)
			var edge := Color(0.45, 0.36, 0.24, 0.8)
			_draw_dotted(rc.position, Vector2(rc.end.x, rc.position.y), edge)
			_draw_dotted(Vector2(rc.end.x, rc.position.y), rc.end, edge)
			_draw_dotted(rc.end, Vector2(rc.position.x, rc.end.y), edge)
			_draw_dotted(Vector2(rc.position.x, rc.end.y), rc.position, edge)
		var x := rect.position.x
		var y := rect.end.y + 3.0
		if not is_unexplored(GameState.player, region_id, GameState.current_region):
			var icon := HudIcons.weather(Weather.of(data, region_id, GameClock.total_days))
			if icon != null:
				_canvas.draw_texture_rect(icon, Rect2(x, y, GLYPH_SIZE, GLYPH_SIZE), false)
				x += GLYPH_SIZE + 2.0
			if not open_markets(data, region_id, GameClock.total_days).is_empty():
				_canvas.draw_texture_rect(HudIcons.map_mark("coin"), Rect2(x, y, GLYPH_SIZE, GLYPH_SIZE), false)
				x += GLYPH_SIZE + 2.0
			var gold := great_name(GameState.player, data, region_id, GameClock.total_days, GameState.world_flags) != ""
			if gold or roamer_count(GameState.player, data, region_id, GameClock.total_days, GameState.world_flags) > 0:
				_canvas.draw_texture_rect(HudIcons.map_mark("paw_gold" if gold else "paw"), Rect2(x, y, GLYPH_SIZE, GLYPH_SIZE), false)
				x += GLYPH_SIZE + 2.0
			elif Wildlife.tracks_today(data, region_id, GameClock.total_days, GameState.player.realm_index, GameState.player):
				_canvas.draw_texture_rect(HudIcons.map_mark("paw"), Rect2(x, y, GLYPH_SIZE, GLYPH_SIZE), false, Color(1, 1, 1, 0.5))
				x += GLYPH_SIZE + 2.0
			if not forage_entries(GameState.player, data, region_id, GameState.current_region, GameClock.total_days, GameState.world_flags).is_empty():
				_canvas.draw_texture_rect(HudIcons.map_mark("leaf"), Rect2(x, y, GLYPH_SIZE, GLYPH_SIZE), false)
				x += GLYPH_SIZE + 2.0
		var kinds: Array = []
		for mark in region_marks(GameState.player, data, GameState.npcs, GameState.world_events, GameClock.total_days, region_id, GameState.current_region, GameState.world_flags):
			if not kinds.has(mark["kind"]):
				kinds.append(mark["kind"])
		for kind in kinds:
			_canvas.draw_circle(Vector2(x + 6.0, y + GLYPH_SIZE / 2.0), 5.0, MARK_COLORS[kind])
			x += 14.0
	if _hint_region != "" and _rects.has(_hint_region):
		var hr: Rect2 = _rects[_hint_region]
		var hm := hint_marker_rect(hr)
		_canvas.draw_rect(hm, Color(0.96, 0.92, 0.8))  # GFX-067: opaque backing so no road line shows through
		_canvas.draw_string(font, Vector2(hm.position.x + 5.0, hm.end.y - 4.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, SEAL_COLOR)
	if _goal_region != "" and _rects.has(_goal_region):
		var gr: Rect2 = _rects[_goal_region]
		_canvas.draw_string(font, Vector2(gr.position.x, gr.position.y - 4.0), "* goal", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SEAL_COLOR)
	if _rects.has(GameState.current_region):
		var cr: Rect2 = _rects[GameState.current_region]
		_canvas.draw_rect(cr.grow(4.0), SEAL_COLOR, false, 2.0)
		_canvas.draw_rect(Rect2(cr.position + Vector2(-9, -9), Vector2(15, 15)), SEAL_COLOR)  # seal stamp
		_canvas.draw_rect(Rect2(cr.position + Vector2(-5, -5), Vector2(7, 7)), Color(0.96, 0.9, 0.8), false, 1.0)


## GFX-067: the box of the "!" hint marker: wholly above and outside the node rect, at its right end.
static func hint_marker_rect(node_rect: Rect2) -> Rect2:
	return Rect2(node_rect.end.x - 16.0, node_rect.position.y - 28.0, 18.0, 26.0)


## Whether the road between two regions needs a minimum realm in either direction.
static func _route_gated(data: GameData, a: String, b: String) -> bool:
	for pair in [[a, b], [b, a]]:
		for route: Dictionary in data.regions.get(pair[0], {}).get("routes", []):
			if route.get("to", "") == pair[1] and route.has("min_realm"):
				return true
	return false


func _select(region_id: String) -> void:
	_selected = region_id
	for b in _canvas.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == region_id)
	_show_details()


func _show_details() -> void:
	var data := GameState.data
	var region: Dictionary = data.regions.get(_selected, {})
	if region.is_empty():
		return
	_name.text = String(region.get("name", _selected))
	_info.text = "%s   |   Danger: %s" % [qi_line(data, _selected, GameState.world_flags, GameState.world_events, GameState.player), danger_name(data, _selected)]
	_hint_note.text = "Your hint points here." if _selected == _hint_region and _selected != GameState.current_region else ""
	if _selected == _goal_region and _selected != GameState.current_region and _hint_note.text == "":
		_hint_note.text = "Your road goal points here."
	_hint_note.visible = _hint_note.text != ""
	var unexplored := is_unexplored(GameState.player, _selected, GameState.current_region)
	_description.text = String(region.get("description", ""))
	if unexplored:
		_description.text += "\n" + "Unexplored. " + lure_line(data, _selected)
		for t: String in ["Today", "You here", "Shops", "Places"]:
			(_heads[t] as Label).visible = false
		for pair: Array in [["Today", _today], ["You here", _you], ["Shops", _shops], ["Places", _places]]:
			_set_block(pair[0], pair[1], "")
	else:
		var today := today_line(GameState.player, data, _selected, GameState.current_region, GameClock.total_days, GameState.world_flags)
		var by_path := forage_line(GameState.player, data, _selected, GameState.current_region, GameClock.total_days, GameState.world_flags)
		if by_path != "":
			today += ("\n" if today != "" else "") + by_path
		var market_day := Places.market_day_line(region, GameClock.total_days)
		if market_day != "":
			today += ("\n" if today != "" else "") + market_day
		_set_block("Today", _today, today)
		var you := PackedStringArray()
		for line: String in [renown_note(GameState.player, data, _selected), ShopScreen.deal_note(GameState.player, _selected, GameClock.total_days).strip_edges(), abode_line(GameState.player, data, _selected)]:
			if line != "":
				you.append(line)
		_set_block("You here", _you, "\n".join(you))
		_set_block("Shops", _shops, "\n".join(shop_rows(data, _selected)))
		var places := place_names(data, _selected)
		var place_text := capped_list(places) if not places.is_empty() else "none known"
		var familiar := familiarity_lines(GameState.player, data, _selected, GameState.current_region, GameState.world_flags)
		if not familiar.is_empty():
			place_text += "\n" + "   |   ".join(familiar)
		_set_block("Places", _places, place_text)
	var foes_text := ""
	if _selected == GameState.current_region:  # always explored
		var tags: Array = region.get("encounter_tags", []) + WorldEvents.encounter_tags(data, GameState.world_events, _selected)
		foes_text = foes_bbcode(Exploration.outlook(GameState.player, data, tags, GameState.world_flags, Calendar.season_of(GameClock.total_days), _selected, GameClock.total_days)["foes"])
	_foes.text = foes_text
	_foes.visible = foes_text != ""
	var marks := region_marks(GameState.player, data, GameState.npcs, GameState.world_events, GameClock.total_days, _selected, GameState.current_region, GameState.world_flags)
	_marks.visible = not marks.is_empty()
	_marks.text = "\n".join(marks.map(func(m: Dictionary) -> String: return "• " + String(m["text"])))
	_routes.text = "\n".join(route_lines(GameState.player, data, GameState.current_region, _selected))


func _focus_selected() -> void:
	var b := _canvas.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()


func _on_region_changed_rebuild(_id: String) -> void:
	if visible:
		_rebuild()


func _on_player_changed_details() -> void:
	if visible:
		_show_details()
