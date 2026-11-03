## Procedural pixel sprites: vehicles (rear view) and props, built from mirrored half-bitmaps in Data.
class_name Sprites

static var _veh_cache: Dictionary = {}
static var _prop_cache: Dictionary = {}


static func _build(half: Array, rows: int, pal: Dictionary) -> ImageTexture:
	var img := Image.create(24, rows, false, Image.FORMAT_RGBA8)
	for y in rows:
		var h: String = half[y]
		var row := h + h.reverse()
		for x in 24:
			var ch := row[x]
			if ch == "." or not pal.has(ch):
				continue
			img.set_pixel(x, y, Color.html(pal[ch]))
	return ImageTexture.create_from_image(img)


## Returns [frameA, frameB] (engine flicker), cached by class + colours.
static func vehicle(cls: String, b: String, l: String, r: String) -> Array:
	var key := cls + b + l + r
	if _veh_cache.has(key):
		return _veh_cache[key]
	var base := {"k": "#14141f", "b": b, "l": l, "r": r, "c": "#6ff0ff", "w": "#ffffff", "g": "#8e93a8"}
	var pa := base.duplicate()
	pa["y"] = "#ffd23a"
	pa["f"] = "#ff7a1a"
	var pb := base.duplicate()
	pb["y"] = "#ff7a1a"
	pb["f"] = "#ffd23a"
	var res := [_build(Data.HALF[cls], 12, pa), _build(Data.HALF[cls], 12, pb)]
	_veh_cache[key] = res
	return res


static func prop(kind: String, pal: Dictionary) -> ImageTexture:
	var key := kind + str(pal)
	if _prop_cache.has(key):
		return _prop_cache[key]
	var t := _build(Data.CRAWLER_HALF if kind == "crawler" else Data.PROP_HALF[kind], 14, pal)
	_prop_cache[key] = t
	return t
