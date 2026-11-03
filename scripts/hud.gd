## In-race heads-up display: lap/time/position, gauges, ability, minimap, banners, countdown.
class_name Hud
extends RefCounted

const W := 256
const H := 224

var rc: Race


func _init(race: Race) -> void:
	rc = race


func _blink(rate: float) -> bool:
	return (int(rc.anim_t * rate) & 1) != 0


func draw(ci: CanvasItem) -> void:
	var R: Dictionary = rc.R
	var P: Dictionary = rc.P
	var trk := rc.trk
	var L := trk.length
	var st: Dictionary = P.st
	var ph: String = R.phase
	var lap := clampi(int(floor(maxf(0.0, P.total) / L)) + 1, 1, R.laps)
	if R.cfg.mode == "elim":
		Gfx.txt(ci, "ELIMINATOR", 6, 6, 1, "#ffffff")
	else:
		Gfx.txt(ci, "LAP %d/%d" % [lap, R.laps], 6, 6, 2, ("#ff8060" if (rc.allin and _blink(4.0)) else "#ffffff"))
	Gfx.txt(ci, Util.fmt_time(R.time), 6, 18, 2, "#9fd0ff")
	var rk: int = R.rank if R.rank != 0 else rc.player_rank()
	if R.cfg.mode != "test":
		Gfx.txt_r(ci, "POS %d/%d" % [rk, R.alive], W - 6, 6, 2, "#ffe040")
	else:
		Gfx.txt_r(ci, "TEST FLIGHT", W - 6, 6, 1, "#ffe040")
	if R.takedowns > 0:
		Gfx.txt_r(ci, "TAKEDOWNS %d" % R.takedowns, W - 6, 18, 1, "#ff9a40")
	_extras(ci, P, R, ph)

	# console under the pod, where the eyes already are
	_console(ci, P, st, ph)
	_status(ci, P, R, ph)

	# minimap
	var mm: Dictionary = trk.mm
	var org := Vector2(2, H - mm.MM - 2)
	ci.draw_rect(Rect2(org, Vector2(mm.MM, mm.MM)), Color(0, 0, 0, 0.55))
	var pl := PackedVector2Array()
	for p in trk.mini_pts:
		pl.append(p + org)
	ci.draw_polyline(pl, Color("#9fb0e8"), 2.0)
	for br in trk.mini_branches:
		var bl := PackedVector2Array()
		for p in br:
			bl.append(p + org)
		ci.draw_polyline(bl, Color("#9fb0e8"), 1.0)
	for s in trk.mini_shortcuts:
		ci.draw_line(s[0] + org, s[1] + org, Color("#ff9a40"), 1.0)
	for b in rc.bots:
		if not b.out and b.crashT <= 0.0:
			var q := rc.bot_pos(b)
			var m := trk.mini_pos(q.x, q.y) + org
			ci.draw_rect(Rect2(m.x - 1, m.y - 1, 2, 2), Gfx.C(b.col[0]))
	for r in rc.remotes:
		var rm := trk.mini_pos(r.x, r.y) + org
		ci.draw_rect(Rect2(rm.x - 1, rm.y - 1, 2, 2), Gfx.C(r.col[0]))
	for mi in rc.mines:
		var m := trk.mini_pos(mi.x, mi.y) + org
		ci.draw_rect(Rect2(m.x, m.y, 1, 1), Color("#ff3030"))
	if ph != "wrecked" and ph != "eliminated":
		var m := trk.mini_pos(P.x, P.y) + org
		var c := Color.WHITE if (_blink(8.0) or ph != "race") else Color("#2a5cff")
		ci.draw_rect(Rect2(m.x - 1, m.y - 1, 3, 3), c)

	if R.wrongT > 1.0 and ph == "race" and _blink(4.0):
		Gfx.txt_c(ci, "WRONG WAY!", 96, 2, "#ff4040")
	if R.cfg.mode == "elim" and ph == "race":
		var t := maxf(0.0, R.elimT)
		var last: bool = rk == R.alive and R.alive > 3
		var ecol := "#cfd6ff"
		if last or t < 5.0:
			ecol = "#ff4040" if _blink(5.0) else "#ffd0d0"
		Gfx.txt_c(ci, ("LAST PLACE! " if last else "") + "ELIMINATION " + str(int(ceil(t))), 54, 1, ecol)
	if rc.banner.t > 0.0:
		Gfx.txt_c(ci, rc.banner.text, 62, 2, rc.banner.col)
	if ph == "race" and R.time < 9.0 and not P.abOn and not P.ramOn and P.crashT <= 0.0 and _blink(2.0):
		Gfx.txt_c(ci, "HOLD J - BOOST    K - RAMJET", 100, 1, "#ffffff")


func draw_countdown(ci: CanvasItem) -> void:
	var R: Dictionary = rc.R
	var n := int(ceil(R.cdT - 0.7))
	if n >= 1 and n <= 3:
		Gfx.txt_c(ci, str(n), 56, 8, "#ffffff", "#102060")
	# rev gauge: hold throttle so the needle sits in the notched zone at GO
	var x := 8
	var y := 70
	var h := 90
	Gfx.rect(ci, x - 1, y - 1, 12, h + 2, "#000000")
	Gfx.rect(ci, x, y, 10, h, "#20263e")
	Gfx.rect(ci, x, y + round(h * (1.0 - 0.70)), 10, round(h * 0.30), "#30a060")
	var hv := clampf(R.rev, 0.0, 1.0) * h
	Gfx.rect(ci, x - 2, y + h - round(hv), 14, 2, "#ff4040" if R.rev > 0.85 else "#ffffff")
	Gfx.txt(ci, "REV", 5, y + h + 4, 1, "#cfd6ff")
	# quick-time engine start
	Gfx.txt(ci, "START ENGINES", 6, 36, 1, "#cfd6ff")
	for i in Race.QTE_KEYS.size():
		var done: bool = i < R.qteI or R.qteDone
		var cur: bool = i == R.qteI and not R.qteDone
		Gfx.rect(ci, 6 + i * 14 - 1, 44 - 1, 12, 12, "#000000")
		var c := "#3a4060"
		if done:
			c = "#30c070"
		elif cur:
			c = "#ffe040" if _blink(6.0) else "#a08820"
		Gfx.rect(ci, 6 + i * 14, 44, 10, 10, c)
		Gfx.txt(ci, Race.QTE_NAMES[i], 8 + i * 14, 47, 1, "#000000", null)


## Heat gauge: fills left to right, green -> amber -> red, with a redline tick at 80%.
func _heat_bar(ci: CanvasItem, x: float, y: float, w: float, h: float, heat: float, locked: bool) -> void:
	var f := clampf(heat / 100.0, 0.0, 1.0)
	var col := "#40d8a0"
	if locked:
		col = "#6a7a90"
	elif heat > 80.0:
		col = "#ffffff" if _blink(8.0) else "#ff3020"
	elif heat > 60.0:
		col = "#ff8a20"
	elif heat > 35.0:
		col = "#ffd030"
	Gfx.bar(ci, x, y, w, h, f, col)
	Gfx.rect(ci, x + round(w * 0.8), y - 1, 1, h + 2, "#ffffff")


func _console(ci: CanvasItem, P: Dictionary, st: Dictionary, ph: String) -> void:
	Gfx.panel(ci, 50, 190, 156, 32, 0.78)
	# speed, centre
	Gfx.txt_c(ci, "%d KMH" % int(round(P.speed * 0.9 / Race.SPEED_SCALE)), 193, 2, "#ffffff")
	# left column: boost heat, hull
	var boost_heat: float = 100.0 - P.ab
	Gfx.txt(ci, "BOOST", 55, 207, 1, "#ff6060" if boost_heat > 80.0 else "#9fd0ff")
	_heat_bar(ci, 80, 207, 46, 5, boost_heat, P.abLock)
	Gfx.txt(ci, "HULL", 55, 215, 1, "#a0ffa0")
	Gfx.bar(ci, 80, 215, 46, 4, P.hp / 100.0, "#33e060" if P.hp > 50.0 else ("#ffd030" if P.hp > 25.0 else "#ff3030"))
	# right column: ramjet heat, crashes
	Gfx.txt(ci, "RAMJET", 132, 207, 1, "#ff6060" if P.heat > 80.0 else "#ffb060")
	_heat_bar(ci, 160, 207, 42, 5, P.heat, not P.rjReady and not P.ramOn and P.heat > 30.0)
	Gfx.txt(ci, "CRASH", 132, 215, 1, "#cfd6ff")
	for i in st.crashes + 1:
		Gfx.rect(ci, 160 + i * 7, 215, 5, 5, "#ffd040" if i < P.crashesLeft + 1 else "#3a3f5a")
	# ability, bottom right
	var ab: String = Data.STYLES[P.style].ability
	var A: Dictionary = Data.ABILITY[ab]
	var cd_frac: float = 1.0 - P.abilCD / (A.cd * st.cd) if P.abilCD > 0.0 else 1.0
	var on: bool = P.autoT > 0.0 or P.shield > 0.0
	Gfx.panel(ci, 210, 198, 42, 24, 0.78)
	Gfx.txt(ci, A.name, 213, 201, 1, "#a0ffa0" if on else "#ffffff")
	Gfx.rect(ci, 213, 211, 36, 8, "#20263e")
	Gfx.rect(ci, 213, 211, round(36 * cd_frac), 8, "#3a4a80" if P.abilCD > 0.0 else "#30a060")
	Gfx.txt(ci, "L", 229, 212, 1, "#ffffff", null)


func _status(ci: CanvasItem, P: Dictionary, R: Dictionary, ph: String) -> void:
	var status := ""
	var scol := "#60d0ff"
	if P.drifting:
		status = ["DRIFTING", "MINI-TURBO", "SUPER MINI-TURBO", "ULTRA MINI-TURBO"][P.stage]
		scol = ["#ffffff", "#40a0ff", "#ff9020", "#d060ff"][P.stage]
	elif _crossing_ahead(P) != "":
		status = _crossing_ahead(P) + " CROSSING!"
		scol = "#ff4040" if _blink(5.0) else "#ffd0d0"
	elif P.draft > 0.12:
		status = "SLIPSTREAM " + "I".repeat(int(P.draft * 5.0)) + "." .repeat(5 - int(P.draft * 5.0))
		scol = "#80e8ff"
	elif P.ion > 0.0:
		status = "ION - BOOSTS JAMMED"
	elif rc.allin and _blink(3.0):
		status = "ALL IN - LIMITS OFF"
		scol = "#ff8060"
	elif R.fumeOn:
		status = "TOXIC FUMES"
		scol = "#c8e040"
	elif P.heat > 80.0:
		status = "RAMJET REDLINE"
		scol = "#ff5040"
	elif P.abLock:
		status = "BOOST OVERHEATED"
		scol = "#ff9060"
	elif not P.rjReady and P.heat > 30.0 and not P.ramOn:
		status = "RAMJET COOLING"
		scol = "#ffa060"
	elif rc.catchup > 0.35:
		status = "UNDERDOG BOOST"
		scol = "#80ffb0"
	if status != "" and ph == "race":
		Gfx.txt_c(ci, status, 112, 1, scol)


## Name of a crawler close ahead (blocking-ish distance), or "".
func _crossing_ahead(P: Dictionary) -> String:
	var trk := rc.trk
	for m in trk.movers:
		var ds: float = trk.wrap_ds(m.s, P.idx * trk.dsa)
		if ds > 0.0 and ds < 3200.0:
			return m.name
	return ""


## Ghost delta, mastery goals, event warning, kill feed, call-outs and the final-lap frame.
func _extras(ci: CanvasItem, P: Dictionary, R: Dictionary, ph: String) -> void:
	var live := ph == "race"
	if rc.ghost.has_delta and live:
		var d: float = rc.ghost.delta
		Gfx.txt(ci, "GHOST %s%.2f" % ["+" if d >= 0.0 else "-", absf(d)], 6, 30, 1, "#ff7070" if d > 0.0 else "#70ff90")
	# goals
	var gy := 40 if rc.ghost.has_delta else 32
	for i in rc.goals.size():
		var g: Dictionary = rc.goals[i]
		var mark := "-"
		var col := "#aab4e8"
		var txt: String = g.label
		if g.done:
			mark = "+"
			col = "#60ff90"
		elif g.failed:
			mark = "X"
			col = "#ff6a6a"
		elif g.kind == "reach" and g.n > 1:
			txt += " %d/%d" % [mini(int(rc.gs.get(g.stat, 0)), int(g.n)), int(g.n)]
		Gfx.txt(ci, mark + " " + txt, 6, gy + i * 8, 1, col)
	# track event
	var ev := rc.events
	if ev.state == "warn" and _blink(5.0):
		Gfx.txt_c(ci, "WARNING: " + ev.title, 6, 1, "#ff5040")
	elif ev.state == "active":
		var arrow := ""
		if ev.kind == "storm":
			arrow = " >>" if ev.wind_dir > 0.0 else " <<"
		Gfx.txt_c(ci, "%s%s %ds" % [ev.title, arrow, int(ceil(ev.remaining()))], 6, 1, "#ffb040")
		Gfx.bar(ci, 100, 14, 56, 2, ev.remaining() / maxf(ev.dur, 1.0), "#ffb040")
	# kill feed
	for i in rc.feed.size():
		var f: Dictionary = rc.feed[i]
		var c := Color(f.col)
		c.a = clampf(f.t / 0.8, 0.0, 1.0)
		Gfx.txt_r(ci, f.text, W - 6, 26 + i * 7, 1, c)
	# call-outs: position gained, near misses, goals
	for i in rc.pops.size():
		var pp: Dictionary = rc.pops[i]
		var pc := Color(pp.col)
		pc.a = clampf(pp.t / 0.4, 0.0, 1.0)
		var rise: float = (1.0 - pp.t / pp.t0) * 8.0
		var yy: float = 100.0 - (rc.pops.size() - 1 - i) * 11.0 - rise
		Gfx.txt_c(ci, pp.text, yy, 2 if pp.big else 1, pc)
	# final-lap frame
	if rc.allin and live:
		var fa := 0.3 + 0.2 * sin(rc.anim_t * 8.0)
		var fcol := Color(1.0, 0.3, 0.2, fa)
		ci.draw_rect(Rect2(0, 0, W, 2), fcol)
		ci.draw_rect(Rect2(0, H - 2, W, 2), fcol)
		ci.draw_rect(Rect2(0, 0, 2, H), fcol)
		ci.draw_rect(Rect2(W - 2, 0, 2, H), fcol)


## Replay of the last overtake: letterbox bars and a caption.
func draw_replay(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, W, 22), Color.BLACK)
	ci.draw_rect(Rect2(0, H - 22, W, 22), Color.BLACK)
	if _blink(2.0):
		Gfx.txt(ci, "REPLAY", 8, 8, 2, "#ff5050")
	Gfx.txt_r(ci, "LAST OVERTAKE", W - 8, 10, 1, "#cfd6ff")
	if rc.clip_name != "" and absf(rc.rp.f - rc.clip_pass) < 22.0:
		Gfx.txt_c(ci, "PASSING " + rc.clip_name, 40, 2, "#ffd040")
	Gfx.txt_c(ci, "ENTER - SKIP", H - 15, 1, "#9fb0ff")
