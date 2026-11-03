## Race simulation: player physics, bots, collisions, abilities, laps and race modes.
## Pure logic (no drawing); WorldView/Hud read its state. Units are world units and seconds.
class_name Race
extends RefCounted

const HORIZON := 72
const CAM_H := 80.0
const CAM_BACK := 115.0
const SPEED_SCALE := 1.5   # physics speed vs. the displayed KMH (display divides this back out)
const MAXV := 520.0 * SPEED_SCALE   # base top speed (units/sec)
const ICE := 2
const ACID := 3
const LAVA := 4
const WATER := 5
const ROUGH := 6

const QTE_KEYS := [Inp.AB, Inp.RAM, Inp.ABIL]    # engine-start prompts: boost, ramjet, ability
const QTE_NAMES := ["J", "K", "L"]

var trk: Track
var inp: Inp
var audio: AudioFx

## current race
var R: Dictionary = {}
var P: Dictionary = {}
var bots: Array = []
var mines: Array = []
var booms: Array = []
var sparks: Array = []

var anim_t := 0.0
var cam_a := 0.0
var cam := {"x": 0.0, "y": 0.0, "a": 0.0}
var cam_h := CAM_H
var cam_back := CAM_BACK
var banner := {"text": "", "t": 0.0, "col": "#ffe040"}
var attract_t := 0.0
var attract_focus := 0
var remotes: Array = []    # other human racers (multiplayer): {x, y, a, speed, ...}

## feel + feedback
var shake := 0.0                  # camera shake 0..1+, decays on its own
var hitstop := 0.0                # real seconds the sim is frozen for after a big hit (read by Meta)
var flash := {"t": 0.0, "dur": 0.2, "col": Color.WHITE}
var feed: Array = []              # kill feed: {text, t, col}
var pops: Array = []              # floating callouts: {text, t, t0, col, big}
var trails: Array = []            # boost trail particles: {x, y, t, col}
var fov_k := 0.0                  # 0..1 field-of-view push while boosting
var catchup := 0.0                # 0..1 how far behind the leaders the player is (drives the catch-up bonus)
var allin := false                # final lap: boost and heat limits loosen

## systems
var events := RaceEvents.new()
var ghost := Ghost.new()
var goals: Array = []
var gs: Dictionary = {}           # goal stats for this race

var _chain := 0                   # consecutive overtakes
var _chain_t := 0.0
var _nm_chain := 0                # consecutive near misses
var _nm_t := 0.0
var _lost_t := 0.0
var _trail_t := 0.0

## replay of the last overtake: a ring of recent snapshots, a clip around the last pass, and playback state
const REC_STEP := 1.0 / 30.0
const RING_LEN := 100
var ring: Array = []
var clip: Array = []
var clip_open := false
var clip_pass := -1
var clip_name := ""
var clip_end := 0.0
var rp: Dictionary = {}
var _rec_t := 0.0


func _init(inp_: Inp, audio_: AudioFx) -> void:
	inp = inp_
	audio = audio_
	R = {"cfg": {}, "phase": "idle", "cdT": 0.0, "time": 0.0, "laps": 3, "elimT": 0.0, "elimNext": 0.0, "alive": 0,
		"rev": 0.0, "qte": QTE_KEYS, "qteI": 0, "qteDone": false, "launchDelay": 0.0, "lapStart": 0.0, "lapTimes": [],
		"takedowns": 0, "rank": 0, "result": null, "slowT": 0.0, "wrongT": 0.0, "cave": 0.0, "fumeOn": false,
		"tfMedal": 0, "tfPar": 0.0, "endT": 0.0, "confetti": false}


func set_banner(text: String, t: float = 1.6, col: String = "#ffe040") -> void:
	banner.text = text
	banner.t = t
	banner.col = col


# --------------------------------------------------------------------- stats

static func compute_stats(veh_key: String, style_key: String, parts: Array, diff_idx: int, scorched: bool, plain: bool = false) -> Dictionary:
	var v: Dictionary = Data.VEH[veh_key]
	var s: Dictionary = Data.STYLES[style_key]
	var up: Dictionary = {"speed": 0, "accel": 0, "cool": 0, "armor": 0} if plain else SaveData.data.up
	if plain:    # the daily challenge: everyone races stock
		parts = []
	var st := {
		"top": v.top * (1 + up.speed * 0.03), "acc": v.acc * (1 + up.accel * 0.04), "turn": v.turn, "grip": v.grip,
		"armor": v.armor * (1 + up.armor * 0.06), "cool": 1.0 + up.cool * 0.05, "abRegen": 1.0, "cd": 1.0,
		"crashes": Data.DIFFS[diff_idx].crashes + s.get("crash", 0), "ion": s.get("ion", false), "shove": v.shove * s.get("shove", 1.0),
		"driftMul": s.get("driftMul", 1.0), "magnet": false, "syn": [],
	}
	st.top *= s.get("top", 1.0)
	st.cool *= s.get("cool", 1.0)
	for id in parts:
		var p: Dictionary = Data.PARTS[id]
		st.top *= 1 + p.get("top", 0.0)
		st.acc *= 1 + p.get("acc", 0.0)
		st.turn *= 1 + p.get("turn", 0.0)
		st.grip *= 1 + p.get("grip", 0.0)
		st.cool *= 1 + p.get("cool", 0.0)
		st.armor *= 1 + p.get("armor", 0.0)
		st.abRegen += p.get("abRegen", 0.0)
		st.cd *= 1 - p.get("cd", 0.0)
		st.crashes += p.get("crash", 0)
		if p.get("ion", false):
			st.ion = true
		if p.get("magnet", false):
			st.magnet = true
	for id in Data.SYNERGIES:
		var all := true
		for need in Data.SYNERGIES[id].needs:
			if not parts.has(need):
				all = false
		if all:
			st.syn.append(id)
	if st.syn.has("overclock"):
		st.cool *= 1.15
	if scorched:
		st.top *= 0.9
	return st


# --------------------------------------------------------------------- setup

## cfg: {mode:'circuit'|'elim'|'test', planetKey, seed, laps, diff, veh, style, parts, scorched, botSkill, tour}
func setup(cfg: Dictionary, track: Track) -> void:
	trk = track
	R.cfg = cfg
	R.laps = 99 if cfg.mode == "elim" else cfg.get("laps", 3)
	R.merge({"phase": "countdown", "cdT": 4.2, "time": 0.0, "rev": 0.0, "qteI": 0, "qteDone": false, "launchDelay": 0.0,
		"lapStart": 0.0, "lapTimes": [], "takedowns": 0, "rank": 0, "result": null, "slowT": 0.0, "wrongT": 0.0, "cave": 0.0,
		"fumeOn": false, "elimT": 0.0, "elimNext": 20.0, "alive": 0, "tfMedal": 0, "endT": 0.0}, true)
	var st := compute_stats(cfg.veh, cfg.style, cfg.parts, cfg.diff, cfg.scorched, cfg.get("daily", false))
	shake = 0.0
	hitstop = 0.0
	flash.t = 0.0
	feed = []
	pops = []
	trails = []
	fov_k = 0.0
	catchup = 0.0
	allin = false
	_chain = 0
	_chain_t = 0.0
	_nm_chain = 0
	_nm_t = 0.0
	_lost_t = 0.0
	ring = []
	clip = []
	clip_open = false
	clip_pass = -1
	rp = {}
	gs = Goals.new_stats()
	goals = [] if cfg.has("mp_order") else Goals.pick(int(cfg.seed), cfg.mode)
	events.begin(self, cfg)
	ghost.begin(cfg)
	mines = []
	booms = []
	sparks = []
	bots = []
	P = {"veh": cfg.veh, "style": cfg.style, "st": st, "x": 0.0, "y": 0.0, "a": 0.0, "vx": 0.0, "vy": 0.0, "speed": 0.0, "steer": 0.0,
		"idx": 0, "total": 0.0, "hp": 100.0, "heat": 0.0, "ab": 100.0, "abLock": false, "ramOn": false, "rjReady": true, "abOn": false,
		"ion": 0.0, "inv": 0.0, "shield": 0.0, "abilCD": 0.0, "autoT": 0.0, "charge": 0.0, "drifting": false, "burstT": 0.0,
		"burstMul": 1.0, "mom": 0.0, "knife": false, "crashesLeft": st.crashes, "crashT": 0.0, "crashWhy": "", "lastHurt": "", "preSpeed": 0.0,
		"hurtT": 0.0, "overheated": false, "wallT": 0.0, "scrapeT": 0.0, "phase": 0.0, "mineCount": 0, "lastLap": 1, "yaw": 0.0, "driftDir": 0, "hopT": 0.0, "draft": 0.0, "lastSide": 1.0, "driftCD": 0.0, "driftHeld": false, "hopArmed": false, "driftT": 0.0, "driftBite": 0.0, "driftBiteS": 0.0, "steerIn": 0.0, "stage": 0, "lastDir": 0, "sideCD": 0.0}
	remotes = []
	if cfg.has("mp_order"):    # multiplayer: only human racers, one slot each
		var order: Array = cfg.mp_order
		for i in order.size():
			var ms := -30.0 - floorf(i / 2.0) * 28.0
			var mlat := (1.0 if i % 2 != 0 else -1.0) * minf(46.0, trk.half * 0.32)
			var id: int = order[i]
			if id == cfg.mp_local:
				_place_player(ms, mlat)
				continue
			var info: Dictionary = cfg.mp_players[id]
			var mcol: Array = Data.BOT_COLORS[i % Data.BOT_COLORS.size()]
			var q := trk.lane_xy(trk.pos_at(ms), mlat)
			remotes.append({"id": id, "name": str(info.name), "cls": info.veh, "col": mcol,
				"spr": VehicleModels.frames(info.veh, mcol[0], mcol[1], mcol[2]), "x": q.x, "y": q.y, "tx": q.x, "ty": q.y,
				"a": P.a, "vx": 0.0, "vy": 0.0, "speed": 0.0, "yaw": 0.0, "total": ms, "ramOn": false, "abOn": false,
				"shield": false, "crashed": false, "fin": -1.0, "out": false})
		R.alive = order.size()
		P.speed = 0.0
		return
	var grid := 1 if cfg.mode == "test" else 12
	var pslot := 0 if cfg.mode == "test" else 9
	var bot_skill: float = cfg.get("botSkill", 1.0)
	var tier_mid: float = Data.DIFFS[cfg.diff].tier
	var rng := Util.Rng.new(cfg.seed + 99)
	var bi := 0
	for i in grid:
		var s := -30.0 - floorf(i / 2.0) * 28.0
		var lat := (1.0 if i % 2 != 0 else -1.0) * minf(46.0, trk.half * 0.32)
		if i == pslot:
			_place_player(s, lat)
			continue
		var cls: String = Util.pick(rng, ["sled", "sled", "bike", "bike", "skim", "skim", "pod"])
		var bname: String = Data.BOT_NAMES[bi % Data.BOT_NAMES.size()]
		if Rivals.is_rival(bname):    # rivals always fly the same pod
			cls = Rivals.cls_for(bname)
		var col: Array = Data.BOT_COLORS[bi % Data.BOT_COLORS.size()]
		var v: Dictionary = Data.VEH[cls]
		var tier := clampi(int(round(tier_mid + (rng.next() + rng.next() - 1.0) * 1.5)), 0, Data.BOT_TIERS.size() - 1)
		if Rivals.is_rival(bname):    # rivals fly a tier above the field
			tier = mini(tier + 1, Data.BOT_TIERS.size() - 1)
		var T: Dictionary = Data.BOT_TIERS[tier]
		var skill: float = T.pace * (0.98 + 0.04 * rng.next()) * bot_skill
		if Rivals.is_rival(bname):
			skill *= 1.0 + 0.01 * int(Rivals.rec(bname).grudge)
		var b := {"id": bi, "name": bname, "cls": cls, "col": col,
			"spr": VehicleModels.frames(cls, col[0], col[1], col[2]), "yaw": 0.0, "s": s, "lat": lat, "lane": lat, "base": 0.0, "branch": 0, "latT": lat, "latV": 0.0, "v": 0.0,
			"skill": skill, "top": v.top, "acc": v.acc, "hitR": v.hitR, "shove": v.shove, "armor": v.armor,
			"hp": 100.0, "heat": 0.0, "ab": 100.0, "abT": 0.0, "abCD": 1.0 + rng.next() * 3.0, "ramT": 0.0, "ramCD": 3.0 + rng.next() * 5.0,
			"ion": 0.0}
		b.tier = tier
		b.T = T
		b.tq = float(tier) / float(Data.BOT_TIERS.size() - 1)    # 0 noob .. 1 star
		b.usesAb = rng.next() < T.ab
		b.usesRam = rng.next() < T.ram
		b.usesDrift = rng.next() < T.drift
		b.usesShield = rng.next() < T.shield
		b.rjReady = true
		b.ramMax = 0.0
		b.drifting = false
		b.driftDir = 0
		b.driftT = 0.0
		b.burstT = 0.0
		b.dodgeOK = true
		b.prey = null
		b.preyT = 0.0
		b.aggroCD = 4.0 + rng.next() * 6.0
		b.stats = {"ab": 0.0, "ram": 0, "drift": 0, "turbo": 0, "shield": 0, "wide": 0, "kills": 0}
		b.shield = 0.0
		b.shieldCD = 4.0 + rng.next() * 6.0
		b.mineCD = (8.0 + rng.next() * 8.0) if rng.next() < 0.2 else 1e9
		b.crashT = 0.0
		b.crashes = Data.DIFFS[cfg.diff].crashes
		b.inv = 0.0
		b.out = false
		b.outWhy = ""
		b.fin = -1.0
		b.elimPlace = 0
		b.hitT = 0.0
		b.rival = Rivals.is_rival(bname)
		b.hunt = Rivals.hunting(bname)
		b.ahead = b.s > P.total
		b.tauntT = 0.0
		b.nmT = -9.0
		bots.append(b)
		bi += 1
	R.alive = bots.size() + 1
	P.speed = 0.0


func _place_player(s: float, lat: float) -> void:
	var p := trk.pos_at(s)
	var q := trk.lane_xy(p, lat)
	P.x = q.x
	P.y = q.y
	P.a = p.a
	cam_a = p.a
	P.idx = p.i
	P.total = s


# ------------------------------------------------------- damage + explosions

func add_boom(x: float, y: float, big: bool) -> void:
	booms.append({"x": x, "y": y, "t": 0.0, "big": big})


func add_sparks(x: float, y: float, n: int, col: String = "") -> void:
	for i in n:
		sparks.append({"col": col, "x": x, "y": y, "vx": (randf() - 0.5) * 120.0, "vy": (randf() - 0.5) * 120.0, "t": 0.4 + randf() * 0.3})


func damage_player(amount: float, why: String) -> bool:
	if R.phase != "race" or P.inv > 0.0 or P.shield > 0.0 or P.crashT > 0.0:
		return false
	P.hp -= amount / P.st.armor
	P.hurtT = 0.25
	P.lastHurt = why
	if P.hp <= 0.0:
		crash_player(why)
	return true


func bot_pos(b: Dictionary) -> Dictionary:
	var p := trk.pos_at(b.s)
	var q := trk.lane_xy(p, b.lat)
	return {"x": q.x, "y": q.y, "a": p.a}


func ion_blast(x: float, y: float, radius: float = 240.0) -> void:
	add_boom(x, y, true)
	for b in bots:
		if not b.out and b.crashT <= 0.0:
			var q := bot_pos(b)
			if Vector2(q.x - x, q.y - y).length() < radius:
				b.ion = 3.0


func crash_player(why: String) -> void:
	if P.crashT > 0.0 or R.phase != "race":
		return
	P.crashT = 1.5
	P.crashWhy = why
	P.preSpeed = maxf(P.speed, 200.0)
	P.ramOn = false
	P.abOn = false
	P.crashesLeft -= 1
	gs.crashes += 1
	shake = 1.3
	flash_screen("#ff5020", 0.3)
	P.vx = 0.0
	P.vy = 0.0
	P.speed = 0.0
	P.hp = 0.0
	if why == "OVERHEAT":
		P.overheated = true
	add_boom(P.x, P.y, true)
	audio.boom()
	if P.st.ion:
		ion_blast(P.x, P.y, 340.0 if P.st.syn.has("chain") else 240.0)
		set_banner("ION BLAST", 1.2, "#60d0ff")
	set_banner("ENGINE OVERHEAT!" if why == "OVERHEAT" else "CRASH!", 1.6, "#ff4040")


func respawn_player() -> void:
	var i: int = P.idx
	var k := 0
	while k < 40 and (trk.hz_type[i] != 0 or trk.fume[i] == 2):
		i = (i + 1) % trk.n
		k += 1
	var p := trk.pts[i]
	var boff: float = P.lastSide * trk.branch_off(i * trk.dsa)
	P.x = p.x - trk.sin_a[i] * boff
	P.y = p.y + trk.cos_a[i] * boff
	P.a = trk.ang[i]
	P.idx = i
	cam_a = P.a
	var sp := maxf(270.0, P.preSpeed * 0.55)
	P.vx = cos(P.a) * sp
	P.vy = sin(P.a) * sp
	P.speed = sp
	P.hp = 100.0
	P.heat = minf(P.heat, 35.0)
	P.inv = 2.4
	P.ion = 0.0
	P.crashT = 0.0
	P.ab = maxf(P.ab, 50.0)
	P.steer = 0.0
	set_banner("BACK IN", 0.9, "#ffffff")


func crash_bot(b: Dictionary, why: String) -> void:
	if b.crashT > 0.0 or b.out:
		return
	b.crashT = 2.6
	b.hp = 0.0
	b.ramT = 0.0
	b.abT = 0.0
	b.drifting = false
	b.prey = null
	b.v = 0.0
	var q := bot_pos(b)
	add_boom(q.x, q.y, true)
	if R.phase == "race" and Vector2(q.x - P.x, q.y - P.y).length() < 400.0:
		audio.boom()


func takedown_bot(b: Dictionary) -> void:
	if b.shield > 0.0:
		b.shield = 0.0
		P.vx *= 0.6
		P.vy *= 0.6
		set_banner("SHIELDED!", 0.9, "#60d0ff")
		return
	crash_bot(b, "takedown")
	R.takedowns += 1
	SaveData.data.stats.takedowns += 1
	R.slowT = 0.9
	hitstop = 0.08
	shake = maxf(shake, 1.0)
	flash_screen("#ffd8a0", 0.14)
	set_banner(b.name + " DOWN!", 1.4, "#ff8030")
	feed.append({"text": "YOU > " + b.name, "t": 4.0, "col": "#ff9a40"})
	if feed.size() > 3:
		feed.pop_front()
	audio.beep(160, 0.3, "sawtooth", 0.1, 40)
	audio.beep(1200, 0.08, "square", 0.05, 600)
	if b.rival:
		Rivals.add_grudge(b.name)
		add_pop("RIVAL DOWN!", "#ff4040", true)
		feed.append({"text": b.name + ": " + Rivals.line(Rivals.WIN_LINES, b.name, 3), "t": 4.0, "col": "#ff6060"})
	if P.st.syn.has("bulwark"):
		P.hp = minf(100.0, P.hp + 30.0)
		add_pop("BULWARK +30 HULL", "#60ff90")
	SaveData.persist()


# ---------------------------------------------------------- player abilities

func use_ability() -> void:
	if P.abilCD > 0.0 or P.ion > 0.0 or P.crashT > 0.0 or R.phase != "race":
		return
	var ab: String = Data.STYLES[P.style].ability
	var cd: float = Data.ABILITY[ab].cd * P.st.cd
	if ab == "shield":
		P.shield = 4.0
		set_banner("SHIELD", 0.8, "#60d0ff")
	elif ab == "vent":
		P.heat = maxf(0.0, P.heat - 55.0)
		set_banner("VENTED", 0.8, "#60d0ff")
	elif ab == "autopilot":
		P.autoT = 4.0
		set_banner("AUTOPILOT", 0.8, "#60d0ff")
	elif ab == "mines":
		var own := 0
		for m in mines:
			if m.own == -1:
				own += 1
		if own >= 6:
			return
		var dx := cos(P.a)
		var dy := sin(P.a)
		mines.append({"x": P.x - dx * 16.0, "y": P.y - dy * 16.0, "own": -1, "t": 0.0})
		set_banner("MINE", 0.6, "#ff8030")
	elif ab == "hack":
		var best = null
		var bd := 320.0
		for b in bots:
			if b.out or b.crashT > 0.0:
				continue
			var q := bot_pos(b)
			var fwd: float = (q.x - P.x) * cos(P.a) + (q.y - P.y) * sin(P.a)
			var d := Vector2(q.x - P.x, q.y - P.y).length()
			if fwd > 0.0 and d < bd:
				bd = d
				best = b
		if best == null:
			set_banner("NO TARGET", 0.6, "#ff6060")
			return
		best.ion = 3.5
		set_banner("HACKED " + best.name, 1.0, "#60d0ff")
	elif ab == "gamble":
		var roll := randf()
		if roll < 0.2:
			P.ab = 100.0
			P.burstT = 2.2
			P.burstMul = 1.9
			set_banner("JACKPOT!", 1.2, "#ffd040")
			flash_screen("#ffe060", 0.2)
		elif roll < 0.65:
			P.burstT = 1.3
			P.burstMul = 1.5
			set_banner("SURGE!", 1.0, "#60ff90")
		elif roll < 0.88:
			P.ion = 1.0
			set_banner("FIZZLE", 1.0, "#ff9060")
		else:
			P.heat = minf(P.heat + 25.0, 90.0)
			set_banner("BUST! ENGINE HOT", 1.0, "#ff4040")
	elif ab == "flash":
		P.burstT = 1.4
		P.burstMul = 1.6
		set_banner("FLASH TURBO", 0.9, "#d060ff")
	elif ab == "phase":
		P.phase = 2.8
		P.inv = maxf(P.inv, 2.8)
		set_banner("PHASE", 0.9, "#c8a0ff")
	if P.st.syn.has("chain"):
		ion_blast(P.x, P.y, 200.0)
		add_pop("CHAIN BLAST", "#60d0ff")
	P.abilCD = cd
	audio.beep(640, 0.15, "square", 0.07, 900)


# ------------------------------------------------------------ player physics

## Which road of an alternate route to take at sample j. The autopilot commits to the left-hand (hazard-free) road
## while the two roads still overlap, then stays on it.
func _branch_target(j: int) -> Vector2:
	var o := trk.branch_off(j * trk.dsa)
	if o > 0.0 and trk.branch_off(P.idx * trk.dsa) < 40.0:
		P.lastSide = -1.0
	o *= P.lastSide
	return Vector2(trk.px[j] - trk.sin_a[j] * o, trk.py[j] + trk.cos_a[j] * o)


func auto_input() -> Dictionary:
	var d := _avoid_angle(12)
	var straight: bool = trk.k_ahead[P.idx] < 0.0005
	var steer := clampf(d * 2.4, -1.0, 1.0)
	# boost in full bursts: wait for a near-full meter on a straight, then run it down
	if not P.get("autoAb", false) and straight and P.ab > 70.0:
		P.autoAb = true
	elif P.get("autoAb", false) and (P.ab < 8.0 or P.abLock):
		P.autoAb = false
	# ramjet on straights up to ~85 heat, lifting before the bend
	var ram: bool = straight and P.heat < (85.0 if P.ramOn else 30.0) and (P.ramOn or P.rjReady)
	# drift the bends: hop, pick the bend's side, then tap in to tighten or steer out to widen as the line needs
	var drift := false
	var lat: float = -(P.x - trk.px[P.idx]) * trk.sin_a[P.idx] + (P.y - trk.py[P.idx]) * trk.cos_a[P.idx]
	if not straight and P.speed > 300.0 and (P.drifting or absf(lat) < trk.half - 30.0):
		var bend_dir := signf(Util.angdiff(trk.ang[(P.idx + 40) % trk.n], trk.ang[P.idx]))
		drift = true
		if P.drifting:
			var need: float = d * P.driftDir
			var inside: float = lat * P.driftDir    # how far towards the inside wall
			if inside > trk.half - 45.0 or absf(need) > 0.3:
				drift = false    # about to clip the wall or a rock: let go and take whatever turbo is charged
			elif inside > trk.half - 80.0 or need < -0.12:
				steer = -P.driftDir    # running out of road on the inside, or overshooting: widen
			elif need > 0.06 or inside < -(trk.half - 60.0):
				steer = P.driftDir if fmod(R.time, 0.16) < 0.08 else 0.0    # tap in to bite harder
			else:
				steer = 0.0
		elif P.hopArmed:
			steer = bend_dir
	return {"up": true, "dn": false, "steer": steer, "ab": P.get("autoAb", false), "ram": ram, "drift": drift}


## Cruise control for after the finish: follow the track and swing around obstacles, like a victory lap.
func finish_input() -> Dictionary:
	var d := _avoid_angle(14)
	return {"up": P.speed < MAXV * 0.7, "dn": false, "steer": clampf(d * 2.4, -1.0, 1.0), "ab": false, "ram": false, "drift": false}


## Heading error to a point ahead on the racing line, swung round any rock or crawler in the way.
func _avoid_angle(ahead: int) -> float:
	var n := trk.n
	var i: int = P.idx
	var j: int = (i + ahead + int(P.speed / 40.0)) % n
	var base := _branch_target(j)
	var lat_now: float = -(P.x - trk.px[i]) * trk.sin_a[i] + (P.y - trk.py[i]) * trk.cos_a[i]
	var base_lat: float = -(base.x - trk.px[j]) * trk.sin_a[j] + (base.y - trk.py[j]) * trk.cos_a[j]
	var lat_t := base_lat + clampf((lat_now - base_lat) * 0.5, -trk.half * 0.4, trk.half * 0.4)
	var hr: float = Data.VEH[P.veh].hitR
	var near_ds: float = 400.0 + P.speed * 0.8    # react to the nearest rock in the way
	for o in trk.obst:
		var ds: float = trk.wrap_ds(o.s, i * trk.dsa)
		if ds > -30.0 and ds < near_ds and absf(o.lat - lat_now) < o.r + hr + 45.0:
			var side := 1.0 if lat_now >= o.lat else -1.0
			lat_t = clampf(o.lat + side * (o.r + hr + 50.0), base_lat - trk.half + 30.0, base_lat + trk.half - 30.0)
			near_ds = ds
	for m in trk.movers:
		var mds: float = trk.wrap_ds(m.s, i * trk.dsa)
		var ml := trk.mover_lat(m, R.time)
		if mds > -30.0 and mds < 1100.0 and absf(ml - lat_now) < 140.0:
			lat_t = clampf(ml + (1.0 if lat_now >= ml else -1.0) * 135.0, base_lat - trk.half + 30.0, base_lat + trk.half - 30.0)
			break
	var tx: float = trk.px[j] - trk.sin_a[j] * lat_t
	var ty: float = trk.py[j] + trk.cos_a[j] * lat_t
	return Util.angdiff(atan2(ty - P.y, tx - P.x), P.a)


## Slipstream: tuck in behind a pod ahead (a wide, forgiving cone, since everyone is fast) and the draft meter fills;
## a full meter gives a speed and acceleration bonus. It bleeds away quickly once you leave the cone.
func update_draft(dt: float) -> void:
	var fwd := Vector2(cos(P.a), sin(P.a))
	var right := Vector2(-fwd.y, fwd.x)
	var in_zone := false
	for q in leader_positions():
		var d: Vector2 = q.pos - Vector2(P.x, P.y)
		var f := d.dot(fwd)
		if f > 60.0 and f < 1400.0 and absf(d.dot(right)) < 45.0 + f * 0.10 and q.v > MAXV * 0.45:
			in_zone = true
			break
	if in_zone:
		P.draft = minf(1.0, P.draft + dt / 1.0)
	else:
		P.draft = maxf(0.0, P.draft - dt / 0.8)


## Pods that can be drafted: live bots (and, in multiplayer, remote racers).
func leader_positions() -> Array:
	var out: Array = []
	for b in bots:
		if not b.out and b.crashT <= 0.0:
			var q := bot_pos(b)
			out.append({"pos": Vector2(q.x, q.y), "v": b.v})
	for r in remotes:
		if not r.get("out", false):
			out.append({"pos": Vector2(r.x, r.y), "v": r.get("speed", 0.0)})
	return out


## Centre of the drivable road nearest (x, y) at spine sample i (handles the two roads of an alternate route).
func road_center_near(x: float, y: float, i: int) -> Vector2:
	var o := trk.branch_off(i * trk.dsa)
	var c := Vector2(trk.px[i], trk.py[i])
	if o <= 0.0:
		return c
	var nrm := Vector2(-trk.sin_a[i], trk.cos_a[i])
	var a := c + nrm * o
	var b := c - nrm * o
	return a if a.distance_squared_to(Vector2(x, y)) < b.distance_squared_to(Vector2(x, y)) else b


func wall_normal(x: float, y: float) -> Vector2:
	var nx := 0.0
	var ny := 0.0
	for k in 8:
		var a := k * PI / 4.0
		var c := cos(a)
		var s := sin(a)
		if trk.mask_at(x + c * 8.0, y + s * 8.0) != 0:
			nx += c
			ny += s
	var l := sqrt(nx * nx + ny * ny)
	if l < 0.01:
		var p := road_center_near(x, y, P.idx)
		var dx := p.x - x
		var dy := p.y - y
		var d := sqrt(dx * dx + dy * dy)
		if d == 0.0:
			d = 1.0
		return Vector2(dx / d, dy / d)
	return Vector2(nx / l, ny / l)


## How hard a drift is biting: -1 while steering out of it, else 0 (light) .. 1 (hard) from the tap rate.
func drift_bend(p: Dictionary, steer_in: float) -> float:
	return -1.0 if steer_in * p.driftDir < -0.5 else p.driftBiteS


func update_player(dt: float, inp_: Dictionary) -> void:
	var st: Dictionary = P.st
	var veh: Dictionary = Data.VEH[P.veh]
	var pl: Dictionary = trk.planet
	P.ion = maxf(0.0, P.ion - dt)
	P.inv = maxf(0.0, P.inv - dt)
	P.shield = maxf(0.0, P.shield - dt)
	P.abilCD = maxf(0.0, P.abilCD - dt)
	P.hurtT = maxf(0.0, P.hurtT - dt)
	P.burstT = maxf(0.0, P.burstT - dt)
	P.hopT = maxf(0.0, P.hopT - dt)
	P.driftCD = maxf(0.0, P.driftCD - dt)
	P.wallT = maxf(0.0, P.wallT - dt)
	P.scrapeT = maxf(0.0, P.scrapeT - dt)
	P.phase = maxf(0.0, P.phase - dt)
	if P.autoT > 0.0:
		P.autoT -= dt
		inp_ = auto_input()
	var terr := trk.mask_at(P.x, P.y)
	var fume: bool = trk.fume[P.idx] == 1
	R.fumeOn = fume

	# heading + velocity axes
	var top_v: float = MAXV * st.top
	var f_prev: float = P.vx * cos(P.a) + P.vy * sin(P.a)
	P.steer += (inp_.steer - P.steer) * minf(1.0, dt * 10.0)
	var momentum: bool = veh.get("momentum", 0) != 0
	var drift_k: float = veh.get("drift", 0.0)
	P.knife = momentum and inp_.drift and f_prev > 160.0
	# Drift, Mario Kart style: tap Space to hop, steer during the hop to lock a direction, hold to keep sliding.
	# Mid-drift, tapping into the turn sets how hard it bites: each tap adds bite that bleeds away, so tap
	# rate is a light-to-hard dial (about 4 taps a second holds it fully tight); holding the outward key
	# widens it. Charge builds through three spark colours; releasing gives a mini-turbo of that size.
	# Switching sides straight away is locked out for a second.
	var drift_ok: bool = drift_k != 0.0 and f_prev > 200.0
	var press_edge: bool = inp_.drift and not P.driftHeld
	var steer_prev: float = P.steerIn
	P.steerIn = inp_.steer
	P.driftHeld = inp_.drift
	P.knife = momentum and drift_k == 0.0 and inp_.drift and f_prev > 160.0
	P.sideCD = maxf(0.0, P.sideCD - dt)
	if press_edge and not P.drifting and drift_ok and P.driftCD <= 0.0:
		P.hopArmed = true
		P.hopT = 0.26
		audio.beep(300, 0.12, "square", 0.05, 520)
	if not inp_.drift or f_prev < 150.0:
		P.hopArmed = false
	if P.hopArmed and not P.drifting and absf(inp_.steer) > 0.3:
		var dir := 1 if inp_.steer > 0.0 else -1
		if not (P.sideCD > 0.0 and dir == -P.lastDir):
			P.drifting = true
			P.hopArmed = false
			P.driftDir = dir
			P.driftT = 0.0
			P.driftBite = 0.25    # the press that picks the side counts as the first tap
			P.driftBiteS = 0.0
			P.stage = 0
			P.charge = 0.0
	elif P.drifting:
		if inp_.drift and f_prev > 150.0:
			if inp_.steer * P.driftDir > 0.5 and steer_prev * P.driftDir <= 0.5:
				P.driftBite = minf(1.0, P.driftBite + 0.25)
			P.driftBite = maxf(0.0, P.driftBite - 1.0 * dt)
			P.driftBiteS += (P.driftBite - P.driftBiteS) * minf(1.0, dt * 6.0)
			var inward: float = drift_bend(P, inp_.steer)
			P.driftT += dt * (0.85 + 0.35 * inward) * st.driftMul
			var stage := 3 if P.driftT >= 2.6 else (2 if P.driftT >= 1.6 else (1 if P.driftT >= 0.8 else 0))
			if stage > P.stage:
				audio.beep(500 + stage * 150, 0.08)
			P.stage = stage
			P.charge = minf(1.0, P.driftT / 2.6)
			var col: String = ["#ffffff", "#40a0ff", "#ff9020", "#d060ff"][stage]
			var fwd := Vector2(cos(P.a), sin(P.a))
			var side := Vector2(-fwd.y, fwd.x)
			for sgn in [-1.0, 1.0]:
				if randf() < dt * (30.0 if stage > 0 else 8.0):
					var q: Vector2 = Vector2(P.x, P.y) - fwd * 9.0 + side * sgn * 6.0
					add_sparks(q.x, q.y, 1, col)
		else:
			P.drifting = false
			P.driftCD = 0.3
			P.sideCD = 1.0
			P.lastDir = P.driftDir
			if P.stage > 0:
				P.burstT = [0.0, 0.55, 1.0, 1.6][P.stage] * (1.35 if st.syn.has("sling") else 1.0)
				P.burstMul = 1.4
				if R.phase == "race":
					gs.turbos += 1
					if P.stage >= 2:
						gs.supers += 1
					if P.stage == 3:
						gs.ultras += 1
					SaveData.data.stats.turbos += 1
					shake = maxf(shake, 0.25 * P.stage)
				set_banner(["", "MINI-TURBO", "SUPER MINI-TURBO", "ULTRA MINI-TURBO"][P.stage], 0.8, ["#ffffff", "#40a0ff", "#ff9020", "#d060ff"][P.stage])
			P.stage = 0
			P.charge = 0.0
	var tr: float = 3.1 * st.turn * (0.4 + 0.6 * clampf(f_prev / top_v, 0.0, 1.7))
	if momentum:
		tr *= 1.0 + 0.25 * clampf(f_prev / top_v, 0.0, 1.0)
	var steer_eff: float = P.steer
	if P.drifting:
		tr *= 1.15
		var bend := drift_bend(P, inp_.steer)
		steer_eff = P.driftDir * (0.45 + (0.55 if bend >= 0.0 else 0.25) * bend)    # 0.2 wide .. 0.45 light .. 1.0 hard
	if P.knife:
		tr *= 1.15
	P.a += steer_eff * tr * dt
	var dx := cos(P.a)
	var dy := sin(P.a)
	var rx := -dy
	var ry := dx
	var f: float = P.vx * dx + P.vy * dy
	var l: float = P.vx * rx + P.vy * ry

	# boosts
	if P.abLock and P.ab > 15.0:
		P.abLock = false
	var ab_act: bool = inp_.ab and P.ab > 3.0 and not P.abLock and P.ion <= 0.0 and f > 70.0
	if ab_act:
		P.ab -= (18.0 if allin else 28.0) * dt
		if st.syn.has("feedback"):
			P.abilCD = maxf(0.0, P.abilCD - dt * 0.8)
		if P.ab <= 3.0:
			P.abLock = true
	else:
		P.ab = minf(100.0, P.ab + 17.0 * st.abRegen * dt * (1.0 if f > 100.0 else 0.4) * (1.4 if allin else 1.0))
	P.abOn = ab_act
	var want_ram: bool = inp_.ram and P.ion <= 0.0
	if want_ram and not P.ramOn and P.rjReady and P.heat < 80.0:
		P.ramOn = true
		SaveData.data.stats.ramjet += 1
		audio.beep(180, 0.5, "sawtooth", 0.08, 500)
	if not want_ram and P.ramOn:
		P.ramOn = false
		if P.heat > 35.0:
			P.rjReady = false
	if P.ion > 0.0 and P.ramOn:
		P.ramOn = false
	if not P.rjReady and P.heat <= 25.0:
		P.rjReady = true
	var hm: float = pl.heat
	if P.ramOn:
		P.heat += 20.0 * hm / st.cool * (1.5 if fume else 1.0) * (1.0 + 0.25 * events.k) * (0.8 if allin else 1.0) * dt
	else:
		P.heat -= 17.0 * st.cool / hm * (1.0 + 0.5 * catchup) * (1.3 if allin else 1.0) * dt
	if terr == LAVA:
		P.heat += 25.0 * dt
	elif terr == ICE:
		P.heat -= 20.0 * dt
	elif terr == WATER:
		P.heat -= 15.0 * dt
	P.heat = clampf(P.heat, 0.0, 105.0)
	if P.heat >= 100.0:
		crash_player("OVERHEAT")
		return

	# speed: boosts are additive bonuses on the base top speed
	update_draft(dt)
	var bonus: float = 0.14 * P.draft * (1.0 + 0.6 * catchup)
	if ab_act:
		bonus += 0.12 if fume else 0.25
	if P.ramOn:
		bonus += 0.45
		if st.syn.has("overclock"):
			bonus += 0.04
	if P.burstT > 0.0:
		bonus += 0.18 * P.burstMul
	if momentum:
		if f > 0.8 * top_v and absf(P.steer) < 0.6:
			P.mom = minf(1.0, P.mom + dt * 0.25)
		else:
			P.mom = maxf(0.0, P.mom - dt * 0.5)
		bonus += 0.10 * P.mom
	var cap: float = top_v * (1.0 + bonus) * (1.0 + 0.025 * catchup + (0.03 if allin else 0.0))
	if terr == ROUGH:
		cap *= 0.7
	elif terr == WATER:
		cap *= 0.78
	elif terr == ACID or terr == LAVA:
		cap *= 0.9
	if P.ion > 0.0:
		cap *= 0.88
	if P.drifting:
		if not (ab_act or P.ramOn or P.burstT > 0.0):
			cap *= 0.92    # a little slower through the slide (boosting keeps full speed)
	if P.hp < 25.0:
		cap *= 0.85
	var accel: float = 420.0 * SPEED_SCALE * st.acc * (1.0 + (0.9 if ab_act else 0.0) + (1.6 if P.ramOn else 0.0) + (1.0 if P.burstT > 0.0 else 0.0) + 0.6 * P.draft * (1.0 + 0.6 * catchup))
	if R.launchDelay > 0.0:
		R.launchDelay -= dt
		accel = 0.0
	if inp_.up or P.ramOn:
		if f < cap:
			f = minf(cap, f + accel * dt)    # thrust never pushes you past the cap
	else:
		f *= exp(-0.25 * dt)
	if inp_.dn:
		f = maxf(-120.0, f - 800.0 * dt)
	if f > cap:
		f -= (f - cap) * minf(1.0, 2.5 * dt)
	if P.knife:
		f *= exp(-0.25 * dt)
	var grip_mul := 0.2 if terr == ICE else (0.8 if terr == ROUGH else 1.0)
	if P.drifting:    # an ice slide: the nose swings but momentum carries on, hard taps bite a little more
		grip_mul *= lerpf(0.08, 0.3, clampf(drift_bend(P, inp_.steer), 0.0, 1.0))
	var g: float = st.grip * pl.roadGrip * grip_mul
	var sp_before := sqrt(f * f + l * l)
	l *= exp(-g * dt)
	if (ab_act or P.ramOn or P.burstT > 0.0) and f > 0.0 and terr != ICE:
		# boosting: grip turns sideways velocity into forward speed instead of bleeding it off, so corners cost no speed
		f = minf(maxf(f, sqrt(maxf(sp_before * sp_before - l * l, 0.0))), cap)
	P.vx = dx * f + rx * l
	P.vy = dy * f + ry * l
	if events.wind != 0.0 and R.phase == "race":    # storm gusts shove the pod sideways across the road
		P.vx += -trk.sin_a[P.idx] * events.wind * dt
		P.vy += trk.cos_a[P.idx] * events.wind * dt
	P.speed = sqrt(P.vx * P.vx + P.vy * P.vy)

	# visual yaw of the pod: leans into steering, and sits much deeper into the turn while drifting
	var yaw_t: float = P.steer * 0.5
	if P.drifting:
		yaw_t = P.driftDir * (0.62 + 0.2 * drift_bend(P, inp_.steer))
	P.yaw += (yaw_t - P.yaw) * minf(1.0, (40.0 if P.hopT > 0.0 else 12.0) * dt)

	# hazards that hurt
	if terr == ACID:
		damage_player(30.0 * dt, "ACID")
	elif terr == LAVA:
		damage_player(12.0 * dt, "LAVA")
	if terr == WATER and P.speed > 160.0 and randf() < dt * 14.0:
		add_sparks(P.x, P.y, 1)

	# move in sub-steps so a fast craft cannot tunnel through walls or props
	var hr: float = veh.hitR * (0.65 if P.knife else 1.0)
	var steps := maxi(1, int(ceil(P.speed * dt / 7.0)))
	var sdt := dt / steps
	for s in steps:
		P.x += P.vx * sdt
		P.y += P.vy * sdt
		_collide_world(sdt, hr, top_v, veh)
	P.speed = sqrt(P.vx * P.vx + P.vy * P.vy)

	# feel: field-of-view push and boost trails
	var fk := 0.0
	if P.ramOn:
		fk = 1.0
	elif ab_act or P.burstT > 0.0:
		fk = 0.7
	fk = minf(1.0, maxf(fk, clampf((P.speed - MAXV) / (MAXV * 0.6), 0.0, 0.6)) + 0.2 * P.draft)
	fov_k += (fk - fov_k) * minf(1.0, 4.0 * dt)
	if (P.ramOn or ab_act or P.burstT > 0.0) and P.speed > 150.0 and Cosmetics.trail_colour(0) != "":
		_trail_t -= dt
		if _trail_t <= 0.0:
			_trail_t = 0.025
			var tf := Vector2(cos(P.a), sin(P.a))
			var ts := Vector2(-tf.y, tf.x)
			for sgn in [-1.0, 1.0]:
				var tq: Vector2 = Vector2(P.x, P.y) - tf * 12.0 + ts * sgn * 6.0
				trails.append({"x": tq.x, "y": tq.y, "t": 0.55, "t0": 0.55, "col": Cosmetics.trail_colour(randi())})
			if trails.size() > 160:
				trails = trails.slice(trails.size() - 160)
	if R.phase == "race":
		gs.maxKmh = maxf(gs.maxKmh, P.speed * 0.9 / SPEED_SCALE)
		if P.ramOn:
			gs.ramSec += dt
		if P.draft > 0.5:
			gs.draftSec += dt


func _collide_world(sdt: float, hr: float, top_v: float, veh: Dictionary) -> void:
	var momentum: bool = veh.get("momentum", 0) != 0
	# walls
	if trk.mask_at(P.x, P.y) == 0:
		var hit := false
		var nx := 0.0
		var ny := 0.0
		var it := 0
		while it < 6 and trk.mask_at(P.x, P.y) == 0:
			var nv := wall_normal(P.x, P.y)
			nx = nv.x
			ny = nv.y
			P.x += nx * 3.0
			P.y += ny * 3.0
			hit = true
			it += 1
		if trk.mask_at(P.x, P.y) == 0:    # still buried in rock: snap back onto the road
			var rc_ := road_center_near(P.x, P.y, P.idx)
			P.x = rc_.x
			P.y = rc_.y
			P.vx *= 0.3
			P.vy *= 0.3
		if hit:
			var vn: float = P.vx * nx + P.vy * ny
			if vn < 0.0:
				var impact := -vn
				P.vx -= 1.2 * vn * nx
				P.vy -= 1.2 * vn * ny
				P.vx *= 0.93
				P.vy *= 0.93
				if impact > 90.0 * SPEED_SCALE and P.wallT <= 0.0:
					damage_player(impact * 0.04 / SPEED_SCALE, "WALL")
					P.wallT = 0.25
					gs.walls += 1
					shake = maxf(shake, minf(1.0, impact / (320.0 * SPEED_SCALE)))
					add_sparks(P.x, P.y, 6)
					audio.beep(110, 0.08, "square", 0.07)
				if momentum:
					P.mom *= 0.5
			elif P.speed > 120.0:
				P.vx *= exp(-1.2 * sdt)
				P.vy *= exp(-1.2 * sdt)
				add_sparks(P.x, P.y, 1)
				damage_player(3.0 * sdt * (P.speed / top_v), "WALL")
				if P.scrapeT <= 0.0:
					gs.walls += 1
					P.scrapeT = 0.8
			P.speed = sqrt(P.vx * P.vx + P.vy * P.vy)
	if P.phase > 0.0:    # phased: slip through crawlers and props (walls stay solid)
		return
	# crawlers (a capsule across the road)
	for m in trk.movers:
		var c := trk.mover_xy(m, R.time)
		if absf(P.x - c.x) > 220.0 or absf(P.y - c.y) > 220.0:
			continue
		var right := Vector2(-trk.sin_a[m.i], trk.cos_a[m.i])
		var ma := c - right * 45.0
		var mb := c + right * 45.0
		var mp := Vector2(P.x, P.y)
		var ab := mb - ma
		var tt := clampf((mp - ma).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := ma + ab * tt
		var md := mp.distance_to(q)
		var mr := 40.0 + hr
		if md < mr and md > 0.01:
			var nx := (mp.x - q.x) / md
			var ny := (mp.y - q.y) / md
			var vn: float = P.vx * nx + P.vy * ny
			P.x += nx * (mr - md)
			P.y += ny * (mr - md)
			if vn < 0.0:
				P.vx -= 1.3 * vn * nx
				P.vy -= 1.3 * vn * ny
				P.vx *= 0.55
				P.vy *= 0.55
				if P.wallT <= 0.0:
					damage_player(32.0, "CRASH")
					P.wallT = 0.5
					add_sparks(P.x, P.y, 10)
					audio.beep(80, 0.18, "square", 0.1)
			P.speed = sqrt(P.vx * P.vx + P.vy * P.vy)
	# solid obstacles
	for o in trk.obst:
		var ox: float = P.x - o.x
		var oy: float = P.y - o.y
		if absf(ox) > 90.0 or absf(oy) > 90.0:
			continue
		var d := sqrt(ox * ox + oy * oy)
		var rr: float = o.r + hr
		if d < rr and d > 0.01:
			var nx := ox / d
			var ny := oy / d
			var vn: float = P.vx * nx + P.vy * ny
			P.x += nx * (rr - d)
			P.y += ny * (rr - d)
			if vn < 0.0:
				P.vx -= 1.3 * vn * nx
				P.vy -= 1.3 * vn * ny
				P.vx *= 0.8
				P.vy *= 0.8
				if P.wallT <= 0.0:
					damage_player(minf(26.0, 6.0 + -vn * 0.045 / SPEED_SCALE), "CRASH")
					P.wallT = 0.3
					add_sparks(P.x, P.y, 8)
					audio.beep(90, 0.12, "square", 0.09)
				if momentum:
					P.mom = 0.0
			P.speed = sqrt(P.vx * P.vx + P.vy * P.vy)


## Updates the player's nearest path sample + lap distance. Returns true when driving the wrong way.
func track_progress() -> bool:
	var n := trk.n
	var pts := trk.pts
	var best: int = P.idx
	var bd := 1e18
	for d in range(-24, 25):
		var i: int = (P.idx + d + n) % n
		var q := pts[i]
		var dd: float = (q.x - P.x) * (q.x - P.x) + (q.y - P.y) * (q.y - P.y)
		if dd < bd:
			bd = dd
			best = i
	if bd > (trk.width * 1.1) * (trk.width * 1.1):    # off the road (shortcut): widen the search
		for d in range(-110, 111):
			var i: int = (P.idx + d + n) % n
			var q := pts[i]
			var dd: float = (q.x - P.x) * (q.x - P.x) + (q.y - P.y) * (q.y - P.y)
			if dd < bd:
				bd = dd
				best = i
	var dlt: int = best - P.idx
	if dlt > n / 2:
		dlt -= n
	if dlt < -n / 2:
		dlt += n
	P.total += dlt * trk.dsa
	P.idx = best
	if trk.branch_off(best * trk.dsa) > 40.0:
		var lat_b: float = -(P.x - trk.px[best]) * trk.sin_a[best] + (P.y - trk.py[best]) * trk.cos_a[best]
		P.lastSide = 1.0 if lat_b >= 0.0 else -1.0
	return cos(Util.angdiff(P.a, trk.ang[best])) < -0.2 and P.speed > 60.0


# ---------------------------------------------------------------------- bots

func bot_hazard(b: Dictionary) -> int:
	var i := trk.idx_of(b.s)
	var t: int = trk.hz_type[i]
	if t == 0:
		return 0
	var side: int = trk.hz_side[i]
	return t if (side == 0 or (side > 0) == (b.lat > 0.0)) else 0


## Spark colour / turbo size a drifting bot has charged: 0 none, 1 mini, 2 super, 3 ultra.
static func bot_drift_stage(b: Dictionary) -> int:
	return 3 if b.driftT >= 2.6 else (2 if b.driftT >= 1.6 else (1 if b.driftT >= 0.8 else 0))


func bot_ram_on(b: Dictionary, heat_limit: float) -> void:
	b.ramT = 1.0    # stays on until update_bot cuts it at heat_limit
	b.ramMax = heat_limit
	b.stats.ram += 1


## Something a shield would save this bot from: a rammer right behind, a rock it can't dodge, acid or lava ahead.
func bot_threat(b: Dictionary, i: int) -> bool:
	if P.ramOn and P.crashT <= 0.0 and R.phase == "race":
		var rel: float = trk.wrap_ds(P.total, b.s)
		var plat: float = -(P.x - trk.px[P.idx]) * trk.sin_a[P.idx] + (P.y - trk.py[P.idx]) * trk.cos_a[P.idx]
		if rel < 0.0 and rel > -250.0 and absf(plat - b.lat) < 45.0:
			return true
	for o in bots:
		if o != b and not o.out and o.crashT <= 0.0 and o.ramT > 0.0:
			var ds: float = trk.wrap_ds(o.s, b.s)
			if ds < 0.0 and ds > -200.0 and absf(o.lat - b.lat) < 35.0:
				return true
	for o in trk.obst:
		var ods: float = trk.wrap_ds(o.s, b.s)
		if ods > 0.0 and ods < 70.0 and absf(o.lat - b.lat) < o.r + 8.0:
			return true
	var ah := (i + 25) % trk.n
	var ht: int = trk.hz_type[ah]
	if ht == ACID or ht == LAVA:
		var side: int = trk.hz_side[ah]
		return side == 0 or (side > 0) == (b.lat > 0.0)
	return false


## Picks (or keeps chasing) a racer just ahead, steers onto their line and lights the ramjet to take them out.
func bot_hunt(b: Dictionary, dt: float, half: float, straight: bool) -> void:
	var T: Dictionary = b.T
	b.aggroCD -= dt
	if b.prey == null:
		if b.aggroCD > 0.0:
			return
		b.aggroCD = lerpf(14.0, 4.0, T.aggro) + randf() * 3.0
		if randf() > T.aggro:
			return
		var best = null
		var best_d := 600.0
		if P.crashT <= 0.0 and P.shield <= 0.0:
			var pd: float = trk.wrap_ds(P.total, b.s)
			if pd > 40.0 and pd < best_d:
				best = "P"
				best_d = pd
		for o in bots:
			if o != b and not o.out and o.crashT <= 0.0 and o.shield <= 0.0:
				var od: float = trk.wrap_ds(o.s, b.s)
				if od > 40.0 and od < best_d:
					best = o
					best_d = od
		if best == null:
			return
		b.prey = best
		b.preyT = 7.0
	b.preyT -= dt
	var ps: float
	var plat: float
	var gone: bool
	if b.prey is String:
		ps = P.total
		plat = -(P.x - trk.px[P.idx]) * trk.sin_a[P.idx] + (P.y - trk.py[P.idx]) * trk.cos_a[P.idx]
		gone = P.crashT > 0.0
	else:
		ps = b.prey.s
		plat = b.prey.lat
		gone = b.prey.out or b.prey.crashT > 0.0
	var rel: float = trk.wrap_ds(ps, b.s)
	if gone or b.preyT <= 0.0 or rel < -30.0 or rel > 900.0:
		b.prey = null
		return
	b.latT = clampf(plat - b.base, -half + 14.0, half - 14.0)
	if rel < 380.0 and b.ramT <= 0.0 and b.rjReady and b.heat < 55.0 and (b.usesRam or b.tier >= 5) and b.ion <= 0.0:
		bot_ram_on(b, maxf(70.0, T.ramMax))


func update_bot(b: Dictionary, dt: float, ref) -> void:
	if b.out:
		return
	b.hitT = maxf(0.0, b.hitT - dt)
	if b.crashT > 0.0:
		b.crashT -= dt
		if b.crashT <= 0.0:
			b.crashes -= 1
			if b.crashes < 0:
				b.out = true
				b.outWhy = "WRECKED"
				b.elimPlace = R.alive
				R.alive -= 1
				return
			b.hp = 100.0
			b.v = 220.0
			b.inv = 1.6
			b.heat *= 0.3
			b.ion = 0.0
		return
	var pl: Dictionary = trk.planet
	var i := trk.idx_of(b.s)
	var half := trk.half
	var off := trk.branch_off(fposmod(b.s, trk.length))    # alternate routes: follow one of the two roads
	if off > 0.0 and b.branch == 0:
		var hs: int = trk.hz_side[(i + 40) % trk.n]
		b.branch = (-hs if randf() < 0.8 else hs) if hs != 0 else (1 if randf() < 0.5 else -1)
	elif off == 0.0:
		b.branch = 0
	b.base = b.branch * off
	b.ion = maxf(0.0, b.ion - dt)
	b.inv = maxf(0.0, b.inv - dt)
	b.shield = maxf(0.0, b.shield - dt)
	b.abCD -= dt
	b.ramCD -= dt
	b.shieldCD -= dt
	b.mineCD -= dt
	var T: Dictionary = b.T
	var bq: float = b.tq    # pilot quality, 0 noob .. 1 star
	var straight: bool = trk.k_ahead[i] < 0.0005    # tracks are straights (k 0) and arcs (k ~0.001)
	var bend: bool = not straight
	var turn := Util.angdiff(trk.ang[(i + 6) % trk.n], trk.ang[(i - 6 + trk.n) % trk.n])
	# drift: slide the bends to carry more speed, then fire the charge as a mini-turbo on the way out.
	# Sloppy drifters bail out early and get a smaller (or no) turbo.
	if b.drifting:
		b.driftT += dt * (0.7 + 0.5 * T.drift)
		if straight or randf() < dt * (1.0 - T.drift) * 1.5:
			var stg := bot_drift_stage(b)
			b.burstT = [0.0, 0.55, 1.0, 1.6][stg]
			if stg > 0:
				b.stats.turbo += 1
			b.drifting = false
	elif bend and b.usesDrift and b.v > 300.0 and absf(turn) > 0.02 and b.ion <= 0.0:
		b.drifting = true
		b.driftDir = 1 if turn > 0.0 else -1
		b.driftT = 0.0
		b.stats.drift += 1
	if b.drifting and randf() < dt * 20.0:
		var stg := bot_drift_stage(b)
		var dp := bot_pos(b)
		if absf(dp.x - P.x) < 1500.0 and absf(dp.y - P.y) < 1500.0:
			add_sparks(dp.x, dp.y, 1, ["#ffffff", "#40a0ff", "#ff9020", "#d060ff"][stg])
	b.burstT = maxf(0.0, b.burstT - dt)
	var corner: float = 45.0 * trk.k_ahead[i] * ((1.0 - 0.3 * T.drift) if b.drifting else 1.0)
	var target: float = MAXV * b.top * b.skill / (1.0 + corner)
	if ref != null:
		var gap: float = b.s - ref
		if gap < -150.0:
			target *= 1.0 + minf(0.17 if R.rank == 1 else 0.14, (-gap - 150.0) / 2500.0)
		elif gap > 500.0:
			target *= 1.0 - minf(0.08, (gap - 500.0) / 4000.0)
	if b.ion <= 0.0:
		# boost: noobs never find it. Sloppy pilots fire short bursts anywhere; good ones wait for a straight
		# or a turbo exit and run the meter right down.
		if b.usesAb and b.abT <= 0.0 and b.abCD <= 0.0 and b.ab > 30.0:
			if straight or b.burstT > 0.0 or randf() > bq:
				b.abT = lerpf(0.4 + randf() * 1.5, b.ab / 28.0, bq)
				b.abCD = lerpf(3.0 + randf() * 4.0, 0.4, bq)
			else:
				b.abCD = 0.2
		if b.abT > 0.0 and bq > 0.6 and bend and not b.drifting:
			b.abT = 0.0    # good pilots don't waste boost scrubbing through a bend
		# ramjet: hold it until the heat they're comfortable with; past 100 it blows. Good pilots only light it
		# on a straight and lift before the next bend; anyone hunting lights it to ram.
		if b.usesRam and b.ramT <= 0.0 and b.rjReady and b.ramCD <= 0.0 and b.heat < 40.0:
			if straight or randf() > bq:
				bot_ram_on(b, T.ramMax + (randf() * 2.0 - 1.0) * T.ramVar)
			else:
				b.ramCD = 0.2
		if b.ramT > 0.0 and (b.heat >= b.ramMax or (bq >= 0.5 and bend and b.prey == null and not b.hunt)):
			b.ramT = 0.0
			b.ramCD = lerpf(4.0 + randf() * 5.0, 1.0, bq)
			if b.heat > 35.0:
				b.rjReady = false
		# shield: the clueless pop it at random; good pilots save it for a rammer, a rock or a hazard
		if b.usesShield and b.shield <= 0.0 and b.shieldCD <= 0.0:
			var threat := bot_threat(b, i)
			if (threat and randf() < dt * 10.0 * T.shield) or randf() < dt * 0.06 * (1.0 - T.shield):
				b.shield = 4.0
				b.shieldCD = 16.0 + randf() * 8.0
				b.stats.shield += 1
	else:
		b.abT = 0.0
		b.ramT = 0.0
		b.drifting = false
	if not b.rjReady and b.heat <= 25.0:
		b.rjReady = true
	if b.abT > 0.0:
		b.abT -= dt
		b.ab -= 28.0 * dt
		b.stats.ab += dt
		if b.ab <= 3.0:
			b.abT = 0.0
		target *= 1.25 if (straight or b.drifting) else 1.1
	else:
		b.ab = minf(100.0, b.ab + 17.0 * dt)
	if b.burstT > 0.0:
		target *= 1.25
	if b.ramT > 0.0:
		target *= 1.62 if b.abT > 0.0 else 1.45
		b.heat += 20.0 * pl.heat * dt
		if b.heat >= 100.0:
			crash_bot(b, "OVERHEAT")
			return
	else:
		b.heat = maxf(0.0, b.heat - 17.0 * dt / pl.heat)
	if b.ion > 0.0:
		target *= 0.88
	# running wide: worse pilots misjudge bends and slide out into the barrier
	if bend and b.inv <= 0.0 and randf() < dt * T.err * clampf(b.v / (MAXV * b.top), 0.0, 1.5):
		var outward := -signf(turn) if turn != 0.0 else 1.0
		b.latV += outward * (150.0 + randf() * 120.0)
		b.latT = clampf(outward * half, -half + 14.0, half - 14.0)
		b.v *= 0.92
		b.stats.wide += 1
	var hz := bot_hazard(b)
	if hz == ACID:
		target *= 0.9
		if b.shield <= 0.0 and b.inv <= 0.0:
			b.hp -= 20.0 * dt
	elif hz == LAVA:
		b.heat += 25.0 * dt
		target *= 0.9
		if b.shield <= 0.0 and b.inv <= 0.0:
			b.hp -= 8.0 * dt
	elif hz == WATER:
		target *= 0.8
		b.heat = maxf(0.0, b.heat - 15.0 * dt)
	elif hz == ICE:
		b.heat = maxf(0.0, b.heat - 20.0 * dt)
	var ahead := (i + 30) % trk.n
	if randf() < dt * 0.25:    # whether they're paying attention to the next hazard
		b.dodgeOK = randf() < T.dodge
	if b.dodgeOK and off == 0.0 and trk.hz_type[ahead] != 0 and trk.hz_side[ahead] != 0:    # dodge half-width hazards
		b.latT = -trk.hz_side[ahead] * half * 0.45
	if b.hp <= 0.0:
		crash_bot(b, "hazard")
		return
	# obstacles: pick a free lane
	for o in trk.obst:
		var ds: float = trk.wrap_ds(o.s, b.s)
		if ds > 0.0 and ds < T.look and absf(o.lat - b.lat) < o.r + 20.0:
			b.latT = clampf((o.lat - (o.r + 28.0) if o.lat > b.lat else o.lat + (o.r + 28.0)) - b.base, -half + 14.0, half - 14.0)
		if absf(ds) < 9.0 and Vector2(o.lat - b.lat, ds).length() < o.r + 7.0 and b.inv <= 0.0:
			b.hp -= 25.0
			b.v *= 0.5
			b.latV = (1.0 if b.lat > o.lat else -1.0) * 70.0
			b.inv = 0.5
	# crawlers crossing the road
	for m in trk.movers:
		var mds: float = trk.wrap_ds(m.s, b.s)
		var ml := trk.mover_lat(m, R.time)
		var msd := 1.0 if b.lat >= ml else -1.0
		if mds > 0.0 and mds < 900.0 and absf(ml - b.lat) < 150.0:
			b.latT = clampf(ml + msd * 130.0 - b.base, -half + 14.0, half - 14.0)
			if mds < 500.0:
				target *= 0.8
		if absf(mds) < 9.0 and absf(ml - b.lat) < 92.0 and b.inv <= 0.0:
			b.hp -= 30.0
			b.v *= 0.4
			b.latV = msd * 90.0
			b.inv = 0.6
	# mines
	var bp := bot_pos(b)
	for m in range(mines.size() - 1, -1, -1):
		var mi: Dictionary = mines[m]
		if mi.t < 0.8 and mi.own == b.id:
			continue
		if absf(mi.x - bp.x) < 10.0 and absf(mi.y - bp.y) < 10.0:
			add_boom(mi.x, mi.y, false)
			mines.remove_at(m)
			if b.shield <= 0.0:
				b.ion = 2.5
				b.hp -= 20.0
				b.v *= 0.6
				if b.hp <= 0.0:
					crash_bot(b, "mine")
					return
	if b.mineCD <= 0.0 and b.ion <= 0.0:
		b.mineCD = 9.0 + randf() * 6.0
		var q := trk.pos_at(b.s - 14.0)
		var w := trk.lane_xy(q, b.lat)
		mines.append({"x": w.x, "y": w.y, "own": b.id, "t": 0.0})
	if events.wind != 0.0:
		b.latV += events.wind * 0.25 * dt
	if b.hunt and R.phase == "race" and P.crashT <= 0.0 and off == 0.0:    # a rival with a grudge goes after you
		var rel: float = P.total - b.s
		var plat: float = -(P.x - trk.px[P.idx]) * trk.sin_a[P.idx] + (P.y - trk.py[P.idx]) * trk.cos_a[P.idx]
		if rel > 40.0 and rel < 900.0:
			b.latT = clampf(plat - b.base, -half + 14.0, half - 14.0)
			target *= 1.04
			if straight and b.ramT <= 0.0 and b.rjReady and b.heat < 50.0 and rel < 650.0:
				bot_ram_on(b, maxf(70.0, T.ramMax))
		elif rel < -40.0 and rel > -500.0:    # ahead of you: block the line
			b.latT = clampf(plat - b.base, -half + 14.0, half - 14.0)
	elif T.aggro > 0.0 and R.phase == "race" and off == 0.0:    # hunters pick a racer just ahead and try to ram them out
		bot_hunt(b, dt, half, straight)
		if b.prey != null:
			target *= 1.05
	b.v += clampf(target - b.v, -400.0 * dt, 360.0 * b.acc * dt)
	b.s += b.v * dt
	b.lane += clampf(b.latT - b.lane, -65.0 * dt, 65.0 * dt) + b.latV * dt
	b.latV *= exp(-3.0 * dt)
	if randf() < dt * 0.3 and absf(b.latV) < 5.0:
		b.latT = clampf((randf() * 2.0 - 1.0) * (half - 22.0), -half + 14.0, half - 14.0)
	var lim := half - 8.0
	if absf(b.lane) > lim:    # barrier: shoved racers take damage
		if absf(b.latV) > 40.0 and b.inv <= 0.0 and b.shield <= 0.0:
			b.hp -= absf(b.latV) * 0.2 / b.armor
			b.inv = 0.4
			b.hitT = 0.4
		b.latV = -b.latV * 0.3
		b.lane = clampf(b.lane, -lim, lim)
		if b.hp <= 0.0:
			b.lat = b.base + b.lane
			crash_bot(b, "wall")
			return
	b.lat = b.base + b.lane
	# visual yaw: into the bend ahead and towards the lane being moved to
	var lat_rate: float = clampf(b.latT - b.lane, -65.0, 65.0) + b.latV
	var yt := clampf(turn * 3.0 + lat_rate / maxf(b.v, 150.0) * 1.5, -0.7, 0.7)
	if b.drifting:    # sit deep into the slide, like the player
		yt = b.driftDir * 0.62
	b.yaw += (yt - b.yaw) * minf(1.0, 6.0 * dt)
	if b.fin < 0.0 and b.s >= R.laps * trk.length:
		b.fin = R.time


func bot_contacts(dt: float) -> void:
	for i in bots.size():
		var a: Dictionary = bots[i]
		if a.out or a.crashT > 0.0 or a.ramT <= 0.0:
			continue
		for j in bots.size():
			if i == j:
				continue
			var o: Dictionary = bots[j]
			if o.out or o.crashT > 0.0 or o.inv > 0.0:
				continue
			if absf(trk.wrap_ds(a.s, o.s)) < 11.0 and absf(a.lat - o.lat) < 13.0:
				if o.shield > 0.0:
					o.shield = 0.0
					a.v *= 0.7
				else:
					crash_bot(o, "rammed")
					a.stats.kills += 1
					a.v *= 0.9


func player_bot_contacts() -> void:
	if R.phase != "race" or P.crashT > 0.0:
		return
	var veh: Dictionary = Data.VEH[P.veh]
	var hr: float = veh.hitR * (0.65 if P.knife else 1.0)
	for b in bots:
		if b.out or b.crashT > 0.0 or P.phase > 0.0:
			continue
		var q := bot_pos(b)
		var ddx: float = P.x - q.x
		var ddy: float = P.y - q.y
		var d := sqrt(ddx * ddx + ddy * ddy)
		var rr: float = hr + b.hitR
		if d >= rr or d < 0.01:
			continue
		var nx := ddx / d
		var ny := ddy / d
		var lat_off: float = ddx * -sin(q.a) + ddy * cos(q.a)
		var side := signf(lat_off)    # +1: player on the bot's right
		if side == 0.0:
			side = 1.0
		var rel := absf(P.speed - b.v)
		if P.ramOn and P.speed > 180.0:
			takedown_bot(b)
			continue
		if b.ramT > 0.0 and b.inv <= 0.0:
			if damage_player(48.0, "RAMMED"):
				P.vx += -sin(P.a) * side * 160.0
				P.vy += cos(P.a) * side * 160.0
			b.v *= 0.92
			continue
		P.x += nx * (rr - d) * 0.4
		P.y += ny * (rr - d) * 0.4
		b.lane = clampf(b.lane - side * (rr - d) * 0.6, -trk.half + 8.0, trk.half - 8.0)
		b.lat = b.base + b.lane
		if b.hitT <= 0.0:
			b.latV = -side * (70.0 + rel * 0.25) * P.st.shove
			b.hitT = 0.35
			b.hp -= 2.0 * P.st.shove
			var absorb: float = veh.absorb
			damage_player((2.0 + rel * 0.03) * (1.0 - absorb), "CONTACT")
			add_sparks((P.x + q.x) / 2.0, (P.y + q.y) / 2.0, 3)
			audio.beep(130, 0.06, "square", 0.06)
			if veh.get("momentum", 0) != 0:
				P.mom *= 0.7
			var f: float = P.vx * cos(P.a) + P.vy * sin(P.a)
			if f > b.v + 20.0 and absf(lat_off) < 8.0:
				P.vx *= 0.95
				P.vy *= 0.95
	# mines hit the player
	var hrm := hr
	for m in range(mines.size() - 1, -1, -1):
		var mi: Dictionary = mines[m]
		if mi.t < 0.8 and mi.own == -1:
			continue
		if Vector2(mi.x - P.x, mi.y - P.y).length() < hrm + 4.0:
			add_boom(mi.x, mi.y, false)
			mines.remove_at(m)
			if P.shield <= 0.0 and P.inv <= 0.0:
				P.ion = 2.5
				damage_player(20.0, "MINE")
				P.vx *= 0.6
				P.vy *= 0.6
				set_banner("ION MINE", 1.0, "#60d0ff")


# ---------------------------------------------------- standings + race flow

## Array of {b: bot or null (the player), t: distance}, leader first.
func standings() -> Array:
	var arr: Array = []
	for b in bots:
		if not b.out:
			arr.append({"b": b, "t": b.s})
	for r in remotes:
		arr.append({"b": r, "t": r.total})
	if R.phase != "wrecked" and R.phase != "eliminated":
		arr.append({"b": null, "t": P.total})
	arr.sort_custom(func(x, y): return x.t > y.t)
	return arr


func player_rank() -> int:
	var s := standings()
	for i in s.size():
		if s[i].b == null:
			return i + 1
	return s.size() + 1


func _update_remotes(dt: float) -> void:
	var k := minf(1.0, 12.0 * dt)
	for r in remotes:
		r.tx += r.vx * dt
		r.ty += r.vy * dt
		r.x += (r.tx - r.x) * k
		r.y += (r.ty - r.y) * k


func finish_race(kind: String) -> void:
	var lap_best := 0.0
	if R.lapTimes.size() > 0:
		lap_best = R.lapTimes.min()
	R.result = {"kind": kind, "rank": R.rank, "time": R.time, "takedowns": R.takedowns, "lapBest": lap_best,
		"crashes": P.st.crashes - P.crashesLeft, "alive": R.alive, "medal": R.tfMedal, "podium": [], "rivals": [], "goals": [],
		"stars": 0, "ghostNew": false, "order": []}
	if R.cfg.has("mp_order") or R.phase == "attract":
		return
	var order := final_order()
	R.result.order = order
	R.result.podium = _podium(order)
	if R.cfg.mode != "test" and bots.size() > 0:
		var wrecked: Array = []
		for b in bots:
			if b.out and b.outWhy == "WRECKED":
				wrecked.append(b.name)
		R.result.rivals = Rivals.after_race(order, wrecked)
	Goals.finalize(goals, gs, R.rank if kind == "finish" else 0, kind == "finish")
	var gdone := 0
	for g in goals:
		if g.done:
			gdone += 1
	R.result.goals = goals.duplicate(true)
	R.result.stars = Goals.stars(goals)
	SaveData.data.stars += R.result.stars
	SaveData.data.stats.goals += gdone
	if kind == "finish" and R.laps < 99:
		R.result.ghostNew = ghost.finish(R.time, P.veh)
	SaveData.persist()


## Names in finishing order ("" is the player). Finished bots come first by finish time, the rest by distance.
func final_order() -> Array:
	var done: Array = []
	var rest: Array = []
	for b in bots:
		if b.out:
			continue
		if b.fin >= 0.0:
			done.append(b)
		else:
			rest.append(b)
	done.sort_custom(func(x, y): return x.fin < y.fin)
	rest.sort_custom(func(x, y): return x.s > y.s)
	var names: Array = []
	for b in done:
		names.append(b.name)
	for b in rest:
		names.append(b.name)
	names.insert(clampi(R.rank - 1, 0, names.size()), "")
	return names


func _bot_named(n: String):
	for b in bots:
		if b.name == n:
			return b
	return null


func _podium(order: Array) -> Array:
	var out: Array = []
	for i in mini(3, order.size()):
		var n: String = order[i]
		if n == "":
			out.append({"name": "YOU", "cls": P.veh, "col": Cosmetics.cb(P.veh), "you": true, "rival": false})
		else:
			var b = _bot_named(n)
			out.append({"name": n, "cls": b.cls, "col": b.col, "you": false, "rival": b.rival})
	return out


## Big-moment feedback when the player crosses the line (the finish panel supplies the title).
func _finish_fx() -> void:
	if R.rank == 1:
		R.slowT = 1.4
		R.confetti = true
		flash_screen("#fff0b0", 0.3)
		shake = maxf(shake, 0.6)
		add_sparks(P.x, P.y, 30, "#ffd040")
		for i in 4:
			audio.beep(784 + i * 196, 0.18, "square", 0.06, 0.0, 0.5 + i * 0.12)


# ------------------------------------------------------- feel + feedback

static func ordinal(n: int) -> String:
	var suf := "TH"
	if n % 100 < 11 or n % 100 > 13:
		suf = ["TH", "ST", "ND", "RD", "TH", "TH", "TH", "TH", "TH", "TH"][n % 10]
	return str(n) + suf


## A floating call-out. A pop with the same `key` as a live one replaces it, so repeats update in place instead of stacking.
func add_pop(text: String, col: String = "#ffffff", big: bool = false, t: float = 1.6, key: String = "") -> void:
	if key != "":
		for pp in pops:
			if pp.key == key:
				pp.text = text
				pp.col = col
				pp.big = big
				pp.t = t
				pp.t0 = t
				return
	pops.append({"text": text, "t": t, "t0": t, "col": col, "big": big, "key": key})
	if pops.size() > 3:
		pops.pop_front()


func flash_screen(col: String, dur: float) -> void:
	flash.col = Color(col)
	flash.t = dur
	flash.dur = dur


## Catch-up: the further behind the leaders, the bigger the slipstream, cooling and top-speed bonus.
func _update_catchup(dt: float) -> void:
	var lead := -1e9
	for b in bots:
		if not b.out:
			lead = maxf(lead, b.s)
	for r in remotes:
		lead = maxf(lead, r.total)
	var tgt := 0.0
	if lead > -1e8:
		tgt = clampf((lead - P.total - 350.0) / 2400.0, 0.0, 1.0)
	catchup += (tgt - catchup) * minf(1.0, dt * 1.5)


## Overtake detection (with a little hysteresis so side-by-side racing does not flicker), pop-ups and rival taunts.
func _track_passes(dt: float) -> void:
	var gained := 0
	var lost := 0
	var passed = null
	for b in bots:
		b.tauntT = maxf(0.0, b.tauntT - dt)
		if b.out or b.crashT > 0.0:
			b.ahead = b.s > P.total
			continue
		var now_ahead: bool = (b.s > P.total - 8.0) if b.ahead else (b.s > P.total + 8.0)
		if now_ahead == b.ahead:
			continue
		b.ahead = now_ahead
		if R.time < 4.0:
			continue
		if not now_ahead:
			gained += 1
			passed = b
		else:
			lost += 1
			if b.rival and b.tauntT <= 0.0:
				b.tauntT = 25.0
				add_pop(b.name + ": " + Rivals.line(Rivals.PASS_LINES, b.name, int(R.time)), "#ff6060")
	var rk := player_rank()
	gs.worstRank = maxi(gs.worstRank, rk) if R.time > 6.0 else gs.worstRank
	if gained > 0:
		gs.passes += gained
		_chain += gained
		_chain_t = 4.0
		audio.beep(480 + 70 * mini(_chain, 8), 0.1, "square", 0.06, 700 + 90 * mini(_chain, 8))
		add_pop(ordinal(rk), "#ffd040" if rk <= 3 else "#ffffff", rk <= 3, 1.6, "rank")
		if gained == 1 and passed != null:
			add_pop("PASSED " + passed.name, "#a0e0ff", false, 1.6, "passed")
		if _chain >= 3:
			add_pop("%d PASS CHAIN!" % _chain, "#ff9a40", true, 1.6, "chain")
		_begin_clip(passed.name if passed != null else "")
	elif lost > 0 and _lost_t <= 0.0 and R.time > 6.0:
		_lost_t = 1.2
		_chain = 0
		audio.beep(220, 0.1, "square", 0.04, 150)
		add_pop(ordinal(rk), "#ff6060", false, 1.6, "rank")


func _award_near(label: String, ab_gain: float, col: String) -> void:
	_nm_chain = _nm_chain + 1 if _nm_t > 0.0 else 1
	_nm_t = 3.0
	gs.nearmiss += 1
	SaveData.data.stats.nearmiss += 1
	P.ab = minf(100.0, P.ab + ab_gain * (2.0 if P.st.magnet else 1.0))
	if P.st.syn.has("stunt"):
		P.burstT = maxf(P.burstT, 0.6)
		P.burstMul = 1.0
	add_pop(label + ("" if _nm_chain < 2 else " X%d" % _nm_chain), col, false, 1.4, "nm")
	audio.beep(900 + 80 * mini(_nm_chain, 5), 0.07, "square", 0.05)


## Skimming past props, crawlers and rivals at speed refills a bit of boost.
func _near_miss() -> void:
	if P.crashT > 0.0 or P.speed < MAXV * 0.5 or P.phase > 0.0:
		return
	var hr: float = Data.VEH[P.veh].hitR
	var pp := Vector2(P.x, P.y)
	var fwd := Vector2(cos(P.a), sin(P.a))
	for o in trk.obst:
		if absf(o.x - P.x) > 70.0 or absf(o.y - P.y) > 70.0:
			continue
		var d: Vector2 = Vector2(o.x, o.y) - pp
		var gap: float = d.length() - (o.r + hr)
		if gap > 0.0 and gap < 12.0 and absf(d.dot(fwd)) < 16.0 and R.time - o.get("nmT", -9.0) > 3.0:
			o.nmT = R.time
			_award_near("NEAR MISS", 10.0, "#80e8ff")
	for m in trk.movers:
		var c := trk.mover_xy(m, R.time)
		if absf(P.x - c.x) > 220.0 or absf(P.y - c.y) > 220.0:
			continue
		var right := Vector2(-trk.sin_a[m.i], trk.cos_a[m.i])
		var ma := c - right * 45.0
		var ab := (c + right * 45.0) - ma
		var q := ma + ab * clampf((pp - ma).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var gap: float = pp.distance_to(q) - (40.0 + hr)
		if gap > 0.0 and gap < 18.0 and absf((q - pp).dot(fwd)) < 24.0 and R.time - m.get("nmT", -9.0) > 3.0:
			m.nmT = R.time
			_award_near("CLOSE CALL", 25.0, "#ffb040")
	for b in bots:
		if b.out or b.crashT > 0.0:
			continue
		var bq := bot_pos(b)
		var bd := Vector2(bq.x, bq.y) - pp
		var bgap: float = bd.length() - (hr + b.hitR)
		if bgap > 0.0 and bgap < 9.0 and absf(bd.dot(fwd)) < 14.0 and R.time - b.nmT > 2.0:
			b.nmT = R.time
			_award_near("CLOSE SHAVE", 6.0, "#a0ffc0")


## Procedural soundtrack: energy follows rank and boosting, tension follows engine heat and hull damage.
func _update_music(dt: float) -> void:
	var on: bool = R.phase == "race" and P.crashT <= 0.0
	audio.music_on = on
	if not on:
		return
	var field := float(maxi(R.alive, 2))
	var rk := float(R.rank if R.rank > 0 else 6)
	var lead := 1.0 - (rk - 1.0) / (field - 1.0)
	var tgt := 0.2 + 0.35 * lead + (0.2 if (P.ramOn or P.abOn) else 0.0) + (0.25 if allin else 0.0)
	audio.music_level += (clampf(tgt, 0.0, 1.0) - audio.music_level) * minf(1.0, dt * 0.8)
	var ten := maxf(clampf((P.heat - 50.0) / 45.0, 0.0, 1.0), clampf((100.0 - P.ab - 70.0) / 30.0, 0.0, 1.0) * 0.6)
	if P.hp < 30.0:
		ten = maxf(ten, 0.6)
	audio.music_tension = move_toward(audio.music_tension, ten, dt * 1.5)
	audio.music_final = allin


# ------------------------------------------------- replay of the last overtake

func _snapshot() -> Dictionary:
	var bs: Array = []
	for b in bots:
		var fl := 0
		if b.ramT > 0.0:
			fl |= 1
		if b.abT > 0.0:
			fl |= 2
		if b.shield > 0.0:
			fl |= 4
		if b.crashT > 0.0:
			fl |= 8
		if b.inv > 0.0:
			fl |= 16
		if b.out:
			fl |= 32
		bs.append([b.s, b.lat, b.yaw, b.v, fl])
	var pf := int(P.ramOn) | (int(P.abOn) << 1) | (int(P.burstT > 0.0) << 2) | (int(P.drifting) << 3) | (int(P.shield > 0.0) << 4) | (int(P.inv > 0.0) << 5)
	return {"p": [P.x, P.y, P.a, P.yaw, P.speed, pf, P.driftDir, P.stage, P.hopT, P.idx], "b": bs}


func _record_replay(dt: float) -> void:
	_rec_t += dt
	if _rec_t < REC_STEP:
		return
	_rec_t -= REC_STEP
	var snap := _snapshot()
	ring.append(snap)
	if ring.size() > RING_LEN:
		ring.pop_front()
	if clip_open:
		clip.append(snap)
		if R.time >= clip_end:
			clip_open = false


func _begin_clip(who: String) -> void:
	if ring.size() < 20:
		return
	clip = ring.duplicate()
	clip_pass = clip.size() - 1
	clip_open = true
	clip_end = R.time + 2.2
	clip_name = who


func can_replay() -> bool:
	return clip.size() > 40 and clip_pass >= 0 and R.result != null and R.result.kind == "finish" and R.cfg.mode == "circuit" \
		and not R.cfg.has("mp_order") and R.rank <= 3


func begin_replay() -> void:
	rp = {"f": 0.0, "t": 0.0}
	R.phase = "replay"
	audio.engine_on = false
	audio.music_on = false
	P.crashT = 0.0
	for b in bots:
		b.out = false
	_apply_snap(0.0)


## Advances the replay; false when it has finished.
func update_replay(dt: float) -> bool:
	anim_t += dt
	rp.t += dt
	var rate := 0.6 if absf(rp.f - clip_pass) > 14.0 else 0.22    # slow right at the moment of the pass
	rp.f += dt / REC_STEP * rate
	if rp.f >= clip.size() - 1:
		return false
	_apply_snap(rp.f)
	cam_a = P.a + sin(rp.t * 0.7) * 0.2
	cam_back = 84.0 + 14.0 * sin(rp.t * 0.5)
	cam_h = 60.0
	cam.a = cam_a
	cam.x = P.x - cos(cam_a) * cam_back
	cam.y = P.y - sin(cam_a) * cam_back
	for b in booms:
		b.t += dt
	booms = booms.filter(func(b): return b.t < 1.4)
	return true


func _apply_snap(f: float) -> void:
	var i := clampi(int(f), 0, clip.size() - 1)
	var j := mini(i + 1, clip.size() - 1)
	var u := f - i
	var a: Array = clip[i].p
	var b2: Array = clip[j].p
	P.x = lerpf(a[0], b2[0], u)
	P.y = lerpf(a[1], b2[1], u)
	P.a = a[2] + Util.angdiff(b2[2], a[2]) * u
	P.yaw = lerpf(a[3], b2[3], u)
	P.speed = a[4]
	var pf: int = a[5]
	P.ramOn = (pf & 1) != 0
	P.abOn = (pf & 2) != 0
	P.burstT = 1.0 if (pf & 4) != 0 else 0.0
	P.drifting = (pf & 8) != 0
	P.shield = 1.0 if (pf & 16) != 0 else 0.0
	P.inv = 0.0
	P.driftDir = a[6]
	P.stage = a[7]
	P.hopT = a[8]
	P.idx = a[9]
	P.crashT = 0.0
	P.ion = 0.0
	P.phase = 0.0
	P.hurtT = 0.0
	P.charge = 0.0
	for k in bots.size():
		var ba: Array = clip[i].b[k]
		var bb: Array = clip[j].b[k]
		var bt: Dictionary = bots[k]
		bt.s = lerpf(ba[0], bb[0], u)
		bt.lat = lerpf(ba[1], bb[1], u)
		bt.yaw = lerpf(ba[2], bb[2], u)
		bt.v = ba[3]
		var fl: int = ba[4]
		bt.ramT = 1.0 if (fl & 1) != 0 else 0.0
		bt.abT = 1.0 if (fl & 2) != 0 else 0.0
		bt.shield = 1.0 if (fl & 4) != 0 else 0.0
		bt.crashT = 1.0 if (fl & 8) != 0 else 0.0
		bt.inv = 0.0
		bt.out = (fl & 32) != 0


func end_replay() -> void:
	R.phase = "finished"
	cam_back = CAM_BACK
	cam_h = CAM_H
	cam_a = P.a


func update_race(dt: float, in_: Dictionary) -> void:
	anim_t += dt
	_update_remotes(dt)
	if banner.t > 0.0:
		banner.t -= dt
	for f in feed:
		f.t -= dt
	feed = feed.filter(func(f): return f.t > 0.0)
	for pp in pops:
		pp.t -= dt
	pops = pops.filter(func(pp): return pp.t > 0.0)
	for tr in trails:
		tr.t -= dt
	trails = trails.filter(func(tr): return tr.t > 0.0)
	flash.t = maxf(0.0, flash.t - dt)
	_chain_t -= dt
	_nm_t -= dt
	_lost_t -= dt
	if _chain_t <= 0.0:
		_chain = 0
	if _nm_t <= 0.0:
		_nm_chain = 0
	for b in booms:
		b.t += dt
	booms = booms.filter(func(b): return b.t < 1.4)
	for s in sparks:
		s.t -= dt
		s.x += s.vx * dt
		s.y += s.vy * dt
	sparks = sparks.filter(func(s): return s.t > 0.0)
	for m in mines:
		m.t += dt
	var ph: String = R.phase

	if ph == "countdown":
		R.cdT -= dt
		if in_.up:
			R.rev = minf(1.1, R.rev + dt * 0.6)
		else:
			R.rev = maxf(0.0, R.rev - dt * 1.0)
		# quick-time engine start prompts
		for step in QTE_KEYS.size():
			if inp.pressed(QTE_KEYS[step]) and not R.qteDone and R.cdT > 0.3:
				if Data.STYLES[P.style].ability == "autopilot" and step == 2 and R.qteI == 0:
					R.qteDone = true
					R.qteI = 3
					set_banner("AUTOPILOT STARTED ENGINES", 1.2, "#60d0ff")
					break
				if step == R.qteI:
					R.qteI += 1
					audio.beep(500 + R.qteI * 120, 0.08)
					if R.qteI >= QTE_KEYS.size():
						R.qteDone = true
				else:
					R.qteI = 0
		if R.cdT <= 0.0:
			R.phase = "race"
			set_banner("GO!", 1.0, "#ffffff")
			audio.beep(880, 0.5, "square", 0.09)
			var heading: float = P.a
			if R.qteDone:
				P.ab = 100.0
				P.abilCD = 0.0
			if R.rev >= 0.40 and R.rev <= 0.70:
				P.vx = cos(heading) * 240.0
				P.vy = sin(heading) * 240.0
				P.burstT = 1.0
				P.burstMul = 1.0
				set_banner("PERFECT LAUNCH!" if R.qteDone else "GOOD REV!", 1.4, "#ffd040")
				if R.qteDone:
					gs.launch = 1
					add_pop("PERFECT LAUNCH", "#ffd040", true)
				shake = 0.5
			elif R.rev > 0.85:
				R.launchDelay = 0.8
				set_banner("WHEELSPIN!", 1.0, "#ff6060")
	elif ph == "race" or ph == "finished" or ph == "wrecked" or ph == "eliminated":
		var live := ph == "race"
		if live:
			R.time += dt
			events.update(dt)
			_update_catchup(dt)
			allin = (R.cfg.mode != "elim" and R.laps < 99 and P.lastLap >= R.laps) or (R.cfg.mode == "elim" and R.alive <= 4)
		else:
			allin = false
			events.settle(dt)
		# player
		if P.crashT > 0.0:
			P.crashT -= dt
			if P.crashT <= 0.0:
				if P.crashesLeft < 0 and live:
					R.phase = "wrecked"
					R.rank = R.alive
					finish_race("wrecked")
					P.hp = 0.0
				elif live:
					respawn_player()
		elif live:
			if inp.pressed(Inp.ABIL):
				use_ability()
			update_player(dt, in_)
		else:
			P.ion = 0.0
			update_player(dt, finish_input())
		if P.crashT <= 0.0:
			R.wrongT = R.wrongT + dt if track_progress() else 0.0

		# bots
		var ref = null if R.cfg.mode == "test" else P.total
		for b in bots:
			update_bot(b, dt, ref)
		bot_contacts(dt)
		if live:
			player_bot_contacts()
			_track_passes(dt)
			_near_miss()
			gs.takedowns = R.takedowns
			for g in Goals.update(goals, gs):
				add_pop("GOAL: " + g.label, "#60ffa0", true, 2.4)
				audio.beep(784, 0.1, "square", 0.06)
				audio.beep(1047, 0.2, "square", 0.06, 0.0, 0.1)
			ghost.record(R.time, P)
			_record_replay(dt)

		# laps
		var L := trk.length
		if live:
			var lap := mini(R.laps, int(floor(maxf(0.0, P.total) / L)) + 1)
			if lap != P.lastLap and P.total > 0.0:
				R.lapTimes.append(R.time - R.lapStart)
				R.lapStart = R.time
				P.lastLap = lap
				if R.cfg.mode != "elim":
					set_banner("FINAL LAP - ALL IN!" if lap == R.laps else "LAP " + str(lap), 1.8, "#ff6040" if lap == R.laps else "#ffe040")
					if lap == R.laps:
						flash_screen("#ff6040", 0.25)
						shake = maxf(shake, 0.4)
				audio.beep(660, 0.2)
			R.rank = player_rank()
			# modes
			if R.cfg.mode == "circuit" or R.cfg.mode == "test":
				if P.total >= R.laps * L:
					R.lapTimes.append(R.time - R.lapStart)
					var done := 0
					for b in bots:
						if not b.out and b.fin >= 0.0:
							done += 1
					for r in remotes:
						if r.fin >= 0.0:
							done += 1
					R.rank = 1 + done
					if R.cfg.mode == "test":
						var par: float = (L / (MAXV * 1.1)) * R.laps    # gold = a clean run with good boost use
						R.tfMedal = 3 if R.time <= par else (2 if R.time <= par * 1.12 else (1 if R.time <= par * 1.28 else 0))
						R.tfPar = par
					R.phase = "finished"
					finish_race("finish")
					_finish_fx()
					audio.beep(523, 0.15)
					audio.beep(659, 0.15, "square", 0.07, 0.0, 0.16)
					audio.beep(784, 0.4, "square", 0.07, 0.0, 0.32)
			elif R.cfg.mode == "elim":
				R.elimT = R.elimNext - R.time
				if R.elimT <= 0.0:
					var s := standings()
					var last: Dictionary = s[s.size() - 1]
					if last.b == null:
						R.phase = "eliminated"
						R.rank = R.alive
						add_boom(P.x, P.y, true)
						audio.boom()
						finish_race("eliminated")
						set_banner("ELIMINATED", 2.0, "#ff4040")
					else:
						last.b.out = true
						last.b.outWhy = "ELIMINATED"
						last.b.elimPlace = R.alive
						R.alive -= 1
						var q := bot_pos(last.b)
						add_boom(q.x, q.y, true)
						set_banner(last.b.name + " OUT", 1.2, "#ff9a40")
						audio.beep(200, 0.4, "sawtooth", 0.09, 80)
					R.elimNext += 14.0
					if R.phase == "race" and R.alive <= 3:
						R.rank = player_rank()
						R.phase = "finished"
						finish_race("finish")
						_finish_fx()

	# camera
	shake = maxf(0.0, shake - dt * 2.2)
	if P.crashT > 0.0 or R.phase != "race":
		fov_k = move_toward(fov_k, 0.0, dt * 2.0)
	cam_a += Util.angdiff(P.a, cam_a) * minf(1.0, 5.0 * dt)
	var in_cave := 1.0 if trk.cave[P.idx] != 0 else 0.0
	R.cave += (in_cave - R.cave) * minf(1.0, 3.0 * dt)
	var sf := clampf((P.speed - MAXV * 0.95) / (MAXV * 0.75), 0.0, 1.0)
	cam_back += (CAM_BACK + 45.0 * sf + 18.0 * fov_k - cam_back) * minf(1.0, 3.0 * dt)
	cam.a = cam_a + (randf() - 0.5) * 0.06 * shake
	cam_h = CAM_H + (randf() - 0.5) * 9.0 * shake
	cam.x = P.x - cos(cam_a) * cam_back
	cam.y = P.y - sin(cam_a) * cam_back
	var run: bool = R.phase == "race" or R.phase == "finished"
	audio.engine_on = run and P.crashT <= 0.0
	audio.engine_freq = 55.0 + (P.speed / MAXV) * 140.0 + (60.0 if P.ramOn else 0.0)
	_update_music(dt)


# ------------------------------------------------------------ attract mode

## Bots racing in the background of every menu.
func start_attract(track: Track) -> void:
	setup({"mode": "circuit", "planetKey": track.planet_key, "seed": track.seed_, "laps": 99, "diff": 1, "veh": "sled",
		"style": "survivor", "parts": [], "scorched": false, "attract": true}, track)
	R.phase = "attract"
	attract_t = 0.0
	attract_focus = 0
	for b in bots:
		b.v = 400.0
		b.shield = 0.0


## Returns false when it is time to start a new attract race.
func update_attract(dt: float) -> bool:
	anim_t += dt
	attract_t += dt
	R.time += dt
	if banner.t > 0.0:
		banner.t -= dt
	for b in booms:
		b.t += dt
	booms = booms.filter(func(b): return b.t < 1.4)
	for b in bots:
		update_bot(b, dt, null)
	bot_contacts(dt)
	var f = bots[attract_focus] if attract_focus < bots.size() else null
	if f == null or f.out or f.crashT > 0.0:
		attract_focus = -1
		for k in bots.size():
			if not bots[k].out and bots[k].crashT <= 0.0:
				attract_focus = k
				break
		f = bots[attract_focus] if attract_focus >= 0 else null
	if f == null or attract_t > 40.0:
		return false
	var q := bot_pos(f)
	cam_a += Util.angdiff(q.a, cam_a) * minf(1.0, 6.0 * dt)
	cam_h = CAM_H
	cam_back = CAM_BACK
	R.cave = 1.0 if trk.cave[trk.idx_of(f.s)] != 0 else 0.0
	cam.a = cam_a
	cam.x = q.x - cos(cam_a) * CAM_BACK
	cam.y = q.y - sin(cam_a) * CAM_BACK
	P.x = q.x
	P.y = q.y
	P.a = q.a
	P.crashT = 1.0
	audio.engine_on = false
	audio.music_on = false
	return true
