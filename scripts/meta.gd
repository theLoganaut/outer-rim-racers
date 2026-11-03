## Menus and campaign flow: title, quick race, daily challenge, test flight, garage, the roguelike tour, podium,
## results and the multiplayer lobby. Owns which screen is up and drives the Race while one is running.
class_name Meta
extends RefCounted

const W := 256
const H := 224
const LAP_OPTIONS := [3, 4, 5]
const TOUR_STAGES := 6
const CIRCUIT_CREDITS := [220, 180, 150, 125, 100, 80, 60, 40, 30, 20, 10, 0]
const TYPE_NAME := {"circuit": "CIRCUIT RACE", "elim": "ELIMINATOR", "test": "TEST FLIGHT", "shop": "HIBI'S SHOP",
	"mystery": "MYSTERY ENCOUNTER", "finale": "LEAGUE FINALE"}
const TYPE_DESC := {
	"circuit": ["4 LAPS. FINISH IN THE TOP 6.", "CREDITS FOR PLACING AND TAKEDOWNS."],
	"elim": ["LAST PLACE IS CUT EVERY FEW SECONDS.", "SURVIVE TO THE FINAL 3."],
	"test": ["SOLO TIME TRIAL. BEAT THE BRONZE", "TIME OR LOSE YOUR TOKEN."],
	"shop": ["SPEND CREDITS ON PARTS.", "NO RACE."],
	"mystery": ["SOMETHING IS OUT THERE...", "NO RACE."],
	"finale": ["5 LAPS. TOP 3 TO BECOME LEAGUE", "CHAMPION. EVERY HAZARD AT ONCE."],
}
const HOWTO := [
	["CONTROLS", ["WASD OR ARROWS - STEER / THROTTLE / BRAKE", "J - BOOST: HAS ITS OWN HEAT BAR", "K - RAMJET: HUGE THRUST, HEATS UP.", "   HIT REDLINE AND THE ENGINE EXPLODES.", "L - YOUR STYLE ABILITY (SEE GARAGE)", "SPACE - DRIFT: TAP TO HOP, STEER TO SLIDE,", "   TAP INTO THE TURN TO TIGHTEN IT,", "   HOLD TO CHARGE, RELEASE FOR A TURBO", "LEFT HAND WASD, RIGHT HAND J K L SPACE"]],
	["RACING", ["HOLD THROTTLE AT THE GREEN NOTCH ON THE REV", "GAUGE AND CLEAR THE ENGINE START PROMPTS", "FOR A PERFECT LAUNCH.", "RAMJET INTO A RIVAL FOR A TAKEDOWN.", "WALLS AND HITS DAMAGE YOUR CHASSIS. ZERO IS A", "CRASH. YOU RESPAWN AT SPEED, BUT CRASHES ARE", "LIMITED. RUN OUT AND YOUR RUN IS OVER."]],
	["HAZARDS", ["ICE - NO GRIP, BUT COOLS YOUR ENGINE", "ACID - CHASSIS DAMAGE (SHIELD BLOCKS IT)", "LAVA - HEAT AND DAMAGE", "WATER - DRAG, COOLS THE ENGINE", "FUMES - JAM BOOSTS, RAMJET RUNS HOT", "CAVES - DARK. MINES - ION JAMS BOOSTS", "GRAVEL WITH ORANGE RAILS - SHORTCUT"]],
	["EXTRAS", ["GHOST: YOUR BEST RUN IS SAVED AS A GHOST.", "RIVALS: TWO NAMED RACERS REMEMBER YOU.", "   TAKE THEM DOWN AND THEY HUNT YOU.", "EVENTS: STORMS, ROCKFALL, CONVOYS AND ION", "   STRIKES HIT MID-RACE. WATCH THE WARNING.", "GOALS: 3 PER RACE. STARS BUY COSMETICS.", "FINAL LAP: BOOST AND HEAT LIMITS LOOSEN.", "FALLING BEHIND GIVES AN UNDERDOG BOOST."]],
	["MODES", ["CAMPAIGN: A ROGUELIKE TOUR. PICK A ROUTE OF", "RACES, ELIMINATORS AND TEST FLIGHTS. EARN", "CREDITS, BUY PARTS. LOSE YOUR TOKEN AND IT", "IS OVER. WIN THE FINALE AT DERVEN ACOS.", "ELIMINATOR: LAST PLACE IS CUT. SURVIVE.", "DAILY: ONE SHARED TRACK A DAY, STOCK PODS.", "GARAGE: SPEND TUNING POINTS ON PERMANENT", "UPGRADES AND NEW VEHICLES."]],
]
const UPGRADES := [
	{"key": "speed", "name": "TOP SPEED", "per": "+3%"}, {"key": "accel", "name": "ACCELERATION", "per": "+4%"},
	{"key": "cool", "name": "ENGINE COOLING", "per": "+5%"}, {"key": "armor", "name": "ARMOR", "per": "+6%"},
]
const CONFETTI := ["#ffd040", "#ff5050", "#50d0ff", "#60ff90", "#ff70e0", "#ffffff"]

var rc: Race
var inp: Inp
var audio: AudioFx
var host: Node    # Main: make_track()

var scene := "title"
var prev_scene := "title"
var menu_sel := 0
var menu_rows: Array = []
var ui_t := 0.0
var flash := {"text": "", "t": 0.0}
var quick := {"planet": 0, "mode": 0, "laps": 1, "diff": 1, "veh": 0, "style": 0, "seed": 0}
var tf_cfg := {"planet": 0, "veh": 0, "style": 0, "seed": 0}
var camp_cfg := {"veh": 0, "style": 0, "diff": 1}
var tour = null
var last_race_cfg: Dictionary = {}
var race_return := "menu"
var last_result_info: Dictionary = {}
var howto_page := 0
var reward_offers: Array = []
var shop_offers: Array = []
var mystery_event: Dictionary = {}
var tour_end_info: Dictionary = {}
var pause_sel := 0
var paused := false
var loading_cfg: Dictionary = {}
var load_t := 0
var lobby := Lobby.new()
var mp_veh := 0
var mp_style := 0
var cos_idx := {"paint": 0, "flame": 0, "trail": 0}
var cos_veh := 0
var _browse_sig := ""
var _busy := false          # an async track build is in flight
var world_ready := false    # a track is baked and the world can be drawn

var VEH_KEYS: Array = Data.VEH.keys()
var STYLE_KEYS: Array = Data.STYLES.keys()
var PLANET_KEYS: Array = Data.PLANETS.keys()


func _init(race: Race, inp_: Inp, audio_: AudioFx, host_: Node) -> void:
	rc = race
	inp = inp_
	audio = audio_
	host = host_
	quick.seed = seed_for()
	lobby.changed.connect(_on_mp_changed)
	lobby.race_start.connect(_on_mp_start)
	lobby.left.connect(_on_mp_left)
	tf_cfg.seed = seed_for()


func say(text: String, t: float = 1.6) -> void:
	flash.text = text
	flash.t = t


func seed_for() -> int:
	return int(randf() * 1e6)


# ------------------------------------------------------------- attract mode

func start_attract() -> void:
	if _busy:
		return
	_busy = true
	var pool: Array = PLANET_KEYS.filter(func(k): return k != "derven" or randf() < 0.3)
	var pk: String = pool[randi() % pool.size()]
	var trk: Track = await host.make_track(pk, seed_for())
	rc.start_attract(trk)
	world_ready = true
	_busy = false


func update_background(dt: float) -> void:
	if not world_ready:
		return
	if rc.R.phase == "attract":
		if not rc.update_attract(dt):
			world_ready = false
			start_attract()
	else:
		rc.update_race(dt, {"up": false, "dn": true, "steer": 0.0, "ab": false, "ram": false, "drift": false})    # finished race stays alive behind results


# ------------------------------------------------------------- generic menus

func cycle(v: int, dir: int, n: int) -> int:
	return Util.cycle(v, dir, n)


func menu_update() -> void:
	if menu_rows.is_empty():
		return
	var n := menu_rows.size()
	if inp.pressed(Inp.UP):
		menu_sel = cycle(menu_sel, -1, n)
		while menu_rows[menu_sel].get("skip", false):
			menu_sel = cycle(menu_sel, -1, n)
		audio.beep(420, 0.04)
	if inp.pressed(Inp.DN):
		menu_sel = cycle(menu_sel, 1, n)
		while menu_rows[menu_sel].get("skip", false):
			menu_sel = cycle(menu_sel, 1, n)
		audio.beep(420, 0.04)
	var r: Dictionary = menu_rows[menu_sel]
	if inp.pressed(Inp.LF) and r.has("change"):
		r.change.call(-1)
		audio.beep(520, 0.04)
	if inp.pressed(Inp.RT) and r.has("change"):
		r.change.call(1)
		audio.beep(520, 0.04)
	if inp.pressed(Inp.OK) and r.has("act"):
		r.act.call()
		audio.beep(700, 0.07)


func draw_rows(ci: CanvasItem, x: float, y: float, w: float, row_h: float) -> void:
	for i in menu_rows.size():
		var r: Dictionary = menu_rows[i]
		var yy := y + i * row_h
		var sel := i == menu_sel
		if sel:
			ci.draw_rect(Rect2(x - 2, yy - 2, w, row_h - 1), Color(80 / 255.0, 100 / 255.0, 1.0, 0.45))
		var label = r.label
		if label is Callable:
			label = label.call()
		var dim: bool = r.get("dim", false)
		Gfx.txt(ci, ("> " if sel else "  ") + label, x, yy, 1, "#7a80a0" if dim else ("#ffffff" if sel else "#c8d0ff"))
		if r.has("val"):
			var v: String = r.val.call()
			var arrows: bool = r.has("change") and sel
			Gfx.txt_r(ci, ("< " if arrows else "") + v + (" >" if arrows else ""), x + w - 6, yy, 1, "#7a80a0" if dim else "#ffe040")


func go(name: String) -> void:
	prev_scene = scene
	scene = name
	menu_sel = 0
	menu_rows = []
	ui_t = 0.0
	match name:
		"title": _enter_title()
		"menu": _enter_menu()
		"quick": _enter_quick()
		"daily": _enter_daily()
		"test": _enter_test()
		"garage": _enter_garage()
		"cosmetics": _enter_cosmetics()
		"campsetup": _enter_campsetup()
		"route": _enter_route()
		"reward": _enter_reward()
		"shop": _enter_shop()
		"mystery": _enter_mystery()
		"podium": _enter_podium()
		"results": _enter_results()
		"tourend": _enter_tourend()
		"mp": _enter_mp()
		"mp_browse": _enter_mp_browse()
		"mp_lobby": _enter_mp_lobby()
	while menu_sel < menu_rows.size() and menu_rows[menu_sel].get("skip", false):
		menu_sel += 1


func unlocked_veh(i: int) -> bool:
	return SaveData.data.vehicles[VEH_KEYS[i]]


# ---------------------------------------------------------- preview panel

func draw_preview(ci: CanvasItem, x: float, y: float, w: float, veh_key, style_key, planet_key) -> void:
	Gfx.panel(ci, x, y, w, 128)
	var yy := y + 5
	if planet_key != null:
		var pl: Dictionary = Data.PLANETS[planet_key]
		for i in pl.sky.size():
			Gfx.rect(ci, x + 4, yy + i * 2, w - 8, 2, pl.sky[i])
		Gfx.rect(ci, x + 4, yy + 16, w - 8, 5, pl.ground[0])
		Gfx.rect(ci, x + 4 + (w - 8) / 2 - 8, yy + 16, 16, 5, pl.road[0])
		Gfx.txt(ci, pl.name, x + 4, yy + 24, 1, "#ffffff")
		Gfx.txt(ci, pl.blurb, x + 4, yy + 31, 1, "#9fb0ff")
		yy += 42
	if veh_key != null:
		var v: Dictionary = Data.VEH[veh_key]
		var pcb: Array = Cosmetics.cb(veh_key)
		var spr: Texture2D = VehicleModels.frames(veh_key, pcb[0], pcb[1], pcb[2])[0][VehicleModels.YAW_MID]
		ci.draw_texture_rect(spr, Rect2(x + (int(w - 84) >> 1), yy - 6, 84, 56), false)
		var owned: bool = SaveData.data.vehicles[veh_key]
		Gfx.txt(ci, v.name + ("" if owned else " (LOCKED)"), x + 4, yy + 40, 1, "#ffe040" if owned else "#ff6060")
		for i in v.blurb.size():
			Gfx.txt(ci, v.blurb[i], x + 4, yy + 48 + i * 7, 1, "#cfd6ff")
		yy += 66
	if style_key != null:
		var s: Dictionary = Data.STYLES[style_key]
		var ok := SaveData.style_unlocked(style_key)
		Gfx.txt(ci, s.name + ("" if ok else " (LOCKED)"), x + 4, yy, 1, "#60d0ff" if ok else "#ff6060")
		for i in s.blurb.size():
			Gfx.txt(ci, s.blurb[i], x + 4, yy + 8 + i * 7, 1, "#cfd6ff")
		Gfx.txt(ci, "L: " + Data.ABILITY[s.ability].name, x + 4, yy + 24, 1, "#a0ffa0")
		if not ok:
			Gfx.txt(ci, "UNLOCK: " + s.unlock.label, x + 4, yy + 31, 1, "#ff9090")


# ----------------------------------------------------------- starting races

## Shows a loading frame first: building a track takes a moment.
func launch_race(cfg: Dictionary, ret: String) -> void:
	last_race_cfg = cfg
	race_return = ret
	loading_cfg = cfg
	load_t = 0
	scene = "loading"
	menu_rows = []
	paused = false


func can_use(vi: int, si: int) -> bool:
	if not SaveData.data.vehicles[VEH_KEYS[vi]]:
		say("VEHICLE LOCKED - BUY IN THE GARAGE")
		return false
	if not SaveData.style_unlocked(STYLE_KEYS[si]):
		say("STYLE LOCKED: " + Data.STYLES[STYLE_KEYS[si]].unlock.label)
		return false
	return true


func _begin_race() -> void:
	_busy = true
	world_ready = false
	var trk: Track = await host.make_track(loading_cfg.planetKey, loading_cfg.seed)
	rc.setup(loading_cfg, trk)
	lobby.remotes = rc.remotes
	rc.R.endT = 0.0
	paused = false
	scene = "race"
	menu_rows = []
	world_ready = true
	_busy = false


# ---------------------------------------------------------------- campaign

func new_tour() -> void:
	tour = {"veh": VEH_KEYS[camp_cfg.veh], "style": STYLE_KEYS[camp_cfg.style], "diff": camp_cfg.diff, "token": 1, "credits": 100,
		"stage": 0, "parts": [], "scorched": false, "cleared": 0, "choices": [], "seed": seed_for(), "lastPlanet": ""}
	gen_choices()


func _pick(arr: Array):
	return arr[randi() % arr.size()]


func gen_choices() -> void:
	var stage: int = tour.stage
	if stage == TOUR_STAGES - 1:
		tour.choices = [{"type": "finale", "planet": "derven"}]
		return
	var out: Array = []
	var n := 2 + (1 if randf() < 0.5 else 0)
	var pool: Array = PLANET_KEYS.filter(func(k): return k != "derven" and k != tour.lastPlanet)
	for i in n:
		var type: String = _pick(["circuit", "circuit", "circuit", "elim", "elim", "test", "test", "shop", "mystery"])
		if i == 0:
			type = _pick(["circuit", "elim", "circuit"])
		if stage == 0 and (type == "shop" or type == "mystery"):
			type = "circuit"
		out.append({"type": type, "planet": _pick(pool)})
	tour.choices = out


func node_race(node: Dictionary) -> Dictionary:
	var base := {"planetKey": node.planet, "seed": seed_for(), "diff": tour.diff, "veh": tour.veh, "style": tour.style, "parts": tour.parts,
		"scorched": tour.scorched, "botSkill": 0.97 + 0.025 * tour.stage, "tour": true}
	if node.type == "circuit":
		base.merge({"mode": "circuit", "laps": 4})
	elif node.type == "finale":
		base.merge({"mode": "circuit", "laps": 5, "botSkill": 1.08, "finale": true}, true)
	elif node.type == "elim":
		base.merge({"mode": "elim"})
	else:
		base.merge({"mode": "test", "laps": 3})
	return base


func evaluate_result() -> Dictionary:
	var res = rc.R.result
	var cfg: Dictionary = rc.R.cfg
	var info := {"lines": [], "right": [], "pass": true, "credits": 0, "title": "", "tour": cfg.get("tour", false)}
	if res == null:
		return info
	if res.kind == "wrecked":
		info.title = "WRECKED"
		info.pass = false
		info.lines.append("CRASH LIMIT EXCEEDED.")
	elif res.kind == "eliminated":
		info.title = "ELIMINATED"
		info.pass = false
		info.lines.append("YOU WERE LAST PLACE WHEN THE CLOCK RAN OUT.")
	elif cfg.mode == "test":
		info.title = ["NO MEDAL", "BRONZE MEDAL", "SILVER MEDAL", "GOLD MEDAL"][res.medal]
		info.pass = res.medal >= 1
		info.credits = [0, 70, 120, 200][res.medal]
		info.lines.append("TIME " + Util.fmt_time(res.time) + "   PAR " + Util.fmt_time(rc.R.tfPar))
	elif cfg.mode == "elim":
		info.title = "VICTORY!" if res.rank == 1 else "SURVIVED!"
		var cr := [220, 170, 130]
		info.credits = cr[res.rank - 1] if res.rank >= 1 and res.rank <= 3 else 0
		info.lines.append("FINAL %d - YOU PLACED %d" % [rc.R.alive, res.rank])
	else:
		var need := 3 if cfg.get("finale", false) else 6
		info.title = "VICTORY!" if res.rank == 1 else "FINISH!"
		info.credits = CIRCUIT_CREDITS[res.rank - 1] if res.rank >= 1 and res.rank <= 12 else 0
		info.pass = (not cfg.get("tour", false)) or res.rank <= need
		info.lines.append("PLACE %d OF 12   TIME %s" % [res.rank, Util.fmt_time(res.time)])
		if cfg.get("tour", false) and not info.pass:
			info.lines.append("NEEDED TOP %d TO ADVANCE." % need)
	if res.takedowns > 0:
		info.credits += res.takedowns * 15
		info.lines.append("%d TAKEDOWNS  +%d CREDITS" % [res.takedowns, res.takedowns * 15])
	if res.kind == "finish" and res.rank == 1 and cfg.mode != "test":
		SaveData.data.stats.wins += 1
		SaveData.persist()
	if res.lapBest > 0.0 and cfg.mode != "elim":
		info.lines.append("BEST LAP " + Util.fmt_time(res.lapBest))
		var key: String = "%s|%d" % [cfg.planetKey, cfg.seed]
		var best: Dictionary = SaveData.data.best
		if not best.has(key) or res.lapBest < best[key]:
			best[key] = res.lapBest
	info.lines.append("CRASHES %d" % res.crashes)
	if res.ghostNew:
		info.lines.append({"t": "NEW BEST - GHOST SAVED", "c": "#80e0ff"})
	if rc.P.overheated and cfg.get("tour", false):
		tour.scorched = true
		info.lines.append("ENGINE SCORCHED: -10% TOP SPEED THIS TOUR.")
	# mastery goals
	var right: Array = []
	if res.goals.size() > 0:
		var done := 0
		for g in res.goals:
			if g.done:
				done += 1
			right.append({"t": ("+ " if g.done else ("X " if g.failed else "- ")) + g.label + " " + "*".repeat(g.tier),
				"c": "#60ff90" if g.done else ("#ff7070" if g.failed else "#aab4e8")})
		right.insert(0, {"t": "GOALS %d/3" % done, "c": "#ffe040"})
		if res.stars > 0:
			right.append({"t": "+%d STARS" % res.stars, "c": "#ffd040"})
			info.credits += res.stars * 15
	# rivals
	for r in res.rivals:
		if r.get("new", false):
			right.append({"t": "NEW RIVAL: " + r.name, "c": "#ff9a40"})
			continue
		if not Rivals.is_rival(r.name):    # beaten so often they retired
			right.append({"t": "%s RETIRES. YOU OWN THEM." % r.name, "c": "#9fe8ff"})
			continue
		var rec: Dictionary = Rivals.rec(r.name)
		right.append({"t": "*%s %s W%d L%d%s" % [r.name, "BEATEN" if r.beat else "BEAT YOU", int(rec.l), int(rec.w), " HUNTING" if Rivals.hunting(r.name) else ""],
			"c": "#9fe8ff" if r.beat else "#ff6a6a"})
		right.append({"t": r.name + ": " + r.text, "c": "#ffb870"})
	info.right = right
	if cfg.get("daily", false) and res.kind == "finish":
		_daily_result(info, res, cfg)
	return info


func random_parts(n: int) -> Array:
	var pool: Array = Data.PARTS.keys()
	pool.shuffle()
	var out: Array = pool.slice(0, n)
	if tour != null and randf() < 0.6:    # lean the offers towards completing a synergy
		var cands := _synergy_parts()
		if cands.size() > 0:
			var pick: String = _pick(cands)
			if not out.has(pick):
				out[0] = pick
	return out


## Parts that would complete a synergy given what the tour already owns.
func _synergy_parts() -> Array:
	var out: Array = []
	for id in Data.SYNERGIES:
		var needs: Array = Data.SYNERGIES[id].needs
		var have := 0
		var missing := ""
		for nd in needs:
			if tour.parts.has(nd):
				have += 1
			else:
				missing = nd
		if have == needs.size() - 1 and missing != "" and not out.has(missing):
			out.append(missing)
	return out


## The synergy buying this part would complete ("" if none).
func syn_for(part: String) -> String:
	if tour == null:
		return ""
	for id in Data.SYNERGIES:
		var needs: Array = Data.SYNERGIES[id].needs
		if not needs.has(part) or tour.parts.has(part):
			continue
		var ok := true
		for nd in needs:
			if nd != part and not tour.parts.has(nd):
				ok = false
		if ok:
			return id
	return ""


## Synergies the tour already has.
func active_synergies() -> Array:
	var out: Array = []
	if tour == null:
		return out
	for id in Data.SYNERGIES:
		var all := true
		for nd in Data.SYNERGIES[id].needs:
			if not tour.parts.has(nd):
				all = false
		if all:
			out.append(id)
	return out


func advance_stage() -> void:
	tour.cleared += 1
	tour.stage += 1
	if tour.stage >= TOUR_STAGES:
		end_tour(true)
		return
	gen_choices()
	go("route")


func end_tour(complete: bool) -> void:
	var tp: int = tour.cleared * 2 + (10 if complete else 0)
	SaveData.data.tp += tp
	if complete:
		SaveData.data.stats.tours += 1
	SaveData.persist()
	tour_end_info = {"complete": complete, "tp": tp, "cleared": tour.cleared}
	go("tourend")


# ------------------------------------------------------------ daily challenge

static func _date_key(unix: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(unix))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Today's shared challenge: the date picks the track, the (loaned, stock) pod and the style, so every player races the same thing.
func daily_info() -> Dictionary:
	var dt := Time.get_datetime_dict_from_system(true)
	var n: int = int(dt.year) * 372 + int(dt.month) * 31 + int(dt.day)
	var pool: Array = PLANET_KEYS.filter(func(k): return k != "derven")
	return {"key": _date_key(Time.get_unix_time_from_system()), "seed": (n * 7919) % 1000003, "planet": pool[n % pool.size()],
		"veh": VEH_KEYS[n % VEH_KEYS.size()], "style": ["survivor", "tenacious", "ramjetrider"][(n / 3) % 3]}


func _daily_cfg(di: Dictionary) -> Dictionary:
	return {"mode": "circuit", "planetKey": di.planet, "seed": di.seed, "laps": 3, "diff": 1, "veh": di.veh, "style": di.style,
		"parts": [], "scorched": false, "daily": true, "dailyKey": di.key}


func _daily_result(info: Dictionary, res: Dictionary, cfg: Dictionary) -> void:
	var d: Dictionary = SaveData.data.daily
	var key: String = cfg.dailyKey
	var prev = d.best.get(key)
	info.lines.append({"t": "DAILY " + key, "c": "#80e0ff"})
	if prev == null or res.time < float(prev.time):
		d.best[key] = {"time": res.time, "rank": res.rank}
		info.lines.append({"t": "NEW DAILY BEST!", "c": "#ffd040"})
	if d.last != key:    # first finish of the day: streak + reward
		var yesterday := _date_key(Time.get_unix_time_from_system() - 86400.0)
		d.streak = (int(d.streak) + 1) if d.last == yesterday else 1
		d.last = key
		var tp := 2 + mini(int(d.streak) - 1, 5)
		SaveData.data.tp += tp
		SaveData.data.stars += 1
		SaveData.data.stats.dailies += 1
		info.lines.append({"t": "STREAK %d: +%d TP +1 STAR" % [int(d.streak), tp], "c": "#a0ffa0"})
	SaveData.persist()


# ----------------------------------------------------------------- screens

func planet_row(c: Dictionary) -> Dictionary:
	return {"label": "PLANET", "val": func(): return Data.PLANETS[PLANET_KEYS[c.planet]].name,
		"change": func(d): c.planet = cycle(c.planet, d, PLANET_KEYS.size())}


func veh_row(c: Dictionary) -> Dictionary:
	return {"label": "VEHICLE", "val": func(): return Data.VEH[VEH_KEYS[c.veh]].name + ("" if unlocked_veh(c.veh) else " *"),
		"change": func(d): c.veh = cycle(c.veh, d, VEH_KEYS.size())}


func style_row(c: Dictionary) -> Dictionary:
	return {"label": "STYLE", "val": func(): return Data.STYLES[STYLE_KEYS[c.style]].name + ("" if SaveData.style_unlocked(STYLE_KEYS[c.style]) else " *"),
		"change": func(d): c.style = cycle(c.style, d, STYLE_KEYS.size())}


func diff_row(c: Dictionary) -> Dictionary:
	return {"label": "DIFFICULTY", "val": func(): return "%s X%d" % [Data.DIFFS[c.diff].name, Data.DIFFS[c.diff].crashes],
		"change": func(d): c.diff = cycle(c.diff, d, Data.DIFFS.size())}


func _enter_title() -> void:
	if rc.R.phase != "attract" and not _busy:
		start_attract()


func _enter_menu() -> void:
	if rc.R.phase != "attract" and not _busy:
		start_attract()
	menu_rows = [
		{"label": "CAMPAIGN", "act": func(): go("campsetup")},
		{"label": "QUICK RACE", "act": func(): go("quick")},
		{"label": "DAILY CHALLENGE", "act": func(): go("daily")},
		{"label": "TEST FLIGHT", "act": func(): go("test")},
		{"label": "MULTIPLAYER", "act": func(): go("mp")},
		{"label": "GARAGE", "act": func(): go("garage")},
		{"label": "HOW TO PLAY", "act": func():
			howto_page = 0
			go("howto")},
	]


func _enter_quick() -> void:
	menu_rows = [
		planet_row(quick),
		{"label": "MODE", "val": func(): return ["CIRCUIT RACE", "ELIMINATOR"][quick.mode], "change": func(d): quick.mode = cycle(quick.mode, d, 2)},
		{"label": "LAPS", "val": func(): return str(LAP_OPTIONS[quick.laps]), "change": func(d): quick.laps = cycle(quick.laps, d, LAP_OPTIONS.size())},
		diff_row(quick), veh_row(quick), style_row(quick),
		{"label": "TRACK SEED", "val": func(): return "#" + str(quick.seed), "change": func(d): quick.seed = maxi(0, quick.seed + d),
			"act": func(): quick.seed = seed_for()},
		{"label": "START RACE", "act": func():
			if not can_use(quick.veh, quick.style):
				return
			launch_race({"mode": ["circuit", "elim"][quick.mode], "planetKey": PLANET_KEYS[quick.planet], "seed": quick.seed,
				"laps": LAP_OPTIONS[quick.laps], "diff": quick.diff, "veh": VEH_KEYS[quick.veh], "style": STYLE_KEYS[quick.style],
				"parts": [], "scorched": false}, "quick")},
	]


func _enter_daily() -> void:
	var di := daily_info()
	menu_rows = [
		{"label": "START DAILY RACE", "act": func(): launch_race(_daily_cfg(di), "daily")},
		{"label": "BACK", "act": func(): go("menu")},
	]


func _enter_test() -> void:
	menu_rows = [planet_row(tf_cfg), veh_row(tf_cfg), style_row(tf_cfg),
		{"label": "TRACK SEED", "val": func(): return "#" + str(tf_cfg.seed), "change": func(d): tf_cfg.seed = maxi(0, tf_cfg.seed + d),
			"act": func(): tf_cfg.seed = seed_for()},
		{"label": "START TEST FLIGHT", "act": func():
			if not can_use(tf_cfg.veh, tf_cfg.style):
				return
			launch_race({"mode": "test", "planetKey": PLANET_KEYS[tf_cfg.planet], "seed": tf_cfg.seed, "laps": 3, "diff": 1,
				"veh": VEH_KEYS[tf_cfg.veh], "style": STYLE_KEYS[tf_cfg.style], "parts": [], "scorched": false}, "test")}]


func _up_cost(lv: int) -> int:
	return 3 + lv * 2


func _enter_garage() -> void:
	menu_rows = []
	for vk in VEH_KEYS:
		if Data.VEH[vk].cost > 0:
			menu_rows.append({"label": Data.VEH[vk].name,
				"val": func(): return "OWNED" if SaveData.data.vehicles[vk] else "%d TP" % Data.VEH[vk].cost,
				"act": func():
					if SaveData.data.vehicles[vk]:
						say("ALREADY OWNED")
						return
					if SaveData.data.tp < Data.VEH[vk].cost:
						say("NOT ENOUGH TUNING POINTS")
						return
					SaveData.data.tp -= Data.VEH[vk].cost
					SaveData.data.vehicles[vk] = true
					SaveData.persist()
					say("UNLOCKED " + Data.VEH[vk].name)})
	for u in UPGRADES:
		menu_rows.append({"label": func(): return u.name + " " + u.per,
			"val": func(): return "MAX" if SaveData.data.up[u.key] >= 5 else "LV %d/5  %d TP" % [SaveData.data.up[u.key], _up_cost(SaveData.data.up[u.key])],
			"act": func():
				var lv: int = SaveData.data.up[u.key]
				if lv >= 5:
					say("ALREADY MAXED")
					return
				if SaveData.data.tp < _up_cost(lv):
					say("NOT ENOUGH TUNING POINTS")
					return
				SaveData.data.tp -= _up_cost(lv)
				SaveData.data.up[u.key] += 1
				SaveData.persist()
				say(u.name + " UPGRADED")})
	menu_rows.append({"label": "COSMETICS", "val": func(): return "%d STARS" % SaveData.data.stars, "act": func(): go("cosmetics")})
	menu_rows.append({"label": "BACK", "act": func(): go("menu")})


func _enter_cosmetics() -> void:
	for cat in Cosmetics.CATS:
		cos_idx[cat] = maxi(0, Cosmetics.keys(cat).find(Cosmetics.equipped(cat)))
	menu_rows = []
	for cat in Cosmetics.CATS:
		menu_rows.append({"label": Cosmetics.CAT_NAME[cat], "val": func(): return _cos_val(cat),
			"change": func(d): cos_idx[cat] = cycle(cos_idx[cat], d, Cosmetics.keys(cat).size()),
			"act": func(): _cos_act(cat)})
	menu_rows.append({"label": "PREVIEW POD", "val": func(): return Data.VEH[VEH_KEYS[cos_veh]].name,
		"change": func(d):
			for k in VEH_KEYS.size():
				cos_veh = cycle(cos_veh, d, VEH_KEYS.size())
				if unlocked_veh(cos_veh):
					break})
	menu_rows.append({"label": "BACK", "act": func(): go("garage")})


func _cos_val(cat: String) -> String:
	var key: String = Cosmetics.keys(cat)[cos_idx[cat]]
	var t: Dictionary = Cosmetics.table(cat)[key]
	var status := "EQUIPPED" if Cosmetics.equipped(cat) == key else ("OWNED" if Cosmetics.owned(cat, key) else "%d STARS" % t.cost)
	return t.name + " - " + status


func _cos_act(cat: String) -> void:
	var key: String = Cosmetics.keys(cat)[cos_idx[cat]]
	var err := Cosmetics.buy(cat, key)
	if err != "":
		say(err)
		return
	Cosmetics.equip(cat, key)
	say("EQUIPPED " + Cosmetics.table(cat)[key].name)


func _enter_campsetup() -> void:
	menu_rows = [veh_row(camp_cfg), style_row(camp_cfg), diff_row(camp_cfg),
		{"label": "START TOUR", "act": func():
			if not can_use(camp_cfg.veh, camp_cfg.style):
				return
			new_tour()
			go("route")}]


func _enter_route() -> void:
	menu_rows = []
	for n in tour.choices:
		menu_rows.append({"label": func(): return TYPE_NAME[n.type] + ("" if (n.type == "shop" or n.type == "mystery") else " - " + Data.PLANETS[n.planet].name),
			"act": func():
				if n.type == "shop":
					go("shop")
					return
				if n.type == "mystery":
					go("mystery")
					return
				launch_race(node_race(n), "route")})


func _enter_reward() -> void:
	menu_rows = []
	for p in reward_offers:
		var syn := syn_for(p)
		menu_rows.append({"label": Data.PARTS[p].name + ("" if syn == "" else " [" + Data.SYNERGIES[syn].name + "]"),
			"val": func(): return Data.PARTS[p].desc,
			"act": func():
				tour.parts.append(p)
				advance_stage()})


func _enter_shop() -> void:
	shop_offers = []
	for p in random_parts(3):
		shop_offers.append({"p": p, "price": 60 + (randi() % 4) * 10, "sold": false})
	rebuild_shop()


func rebuild_shop() -> void:
	menu_rows = []
	for o in shop_offers:
		menu_rows.append({"label": Data.PARTS[o.p].name + " - " + Data.PARTS[o.p].desc,
			"val": func(): return "SOLD" if o.sold else "%dC" % o.price,
			"act": func():
				if o.sold:
					return
				if tour.credits < o.price:
					say("NOT ENOUGH CREDITS")
					return
				tour.credits -= o.price
				o.sold = true
				tour.parts.append(o.p)
				say("INSTALLED " + Data.PARTS[o.p].name)})
	menu_rows.append({"label": "LEAVE SHOP", "act": func(): advance_stage()})


func _mysteries() -> Array:
	return [
		{"title": "DERELICT SKIFF", "text": ["A STRIPPED SKIFF DRIFTS NEAR THE PITS.", "ITS HOLD IS STILL SEALED."],
			"opts": [{"label": "SALVAGE IT (GAMBLE)", "fn": func():
				if randf() < 0.6:
					tour.credits += 90
					return "SCRAPPED 90 CREDITS OF PARTS!"
				tour.credits = maxi(0, tour.credits - 40)
				return "BOOBY-TRAPPED. LOST 40 CREDITS."}, {"label": "LEAVE IT", "fn": func(): return "YOU MOVE ON."}]},
		{"title": "LOST TOOLBOX", "text": ["A MECHANIC WAVES YOU OVER.", "\"THIS FELL OFF A TRANSPORT. TAKE IT.\""],
			"opts": [{"label": "TAKE IT", "fn": func():
				var p: String = random_parts(1)[0]
				tour.parts.append(p)
				return "FOUND: " + Data.PARTS[p].name}]},
		{"title": "SHADY MECHANIC", "text": ["\"I CAN TUNE YOU UP FOR 60 CREDITS.", "NO QUESTIONS.\""],
			"opts": [{"label": "PAY 60 CREDITS", "fn": func():
				if tour.credits < 60:
					return "YOU CANNOT AFFORD IT."
				tour.credits -= 60
				var p: String = random_parts(1)[0]
				tour.parts.append(p)
				return "INSTALLED: " + Data.PARTS[p].name}, {"label": "DECLINE", "fn": func(): return "YOU WALK AWAY."}]},
	]


func _enter_mystery() -> void:
	mystery_event = _pick(_mysteries()).duplicate()
	mystery_event.result = null
	menu_rows = []
	for o in mystery_event.opts:
		menu_rows.append({"label": o.label, "act": func():
			mystery_event.result = o.fn.call()
			menu_rows = [{"label": "CONTINUE", "act": func(): advance_stage()}]
			menu_sel = 0})


func _return_scene() -> String:
	return "test" if race_return == "test" else ("daily" if race_return == "daily" else "quick")


func _has_podium() -> bool:
	var res = rc.R.result
	return res != null and res.kind == "finish" and race_return != "mp" and rc.R.cfg.mode != "test" and res.podium.size() > 0


## After the finish screen (and any replay): the podium if you finished, otherwise straight to the results.
func _after_race() -> void:
	go("podium" if _has_podium() else "results")


func _enter_podium() -> void:
	menu_rows = [{"label": "CONTINUE", "act": func(): go("results")}]


func _enter_results() -> void:
	last_result_info = evaluate_result()
	var info := last_result_info
	if tour != null:
		tour.credits += info.credits
	menu_rows = [{"label": "CONTINUE", "act": func():
		start_attract()
		if tour != null:
			if not info.pass:
				tour.token -= 1
				end_tour(false)
				return
			reward_offers = random_parts(3)
			go("reward")
		else:
			if race_return == "mp" and lobby.active:
				lobby.set_mine(lobby.me().veh, lobby.me().style, false)
				go("mp_lobby")
			else:
				go(_return_scene())}]
	if tour == null and race_return != "mp":
		menu_rows.append({"label": "RETRY THIS TRACK", "act": func(): launch_race(last_race_cfg, race_return)})


func _enter_tourend() -> void:
	menu_rows = [{"label": "CONTINUE", "act": func():
		tour = null
		go("menu")}]


# ------------------------------------------------------------ multiplayer

func _on_mp_changed() -> void:
	if (scene == "mp" or scene == "mp_browse") and lobby.active and not lobby.players.is_empty():
		mp_veh = 0
		mp_style = 0
		go("mp_lobby")


func _on_mp_start(cfg: Dictionary) -> void:
	cfg.mp_local = lobby.net.local_id
	launch_race(cfg, "mp")


func _on_mp_left(reason: String) -> void:
	lobby.active = false
	say(reason)
	if scene == "mp_lobby" or scene == "mp_browse" or scene == "mp" or scene == "race" or scene == "loading":
		go("mp")


func _enter_mp() -> void:
	menu_rows = [
		{"label": "HOST STEAM LOBBY", "act": func():
			if not lobby.available():
				say("STEAM NOT AVAILABLE")
				return
			lobby.settings.seed = seed_for()
			lobby.host()},
		{"label": "BROWSE LOBBIES", "act": func():
			if not lobby.available():
				say("STEAM NOT AVAILABLE")
				return
			go("mp_browse")},
		{"label": "BACK", "act": func(): go("menu")},
	]


func _enter_mp_browse() -> void:
	_browse_sig = ""
	lobby.net.request_lobbies()
	_refresh_browse()


func _refresh_browse() -> void:
	var sig := str(lobby.net.lobby_list)
	if sig == _browse_sig:
		return
	_browse_sig = sig
	menu_rows = []
	for l in lobby.net.lobby_list:
		menu_rows.append({"label": l.name, "val": func(): return "%d/%d" % [l.players, l.max], "act": func(): lobby.join(l.id)})
	menu_rows.append({"label": "REFRESH", "act": func():
		_browse_sig = ""
		lobby.net.request_lobbies()})
	menu_rows.append({"label": "BACK", "act": func(): go("mp")})
	menu_sel = clampi(menu_sel, 0, menu_rows.size() - 1)


func _mp_pick(cur: int, d: int, keys: Array, unlocked: Callable) -> int:
	var v := cur
	for k in keys.size():
		v = cycle(v, d, keys.size())
		if unlocked.call(v):
			return v
	return cur


func _enter_mp_lobby() -> void:
	var host := lobby.is_host()
	var rows: Array = []
	rows.append({"label": "PLANET", "dim": not host, "val": func(): return Data.PLANETS[PLANET_KEYS[lobby.settings.planet]].name})
	rows.append({"label": "LAPS", "dim": not host, "val": func(): return str(lobby.settings.laps)})
	rows.append({"label": "TRACK SEED", "dim": not host, "val": func(): return "#" + str(lobby.settings.seed)})
	if host:
		rows[0].change = func(d): lobby.set_settings(cycle(lobby.settings.planet, d, PLANET_KEYS.size()), lobby.settings.laps, lobby.settings.seed)
		rows[1].change = func(d): lobby.set_settings(lobby.settings.planet, clampi(lobby.settings.laps + d, 1, 9), lobby.settings.seed)
		rows[2].change = func(d): lobby.set_settings(lobby.settings.planet, lobby.settings.laps, maxi(0, lobby.settings.seed + d))
		rows[2].act = func(): lobby.set_settings(lobby.settings.planet, lobby.settings.laps, seed_for())
	rows.append({"label": "VEHICLE", "val": func(): return Data.VEH[VEH_KEYS[mp_veh]].name,
		"change": func(d):
			mp_veh = _mp_pick(mp_veh, d, VEH_KEYS, func(i): return unlocked_veh(i))
			lobby.set_mine(VEH_KEYS[mp_veh], STYLE_KEYS[mp_style], false)})
	rows.append({"label": "STYLE", "val": func(): return Data.STYLES[STYLE_KEYS[mp_style]].name,
		"change": func(d):
			mp_style = _mp_pick(mp_style, d, STYLE_KEYS, func(i): return SaveData.style_unlocked(STYLE_KEYS[i]))
			lobby.set_mine(VEH_KEYS[mp_veh], STYLE_KEYS[mp_style], false)})
	rows.append({"label": "READY", "val": func(): return "YES" if lobby.me().get("ready", false) else "NO",
		"act": func(): lobby.set_mine(VEH_KEYS[mp_veh], STYLE_KEYS[mp_style], not lobby.me().get("ready", false))})
	if host:
		rows.append({"label": "START RACE", "act": func():
			if lobby.all_ready():
				lobby.start_race()
			else:
				say("EVERYONE MUST BE READY")})
	rows.append({"label": "LEAVE LOBBY", "act": func():
		lobby.leave()
		go("mp")})
	menu_rows = rows
	lobby.set_mine(VEH_KEYS[mp_veh], STYLE_KEYS[mp_style], false)


# ------------------------------------------------------------- per-frame

func update(dt: float) -> void:
	ui_t += dt
	if flash.t > 0.0:
		flash.t -= dt
	lobby.poll(dt)
	if scene == "race":
		_update_race_screen(dt)
		return
	update_background(dt)
	match scene:
		"loading":
			load_t += 1
			if load_t >= 3 and not _busy:
				_begin_race()
		"title":
			if inp.pressed(Inp.OK):
				go("menu")
				audio.beep(700, 0.1)
		"menu":
			menu_update()
			if inp.pressed(Inp.BACK):
				go("title")
		"howto":
			if inp.pressed(Inp.LF):
				howto_page = cycle(howto_page, -1, HOWTO.size())
			if inp.pressed(Inp.RT):
				howto_page = cycle(howto_page, 1, HOWTO.size())
			if inp.pressed(Inp.BACK + Inp.OK):
				go("menu")
		"mp", "mp_lobby":
			menu_update()
			if inp.pressed(Inp.BACK) and scene == "mp":
				go("menu")
		"mp_browse":
			_refresh_browse()
			menu_update()
			if inp.pressed(Inp.BACK):
				go("mp")
		"quick", "test", "campsetup", "garage", "daily":
			menu_update()
			if inp.pressed(Inp.BACK):
				go("menu")
		"cosmetics":
			menu_update()
			if inp.pressed(Inp.BACK):
				go("garage")
		_:
			menu_update()


func _race_input() -> Dictionary:
	return {"up": inp.down(Inp.UP), "dn": inp.down(Inp.DN), "steer": (1.0 if inp.down(Inp.RT) else 0.0) - (1.0 if inp.down(Inp.LF) else 0.0),
		"ab": inp.down(Inp.AB), "ram": inp.down(Inp.RAM), "drift": inp.down(Inp.DRIFT)}


func _update_race_screen(dt: float) -> void:
	var ph: String = rc.R.phase
	if paused:
		var rows: Array = ["RESUME", "ABANDON TOUR"] if tour != null else ["RESUME", "RESTART", "QUIT"]
		if inp.pressed(Inp.UP):
			pause_sel = cycle(pause_sel, -1, rows.size())
		if inp.pressed(Inp.DN):
			pause_sel = cycle(pause_sel, 1, rows.size())
		if inp.pressed(Inp.PAUSE + Inp.BACK):
			paused = false
		if inp.pressed(Inp.OK):
			var r: String = rows[pause_sel]
			if r == "RESUME":
				paused = false
			elif r == "RESTART":
				launch_race(last_race_cfg, race_return)
			elif r == "QUIT":
				paused = false
				world_ready = false
				start_attract()
				go(_return_scene())
			elif r == "ABANDON TOUR":
				paused = false
				world_ready = false
				start_attract()
				end_tour(false)
		return
	if ph == "replay":    # replay of the last overtake; Enter skips
		var playing := rc.update_replay(dt)
		if inp.pressed(Inp.OK) or not playing:
			rc.end_replay()
			_after_race()
		return
	if inp.pressed(Inp.PAUSE + Inp.BACK) and (ph == "race" or ph == "countdown") and race_return != "mp":
		paused = true
		pause_sel = 0
		return
	if rc.hitstop > 0.0:    # a brief freeze on big hits
		rc.hitstop -= dt
		return
	var slow: bool = rc.R.slowT > 0.0
	if slow:
		rc.R.slowT -= dt
	rc.update_race(dt * (0.35 if slow else 1.0), _race_input())
	if race_return == "mp" and lobby.active:
		var fin := -1.0
		if rc.R.result != null and rc.R.result.kind == "finish":
			fin = rc.R.result.time
		lobby.send_state(rc.P, rc.P.total, fin, dt)
	if ph == "finished" or ph == "wrecked" or ph == "eliminated":
		rc.R.endT += dt
		if rc.R.endT > 1.4 and inp.pressed(Inp.OK):
			if ph == "finished" and rc.can_replay():
				rc.begin_replay()
			else:
				_after_race()


# -------------------------------------------------------------- drawing

## Draws the active screen over the world (everything the reference's SCREENS[...].draw() did).
func draw(ci: CanvasItem) -> void:
	if scene == "race":
		_draw_race_overlays(ci)
	else:
		if world_ready:
			ci.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 24 / 255.0, 0.28))
		_draw_screen(ci)
	if flash.t > 0.0:
		var tw := Gfx.txt_w(flash.text, 1)
		Gfx.panel(ci, W / 2.0 - tw / 2.0 - 8, 192, tw + 16, 14, 0.85)
		Gfx.txt_c(ci, flash.text, 196, 1, "#ffe040")


## Splits entries (strings or {t, c}) into lines of at most `n` characters.
func _wrap_lines(arr: Array, n: int) -> Array:
	var out: Array = []
	for e in arr:
		var text: String = e if e is String else e.t
		var col: String = "#e0e8ff" if e is String else e.c
		var words := text.split(" ", false)
		var cur := ""
		for w in words:
			if cur != "" and cur.length() + 1 + w.length() > n:
				out.append({"t": cur, "c": col})
				cur = "  " + w
			else:
				cur = w if cur == "" else cur + " " + w
		if cur != "":
			out.append({"t": cur, "c": col})
	return out


func _confetti(ci: CanvasItem, t: float) -> void:
	for i in 70:
		var cx := fposmod(i * 37.0 + sin(i * 1.7 + t * 2.0) * 14.0, W)
		var cy := fposmod(t * (40.0 + (i % 5) * 18.0) + i * 29.0, H + 10.0) - 6.0
		ci.draw_rect(Rect2(cx, cy, 2 + (i % 2), 2), Gfx.C(CONFETTI[i % CONFETTI.size()]))


func _draw_podium(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 20 / 255.0, 0.5))
	var res: Dictionary = rc.R.result
	var pod: Array = res.podium
	Gfx.txt_c(ci, "PODIUM", 8, 3, "#ffe040", "#7a1a1a")
	# the loudest rival has something to say
	var quote := ""
	var qcol := "#ffb870"
	for r in res.rivals:
		if r.get("text", "") != "":
			quote = r.name + ": " + r.text
			qcol = "#9fe8ff" if r.beat else "#ff9a40"
			if not r.beat:
				break
	if quote != "":
		Gfx.txt_c(ci, quote, 32, 1, qcol)
	# blocks: 2nd on the left, 1st in the middle, 3rd on the right
	var slots := [[1, 48.0, 32.0], [0, 102.0, 46.0], [2, 156.0, 22.0]]
	var base_y := 182.0
	for sl in slots:
		var idx: int = sl[0]
		if idx >= pod.size():
			continue
		var e: Dictionary = pod[idx]
		var bx: float = sl[1]
		var bh: float = sl[2]
		var top := base_y - bh
		ci.draw_rect(Rect2(bx, top, 52, bh), Color(30 / 255.0, 36 / 255.0, 80 / 255.0, 0.95))
		ci.draw_rect(Rect2(bx, top, 52, 2), Gfx.C("#ffd040" if idx == 0 else ("#c8d0e0" if idx == 1 else "#c88850")))
		Gfx.txt(ci, str(idx + 1), bx + 22, top + 6, 3, "#ffd040" if idx == 0 else "#e0e8ff")
		var spr: Texture2D = VehicleModels.frames(e.cls, e.col[0], e.col[1], e.col[2])[0][VehicleModels.YAW_MID]
		var bob := sin(ui_t * 3.0 + idx) * 1.5
		ci.draw_texture_rect(spr, Rect2(bx - 4, top - 40 + bob, 60, 40), false)
		var nm: String = e.name
		Gfx.txt(ci, nm, int(bx + 26 - Gfx.txt_w(nm, 1) / 2.0), base_y + 4, 1, "#ffd040" if e.you else ("#ff9a40" if e.rival else "#cfd6ff"))
	if res.rank > 3:
		Gfx.txt_c(ci, "YOU FINISHED %s" % Race.ordinal(res.rank), 160, 1, "#ffffff")
	if res.rank == 1:
		_confetti(ci, ui_t)
	draw_rows(ci, 90, 200, 90, 12)


func _draw_results(ci: CanvasItem) -> void:
	var info := last_result_info
	Gfx.txt_c(ci, info.title, 6, 3, "#ffe040" if info.pass else "#ff5050")
	var lrows := _wrap_lines(info.lines, 27)
	var rrows := _wrap_lines(info.right, 27)
	var nrows := maxi(lrows.size(), rrows.size())
	var ph := 8 + nrows * 9
	var py := 26
	Gfx.panel(ci, 5, py, 122, ph, 0.88)
	if rrows.size() > 0:
		Gfx.panel(ci, 129, py, 122, ph, 0.88)
	for j in lrows.size():
		Gfx.txt(ci, lrows[j].t, 10, py + 6 + j * 9, 1, lrows[j].c)
	for j in rrows.size():
		Gfx.txt(ci, rrows[j].t, 134, py + 6 + j * 9, 1, rrows[j].c)
	var y := py + ph + 6
	if info.credits > 0:
		Gfx.txt_c(ci, "+%d CREDITS" % info.credits, y, 1, "#a0ffa0")
		y += 9
	if tour != null:
		Gfx.txt_c(ci, "CHOOSE A PART NEXT" if info.pass else "YOU LOSE YOUR LEAGUE TOKEN", y, 1, "#9fb0ff" if info.pass else "#ff9090")
		y += 9
	draw_rows(ci, 90, y + 4, 90, 12)


func _draw_screen(ci: CanvasItem) -> void:
	match scene:
		"loading":
			Gfx.panel(ci, 48, 80, 160, 44, 0.9)
			Gfx.txt_c(ci, "GENERATING TRACK", 90, 2, "#ffe040")
			Gfx.txt_c(ci, Data.PLANETS[loading_cfg.planetKey].name, 110, 1, "#9fb0ff")
		"title":
			Gfx.txt_c(ci, "OUTER RIM", 22, 5, "#ffe040", "#7a1a1a")
			Gfx.txt_c(ci, "RACER", 52, 7, "#ffffff", "#1a2a7a")
			if (int(ui_t * 2.0) & 1) != 0:
				Gfx.txt_c(ci, "PRESS ENTER", 120, 2, "#ffffff")
			Gfx.txt_c(ci, "ROGUELIKE HOVER RACING ON SEVEN WORLDS", 150, 1, "#e0e8ff")
			Gfx.txt_c(ci, "AFTERBURNER - RAMJET - TAKEDOWNS - PROCEDURAL TRACKS", 162, 1, "#e0e8ff")
			Gfx.txt_c(ci, "PIXEL MODE 7 STYLE", 174, 1, "#9fb0ff")
			Gfx.txt_r(ci, BuildInfo.label(), W - 4, H - 10, 1, "#5a6890")
		"menu":
			Gfx.txt_c(ci, "OUTER RIM RACER", 14, 3, "#ffe040", "#7a1a1a")
			Gfx.panel(ci, 70, 52, 116, 112)
			draw_rows(ci, 78, 62, 100, 14)
			Gfx.txt_r(ci, "TUNING POINTS %d" % SaveData.data.tp, W - 6, H - 12, 1, "#a0ffa0")
			var st: Dictionary = SaveData.data.stats
			Gfx.txt(ci, "TAKEDOWNS %d  WINS %d  TOURS %d" % [st.takedowns, st.wins, st.tours], 6, H - 12, 1, "#9fb0ff")
			Gfx.txt(ci, "STARS %d   DAILY STREAK %d" % [SaveData.data.stars, SaveData.data.daily.streak], 6, H - 21, 1, "#ffd040")
		"howto":
			Gfx.panel(ci, 10, 12, 236, 150, 0.85)
			Gfx.txt(ci, "HOW TO PLAY - %s (%d/%d)" % [HOWTO[howto_page][0], howto_page + 1, HOWTO.size()], 18, 20, 1, "#ffe040")
			for i in HOWTO[howto_page][1].size():
				Gfx.txt(ci, HOWTO[howto_page][1][i], 18, 36 + i * 10, 1, "#e0e8ff")
			Gfx.txt_c(ci, "LEFT/RIGHT - PAGE    ENTER - BACK", 168, 1, "#9fb0ff")
		"quick":
			Gfx.txt(ci, "QUICK RACE", 10, 8, 2, "#ffe040")
			Gfx.panel(ci, 8, 26, 126, 126, 0.8)
			draw_rows(ci, 12, 34, 118, 14)
			draw_preview(ci, 138, 26, 112, VEH_KEYS[quick.veh], STYLE_KEYS[quick.style], PLANET_KEYS[quick.planet])
			Gfx.txt(ci, "ENTER ON SEED = NEW RANDOM TRACK", 10, 158, 1, "#9fb0ff")
		"daily":
			var di := daily_info()
			var d: Dictionary = SaveData.data.daily
			Gfx.txt(ci, "DAILY CHALLENGE", 10, 8, 2, "#ffe040")
			Gfx.txt_r(ci, di.key, W - 8, 10, 1, "#9fb0ff")
			Gfx.panel(ci, 8, 26, 240, 114, 0.85)
			var pl: Dictionary = Data.PLANETS[di.planet]
			Gfx.txt(ci, pl.name + " - " + pl.blurb, 14, 32, 1, "#ffffff")
			Gfx.txt(ci, "POD: %s (LOANED, STOCK)" % Data.VEH[di.veh].name, 14, 42, 1, "#cfd6ff")
			Gfx.txt(ci, "STYLE: %s   3 LAPS   12 RACERS" % Data.STYLES[di.style].name, 14, 51, 1, "#cfd6ff")
			Gfx.txt(ci, "TODAY'S GOALS:", 14, 64, 1, "#ffe040")
			var gl := Goals.pick(di.seed, "circuit")
			for j in gl.size():
				Gfx.txt(ci, "- " + gl[j].label + " " + "*".repeat(gl[j].tier), 14, 73 + j * 8, 1, "#aab4e8")
			var bt = d.best.get(di.key)
			if bt != null:
				Gfx.txt(ci, "YOUR BEST: %s  (PLACE %d)" % [Util.fmt_time(float(bt.time)), int(bt.rank)], 14, 102, 1, "#80ff9a")
			else:
				Gfx.txt(ci, "NOT FINISHED TODAY YET.", 14, 102, 1, "#ff9a9a")
			Gfx.txt(ci, "STREAK %d DAYS" % int(d.streak), 14, 112, 1, "#ffd040")
			Gfx.txt(ci, "FIRST FINISH EACH DAY: TP + A STAR.", 14, 122, 1, "#9fb0ff")
			Gfx.txt(ci, "SAME TRACK, EVENTS AND GOALS FOR EVERYONE.", 10, 146, 1, "#9fb0ff")
			Gfx.panel(ci, 70, 158, 116, 34, 0.8)
			draw_rows(ci, 78, 166, 100, 14)
		"test":
			Gfx.txt(ci, "TEST FLIGHT", 10, 8, 2, "#ffe040")
			Gfx.panel(ci, 8, 26, 126, 84, 0.8)
			draw_rows(ci, 12, 34, 118, 14)
			draw_preview(ci, 138, 26, 112, VEH_KEYS[tf_cfg.veh], STYLE_KEYS[tf_cfg.style], PLANET_KEYS[tf_cfg.planet])
			Gfx.txt(ci, "SOLO. 3 LAPS. CLEAN LAPS EARN MEDALS.", 10, 118, 1, "#9fb0ff")
		"garage":
			Gfx.txt(ci, "GARAGE", 10, 8, 2, "#ffe040")
			Gfx.txt_r(ci, "TUNING POINTS %d" % SaveData.data.tp, W - 8, 10, 1, "#a0ffa0")
			Gfx.panel(ci, 8, 26, 240, 108, 0.82)
			draw_rows(ci, 14, 32, 228, 10)
			Gfx.txt(ci, "STYLES UNLOCK BY PLAYING:", 10, 138, 1, "#9fb0ff")
			var i := 0
			for k in STYLE_KEYS:
				if not Data.STYLES[k].has("unlock"):
					continue
				var u: Dictionary = Data.STYLES[k].unlock
				var have: int = SaveData.data.stats[u.stat]
				Gfx.txt(ci, "%s: %s (%d/%d)" % [Data.STYLES[k].name, u.label, mini(have, u.n), u.n], 10, 147 + i * 8, 1, "#a0ffa0" if have >= u.n else "#cfd6ff")
				i += 1
			Gfx.txt(ci, "PERMANENT UPGRADES APPLY TO EVERY RUN.", 10, 147 + i * 8 + 3, 1, "#9fb0ff")
		"cosmetics":
			Gfx.txt(ci, "COSMETICS", 10, 8, 2, "#ffe040")
			Gfx.txt_r(ci, "STARS %d" % SaveData.data.stars, W - 8, 10, 1, "#ffd040")
			Gfx.panel(ci, 8, 26, 126, 62, 0.82)
			draw_rows(ci, 12, 34, 118, 12)
			var pk: String = Cosmetics.keys("paint")[cos_idx.paint]
			var fk: String = Cosmetics.keys("flame")[cos_idx.flame]
			var tk: String = Cosmetics.keys("trail")[cos_idx.trail]
			Gfx.panel(ci, 138, 26, 112, 100, 0.82)
			var vk: String = VEH_KEYS[cos_veh]
			var ccb: Array = Cosmetics.cb(vk, pk)
			var cspr: Texture2D = VehicleModels.frames(vk, ccb[0], ccb[1], ccb[2])[0][VehicleModels.YAW_MID]
			ci.draw_texture_rect(cspr, Rect2(152, 34, 84, 56), false)
			var fcol: Array = Cosmetics.flame(["#ffe880", "#ff6a20"], fk)
			for j in 2:    # flame swatches under the pod
				var fx := 176.0 + j * 22.0
				Gfx.rect(ci, fx, 90, 4, 8 + (int(ui_t * 14.0) & 1) * 3, fcol[0])
				Gfx.rect(ci, fx + 1, 94, 2, 6, fcol[1])
			Gfx.txt(ci, "TRAIL: " + Cosmetics.TRAILS[tk].name, 144, 108, 1, "#cfd6ff")
			Gfx.txt(ci, "ENTER = BUY / EQUIP", 10, 96, 1, "#9fb0ff")
			Gfx.txt(ci, "EARN STARS BY COMPLETING", 10, 108, 1, "#cfd6ff")
			Gfx.txt(ci, "THE 3 GOALS IN EVERY RACE.", 10, 116, 1, "#cfd6ff")
		"campsetup":
			Gfx.txt(ci, "CAMPAIGN", 10, 8, 2, "#ffe040")
			Gfx.panel(ci, 8, 26, 126, 62, 0.8)
			draw_rows(ci, 12, 34, 118, 14)
			draw_preview(ci, 138, 26, 112, VEH_KEYS[camp_cfg.veh], STYLE_KEYS[camp_cfg.style], null)
			var l := ["A ROGUELIKE TOUR OF 6 STAGES.", "YOU HAVE ONE LEAGUE TOKEN.", "LOSE A KEY RACE AND THE TOUR ENDS.", "WIN THE FINALE AT DERVEN ACOS.", "PARTS AND CREDITS RESET EACH TOUR.", "TUNING POINTS ARE KEPT FOREVER."]
			for j in l.size():
				Gfx.txt(ci, l[j], 10, 98 + j * 10, 1, "#cfd6ff")
		"route":
			Gfx.txt(ci, "TOUR - STAGE %d/%d" % [tour.stage + 1, TOUR_STAGES], 10, 8, 2, "#ffe040")
			Gfx.txt_r(ci, "CREDITS %d" % tour.credits, W - 8, 8, 1, "#a0ffa0")
			Gfx.txt_r(ci, "TOKEN %d" % tour.token, W - 8, 17, 1, "#ffd040")
			for j in TOUR_STAGES:    # route ladder
				Gfx.rect(ci, 10 + j * 22, 28, 18, 5, "#30c070" if j < tour.stage else ("#ffe040" if j == tour.stage else "#3a4060"))
			Gfx.txt(ci, "CHOOSE YOUR NEXT EVENT", 10, 38, 1, "#cfd6ff")
			var nc: int = tour.choices.size()
			Gfx.panel(ci, 8, 48, 240, 14 * nc + 8, 0.82)
			draw_rows(ci, 14, 54, 228, 14)
			var n: Dictionary = tour.choices[menu_sel]
			Gfx.panel(ci, 8, 48 + 14 * nc + 14, 240, 38, 0.82)
			for j in TYPE_DESC[n.type].size():
				Gfx.txt(ci, TYPE_DESC[n.type][j], 14, 48 + 14 * nc + 20 + j * 9, 1, "#e0e8ff")
			if Data.PLANETS.has(n.planet) and n.type != "shop" and n.type != "mystery":
				Gfx.txt(ci, Data.PLANETS[n.planet].blurb, 14, 48 + 14 * nc + 38, 1, "#9fb0ff")
			var pn: Array = tour.parts.map(func(p): return Data.PARTS[p].name)
			Gfx.txt(ci, "PARTS: " + (", ".join(pn) if pn.size() > 0 else "NONE"), 10, 168, 1, "#9fb0ff")
			Gfx.txt(ci, Data.VEH[tour.veh].name + " / " + Data.STYLES[tour.style].name + (" / SCORCHED" if tour.scorched else ""), 10, 178, 1, "#cfd6ff")
			var syn: Array = active_synergies().map(func(id): return Data.SYNERGIES[id].name)
			if syn.size() > 0:
				Gfx.txt(ci, "SYNERGY: " + ", ".join(syn), 10, 188, 1, "#ffd040")
		"reward":
			Gfx.txt_c(ci, "CHOOSE A PART", 20, 2, "#ffe040")
			Gfx.panel(ci, 8, 44, 240, 14 * reward_offers.size() + 8, 0.85)
			draw_rows(ci, 14, 50, 228, 14)
			var rsyn := syn_for(reward_offers[menu_sel]) if menu_sel < reward_offers.size() else ""
			if rsyn != "":
				Gfx.txt_c(ci, "SYNERGY: " + Data.SYNERGIES[rsyn].name, 100, 1, "#ffd040")
				Gfx.txt_c(ci, Data.SYNERGIES[rsyn].desc, 109, 1, "#e0e8ff")
			Gfx.txt_c(ci, "PARTS LAST FOR THIS TOUR ONLY", 124, 1, "#9fb0ff")
		"shop":
			Gfx.txt(ci, "HIBI'S SHOP", 10, 8, 2, "#ffe040")
			Gfx.txt_r(ci, "CREDITS %d" % tour.credits, W - 8, 10, 1, "#a0ffa0")
			Gfx.panel(ci, 8, 28, 240, 14 * menu_rows.size() + 8, 0.85)
			draw_rows(ci, 14, 34, 228, 14)
			if menu_sel < shop_offers.size():
				var ssyn := syn_for(shop_offers[menu_sel].p)
				if ssyn != "":
					Gfx.txt_c(ci, "SYNERGY: " + Data.SYNERGIES[ssyn].name + " - " + Data.SYNERGIES[ssyn].desc, 112, 1, "#ffd040")
			Gfx.txt_c(ci, "RACER PARTS, HONEST PRICES. MOSTLY.", 130, 1, "#9fb0ff")
		"mystery":
			Gfx.txt(ci, mystery_event.title, 10, 8, 2, "#ffe040")
			Gfx.panel(ci, 8, 28, 240, 56, 0.85)
			var lines: Array = [mystery_event.result] if mystery_event.result != null else mystery_event.text
			for j in lines.size():
				Gfx.txt(ci, lines[j], 14, 36 + j * 10, 1, "#e0e8ff")
			Gfx.panel(ci, 8, 94, 240, 14 * menu_rows.size() + 8, 0.85)
			draw_rows(ci, 14, 100, 228, 14)
		"mp":
			Gfx.txt(ci, "MULTIPLAYER", 10, 8, 2, "#ffe040")
			Gfx.panel(ci, 8, 30, 160, 52, 0.8)
			draw_rows(ci, 14, 38, 148, 14)
			if lobby.available():
				Gfx.txt(ci, "HOST A LOBBY OR JOIN A FRIEND'S. UP TO 10 RACERS.", 10, 92, 1, "#9fb0ff")
			else:
				Gfx.txt(ci, "STEAM NOT AVAILABLE.", 10, 92, 1, "#ff9090")
				Gfx.txt(ci, "RUN WITH A GODOTSTEAM BUILD OF GODOT", 10, 102, 1, "#cfd6ff")
				Gfx.txt(ci, "AND KEEP THE STEAM CLIENT OPEN.", 10, 112, 1, "#cfd6ff")
		"mp_browse":
			Gfx.txt(ci, "OPEN LOBBIES", 10, 8, 2, "#ffe040")
			Gfx.panel(ci, 8, 30, 240, 14 * menu_rows.size() + 8, 0.82)
			draw_rows(ci, 14, 38, 228, 14)
			if lobby.net.lobby_list.is_empty():
				Gfx.txt(ci, "NO LOBBIES FOUND YET. PRESS REFRESH.", 10, 150, 1, "#9fb0ff")
		"mp_lobby":
			Gfx.txt(ci, "LOBBY  %d/%d" % [lobby.players.size(), Lobby.MAX_PLAYERS], 10, 8, 2, "#ffe040")
			Gfx.panel(ci, 8, 26, 130, 14 * menu_rows.size() + 8, 0.82)
			draw_rows(ci, 12, 34, 124, 14)
			Gfx.panel(ci, 142, 26, 106, 148, 0.82)
			var yy := 32
			for id in lobby.players:
				var pl: Dictionary = lobby.players[id]
				var is_host: bool = id == lobby.net.host_id
				Gfx.txt(ci, ("* " if is_host else "") + str(pl.name), 146, yy, 1, "#ffffff")
				Gfx.txt(ci, str(Data.VEH[pl.veh].name) + (" - READY" if pl.ready else ""), 146, yy + 7, 1, "#a0ffa0" if pl.ready else "#9fb0ff")
				yy += 16
			Gfx.txt(ci, "* = HOST", 146, 164, 1, "#7a80a0")
		"podium":
			_draw_podium(ci)
		"results":
			_draw_results(ci)
		"tourend":
			var i2 := tour_end_info
			Gfx.panel(ci, 24, 20, 208, 110, 0.9)
			Gfx.txt_c(ci, "TOUR COMPLETE!" if i2.complete else "TOUR OVER", 28, 3, "#ffe040" if i2.complete else "#ff5050")
			Gfx.txt_c(ci, "STAGES CLEARED %d/%d" % [i2.cleared, TOUR_STAGES], 60, 1, "#e0e8ff")
			Gfx.txt_c(ci, "YOU ARE THE GALACTIC LEAGUE CHAMPION." if i2.complete else "YOUR TOKEN IS GONE. THE LEAGUE MOVES ON.", 72, 1, "#cfd6ff")
			Gfx.txt_c(ci, "+%d TUNING POINTS (KEPT FOREVER)" % i2.tp, 90, 1, "#a0ffa0")
			Gfx.txt_c(ci, "SPEND THEM IN THE GARAGE", 100, 1, "#9fb0ff")
			draw_rows(ci, 90, 140, 90, 12)


func _draw_race_overlays(ci: CanvasItem) -> void:
	var R: Dictionary = rc.R
	var P: Dictionary = rc.P
	var ph: String = R.phase
	if R.slowT > 0.0:
		ci.draw_rect(Rect2(0, 0, W, H), Color(1.0, 120 / 255.0, 40 / 255.0, 0.10))
	if rc.flash.t > 0.0:    # screen flash on takedowns, crashes, strikes and the final lap
		var fc: Color = rc.flash.col
		ci.draw_rect(Rect2(0, 0, W, H), Color(fc.r, fc.g, fc.b, 0.5 * rc.flash.t / maxf(rc.flash.dur, 0.01)))
	if ph == "finished" and R.confetti and R.endT < 10.0:
		_confetti(ci, R.endT)
	if ph == "finished" or ph == "wrecked" or ph == "eliminated":
		if R.endT > 0.6:
			var res: Dictionary = R.result
			Gfx.panel(ci, 40, 56, 176, 56, 0.8)
			var title := "WRECKED"
			if ph == "finished":
				title = "COURSE COMPLETE" if R.cfg.mode == "test" else ("VICTORY!" if res.rank == 1 else "FINISH!")
			elif ph == "eliminated":
				title = "ELIMINATED"
			Gfx.txt_c(ci, title, 62, 2, "#ffe040" if ph == "finished" else "#ff5050")
			if R.endT > 1.4 and (int(ui_t * 2.0) & 1) != 0:
				Gfx.txt_c(ci, "ENTER - REPLAY" if (ph == "finished" and rc.can_replay()) else "PRESS ENTER", 92, 1, "#ffffff")
	if P.crashT > 0.0 and ph == "race":
		ci.draw_rect(Rect2(0, 0, W, H), Color(1.0, 60 / 255.0, 20 / 255.0, 0.18 * minf(1.0, P.crashT)))
		Gfx.txt_c(ci, ("CRASHES LEFT %d" % P.crashesLeft) if P.crashesLeft >= 0 else "NO CRASHES LEFT", 98, 1, "#ffffff")
	if paused:
		var rows: Array = ["RESUME", "ABANDON TOUR"] if tour != null else ["RESUME", "RESTART", "QUIT"]
		Gfx.panel(ci, 76, 70, 104, 14 * rows.size() + 28, 0.9)
		Gfx.txt_c(ci, "PAUSED", 76, 2, "#ffe040")
		for i in rows.size():
			Gfx.txt(ci, ("> " if i == pause_sel else "  ") + rows[i], 84, 96 + i * 12, 1, "#ffffff" if i == pause_sel else "#c8d0ff")
