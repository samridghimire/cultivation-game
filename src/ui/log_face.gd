class_name LogFace
extends RefCounted
## WU-650: a small portrait at the start of a message-log row that names an NPC.
## A log line carries its face as a leading marker (MARK_OPEN id MARK_CLOSE) so the same string
## works in BBCode lists; `append` turns the marker into an inline image.

const MARK_OPEN := "\u0001"
const MARK_CLOSE := "\u0002"
const SIZE := 16


## `line` prefixed with the marker for `npc_id` ("" = no face, line unchanged).
static func encode(npc_id: String, line: String) -> String:
	return line if npc_id == "" else MARK_OPEN + npc_id + MARK_CLOSE + line


## Splits an encoded line into {"npc": id or "", "text": rest}.
static func decode(line: String) -> Dictionary:
	if line.begins_with(MARK_OPEN):
		var end := line.find(MARK_CLOSE)
		if end > 0:
			return {"npc": line.substr(1, end - 1), "text": line.substr(end + 1)}
	return {"npc": "", "text": line}


## The head of `npc_id`, drawn with the same look the world uses (null when it can't be built).
static func texture(npc_id: String) -> Texture2D:
	if GameState.npcs == null or not GameState.npcs.has(npc_id):
		return null
	var look := preload("res://src/world/interactables/npc.gd").look_of(npc_id, Color("8a8a8a"))
	var full := PixelFigure.frame(look, "down", 0)
	var img := full.get_image().get_region(Rect2i(0, 0, mini(full.get_width(), SIZE), mini(full.get_height(), SIZE)))
	return ImageTexture.create_from_image(img)


## Appends `line` to `label`, with the portrait first when it carries one.
static func append(label: RichTextLabel, line: String) -> void:
	var parts := decode(line)
	var tex: Texture2D = texture(String(parts["npc"])) if parts["npc"] != "" else null
	if tex != null:
		label.add_image(tex, SIZE, SIZE)
		label.append_text(" ")
	label.append_text(String(parts["text"]))
