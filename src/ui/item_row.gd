class_name ItemRow
extends RefCounted
## Shared item list row (GFX-032): a button with a framed icon slot, the name (plus an optional accent-free tag),
## and a right-aligned badge ("x3" for a stack, or a price with a stone icon in the shop).

const SLOT := 36
const BADGE_WIDTH := 56
const SLOT_FILL := Color("1c1612")
const SLOT_BORDER := Color("6b5a3e")

static var _frames: Dictionary = {}


## A 36 px slot image: dark fill, 1 px border, the item icon centred (nearest).
static func framed(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _frames.has(tex):
		return _frames[tex]
	var img := Image.create(SLOT, SLOT, false, Image.FORMAT_RGBA8)
	img.fill(SLOT_FILL)
	for i in SLOT:
		for edge: Vector2i in [Vector2i(i, 0), Vector2i(i, SLOT - 1), Vector2i(0, i), Vector2i(SLOT - 1, i)]:
			img.set_pixelv(edge, SLOT_BORDER)
	var src := tex.get_image()
	if src != null:
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var icon_px := ItemIcon.SIZE * ItemIcon.ZOOM
		if src.get_width() != icon_px:
			src.resize(icon_px, icon_px, Image.INTERPOLATE_NEAREST)
		var at := Vector2i((SLOT - icon_px) / 2, (SLOT - icon_px) / 2)
		img.blend_rect(src, Rect2i(0, 0, icon_px, icon_px), at)
	var out := ImageTexture.create_from_image(img)
	_frames[tex] = out
	return out


## The count badge text: "x3", "" for a single item.
static func badge_text(count: int) -> String:
	return "x%d" % count if count > 1 else ""


## Row button for `item_id`. The button text is the name plus `extra_tag`; `price` >= 0 shows a stone-priced badge
## instead of the count badge. Selection and focus are the caller's business.
static func make(data: GameData, item_id: String, count: int, extra_tag: String = "", price: int = -1, trend: int = 0) -> Button:
	var name := String(data.items.get(item_id, {}).get("name", item_id))
	var b := UIStyle.button(name if extra_tag == "" else "%s  %s" % [name, extra_tag], Callable())
	b.name = item_id
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.expand_icon = false
	var tex := framed(ItemIcon.for_id(data, item_id))
	if tex != null:
		b.icon = tex
		b.add_theme_constant_override("icon_max_width", SLOT)
	var badge := HBoxContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.alignment = BoxContainer.ALIGNMENT_END
	badge.add_theme_constant_override("separation", 4)
	badge.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	badge.offset_left = -BADGE_WIDTH - 8 - (16 if trend != 0 and price >= 0 else 0)
	badge.offset_right = -8
	if price >= 0 and trend != 0:
		var arrow := TextureRect.new()
		arrow.name = "TrendArrow"
		arrow.texture = HudIcons.trend(trend)
		arrow.custom_minimum_size = Vector2(12, 12)
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(arrow)
	if price >= 0:
		var stone := TextureRect.new()
		stone.texture = ItemIcon.for_id(data, "spirit_stone")
		stone.custom_minimum_size = Vector2(16, 16)
		stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(stone)
	var text := str(price) if price >= 0 else badge_text(count)
	var l := UIStyle.label(text, 15, UIStyle.ACCENT if price >= 0 else Color(0.8, 0.8, 0.85))
	l.name = "BadgeLabel"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(l)
	badge.visible = text != ""
	b.add_child(badge)
	return b
