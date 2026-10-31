class_name PortraitBox
extends PanelContainer
## Framed pixel portrait of the speaker (WU-408); hidden while it has no texture.

## Portrait scale over the 16x20 figure frame.
const SCALE := 3
## Width the box takes: portrait + frame margins (12 each side) + gap to the text column.
const COLUMN_WIDTH := PixelFigure.SIZE.x * SCALE + 24 + 12

var _rect: TextureRect


func _init(zoom: int = SCALE) -> void:
	var style := UIStyle.panel_style()
	if zoom < SCALE:  # WU-413: a small chip portrait gets a thin frame
		style.set_content_margin_all(3)
	add_theme_stylebox_override("panel", style)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_rect = TextureRect.new()
	_rect.custom_minimum_size = Vector2(PixelFigure.SIZE * zoom)
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_rect)
	visible = false


func set_portrait(tex: Texture2D) -> void:
	_rect.texture = tex
	visible = tex != null
