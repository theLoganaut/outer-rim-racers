## Draws the 3D-looking world: banded sky + parallax scenery, the Mode 7 ground (shader), and sorted sprites.
class_name WorldView
extends RefCounted

const W := 256
const H := 224
const HORIZON := 72
const FOCAL := 160.0
const VEH_SCALE := 18.0   # car size in world units

var rc: Race
var ground_mat: ShaderMaterial
var _mine_a: Texture2D
var _mine_b: Texture2D
var _planet_key := ""
var focal := FOCAL    # FOV push while boosting narrows this


func _init(race: Race, ground_material: ShaderMaterial) -> void:
	rc = race
	ground_mat = ground_material
	_mine_a = Sprites.prop("mine", Data.PAL_MINE)
	var pal_b := Data.PAL_MINE.duplicate()
	pal_b["r"] = "#601010"
	_mine_b = Sprites.prop("mine", pal_b)


# ----------------------------------------------------------------------- sky

static func _wrap_x(base: float, off: float) -> float:
	var x := fposmod(base - off, 512.0)
	if x > 384.0:
		x -= 512.0
	return x


static func _hash_px(x: int, y: int) -> int:
	return Util.hash2(x, y)


func _draw_mountains(ci: CanvasItem, pl: Dictionary, off: float) -> void:
	for lay in pl.mtn:
		var col := Gfx.C(lay.col)
		var o: float = off * lay.par
		var run_x := 0
		var run_h := -999
		var mesa: bool = lay.get("mesa", false)
		for x in W + 1:
			var h := -999
			if x < W:
				var xs: float = x + o
				var hf: float = lay.base + lay.a1 * sin(xs * TAU * lay.f1 / 512.0 + lay.f1) + lay.a2 * sin(xs * TAU * lay.f2 / 512.0)
				if mesa:
					hf = floorf(hf / 4.0 + 0.5) * 4.0
				h = int(floorf(hf + 0.5))
			if h != run_h:
				if run_h > 0:
					ci.draw_rect(Rect2(run_x, HORIZON - run_h, x - run_x, run_h), col)
				run_x = x
				run_h = h


func _scenery_back(ci: CanvasItem, pl: Dictionary, off: float, t: float) -> void:
	var s: String = pl.scenery
	if s == "twinsuns":
		var x := _wrap_x(150, off * 0.4)
		ci.draw_rect(Rect2(x - 14, 24, 28, 22), Color(255 / 255.0, 240 / 255.0, 200 / 255.0, 0.18))
		Gfx.disc(ci, x, 34, 8, "#fff6d0")
		x = _wrap_x(178, off * 0.4)
		Gfx.disc(ci, x, 46, 5, "#ffe8a8")
	elif s == "destroyer":
		var x := _wrap_x(120, off * 0.4)
		Gfx.disc(ci, x, 40, 9, "#fff3c0")
		x = _wrap_x(330, off * 0.55)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 70, HORIZON - 12), Vector2(x + 30, HORIZON - 40),
			Vector2(x + 36, HORIZON - 34), Vector2(x - 40, HORIZON - 8)]), Color("#6a665e"))
		Gfx.rect(ci, x - 6, HORIZON - 36, 10, 3, "#8a857a")
	elif s == "aurora":
		var x := 0
		while x < W:
			var v := sin((x + off) * 0.03 + t * 0.6) + sin((x + off) * 0.011 - t * 0.4)
			var h := 8 + int(round(v * 5.0))
			ci.draw_rect(Rect2(x, 10 + round(v * 3.0), 3, h), Color(120 / 255.0, 1.0, 200 / 255.0, 0.20))
			ci.draw_rect(Rect2(x, 20 + round(v * 3.0), 3, h), Color(160 / 255.0, 140 / 255.0, 1.0, 0.16))
			x += 3
	elif s == "ringplanet":
		var x := _wrap_x(210, off * 0.4)
		Gfx.disc(ci, x, 36, 16, "#8a6aa8")
		Gfx.disc(ci, x - 4, 33, 12, "#a284c0")
		Gfx.rect(ci, x - 30, 38, 60, 2, "#d8c0f0")
		for i in 40:    # stars
			var sx := (i * 97 + 13) % W
			var sy := (i * 31 + 7) % 50
			if (int(t * 2.0) + i) % 5 != 0:
				ci.draw_rect(Rect2(sx, sy, 1, 1), Color.WHITE)


func _scenery_front(ci: CanvasItem, pl: Dictionary, off: float, t: float) -> void:
	var s: String = pl.scenery
	if s == "antennas":
		for base in [60, 140, 330, 420, 250]:
			var x := _wrap_x(base, off * 1.3)
			var dark := Color("#16161c")
			ci.draw_rect(Rect2(x, HORIZON - 26, 1, 26), dark)
			ci.draw_rect(Rect2(x - 3, HORIZON - 20, 7, 1), dark)
			ci.draw_rect(Rect2(x - 2, HORIZON - 12, 5, 1), dark)
			if fmod(t * 2.0 + base, 2.0) < 1.0:
				ci.draw_rect(Rect2(x, HORIZON - 27, 1, 1), Color("#ff3030"))
		for base in [200, 380]:
			var x := _wrap_x(base, off * 1.1)
			var c := Color(40 / 255.0, 50 / 255.0, 20 / 255.0, 0.55)
			ci.draw_rect(Rect2(x, HORIZON - 40, 6, 40), c)
			ci.draw_rect(Rect2(x - 2, HORIZON - 48, 10, 10), c)
	elif s == "mist":
		var x := 0
		while x < W:
			var h := 5 + int(round(2.0 * sin((x + off) * 0.05 + t)))
			ci.draw_rect(Rect2(x, HORIZON - h, 4, h), Color(210 / 255.0, 240 / 255.0, 230 / 255.0, 0.30))
			x += 4
	elif s == "mesas":
		for base in [90, 260, 400]:
			var x := _wrap_x(base, off * 1.2)
			Gfx.rect(ci, x, HORIZON - 14, 34, 14, "#c47868")
			Gfx.rect(ci, x, HORIZON - 14, 34, 2, "#e0a090")
			Gfx.rect(ci, x + 22, HORIZON - 12, 12, 12, "#9a5448")


## The sky: banded gradient + parallax layers. cave 0..1 darkens it to rock.
func draw_sky(ci: CanvasItem) -> void:
	var pl: Dictionary = rc.trk.planet
	var off: float = rc.cam_a * 81.5
	var t: float = rc.anim_t
	var cave: float = rc.R.cave
	var bands: int = pl.sky.size()
	var bh := float(HORIZON) / bands
	for i in bands:
		ci.draw_rect(Rect2(0, floorf(i * bh), W, ceilf(bh) + 1), Gfx.C(pl.sky[i]))
	_scenery_back(ci, pl, off, t)
	_draw_mountains(ci, pl, off)
	_scenery_front(ci, pl, off, t)
	if cave > 0.01:
		ci.draw_rect(Rect2(0, 0, W, HORIZON), Color(14 / 255.0, 10 / 255.0, 8 / 255.0, clampf(cave * 0.96, 0.0, 0.96)))
		var c := Color(40 / 255.0, 30 / 255.0, 22 / 255.0, clampf(cave, 0.0, 1.0))
		var x := 0
		while x < W:    # stalactites
			var h := 6 + (_hash_px(x >> 1, 7) % 18)
			ci.draw_rect(Rect2(x, 0, 3, h), c)
			x += 3


# -------------------------------------------------------------------- ground

## Pushes the camera + planet colours into the Mode 7 shader.
func update_ground() -> void:
	var pl: Dictionary = rc.trk.planet
	var cam: Dictionary = rc.cam
	ground_mat.set_shader_parameter("cam_pos", Vector2(cam.x, cam.y))
	ground_mat.set_shader_parameter("cam_dir", Vector2(cos(cam.a), sin(cam.a)))
	ground_mat.set_shader_parameter("cam_h", rc.cam_h)
	ground_mat.set_shader_parameter("cave", rc.R.cave)
	focal = FOCAL * (1.0 - 0.12 * rc.fov_k)
	ground_mat.set_shader_parameter("focal", focal)
	var sk: float = rc.events.k
	ground_mat.set_shader_parameter("fog_start", 1600.0 * (1.0 - 0.8 * sk))
	ground_mat.set_shader_parameter("fog_range", 12000.0 * (1.0 - 0.7 * sk))
	if _planet_key != rc.trk.planet_key:
		_planet_key = rc.trk.planet_key
		var fog := Color.html(pl.fog)
		var ga := Color.html(pl.ground[0])
		var gb := Color.html(pl.ground[1])
		ground_mat.set_shader_parameter("fog_rgb", Vector3(fog.r, fog.g, fog.b))
		ground_mat.set_shader_parameter("ground_a", Vector3(ga.r, ga.g, ga.b))
		ground_mat.set_shader_parameter("ground_b", Vector3(gb.r, gb.g, gb.b))


func invalidate_planet() -> void:
	_planet_key = ""


# ------------------------------------------------------------------- sprites

func _draw_sprite_scaled(ci: CanvasItem, spr: Texture2D, sx: float, gy: float, w: float, ratio: float, lean: float) -> void:
	w = maxf(2.0, round(w))
	var h := maxf(1.0, round(w * ratio))
	if lean == 0.0:
		ci.draw_texture_rect(spr, Rect2(round(sx - w / 2.0), round(gy - h), w, h), false)
		return
	var rows := spr.get_height()
	var dh := h / rows
	for r in rows:
		var ox := lean * (r - rows * 0.66) * w / 40.0
		ci.draw_texture_rect_region(spr, Rect2(round(sx - w / 2.0 + ox), round(gy - h + r * dh), w, ceilf(dh) + 0.5),
			Rect2(0, r, spr.get_width(), 1))


const NOZZLE_X := {"sled": 1.0, "bike": 0.75, "skim": 1.0, "pod": 1.45}
const NOZZLE_Y := {"sled": 0.85, "bike": 0.7, "skim": 0.5, "pod": 0.95}
const NOZZLE_Z := {"sled": 2.6, "bike": 2.6, "skim": 2.1, "pod": 0.95}


## Draws a pre-rendered pod frame, bottom-centred on (sx, gy). w is the on-screen width of the old 24px sprite.
func _draw_pod(ci: CanvasItem, tex: Texture2D, sx: float, gy: float, w: float) -> void:
	var dw := maxf(4.0, round(w * 2.3))
	var dh := round(dw * VehicleModels.CELL_H / VehicleModels.CELL_W)
	ci.draw_texture_rect(tex, Rect2(round(sx - dw / 2.0), round(gy - dh + dh * 0.08), dw, dh), false)


## Screen offsets (relative to the ground point) of the pod's two nozzles for a class and yaw.
func _nozzles(cls: String, yaw: float, w: float) -> Array:
	var u := w / 3.0    # pixels per model unit
	var nx: float = NOZZLE_X[cls]
	var ny: float = NOZZLE_Y[cls]
	var nz: float = NOZZLE_Z[cls]
	var out: Array = []
	for sgn in [-1.0, 1.0]:
		var rx: float = sgn * nx * cos(yaw) - nz * sin(yaw)
		var rz: float = nz * cos(yaw) + sgn * nx * sin(yaw)
		out.append(Vector2(rx * u, -ny * 0.94 * u + rz * 0.34 * u))
	return out


func _draw_boom(ci: CanvasItem, sx: float, gy: float, t: float, sc: float, big: bool) -> void:
	if t >= 1.4:
		return
	var n := 16 if big else 9
	var cols := ["#fff2a0", "#ffb030", "#ff5a10", "#601818"]
	for i in n:
		var a := i * 2.4 + t * 2.0
		var rr := minf(t, 1.2) * (14.0 + (i % 4) * 8.0) * sc * (1.0 if big else 0.55)
		var s := maxf(1.0, (9.0 - t * 6.0 + (i % 3) * 2.0) * sc * (1.0 if big else 0.6))
		ci.draw_rect(Rect2(sx + cos(a) * rr - s / 2.0, gy - 8.0 * sc + sin(a) * rr * 0.6 - s / 2.0, s, s), Gfx.C(cols[(i + int(t * 12.0)) % 4]))


func _draw_smoke(ci: CanvasItem, sx: float, gy: float, w: float) -> void:
	for i in 3:
		var t := fmod(rc.anim_t * 1.6 + i / 3.0, 1.0)
		var c := Color(70 / 255.0, 70 / 255.0, 80 / 255.0, 0.7 * (1.0 - t))
		var s := maxf(1.0, round(w / 8.0 * (1.0 + t)))
		ci.draw_rect(Rect2(round(sx - w * 0.2 + (i - 1) * w * 0.2 + sin(rc.anim_t * 9.0 + i) * 1.5), round(gy - w / 2.0 - t * w * 0.5), s, s), c)


func _draw_shield_ring(ci: CanvasItem, sx: float, gy: float, w: float) -> void:
	var c := Color(96 / 255.0, 208 / 255.0, 1.0, 0.55 + 0.25 * sin(rc.anim_t * 20.0))
	var x := round(sx - w * 0.6)
	var y := round(gy - w * 0.7)
	var rw := round(w * 1.2)
	var rh := round(w * 0.7)
	ci.draw_rect(Rect2(x, y, rw, 1), c)
	ci.draw_rect(Rect2(x, y + rh, rw, 1), c)
	ci.draw_rect(Rect2(x, y, 1, rh), c)
	ci.draw_rect(Rect2(x + rw, y, 1, rh + 1), c)


func _draw_flames(ci: CanvasItem, sx: float, gy: float, w: float, col1: String, col2: String, frame: int, big: bool, noz: Array) -> void:
	var c := Gfx.C(col1 if frame != 0 else col2)
	var fw := maxf(2.0, round(w / 10.0))
	var fh := round(w / (3.0 if big else 5.0) + frame * 2)
	for q in noz:
		ci.draw_rect(Rect2(round(sx + q.x - fw / 2.0), round(gy + q.y), fw, fh), c)


func _shadow(ci: CanvasItem, sx: float, gy: float, w: float) -> void:
	ci.draw_rect(Rect2(round(sx - w * 0.6), round(gy - 1), round(w * 1.2), maxf(1.0, round(w / 8.0))), Color(0, 0, 0, 0.35))


# ------------------------------------------------------------------- objects

const WARN_FAR := 2400.0    # obstacles start flashing a warning at this range...
const WARN_NEAR := 300.0    # ...the sign is at full size here...
const WARN_GONE := 160.0    # ...and has faded out by here


## Flashing rounded-triangle "!" over a rock / wreck in the road. Starts smaller than the obstacle and grows
## past it as you close in, so the size itself tells you how near it is.
func _hazard_sign(ci: CanvasItem, sx: float, cy: float, ow: float, fwd: float, t: float) -> void:
	if (int(t * 6.0) & 1) == 0:
		return
	var u := clampf((WARN_FAR - fwd) / (WARN_FAR - WARN_NEAR), 0.0, 1.0)
	var side := maxf(6.0, ow * lerpf(0.6, 1.8, u))
	var al := clampf((fwd - WARN_GONE) / (WARN_NEAR - WARN_GONE), 0.0, 1.0)
	var rho := side / (2.0 * sqrt(3.0))    # inradius; the triangle is built around its incentre
	var cr := rho * 0.35                   # corner rounding
	var c := Vector2(round(sx), round(cy + rho * 0.5))
	var pts := PackedVector2Array()
	for deg in [-90.0, 30.0, 150.0]:
		var vc: Vector2 = c + Vector2.from_angle(deg_to_rad(deg)) * 2.0 * (rho - cr)
		for j in 5:
			pts.append(vc + Vector2.from_angle(deg_to_rad(deg - 60.0 + 30.0 * j)) * cr)
	ci.draw_colored_polygon(pts, Color(1.0, 0.82, 0.12, 0.9 * al))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0.35, 0.08, 0.02, al), 1.0)
	if side >= 9.0:
		var bw := maxf(1.0, round(side * 0.1))
		var ink := Color(0.15, 0.04, 0.0, al)
		ci.draw_rect(Rect2(round(c.x - bw / 2.0), round(c.y - rho * 1.15), bw, maxf(2.0, round(rho * 1.25))), ink)
		ci.draw_rect(Rect2(round(c.x - bw / 2.0), round(c.y + rho * 0.35), bw, bw), ink)


func draw_objects(ci: CanvasItem, show_player: bool) -> void:
	var R: Dictionary = rc.R
	var P: Dictionary = rc.P
	var trk := rc.trk
	var cam: Dictionary = rc.cam
	var cdx := cos(cam.a)
	var cdy := sin(cam.a)
	var crx := -cdy
	var cry := cdx
	var anim_t := rc.anim_t

	# speed streaks while boosting
	if R.phase == "race" and (P.ramOn or P.abOn or P.burstT > 0.0 or P.speed > Race.MAXV * 1.3):
		var sc := Color(1.0, 170 / 255.0, 60 / 255.0, 0.55) if P.ramOn else Color(150 / 255.0, 220 / 255.0, 1.0, 0.5)
		for i in 16:
			var x := (i * 71 + 13) % W
			var y := HORIZON + fmod(anim_t * 460.0 + i * 53, H - HORIZON)
			ci.draw_rect(Rect2(x, floorf(y), 1, 8), sc)

	# warp lines radiate from the vanishing point as the FOV pushes out
	if rc.fov_k > 0.12 and R.phase == "race":
		var fk: float = rc.fov_k
		var vp := Vector2(W / 2.0, HORIZON + 24.0)
		for i in 28:
			var ang := float(i) * TAU / 28.0 + sin(i * 12.9) * 0.09
			var u := fposmod(anim_t * (2.4 + 0.5 * (i % 3)) + i * 0.37, 1.0)
			var r0 := 26.0 + u * u * 150.0
			var r1 := r0 + 6.0 + fk * 34.0 * u
			var dir := Vector2(cos(ang), sin(ang) * 0.62)
			var al := (0.10 + 0.38 * fk * u) * (0.5 if dir.y < 0.0 else 1.0)
			ci.draw_line(vp + dir * r0, vp + dir * r1, Color(1.0, 1.0, 1.0, al), 1.0)

	# slipstream wind: streaks rush past the pod, thicker as the draft fills
	if P.draft > 0.15 and R.phase == "race":
		var wc := Color(0.8, 0.95, 1.0, 0.25 + 0.4 * P.draft)
		for i in 14:
			var side := -1.0 if i % 2 == 0 else 1.0
			var sx0 := W / 2.0 + side * (34.0 + (i * 17) % 70)
			var sy0 := 100.0 + fmod(anim_t * 380.0 + i * 41.0, 90.0)
			ci.draw_rect(Rect2(sx0, sy0, 1, 3.0 + 9.0 * P.draft), wc)
	var storm_k: float = rc.events.k
	var items: Array = []
	var add := func(x: float, y: float, kind: String, ref, max_fwd: float) -> void:
		var dx: float = x - cam.x
		var dy: float = y - cam.y
		var fwd := dx * cdx + dy * cdy
		if fwd < 6.0 or fwd > max_fwd * (1.0 - 0.55 * storm_k):
			return
		var lat := dx * crx + dy * cry
		if absf(lat * focal / fwd) > W:
			return
		items.append({"fwd": fwd, "lat": lat, "kind": kind, "ref": ref})
	for o in trk.decor:
		add.call(o.x, o.y, "prop", o, 5200.0)
	for o in trk.obst:
		add.call(o.x, o.y, "obst", o, 4200.0)
	for m in trk.movers:
		var mp := trk.mover_xy(m, R.time)
		add.call(mp.x, mp.y, "mover", m, 7000.0)
	for m in rc.mines:
		add.call(m.x, m.y, "mine", m, 1800.0)
	for b in rc.bots:
		if not b.out:
			var q := rc.bot_pos(b)
			add.call(q.x, q.y, "bot", b, 6000.0)
	for r in rc.remotes:
		if not r.crashed:
			add.call(r.x, r.y, "remote", r, 6000.0)
	for b in rc.booms:
		add.call(b.x, b.y, "boom", b, 3000.0)
	if rc.ghost.on and (R.phase == "race" or R.phase == "countdown"):
		add.call(rc.ghost.x, rc.ghost.y, "ghost", rc.ghost, 5000.0)
	for w in rc.events.warns:
		add.call(w.x, w.y, "warn", w, 4200.0)
	if show_player and P.crashT <= 0.0 and R.phase != "wrecked" and R.phase != "eliminated":
		add.call(P.x, P.y, "player", P, 6000.0)
	items.sort_custom(func(a, b): return a.fwd > b.fwd)

	var frame := int(anim_t * 14.0) & 1
	var hazard_signs: Array = []
	for it in items:
		var k: float = focal / it.fwd
		var sx: float = W / 2.0 + it.lat * k
		var gy: float = HORIZON + rc.cam_h * k
		var o = it.ref
		var kind: String = it.kind
		if kind == "boom":
			_draw_boom(ci, sx, gy, o.t, clampf(k / 2.0, 0.1, 2.0), o.big)
		elif kind == "prop" or kind == "obst":
			_draw_sprite_scaled(ci, Sprites.prop(o.shape, o.pal), sx, gy, o.w * k, 14.0 / 24.0 * o.ah, 0.0)
			if kind == "obst" and it.fwd < WARN_FAR and it.fwd > WARN_GONE and R.phase == "race":
				hazard_signs.append([sx, gy - o.w * k * 0.3, o.w * k, it.fwd])
		elif kind == "mover":
			var pal: Dictionary = o.pal.duplicate()
			if (int(anim_t * 3.0) & 1) != 0:
				pal["r"] = "#ff2020"    # warning lights flash
			var mw: float = o.w * k
			_draw_sprite_scaled(ci, Sprites.prop("crawler", pal), sx, gy, mw, 14.0 / 24.0 * 1.5, 0.0)
			if it.fwd < 3200.0 and mw > 6.0:
				Gfx.txt(ci, o.name, round(sx - Gfx.txt_w(o.name, 1) / 2.0), round(gy - mw * 14.0 / 24.0 * 1.5 - 9.0), 1, "#ff6060")
		elif kind == "mine":
			_draw_sprite_scaled(ci, _mine_a if (int(anim_t * 4.0) & 1) != 0 else _mine_b, sx, gy, 10.0 * k, 14.0 / 24.0, 0.0)
		elif kind == "bot":
			var v: Dictionary = Data.VEH[o.cls]
			var w: float = VEH_SCALE * v.wmul * k
			if o.crashT > 0.0:
				_draw_boom(ci, sx, gy, 1.5 - minf(1.4, o.crashT * 0.5), clampf(k / 2.0, 0.1, 2.0), true)
				continue
			_shadow(ci, sx, gy, w)
			if not (o.inv > 0.0 and (int(anim_t * 24.0) & 1) != 0):
				_draw_pod(ci, o.spr[frame][VehicleModels.yaw_index(o.yaw)], sx, gy, w)
			if o.ramT > 0.0:
				_draw_flames(ci, sx, gy, w, "#ffe880", "#ff7a30", frame, true, _nozzles(o.cls, o.yaw, w))
			elif o.abT > 0.0 or o.get("burstT", 0.0) > 0.0:
				_draw_flames(ci, sx, gy, w, "#c8f0ff", "#60b8ff", frame, false, _nozzles(o.cls, o.yaw, w))
			if o.shield > 0.0:
				_draw_shield_ring(ci, sx, gy, w)
			if o.get("drifting", false):
				var dc := Color("#ffd040") if o.driftT > 0.8 else Color.WHITE
				for di in 3:
					ci.draw_rect(Rect2(round(sx - w * 0.5 + di * w * 0.5), round(gy - 1), 1, 2), dc)
			if o.ion > 0.0:
				ci.draw_rect(Rect2(round(sx + sin(anim_t * 30.0) * w * 0.3), round(gy - w * 0.4), 1, 2), Color("#60d0ff"))
			if o.hp < 40.0 or o.heat > 80.0:
				_draw_smoke(ci, sx, gy, w)
			if o.rival and it.fwd < 900.0 and it.fwd > 20.0:    # rivals are tagged from afar; hunters flash
				var rn: String = ("!" if o.hunt else "*") + o.name
				var rcol := "#ff4040" if (o.hunt and (int(anim_t * 5.0) & 1) != 0) else "#ff9a40"
				Gfx.txt(ci, rn, round(sx - Gfx.txt_w(rn, 1) / 2.0), round(gy - w * 0.5 - 8.0), 1, rcol)
			elif it.fwd < 260.0 and it.fwd > 20.0:
				var nm: String = o.name + " " + o.T.tag
				Gfx.txt(ci, nm, round(sx - Gfx.txt_w(nm, 1) / 2.0), round(gy - w * 0.5 - 8.0), 1, "#ffffff")
		elif kind == "ghost":
			var gv: Dictionary = Data.VEH[o.veh]
			var gw: float = VEH_SCALE * gv.wmul * k
			var gspr := VehicleModels.frames(o.veh, gv.cb[0], gv.cb[1], gv.cb[2])
			var gdw := maxf(4.0, round(gw * 2.3))
			var gdh := round(gdw * VehicleModels.CELL_H / VehicleModels.CELL_W)
			ci.draw_texture_rect(gspr[frame][VehicleModels.yaw_index(o.yaw)], Rect2(round(sx - gdw / 2.0), round(gy - gdh + gdh * 0.08), gdw, gdh),
				false, Color(0.55, 0.9, 1.0, 0.42))
			if it.fwd < 700.0 and it.fwd > 20.0:
				Gfx.txt(ci, "GHOST", round(sx - Gfx.txt_w("GHOST", 1) / 2.0), round(gy - gw * 0.5 - 8.0), 1, "#80e0ff")
		elif kind == "warn":
			var wa: float = clampf(o.t / o.delay, 0.0, 1.0)
			var wr: float = (46.0 if o.kind == "rock" else 120.0) * k
			var wcol := Color(1.0, 0.25, 0.15, 0.35 + 0.5 * wa) if o.kind == "rock" else Color(0.75, 0.5, 1.0, 0.35 + 0.5 * wa)
			var wsc := 1.0 + (1.0 - wa) * 0.7
			var rw := maxf(4.0, wr * wsc)
			var rh := maxf(2.0, rw * 0.32)
			ci.draw_rect(Rect2(round(sx - rw), round(gy - rh), rw * 2.0, 1), wcol)
			ci.draw_rect(Rect2(round(sx - rw), round(gy + rh), rw * 2.0, 1), wcol)
			ci.draw_rect(Rect2(round(sx - rw), round(gy - rh), 1, rh * 2.0 + 1), wcol)
			ci.draw_rect(Rect2(round(sx + rw), round(gy - rh), 1, rh * 2.0 + 1), wcol)
			if (int(anim_t * 8.0) & 1) != 0:
				Gfx.txt(ci, "!", round(sx - 1.0), round(gy - rh - 8.0 - 12.0 * (1.0 - wa)), 1, "#ffffff")
		elif kind == "remote":
			var rv: Dictionary = Data.VEH[o.cls]
			var rw: float = VEH_SCALE * rv.wmul * k
			_shadow(ci, sx, gy, rw)
			_draw_pod(ci, o.spr[frame][VehicleModels.yaw_index(o.yaw)], sx, gy, rw)
			var rn := _nozzles(o.cls, o.yaw, rw)
			if o.ramOn:
				_draw_flames(ci, sx, gy, rw, "#ffe880", "#ff7a30", frame, true, rn)
			elif o.abOn:
				_draw_flames(ci, sx, gy, rw, "#c8f0ff", "#60b8ff", frame, false, rn)
			if o.shield:
				_draw_shield_ring(ci, sx, gy, rw)
			if it.fwd < 600.0 and it.fwd > 20.0:
				Gfx.txt(ci, o.name, round(sx - Gfx.txt_w(o.name, 1) / 2.0), round(gy - rw * 0.5 - 12.0), 1, "#80ffa0")
		elif kind == "player":
			var v: Dictionary = Data.VEH[P.veh]
			var w: float = VEH_SCALE * v.wmul * k
			var pcb: Array = Cosmetics.cb(P.veh)
			var spr := VehicleModels.frames(P.veh, pcb[0], pcb[1], pcb[2])
			var noz := _nozzles(P.veh, P.yaw, w)
			_shadow(ci, sx, gy, w)
			var bob := 1.0 if (P.speed > 50.0 and (int(anim_t * 30.0) & 1) != 0) else 0.0
			if P.hopT > 0.0:    # hop into the drift
				bob += sin(PI * (1.0 - P.hopT / 0.26)) * 9.0 * clampf(k / 1.4, 0.5, 2.0)
			var blink: bool = (P.inv > 0.0 or P.hurtT > 0.0) and (int(anim_t * 24.0) & 1) != 0
			if not blink:
				_draw_pod(ci, spr[frame][VehicleModels.yaw_index(P.yaw)], sx, gy - bob, w)
			if P.ramOn:
				var rf: Array = Cosmetics.flame(["#ffe880", "#ff6a20"])
				_draw_flames(ci, sx, gy - bob, w, rf[0], rf[1], frame, true, noz)
			elif P.abOn or P.burstT > 0.0:
				var af: Array = Cosmetics.flame(["#c8f0ff", "#60b8ff"])
				_draw_flames(ci, sx, gy - bob, w, af[0], af[1], frame, false, noz)
			if P.shield > 0.0:
				_draw_shield_ring(ci, sx, gy - bob, w)
			if P.ion > 0.0 and (int(anim_t * 20.0) & 1) != 0:
				for i in 3:
					ci.draw_rect(Rect2(round(sx - w * 0.4 + fmod(anim_t * 97.0 + i * 31, w * 0.8)), round(gy - w * 0.4 - i * 2), 1, 2), Color("#60d0ff"))
			if P.heat > 80.0 and (int(anim_t * 10.0) & 1) != 0:
				_draw_smoke(ci, sx, gy, w)
			if P.hp < 30.0:
				_draw_smoke(ci, sx, gy, w)
			if P.drifting:
				var dc := Color("#ffd040") if P.charge > 0.35 else Color.WHITE
				for i in 3:
					ci.draw_rect(Rect2(round(sx - w * 0.5 + i * w * 0.5), round(gy - 1), 1, 2), dc)
	for hs in hazard_signs:    # drawn over everything so nearer objects can't hide them
		_hazard_sign(ci, hs[0], hs[1], hs[2], hs[3], anim_t)
	for s in rc.sparks:    # sparks in world space
		var dx: float = s.x - cam.x
		var dy: float = s.y - cam.y
		var fwd := dx * cdx + dy * cdy
		if fwd < 8.0:
			continue
		var k := focal / fwd
		var sz := 2.0 if s.col != "" else 1.0
		ci.draw_rect(Rect2(round(W / 2.0 + (dx * crx + dy * cry) * k), round(HORIZON + rc.cam_h * k - 3.0), sz, sz), Color(s.col if s.col != "" else "#ffe060"))
	for tr in rc.trails:    # boost trail particles
		var tdx: float = tr.x - cam.x
		var tdy: float = tr.y - cam.y
		var tf := tdx * cdx + tdy * cdy
		if tf < 8.0:
			continue
		var tk := focal / tf
		var ta: float = tr.t / tr.t0
		var tc := Color(tr.col)
		tc.a = ta
		var tz := maxf(1.0, round(3.5 * tk * (0.4 + ta)))
		ci.draw_rect(Rect2(round(W / 2.0 + (tdx * crx + tdy * cry) * tk), round(HORIZON + rc.cam_h * tk - 4.0 * tk - 1.0), tz, tz), tc)

	# storms: a wash of haze, a heavier band over the horizon, and wind-driven streaks over everything
	var sk: float = rc.events.k
	if sk > 0.02:
		var fc := Gfx.C(trk.planet.fog)
		ci.draw_rect(Rect2(0, 0, W, H), Color(fc.r, fc.g, fc.b, 0.30 * sk))
		ci.draw_rect(Rect2(0, HORIZON - 40, W, 70), Color(fc.r, fc.g, fc.b, 0.40 * sk))
		var wd: float = rc.events.wind_dir
		for i in 70:
			var yy := fposmod(i * 37.0 + anim_t * 40.0, H)
			var xx := fposmod(i * 53.0 + anim_t * wd * (320.0 + (i % 5) * 70.0), W + 60.0) - 30.0
			ci.draw_rect(Rect2(xx, yy, 6 + (i % 4) * 4, 1 + (1 if i % 3 == 0 else 0)), Color(minf(fc.r + 0.15, 1.0), minf(fc.g + 0.15, 1.0), minf(fc.b + 0.15, 1.0), 0.6 * sk))
	if rc.events.state == "active" and rc.events.kind == "ionstorm":
		ci.draw_rect(Rect2(0, 0, W, H), Color(0.35, 0.18, 0.6, 0.08 + 0.04 * sin(anim_t * 9.0)))
