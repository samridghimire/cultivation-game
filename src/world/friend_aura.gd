class_name FriendAura
extends Node2D
## GFX-264: a named villager who cultivates shows it: a soft ellipse in their main root's colour under the figure
## (Qi Refining+), a brighter rim at Foundation+. Slow 3 s pulse, none with `reduce_motion`. Mortals draw nothing.

const PERIOD := 3.0
const FALLBACK := Color("f0d98a")

var npc_id := ""
var override_realm := -1  ## screenshots/tests: force a realm index (-1 = the villager's own)


## {alpha, radius, pulse (alpha swing), rim (bool)} for a realm index; alpha 0 = no aura.
static func aura_for(realm_index: int) -> Dictionary:
	if realm_index < 1:
		return {"alpha": 0.0, "radius": 0.0, "pulse": 0.0, "rim": false}
	var r := mini(realm_index, 3)
	return {"alpha": 0.18 + 0.05 * float(r - 1), "radius": 20.0 + 3.0 * float(r - 1), "pulse": 0.08, "rim": realm_index >= 2}


## Alpha at time `t` (never above 0.35); a still aura when `calm`.
static func alpha_at(realm_index: int, t: float, calm: bool) -> float:
	var a := aura_for(realm_index)
	var base := float(a["alpha"])
	if base <= 0.0 or calm:
		return minf(base, 0.35)
	return minf(base + float(a["pulse"]) * sin(t * TAU / PERIOD), 0.35)


## The villager's strongest root's colour, pale gold with no root.
static func color_for(c: CharacterData) -> Color:
	var best := ""
	var best_v := 0
	if c != null:
		for e in c.spiritual_roots:
			var v := int(c.spiritual_roots[e])
			if v > best_v:
				best_v = v
				best = String(e)
	return CharacterSheet.ELEMENT_COLORS.get(best, FALLBACK)


func _realm() -> int:
	if override_realm >= 0:
		return override_realm
	var c: CharacterData = GameState.npcs.get(npc_id)
	return c.realm_index if c != null else 0


func _calm() -> bool:
	return bool(Settings.get_value("reduce_motion"))


func _process(_delta: float) -> void:
	if _realm() >= 1:
		queue_redraw()


func _draw() -> void:
	var realm := _realm()
	var a := aura_for(realm)
	if float(a["alpha"]) <= 0.0:
		return
	var col := color_for(GameState.npcs.get(npc_id))
	var t := float(Time.get_ticks_msec()) / 1000.0
	var alpha := alpha_at(realm, t, _calm())
	var rad := float(a["radius"])
	var pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * float(i) / 24.0
		pts.append(Vector2(cos(ang) * rad, sin(ang) * rad * 0.4))
	draw_colored_polygon(pts, Color(col, alpha))
	if bool(a["rim"]):
		pts.append(pts[0])
		draw_polyline(pts, Color(col.lightened(0.4), minf(alpha + 0.12, 0.35)), 2.0)
