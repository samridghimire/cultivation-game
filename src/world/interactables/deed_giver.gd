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


func portrait_texture() -> Texture2D:
	if PlaceLooks.is_camp(look):
		return null
	return PixelFigure.frame(PlaceLooks.figure_look(look, color), "down", 0)


func draw_generated_art() -> bool:
	if PlaceLooks.is_camp(look):
		PlaceArt.draw(self, "camp", size, color)
		return true
	var tex := PixelFigure.frame(PlaceLooks.figure_look(look, color), "down", 0)
	var s := float(Sprites.scale())
	var tex_size := Vector2(tex.get_size()) * s
	draw_texture_rect(tex, Rect2(Vector2(-tex_size.x / 2.0, size.y / 2.0 - tex_size.y), tex_size), false)
	return true


func is_available() -> bool:
	return hidden_by_flag == "" or not GameState.world_flags.get(hidden_by_flag, false)


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for entry in Deeds.options(GameState.player, GameState.data, deed_context, GameState.world_flags, GameClock.total_days):
		var deed: Dictionary = entry["deed"]
		var label := String(deed["name"])
		if entry["danger"] != "":
			label += " [fight: %s%s]" % [entry["danger"], ", to the death" if entry.get("lethal", false) else ""]
		options.append({"label": label, "action": GameState.perform_deed.bind(deed["id"]), "disabled": entry["disabled"], "reason": entry["reason"] if entry["disabled"] else ""})
	return options
