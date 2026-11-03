## Procedural track: path generation, hazards, props, and spatial queries.
## The pixels themselves are painted on the GPU by TrackBaker; this class owns the data and collision.
##   1. a star-shaped polygon with filleted corners => never self-intersects
##   2. validated for curvature, proximity and length, resampled evenly
##   3. hazards / caves / fume zones / obstacles / shortcuts placed per planet
class_name Track
extends RefCounted

const T := 8192          # world size in units
const TEXEL := 2.0       # world units per baked texel (texture is T/TEXEL square)
const S := 2.0           # generation scale: longer straights and wider bends than the reference
const VERGE := 130.0     # off-road margin either side of the road (no slowdown)
const WALL_W := 70.0     # rock wall band beyond the verge
const EDGE_AMP := 14.0   # how much the road edge wanders
const DS := 8.0          # path sample spacing
const CELL := 128        # spatial-grid cell size
const GRID := T / CELL
const SHORTCUT_W := 40.0 # half-width of a shortcut lane

var planet: Dictionary
var planet_key: String
var seed_: int
var attempts := 0
var fallback := false

var pts: PackedVector2Array
var px: PackedFloat64Array
var py: PackedFloat64Array
var ang: PackedFloat64Array
var cos_a: PackedFloat64Array
var sin_a: PackedFloat64Array
var curv: PackedFloat64Array
var k_ahead: PackedFloat64Array
var n := 0
var dsa := 0.0
var length := 0.0
var width := 0.0
var half := 0.0

var hz_type: PackedByteArray
var hz_side: PackedInt32Array
var hz_edge: PackedByteArray
var fume: PackedByteArray
var cave: PackedByteArray
var hazards: Array = []
var zones: Array = []
var shortcuts: Array = []
var splits: Array = []    # alternate routes: {i0, i1, s0, s1, D} - two roads at +/-D from the spine
var movers: Array = []    # crawlers sliding across the road
var obst: Array = []
var decor: Array = []
var noise1: PackedFloat32Array
var noise2: PackedFloat32Array

var tex: Texture2D    # baked ground texture (set by Main after baking)
var mm: Dictionary = {}
var mini_pts: PackedVector2Array
var mini_shortcuts: Array = []
var mini_branches: Array = []

var _cells: Array = []
var _reach := 0.0
var edge_k1 := 0.0
var edge_k2 := 0.0


# ---------------------------------------------------------------- generation

static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func _build_spline(ctrl: Array) -> Dictionary:
	var m := ctrl.size()
	var dense := PackedVector2Array()
	for i in m:
		for k in 40:
			dense.append(_catmull(ctrl[(i - 1 + m) % m], ctrl[i], ctrl[(i + 1) % m], ctrl[(i + 2) % m], k / 40.0))
	return _resample(dense)


## Closed polyline -> evenly spaced samples.
static func _resample(dense: PackedVector2Array) -> Dictionary:
	var m := dense.size()
	var cum := PackedFloat64Array()
	cum.resize(m + 1)
	var total := 0.0
	for i in range(1, m + 1):
		total += dense[i - 1].distance_to(dense[i % m])
		cum[i] = total
	var cnt := int(floor(total / DS))
	var step := total / cnt
	var out := PackedVector2Array()
	var j := 0
	for i in cnt:
		var target := i * step
		while cum[j + 1] < target:
			j += 1
		var a := dense[j]
		var b := dense[(j + 1) % m]
		var den := cum[j + 1] - cum[j]
		if den == 0.0:
			den = 1.0
		out.append(a + (b - a) * ((target - cum[j]) / den))
	return {"pts": out, "n": cnt, "dsa": step, "len": total}


## A random star-shaped polygon with filleted corners: long straights joined by wide bends.
## Returns an empty array when the shape is unusable.
static func _gen_poly_dense(pl: Dictionary, rng: Util.Rng) -> PackedVector2Array:
	var g: Dictionary = pl.gen
	var nv: int = int(g.verts[0]) + int(rng.next() * (g.verts[1] - g.verts[0] + 1))
	var base := rng.next() * TAU
	var stretch: float = g.stretch[0] + rng.next() * (g.stretch[1] - g.stretch[0])
	var rot := rng.next() * TAU
	var v: Array = []
	for i in nv:
		var th := base + (i + (rng.next() - 0.5) * 0.6) / nv * TAU
		var r: float
		if rng.next() < g.dents:
			r = 0.28 + 0.34 * rng.next()    # dents make S-bends and hairpins
		else:
			r = 0.74 + 0.26 * rng.next()
		var x := cos(th) * r * stretch
		var y := sin(th) * r
		v.append(Vector2(x * cos(rot) - y * sin(rot), x * sin(rot) + y * cos(rot)))
	var x0 := 1e9
	var x1 := -1e9
	var y0 := 1e9
	var y1 := -1e9
	for p in v:
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var margin := 230.0 * S
	var sc := minf((T - 2 * margin) / (x1 - x0), (T - 2 * margin) / (y1 - y0))
	var cx := (x0 + x1) / 2.0
	var cy := (y0 + y1) / 2.0
	for i in nv:
		v[i] = Vector2(T / 2.0 + (v[i].x - cx) * sc, T / 2.0 + (v[i].y - cy) * sc)
	var want: float = (g.fillet[0] + rng.next() * (g.fillet[1] - g.fillet[0])) * S
	var dense := PackedVector2Array()
	var t1: Array = []
	var t2: Array = []
	var cc: Array = []
	var rad: Array = []
	for i in nv:
		var a: Vector2 = v[(i - 1 + nv) % nv]
		var b: Vector2 = v[i]
		var c: Vector2 = v[(i + 1) % nv]
		var l1 := a.distance_to(b)
		var l2 := c.distance_to(b)
		var u1 := (a - b) / l1
		var u2 := (c - b) / l2
		var al := acos(clampf(u1.dot(u2), -1.0, 1.0))
		if al < 0.35 or al > 3.1:
			return PackedVector2Array()    # spikes and almost-straight vertices
		var tn := tan(al / 2.0)
		var rr := want
		var d := rr / tn
		var maxd := 0.47 * minf(l1, l2)
		if d > maxd:
			d = maxd
			rr = d * tn
		if rr < 285.0 * S:
			return PackedVector2Array()    # bend would be too tight at speed
		var bis := u1 + u2
		var bl := bis.length()
		if bl == 0.0:
			bl = 1.0
		var hd := rr / sin(al / 2.0)
		t1.append(b + u1 * d)
		t2.append(b + u2 * d)
		cc.append(b + bis / bl * hd)
		rad.append(rr)
	for i in nv:
		var a1 := atan2(t1[i].y - cc[i].y, t1[i].x - cc[i].x)
		var a2 := atan2(t2[i].y - cc[i].y, t2[i].x - cc[i].x)
		var sweep := Util.angdiff(a2, a1)
		var steps := maxi(4, int(ceil(absf(sweep) * rad[i] / 6.0)))
		for k in steps + 1:
			var a := a1 + sweep * k / steps
			dense.append(cc[i] + Vector2(cos(a), sin(a)) * rad[i])
		var nx: Vector2 = t1[(i + 1) % nv]
		var ln: float = (nx - t2[i]).length()
		var n2 := maxi(1, int(ceil(ln / 6.0)))
		for k in range(1, n2):
			dense.append(t2[i] + (nx - t2[i]) * (float(k) / n2))
	return dense


static func _path_angles(p: PackedVector2Array) -> PackedFloat64Array:
	var m := p.size()
	var out := PackedFloat64Array()
	out.resize(m)
	for i in m:
		var a := p[(i + 1) % m]
		var b := p[(i - 1 + m) % m]
		out[i] = atan2(a.y - b.y, a.x - b.x)
	return out


static func _validate(res: Dictionary, width_: float) -> bool:
	var p: PackedVector2Array = res.pts
	var m: int = res.n
	var step: float = res.dsa
	var total: float = res.len
	if total < 9500.0 * S or total > 21000.0 * S:
		return false
	var an := _path_angles(p)
	var kmax := 1.0 / maxf(width_ * 1.2, 270.0 * S)
	for i in m:
		var k := absf(Util.angdiff(an[(i + 3) % m], an[(i - 3 + m) % m])) / (6.0 * step)
		if k > kmax:    # wide sweeping bends only
			return false
	var gap := width_ * 1.75
	var gap2 := gap * gap
	var skip := int(ceil(m * 0.12))
	var grid := {}
	for i in range(0, m, 2):
		var key := int(floor(p[i].x / gap)) * 100000 + int(floor(p[i].y / gap))
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		grid[key].append(i)
	for i in range(0, m, 2):    # separate sections must not run too close
		var cx := int(floor(p[i].x / gap))
		var cy := int(floor(p[i].y / gap))
		for gx in range(cx - 1, cx + 2):
			for gy in range(cy - 1, cy + 2):
				var list = grid.get(gx * 100000 + gy)
				if list == null:
					continue
				for j in list:
					if j <= i:
						continue
					if mini(j - i, m - (j - i)) < skip:
						continue
					if p[i].distance_squared_to(p[j]) < gap2:
						return false
	return true


static func _mark(o: PackedByteArray, m: int, i0: int, ln: int, pad: int, v: int = 1) -> void:
	for k in range(-pad, ln + pad):
		o[(((i0 + k) % m) + m) % m] = v


static func _free(o: PackedByteArray, m: int, i0: int, ln: int, pad: int) -> bool:
	for k in range(-pad, ln + pad):
		if o[(((i0 + k) % m) + m) % m] != 0:
			return false
	return true


func _place_hazards(pl: Dictionary, rng: Util.Rng, scale: float) -> void:
	var occ := PackedByteArray()
	occ.resize(n)
	var occ_f := PackedByteArray()
	occ_f.resize(n)
	var occ_c := PackedByteArray()
	occ_c.resize(n)
	hz_type.resize(n)
	hz_side.resize(n)
	fume.resize(n)
	cave.resize(n)
	_mark(occ, n, -60, 220, 0)    # keep the start line clear
	_mark(occ_f, n, -60, 220, 0)
	_mark(occ_c, n, -60, 220, 0)
	for spec in pl.gen.haz:
		for c in maxi(1, int(round(spec.count * scale))):
			for tries in 60:
				var i0 := int(rng.next() * n)
				var ln := int(round((spec.len[0] + rng.next() * (spec.len[1] - spec.len[0])) * 1.7 * S))
				if not _free(occ, n, i0, ln, 22):
					continue
				_mark(occ, n, i0, ln, 0)
				var side := 0
				if spec.side == "half":
					side = -1 if rng.next() < 0.5 else 1
				for k in ln:
					hz_type[(i0 + k) % n] = spec.type
					hz_side[(i0 + k) % n] = side
				hazards.append({"type": spec.type, "i0": i0, "len": ln, "side": side})
				break
	for c in int(round(pl.gen.fume * scale)):
		for tries in 60:
			var i0 := int(rng.next() * n)
			var ln := int(round((45 + int(rng.next() * 25)) * 1.7 * S))
			if not _free(occ_f, n, i0, ln, 20):
				continue
			_mark(occ_f, n, i0, ln, 0)
			for k in ln:
				fume[(i0 + k) % n] = 1
			zones.append({"kind": "fume", "i0": i0, "len": ln})
			break
	for c in int(round(pl.gen.cave * scale)):
		for tries in 60:
			var i0 := int(rng.next() * n)
			var ln := int(round((55 + int(rng.next() * 35)) * 1.7 * S))
			if not _free(occ_c, n, i0, ln, 20):
				continue
			_mark(occ_c, n, i0, ln, 0)
			for k in ln:
				cave[(i0 + k) % n] = 1
			zones.append({"kind": "cave", "i0": i0, "len": ln})
			break


static func _make_noise(rng: Util.Rng) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(64 * 64)
	for i in g.size():
		g[i] = rng.next()
	return g


static func generate(planet_key_: String, seed_in: int) -> Track:
	var trk := Track.new()
	var pl: Dictionary = Data.PLANETS[planet_key_]
	var rng := Util.Rng.new(seed_in)
	trk.planet = pl
	trk.planet_key = planet_key_
	trk.seed_ = seed_in

	# 1-2: path
	var res := {}
	var tries := 0
	while tries < 400:
		var dense := _gen_poly_dense(pl, rng)
		if dense.size() > 0:
			var r := _resample(dense)
			if _validate(r, pl.width):
				res = r
				break
		tries += 1
	trk.attempts = tries
	if res.is_empty():    # safe fallback: a plain oval
		trk.fallback = true
		var c: Array = []
		for i in 20:
			var th := i / 20.0 * TAU
			c.append(Vector2(Track.T / 2.0 + cos(th) * 760.0 * S, Track.T / 2.0 + sin(th) * 560.0 * S))
		res = _build_spline(c)

	trk.pts = res.pts
	trk.n = res.n
	trk.dsa = res.dsa
	trk.length = res.len
	trk.width = pl.width
	trk.half = trk.width / 2.0
	var n_: int = trk.n
	trk.ang = _path_angles(trk.pts)
	trk.px.resize(n_)
	trk.py.resize(n_)
	trk.cos_a.resize(n_)
	trk.sin_a.resize(n_)
	for i in n_:
		trk.cos_a[i] = cos(trk.ang[i])
		trk.sin_a[i] = sin(trk.ang[i])
		trk.px[i] = trk.pts[i].x
		trk.py[i] = trk.pts[i].y
	trk.curv.resize(n_)
	for i in n_:
		trk.curv[i] = absf(Util.angdiff(trk.ang[(i + 3) % n_], trk.ang[(i - 3 + n_) % n_])) / (6.0 * trk.dsa)
	trk.k_ahead.resize(n_)
	for i in n_:
		var m := 0.0
		for j in 40:
			m = maxf(m, trk.curv[(i + j) % n_])
		trk.k_ahead[i] = m
	var len_scale: float = trk.length / 5000.0
	trk.edge_k1 = TAU * round(trk.length / 300.0) / trk.length
	trk.edge_k2 = TAU * round(trk.length / 110.0) / trk.length
	trk._place_hazards(pl, rng, len_scale * 0.6)
	trk.hz_edge.resize(n_)
	for i in n_:
		var t: int = trk.hz_type[i]
		if t != 0 and (trk.hz_type[(i + 2) % n_] != t or trk.hz_type[(i - 2 + n_) % n_] != t):
			trk.hz_edge[i] = 1
	trk._build_grid()

	# 4b: noise lattices consumed by the ground painter (drawn from the same stream as the reference)
	trk.noise1 = _make_noise(rng)
	trk.noise2 = _make_noise(rng)

	trk._place_splits(pl, rng)

	# 4c: shortcuts. A chord across a loop of the track, through open ground.
	for c in pl.gen.shortcuts:
		for tr in 400:
			var i := int(rng.next() * n_)
			var j := (i + 40 + int(rng.next() * n_ * 0.4)) % n_
			if trk.hz_type[i] != 0 or trk.hz_type[j] != 0:
				continue
			var a := Vector2(trk.px[i], trk.py[i])
			var b := Vector2(trk.px[j], trk.py[j])
			var dist := a.distance_to(b)
			var path_len := float(((j - i) % n_ + n_) % n_) * trk.dsa
			if dist < 260.0 or path_len < 550.0 or path_len > 3600.0 or path_len / dist < 1.55:
				continue
			if absi(i - n_) < 70 or absi(j - n_) < 70 or i < 70 or j < 70:    # keep the start line area clean
				continue
			var ok := true
			var d := 70.0
			while d < dist - 70.0 and ok:
				var q := a + (b - a) * (d / dist)
				if trk.near_road(float(int(q.x)), float(int(q.y))):
					ok = false
				d += 10.0
			if not ok:
				continue
			trk.shortcuts.append({"i": i, "j": j, "a": a, "b": b, "dist": dist, "pathLen": path_len})
			break

	# 5: obstacles + scenery props
	var ob: Dictionary = pl.gen.obst
	var shape: String = Data.PROP_SHAPE.get(ob.kind, ob.kind)
	var n_on := int(round(ob.on * len_scale * 0.4))
	var n_decor := int(round(ob.decor * len_scale * 1.5))
	for c in n_on:
		var s0: float = 70.0 * trk.dsa + (trk.length - 100.0 * trk.dsa) * (c + 0.2 + 0.6 * rng.next()) / n_on
		var i := int(floor(s0 / trk.dsa)) % n_
		if trk.hz_type[i] != 0 or trk.in_split(i):
			continue
		var lat: float = (1 if c % 2 != 0 else -1) * trk.half * (0.3 + 0.3 * rng.next())
		var o := trk.place(s0, lat)
		o.merge({"kind": ob.kind, "shape": shape, "pal": pl.props[ob.kind], "w": (26.0 if ob.kind == "wreck" else 15.0) * 2.0, "ah": 1.0, "r": float(Data.PROP_RADIUS[ob.kind]) * 2.0})
		trk.obst.append(o)
	for sp in trk.splits:    # the left-hand alternate road is an obstacle field
		for k in 8:
			var sk: float = sp.s0 + (sp.s1 - sp.s0) * (0.3 + 0.4 * (k + rng.next() * 0.6) / 8.0)
			var latk: float = -sp.D + (rng.next() - 0.5) * trk.half * 1.1
			var ok2 := trk.place(sk, latk)
			ok2.merge({"kind": ob.kind, "shape": shape, "pal": pl.props[ob.kind], "w": (26.0 if ob.kind == "wreck" else 15.0) * 2.0, "ah": 1.0, "r": float(Data.PROP_RADIUS[ob.kind]) * 2.0})
			trk.obst.append(ok2)
	for c in n_decor:
		for tr in 12:
			var s0 := rng.next() * trk.length
			var side := -1 if rng.next() < 0.5 else 1
			var lat: float = side * (trk.half + VERGE + WALL_W + 40.0 + rng.next() * 1600.0)
			var q := trk.place(s0, lat)
			if q.x < 80 or q.y < 80 or q.x > T - 80 or q.y > T - 80 or trk.near_road(float(int(q.x)), float(int(q.y))):
				continue
			var dk: Dictionary = Util.pick(rng, pl.decorKinds)
			var pal = dk.get("pal")
			if pal == null:
				pal = pl.props.get(dk.kind, Data.PAL_WRECK)
			q.merge({"kind": dk.kind, "shape": Data.PROP_SHAPE.get(dk.kind, dk.kind), "pal": pal, "w": dk.w * 0.75, "ah": dk.ah, "r": 0.0})
			trk.decor.append(q)
			break

	trk._place_movers(rng, maxi(1, int(round(len_scale * 0.45))))
	trk._build_minimap()
	return trk


## Lateral offset of the two alternate roads from the spine at track distance sm (0 outside a split).
func branch_off(sm: float) -> float:
	var o := 0.0
	for sp in splits:
		if sm > sp.s0 and sm < sp.s1:
			var t: float = (sm - sp.s0) / (sp.s1 - sp.s0)
			var u := clampf(minf(t, 1.0 - t) / 0.3, 0.0, 1.0)
			o = maxf(o, sp.D * u * u * (3.0 - 2.0 * u))
	return o


func in_split(i: int) -> bool:
	for sp in splits:
		if i >= sp.i0 - 20 and i <= sp.i1 + 20:
			return true
	return false


func _place_splits(pl: Dictionary, rng: Util.Rng) -> void:
	var want: int = pl.gen.get("splits", 1)
	for k in want:
		for tries in 150:
			var ln := 260 + int(rng.next() * 80)
			if n < ln + 300:
				break
			var i0 := 120 + int(rng.next() * (n - ln - 240))
			var i1 := i0 + ln
			var ok := not in_split(i0) and not in_split(i1)
			for sp in splits:
				if i0 < sp.i1 + 80 and i1 > sp.i0 - 80:
					ok = false
			if not ok:
				continue
			var kmax := 0.0
			for i in range(i0 - 10, i1 + 10):
				kmax = maxf(kmax, curv[i % n])
			if kmax > 0.0008:
				continue    # only on near-straight stretches
			var D := width + VERGE * 2.2
			for i in range(i0 - 20, i1 + 20):
				hz_type[i % n] = 0
				hz_side[i % n] = 0
				fume[i % n] = 0
				cave[i % n] = 0
			# right-hand road has the hazard (or rough gravel), left-hand road has the obstacle field
			var haz_t := 6
			if pl.gen.haz.size() > 0:
				haz_t = pl.gen.haz[0].type
			for i in range(i0 + int(ln * 0.25), i1 - int(ln * 0.25)):
				hz_type[i] = haz_t
				hz_side[i] = 1
			splits.append({"i0": i0, "i1": i1, "s0": i0 * dsa, "s1": i1 * dsa, "D": D})
			break


func _place_movers(rng: Util.Rng, count: int) -> void:
	var info: Dictionary = Data.MOVERS[planet_key]
	for c in count:
		for tries in 120:
			var i := 100 + int(rng.next() * (n - 200))
			if k_ahead[i] > 0.0004 or hz_type[i] != 0 or in_split(i):
				continue
			var clear := true
			for m in movers:
				if absi(m.i - i) < 120:
					clear = false
			if not clear:
				continue
			movers.append({"i": i, "s": i * dsa, "w": 170.0, "amp": half + 40.0, "speed": 70.0, "phase": rng.next(),
				"name": info.name, "pal": info.pal})
			break


## Current lateral position of a mover (a triangle wave across the road) at race time t.
func mover_lat(m: Dictionary, t: float) -> float:
	var u: float = m.speed * t / (4.0 * m.amp) + m.phase
	return m.amp * (absf(fposmod(u, 1.0) * 4.0 - 2.0) - 1.0)


func mover_xy(m: Dictionary, t: float) -> Vector2:
	var i: int = m.i
	var lat := mover_lat(m, t)
	return Vector2(px[i] - sin_a[i] * lat, py[i] + cos_a[i] * lat)


func place(s: float, lat: float) -> Dictionary:
	var q := (fposmod(s, length)) / dsa
	var i := int(floor(q)) % n
	return {"x": px[i] - sin_a[i] * lat, "y": py[i] + cos_a[i] * lat, "s": i * dsa, "lat": lat}


func _build_minimap() -> void:
	var size := 48
	var mx0 := 1e9
	var mx1 := -1e9
	var my0 := 1e9
	var my1 := -1e9
	for p in pts:
		mx0 = minf(mx0, p.x)
		mx1 = maxf(mx1, p.x)
		my0 = minf(my0, p.y)
		my1 = maxf(my1, p.y)
	var sc := (size - 8) / maxf(mx1 - mx0, my1 - my0)
	var off_x := (size - (mx1 - mx0) * sc) / 2.0
	var off_y := (size - (my1 - my0) * sc) / 2.0
	mm = {"MM": size, "scale": sc, "ox": mx0, "oy": my0, "offX": off_x, "offY": off_y}
	mini_pts = PackedVector2Array()
	for i in range(0, n + 1, 4):
		var p := pts[i % n]
		mini_pts.append(Vector2((p.x - mx0) * sc + off_x, (p.y - my0) * sc + off_y))
	for sp in splits:
		for sgn in [-1.0, 1.0]:
			var line := PackedVector2Array()
			for i in range(sp.i0, sp.i1 + 1, 4):
				var o: float = sgn * branch_off(i * dsa)
				var wx: float = px[i % n] - sin_a[i % n] * o
				var wy: float = py[i % n] + cos_a[i % n] * o
				line.append(Vector2((wx - mx0) * sc + off_x, (wy - my0) * sc + off_y))
			mini_branches.append(line)
	for s in shortcuts:
		mini_shortcuts.append([Vector2((px[s.i] - mx0) * sc + off_x, (py[s.i] - my0) * sc + off_y),
			Vector2((px[s.j] - mx0) * sc + off_x, (py[s.j] - my0) * sc + off_y)])


## Minimap pixel (within the 48x48 map) for a world position.
func mini_pos(x: float, y: float) -> Vector2:
	return Vector2(roundf((x - mm.ox) * mm.scale + mm.offX), roundf((y - mm.oy) * mm.scale + mm.offY))


# ------------------------------------------------------------------- queries

func _build_grid() -> void:
	_reach = ceil(half + VERGE + EDGE_AMP + 2.0)
	_cells = []
	_cells.resize(GRID * GRID)
	for k in _cells.size():
		_cells[k] = PackedInt32Array()
	for i in range(0, n, 2):
		var cx := clampi(int(px[i]) / CELL, 0, GRID - 1)
		var cy := clampi(int(py[i]) / CELL, 0, GRID - 1)
		_cells[cy * GRID + cx].append(i)


## Index of the centreline sample nearest to (x, y), or -1 if none lies within `reach` (default: the drivable band).
func nearest(x: float, y: float, reach: float = -1.0) -> int:
	if x < 0.0 or y < 0.0 or x >= T or y >= T:
		return -1
	if reach < 0.0:
		reach = _reach
	var cx := int(x) / CELL
	var cy := int(y) / CELL
	var span := int(ceil(reach / CELL))
	var best := -1
	var bd := reach * reach
	for gy in range(maxi(cy - span, 0), mini(cy + span, GRID - 1) + 1):
		for gx in range(maxi(cx - span, 0), mini(cx + span, GRID - 1) + 1):
			for i in _cells[gy * GRID + gx]:
				var dx := x - px[i]
				var dy := y - py[i]
				var d2 := dx * dx + dy * dy
				if d2 < bd:
					bd = d2
					best = i
	return best


## True within the whole road + verge + wall band (used to keep scenery and shortcuts clear of it).
func near_road(x: float, y: float) -> bool:
	if nearest(x, y, half + VERGE + WALL_W + 30.0) >= 0:
		return true
	if not splits.is_empty():
		var i := _nearest_split(x, y)
		if i >= 0:
			var lat := -(x - px[i]) * sin_a[i] + (y - py[i]) * cos_a[i]
			return absf(absf(lat) - branch_off(i * dsa)) < half + VERGE + WALL_W + 30.0
	return false


## Nearest spine sample inside a split's index range (the alternate roads lie far from the spine).
func _nearest_split(x: float, y: float) -> int:
	var best := -1
	var reach := 0.0
	for sp in splits:
		reach = maxf(reach, sp.D + half + VERGE + EDGE_AMP + 4.0)
	var bd := reach * reach
	for sp in splits:
		for i in range(sp.i0, sp.i1 + 1, 2):
			var dx := x - px[i % n]
			var dy := y - py[i % n]
			var d2 := dx * dx + dy * dy
			if d2 < bd:
				bd = d2
				best = i % n
	return best


## Lateral wander of the road edge at track distance s (periodic, so it closes at the start line).
func edge_offset(s: float) -> float:
	return EDGE_AMP * 0.5 * (sin(s * edge_k1) + sin(s * edge_k2 + 1.7))


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Collision mask: 0 wall, 1 road (incl. verge), 2 ice, 3 acid, 4 lava, 5 water, 6 rough (shortcut / gravel).
func mask_at(x: float, y: float) -> int:
	var ix := floorf(x)
	var iy := floorf(y)
	if ix < 0.0 or iy < 0.0 or ix >= T or iy >= T:
		return 0
	var i := nearest(ix, iy)
	if i < 0 and not splits.is_empty():
		i = _nearest_split(ix, iy)
	if i >= 0:
		var lat := -(ix - px[i]) * sin_a[i] + (iy - py[i]) * cos_a[i]
		var ar := absf(absf(lat) - branch_off(i * dsa)) + edge_offset(i * dsa)
		if ar <= half:
			var ht: int = hz_type[i]
			if ht != 0 and (hz_side[i] == 0 or (hz_side[i] > 0) == (lat > 0.0)):
				return ht
			return 1
		if ar <= half + VERGE:
			return 1    # the verge drives like road; only shortcuts and gravel hazards are rough
	var p := Vector2(ix, iy)
	for s in shortcuts:
		if _seg_dist(p, s.a, s.b) <= SHORTCUT_W:
			return 6
	return 0


func pos_at(s: float) -> Dictionary:
	s = fposmod(s, length)
	var u := s / dsa
	var i := int(floor(u)) % n
	var f := u - floorf(u)
	var a := pts[i]
	var b := pts[(i + 1) % n]
	return {"x": a.x + (b.x - a.x) * f, "y": a.y + (b.y - a.y) * f, "a": ang[i], "i": i}


func lane_xy(p: Dictionary, lat: float) -> Vector2:
	return Vector2(p.x - sin(p.a) * lat, p.y + cos(p.a) * lat)


func idx_of(s: float) -> int:
	return int(floor(fposmod(s, length) / dsa)) % n


## Signed distance a-b along the track, wrapped to half a lap.
func wrap_ds(a: float, b: float) -> float:
	var d := a - b
	while d > length / 2.0:
		d -= length
	while d < -length / 2.0:
		d += length
	return d
