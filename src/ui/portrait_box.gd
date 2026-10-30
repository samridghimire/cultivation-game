class_name PortraitBox
extends PanelContainer
## Framed pixel portrait of the speaker (WU-408); hidden while it has no texture.

## Portrait scale over the 16x20 figure frame.
const SCALE := 3
## Width the box takes: portrait + frame margins (12 each side) + gap to the text column.
const COLUMN_WIDTH := PixelFigure.SIZE.x * SCALE + 24 + 12

var _rect: TextureRect


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_rect = TextureRect.new()
	_rect.custom_minimum_size = Vector2(PixelFigure.SIZE * SCALE)
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_rect)
	visible = false


func set_portrait(tex: Texture2D) -> void:
	_rect.texture = tex
	visible = tex != null
