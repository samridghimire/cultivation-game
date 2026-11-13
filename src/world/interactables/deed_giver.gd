extends Interactable
## An NPC or place that offers moral choices from data/deeds.json.
## Disappears if `hidden_by_flag` is set in the world flags.

@export var deed_context := "villager"
@export var hidden_by_flag := ""
## Optional look from regions.json (GFX-018, see PlaceLooks).
@export var look := {}


## Named sprite per deed context before the generic place art, once a pack lands.
func sprite_keys() -> PackedStringArray:
	return PackedStringArray(["npc_" + deed_context, "place_" + art_kind])


## GFX-129: the place look plus the accessories its display name implies ("Farmer Tian" wears a straw hat).
func _figure_look() -> Dictionary:
	var out := PlaceLooks.figure_look(look, color)
	var role := {"id": display_name, "name": display_name, "age_years": 14 if look.get("child", false) == true else (70 if look.get("hair", "") == "grey" else 30)}
	var acc := PixelFigure.accessories_for(role)
	out["accessories"] = acc
	if not look.has("robe") and PixelFigure.ROLE_ROBES.has(PixelFigure.role_of(role)):
		out["robe"] = PixelFigure.ROLE_ROBES[PixelFigure.role_of(role)]
	return out


func portrait_texture() -> Texture2D:
	if PlaceLooks.is_camp(look):
		return null
	return PixelFigure.frame(_figure_look(), "down", 0)


func draw_generated_art() -> bool:
	if PlaceLooks.is_camp(look):
		PlaceArt.draw(self, "camp", size, color)
		return true
	var tex := PixelFigure.frame(_figure_look(), "down", 0)
	var s := float(Sprites.scale())
	var tex_size := Vector2(tex.get_size()) * s
	var sh := Scenery.figure_shadow(tex_size, winter)
	PlaceArt.ellipse(self, Vector2(0, size.y / 2.0 - 1.0), sh.size / 2.0, Scenery.figure_shadow_color(winter))
	draw_texture_rect(tex, Rect2(Vector2(-tex_size.x / 2.0, size.y / 2.0 - tex_size.y), tex_size), false)
	return true


func is_available() -> bool:
	return hidden_by_flag == "" or not Effects.flag_active(GameState.world_flags, hidden_by_flag, GameClock.total_days)


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for entry in Deeds.options(GameState.player, GameState.data, deed_context, GameState.world_flags, GameClock.total_days):
		var deed: Dictionary = entry["deed"]
		var label := String(deed["name"])
		if entry["danger"] != "":
			label += " [fight: %s%s]" % [entry["danger"], ", to the death" if entry.get("lethal", false) else ""]
		options.append({"label": label, "action": GameState.perform_deed.bind(deed["id"]), "disabled": entry["disabled"], "reason": entry["reason"] if entry["disabled"] else ""})
	return options
