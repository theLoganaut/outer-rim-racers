## Mid-race track events: storms (wind + whiteout), rockfall, crawler convoys and ion storms.
## They are scheduled from the track seed, so the same seed (and the daily challenge) always plays out the same way.
class_name RaceEvents
extends RefCounted

const POOL := {"hullfall": ["storm", "convoy"], "rime": ["storm", "rockfall"], "sentinel": ["ionstorm", "rockfall"],
	"lantaana": ["convoy", "rockfall"], "quarez": ["storm", "convoy"], "cinnabar": ["storm", "convoy"],
	"derven": ["ionstorm", "rockfall", "convoy"]}
const STORM_NAME := {"hullfall": "SANDSTORM", "quarez": "SANDSTORM", "rime": "BLIZZARD", "cinnabar": "SALT STORM"}
const KIND_NAME := {"rockfall": "ROCKFALL", "convoy": "CRAWLER CONVOY", "ionstorm": "ION STORM"}
const WARN_T := 3.0
const MAX_EVENTS := 3

var rc: Race
var rng: Util.Rng
var kinds: Array = []
var enabled := false
var state := "idle"    # idle | warn | active
var kind := ""
var title := ""
var t := 0.0           # seconds in the current state
var dur := 0.0
var next_at := 0.0
var count := 0
var k := 0.0           # 0..1 storm intensity (visibility, wind)
var wind := 0.0        # sideways acceleration along the track normal
var wind_dir := 1.0
var warns: Array = []  # incoming hits: {kind, x, y, s, lat, t, delay}
var _spawn := 0.0


func begin(race: Race, cfg: Dictionary) -> void:
	rc = race
	enabled = (cfg.mode == "circuit" or cfg.mode == "elim") and not cfg.has("mp_order") and not cfg.get("attract", false)
	rng = Util.Rng.new(int(cfg.seed) + 777)
	kinds = POOL.get(cfg.planetKey, ["storm"])
	if cfg.has("forceEvent"):    # dev hook: test one event kind early
		kinds = [cfg.forceEvent]
	state = "idle"
	kind = ""
	title = ""
	t = 0.0
	count = 0
	k = 0.0
	wind = 0.0
	warns = []
	next_at = 6.0 if cfg.has("forceEvent") else 22.0 + rng.next() * 12.0


## Called while the race is not live (finished, wrecked, replay): the weather clears, pending strikes are dropped.
func settle(dt: float) -> void:
	k = move_toward(k, 0.0, dt * 0.5)
	wind = 0.0
	warns = []
	if state == "warn":
		state = "idle"


func remaining() -> float:
	return maxf(0.0, dur - t)


func storm_on() -> bool:
	return k > 0.01


func update(dt: float) -> void:
	if not enabled:
		return
	var R: Dictionary = rc.R
	match state:
		"idle":
			if count < MAX_EVENTS and R.time >= next_at:
				_start_warn()
		"warn":
			t += dt
			if t >= WARN_T:
				_start_active()
		"active":
			t += dt
			_tick(dt)
			if t >= dur:
				state = "idle"
				count += 1
				next_at = R.time + 26.0 + rng.next() * 14.0
	var target := 1.0 if (state == "active" and kind == "storm" and t < dur - 2.5) else 0.0
	k = move_toward(k, target, dt * 0.5)
	wind = wind_dir * (210.0 + 110.0 * sin(R.time * 0.8)) * k if k > 0.0 else 0.0
	for i in range(warns.size() - 1, -1, -1):
		var w: Dictionary = warns[i]
		w.t += dt
		if w.t >= w.delay:
			_land(w)
			warns.remove_at(i)
	_purge(R.time)


func _purge(now: float) -> void:
	var trk := rc.trk
	for i in range(trk.obst.size() - 1, -1, -1):
		var o: Dictionary = trk.obst[i]
		if o.get("temp", false) and now > o.die:
			trk.obst.remove_at(i)
	for i in range(trk.movers.size() - 1, -1, -1):
		var m: Dictionary = trk.movers[i]
		if m.get("temp", false) and now > m.die:
			trk.movers.remove_at(i)


func _start_warn() -> void:
	var prev := kind
	kind = kinds[int(rng.next() * kinds.size())]
	if kinds.size() > 1 and kind == prev:
		kind = kinds[(kinds.find(kind) + 1) % kinds.size()]
	title = STORM_NAME.get(rc.trk.planet_key, "SANDSTORM") if kind == "storm" else KIND_NAME[kind]
	state = "warn"
	t = 0.0
	rc.set_banner("WARNING: " + title, 2.4, "#ff6040")
	rc.audio.beep(330, 0.25, "square", 0.08, 220)
	rc.audio.beep(330, 0.25, "square", 0.08, 220, 0.3)


func _start_active() -> void:
	state = "active"
	t = 0.0
	dur = 24.0 if kind == "convoy" else 18.0 + rng.next() * 8.0
	wind_dir = 1.0 if rng.next() < 0.5 else -1.0
	_spawn = 0.4
	if kind == "convoy":
		for c in 3:
			_spawn_mover()
	rc.set_banner(title + "!", 1.6, "#ffb040")


func _tick(dt: float) -> void:
	if kind == "rockfall" or kind == "ionstorm":
		_spawn -= dt
		if _spawn <= 0.0:
			_spawn = (0.85 + rng.next() * 0.7) if kind == "rockfall" else (1.5 + rng.next() * 1.0)
			_queue_hit()


## A free stretch of road ahead of the player (or of the field leader, so the front runners meet it too).
func _site(min_ahead: float, max_ahead: float) -> Dictionary:
	var trk := rc.trk
	var P: Dictionary = rc.P
	for tries in 12:
		var base: float = P.total
		if tries % 2 == 1:
			for b in rc.bots:
				if not b.out:
					base = maxf(base, b.s)
		var s: float = fposmod(base + min_ahead + rng.next() * (max_ahead - min_ahead), trk.length)
		var i := trk.idx_of(s)
		if trk.hz_type[i] != 0 or trk.in_split(i):
			continue
		var lat: float = (rng.next() * 2.0 - 1.0) * (trk.half - 40.0)
		var p := trk.place(s, lat)
		p["i"] = i
		return p
	return {}


func _queue_hit() -> void:
	var p := _site(900.0, 2400.0)
	if p.is_empty():
		return
	warns.append({"kind": "rock" if kind == "rockfall" else "ion", "x": p.x, "y": p.y, "s": p.s, "lat": p.lat, "t": 0.0,
		"delay": 1.4 if kind == "rockfall" else 1.2})
	rc.audio.beep(900, 0.05, "square", 0.04)


func _land(w: Dictionary) -> void:
	var rcv := rc
	var P: Dictionary = rcv.P
	rcv.add_boom(w.x, w.y, w.kind == "ion")
	if Vector2(P.x - w.x, P.y - w.y).length() < 700.0:
		rcv.audio.boom()
		rcv.shake = maxf(rcv.shake, 0.5)
	if w.kind == "rock":
		if Vector2(P.x - w.x, P.y - w.y).length() < 24.0 and rcv.R.phase == "race":
			rcv.damage_player(30.0, "ROCKFALL")
			rcv.shake = 1.0
		for b in rcv.bots:
			if b.out or b.crashT > 0.0 or b.inv > 0.0:
				continue
			var q := rcv.bot_pos(b)
			if Vector2(q.x - w.x, q.y - w.y).length() < 24.0 and b.shield <= 0.0:
				b.hp -= 30.0
				b.v *= 0.5
				b.inv = 0.5
				if b.hp <= 0.0:
					rcv.crash_bot(b, "rockfall")
		var trk := rcv.trk
		var pl: Dictionary = trk.planet
		var k0: String = pl.props.keys()[0]
		var o := {"x": w.x, "y": w.y, "s": w.s, "lat": w.lat, "kind": k0, "shape": Data.PROP_SHAPE.get(k0, k0), "pal": pl.props[k0],
			"w": 30.0, "ah": 1.0, "r": float(Data.PROP_RADIUS.get(k0, 6.5)) * 2.0, "temp": true, "die": rcv.R.time + 16.0}
		trk.obst.append(o)
	else:
		rcv.flash_screen("#c8a0ff", 0.25)
		if Vector2(P.x - w.x, P.y - w.y).length() < 120.0 and rcv.R.phase == "race" and P.shield <= 0.0 and P.inv <= 0.0:
			P.ion = maxf(P.ion, 2.2)
			rcv.damage_player(8.0, "ION")
			rcv.set_banner("ION STRIKE", 1.0, "#60d0ff")
		for b in rcv.bots:
			if b.out or b.crashT > 0.0:
				continue
			var q := rcv.bot_pos(b)
			if Vector2(q.x - w.x, q.y - w.y).length() < 120.0 and b.shield <= 0.0:
				b.ion = 2.2


func _spawn_mover() -> void:
	var trk := rc.trk
	var info: Dictionary = Data.MOVERS[trk.planet_key]
	for tries in 60:
		var i: int = (rc.P.idx + 120 + int(rng.next() * 500)) % trk.n
		var ahead: float = trk.wrap_ds(i * trk.dsa, rc.P.idx * trk.dsa)
		if ahead < 1500.0 or ahead > 6000.0:
			continue
		if trk.k_ahead[i] > 0.0004 or trk.hz_type[i] != 0 or trk.in_split(i):
			continue
		var clear := true
		for m in trk.movers:
			if absi(m.i - i) < 110:
				clear = false
		if not clear:
			continue
		trk.movers.append({"i": i, "s": i * trk.dsa, "w": 170.0, "amp": trk.half + 40.0, "speed": 95.0, "phase": rng.next(),
			"name": info.name, "pal": info.pal, "temp": true, "die": rc.R.time + dur + 10.0})
		return
