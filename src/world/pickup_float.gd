class_name PickupFloat
extends RefCounted
## GFX-092: the small "+1 Hen's Egg" text with the item's icon that floats above the player for about a second
## after a pickup. Under reduce_motion it only fades (no drift).

const LIFETIME := 1.0
const ICON_ZOOM := 2


## "+1 Hen's Egg" (the item's name, plural when more than one).
static func text_for(data: GameData, item_id: String, amount: int) -> String:
	if not data.items.has(item_id):
		return ""
	return "+%d %s" % [amount, Items.item_plural(data, item_id, amount)]


## Adds the float to `parent` at `pos` (world space, above the thing picked up). Returns the node, or null for an unknown item.
static func spawn(parent: Node, data: GameData, item_id: String, amount: int, pos: Vector2) -> Control:
	var text := text_for(data, item_id, amount)
	if text == "":
		return null
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.z_index = 20
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := ItemIcon.for_id(data, item_id)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(ItemIcon.SIZE * ICON_ZOOM, ItemIcon.SIZE * ICON_ZOOM)
		box.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UIStyle.ACCENT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	box.add_child(label)
	box.position = pos + Vector2(-44, -52)
	parent.add_child(box)
	var tw := box.create_tween()
	if MotionFx.reduced():
		tw.tween_property(box, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	else:
		tw.set_parallel(true)
		tw.tween_property(box, "position:y", box.position.y - 24.0, LIFETIME)
		tw.tween_property(box, "modulate:a", 0.0, LIFETIME * 0.6).set_delay(LIFETIME * 0.4)
	tw.chain().tween_callback(box.queue_free)
	return box
