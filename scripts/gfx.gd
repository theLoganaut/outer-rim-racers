## Pixel-art drawing helpers (3x5 bitmap font, panels, bars) for the 256x224 canvas.
class_name Gfx

const W := 256
const H := 224

static var _atlas: ImageTexture
static var _glyph: Dictionary = {}
static var _cc: Dictionary = {}


static func C(v) -> Color:
	if v is Color:
		return v
	if _cc.has(v):
		return _cc[v]
	var c := Color.html(v)
	_cc[v] = c
	return c


static func _init_font() -> void:
	var keys: Array = Data.FONT_SRC.keys()
	var img := Image.create(keys.size() * 3, 5, false, Image.FORMAT_RGBA8)
	for gi in keys.size():
		var bits: String = Data.FONT_SRC[keys[gi]].replace("/", "")
		_glyph[keys[gi]] = gi
		for j in 15:
			if bits[j] == "1":
				img.set_pixel(gi * 3 + (j % 3), j / 3, Color.WHITE)
	_atlas = ImageTexture.create_from_image(img)


static func _draw_txt(ci: CanvasItem, s: String, x: float, y: float, sc: float, col: Color) -> void:
	for i in s.length():
		var gi = _glyph.get(s[i], -1)
		if gi < 0:
			continue
		ci.draw_texture_rect_region(_atlas, Rect2(x + i * 4 * sc, y, 3 * sc, 5 * sc), Rect2(gi * 3, 0, 3, 5), col)


static func txt_w(s, sc: float) -> float:
	return str(s).length() * 4 * sc - sc


static func txt(ci: CanvasItem, s, x: float, y: float, sc: float, col, shadow = Color.BLACK) -> void:
	if _atlas == null:
		_init_font()
	var t := str(s).to_upper()
	if shadow != null:
		_draw_txt(ci, t, x + sc, y + sc, sc, C(shadow))
	_draw_txt(ci, t, x, y, sc, C(col))


static func txt_c(ci: CanvasItem, s, y: float, sc: float, col, shadow = Color.BLACK) -> void:
	txt(ci, s, int((W - txt_w(s, sc)) / 2.0), y, sc, col, shadow)


static func txt_r(ci: CanvasItem, s, xr: float, y: float, sc: float, col, shadow = Color.BLACK) -> void:
	txt(ci, s, xr - txt_w(s, sc), y, sc, col, shadow)


static func rect(ci: CanvasItem, x: float, y: float, w: float, h: float, col) -> void:
	ci.draw_rect(Rect2(x, y, w, h), C(col))


static func panel(ci: CanvasItem, x: float, y: float, w: float, h: float, a: float = 0.72) -> void:
	ci.draw_rect(Rect2(x, y, w, h), Color(6 / 255.0, 8 / 255.0, 24 / 255.0, a))
	var c := Color("#6a7cff")
	ci.draw_rect(Rect2(x, y, w, 1), c)
	ci.draw_rect(Rect2(x, y + h - 1, w, 1), c)
	ci.draw_rect(Rect2(x, y, 1, h), c)
	ci.draw_rect(Rect2(x + w - 1, y, 1, h), c)


static func bar(ci: CanvasItem, x: float, y: float, w: float, h: float, frac: float, col, back = "#2a3050") -> void:
	var f := clampf(frac, 0.0, 1.0)
	ci.draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color.BLACK)
	ci.draw_rect(Rect2(x, y, w, h), C(back))
	ci.draw_rect(Rect2(x, y, round(w * f), h), C(col))
	ci.draw_rect(Rect2(x, y, round(w * f), 1), Color(1, 1, 1, 0.3))


static func disc(ci: CanvasItem, cx: float, cy: float, r: int, col) -> void:
	var c := C(col)
	for y in range(-r, r + 1):
		var w := int(floor(sqrt(r * r - y * y)))
		ci.draw_rect(Rect2(cx - w, cy + y, w * 2 + 1, 1), c)
