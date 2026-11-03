extends Node
## Feature test harness: plays a whole race on autopilot and logs what the new systems do.
##   godot --headless --path . res://tools/ft.tscn -- planet=hullfall seed=4242 laps=2 mode=circuit veh=sled style=survivor speed=6 daily=1 shots=300:a.png
const OUT := "/private/tmp/claude-501/-Users-logan-outer-rim-racers/280daf0e-0a8b-4535-a1ff-9ee4c8ea292e/scratchpad/"
var main: Node
var args := {}
var frame := 0
var shots := {}
var stage := "boot"
var wait := 0
var last_phase := ""
var logged_events := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Engine.time_scale = float(args.get("speed", "4"))
	main = load("res://main.tscn").instantiate()
	add_child(main)
	while main.meta == null:
		await get_tree().process_frame
	for s in str(args.get("shots", "")).split(",", false):
		var p := s.split(":")
		shots[int(p[0])] = p[1]
	await get_tree().process_frame
	var cfg := {"mode": args.get("mode", "circuit"), "planetKey": args.get("planet", "hullfall"), "seed": int(args.get("seed", "4242")), "laps": int(args.get("laps", "2")),
		"diff": int(args.get("diff", "1")), "veh": args.get("veh", "sled"), "style": args.get("style", "survivor"), "parts": str(args.get("parts", "")).split(",", false), "scorched": false}
	if args.has("daily"):
		cfg.merge({"daily": true, "dailyKey": "test-day", "parts": []})
	if args.has("hunt"):
		for n in SaveData.data.rivals:
			SaveData.data.rivals[n].grudge = 3
	if args.has("force"):
		cfg.forceEvent = args.force
	if args.has("botskill"):
		cfg.botSkill = float(args.botskill)
	for c in ["paint", "flame", "trail"]:
		if args.has(c):
			SaveData.data.cos[c] = args[c]
	if args.has("stars"):
		SaveData.data.stars = int(args.stars)
	if args.has("selftest"):
		_selftest()
		get_tree().quit()
		return
	if args.has("scene"):    # just show a menu screen
		stage = "scene"
		if args.scene == "reward" or args.scene == "route":
			main.meta.new_tour()
			main.meta.tour.parts = ["engine", "ioncore"]
			main.meta.reward_offers = ["coolant", "capacitor", "gyro"]
		main.meta.go(args.scene)
		return
	main.meta.launch_race(cfg, "daily" if args.has("daily") else "quick")
	stage = "race"


func tap(key: int) -> void:
	main.inp._held[key] = true
	main.inp._hit[key] = true


func _process(_dt: float) -> void:
	if main == null or main.meta == null or stage == "boot":
		return
	frame += 1
	if main.rc != null and main.rc.R.get("phase", "") == "race":
		if main.rc.P.get("drifting", false):
			if not logged_events.has("dr_on"):
				logged_events["dr_on"] = true
				logged_events["dr_n"] = logged_events.get("dr_n", 0) + 1
			logged_events["dr_f"] = logged_events.get("dr_f", 0) + 1
		else:
			logged_events.erase("dr_on")
		logged_events["race_f"] = logged_events.get("race_f", 0) + 1
		if main.rc.P.get("lastHurt", "") != "":
			var hk: String = "hurt_" + main.rc.P.lastHurt
			logged_events[hk] = logged_events.get(hk, 0) + 1
			main.rc.P.lastHurt = ""
	if main.rc != null and main.rc.P.get("crashT", 0.0) > 1.4 and not logged_events.has("crash%d" % int(main.rc.R.time)):
		logged_events["crash%d" % int(main.rc.R.time)] = true
		print("PLAYER CRASH ", main.rc.P.crashWhy, " t=", snappedf(main.rc.R.time, 0.1))
	if stage == "scene":
		if shots.has(frame):
			var simg := get_viewport().get_texture().get_image()
			simg.resize(simg.get_width() * 3, simg.get_height() * 3, Image.INTERPOLATE_NEAREST)
			simg.save_png(OUT + shots[frame])
			print("shot ", shots[frame])
		if frame > int(args.get("maxf", "60")):
			get_tree().quit()
		return
	var meta = main.meta
	var rc = main.rc
	var inp = main.inp
	if not inp._hit.is_empty() and frame % 2 == 0:
		inp._held.erase(KEY_ENTER)
	if meta.scene == "race" and rc.R.phase == "race":
		var P: Dictionary = rc.P
		P.autoT = 5.0
		if int(rc.R.time * 0.5) % 4 == 1:
			inp._held[KEY_K] = true
		else:
			inp._held.erase(KEY_K)
		if rc.R.time > 8.0 and rc.R.time < 8.1:
			tap(KEY_L)
		if args.has("forcetd") and rc.R.time > 10.0 and not _taken.has("td"):
			for b in rc.bots:
				if b.rival and not b.out and b.crashT <= 0.0:
					_taken["td"] = true
					print("FORCED takedown of ", b.name, " grudge before=", Rivals.rec(b.name).grudge)
					rc.takedown_bot(b)
					print("grudge after=", Rivals.rec(b.name).grudge)
					break
		if args.has("forcetd") and _taken.has("td") and not _taken.has("tdshot") and rc.R.time > 10.3:
			_snap("tdshot")
		if args.has("ghostdbg") and frame % 120 == 0:
			print("ghost on=", rc.ghost.on, " delta=", rc.ghost.delta, " has=", rc.ghost.has_delta)
	if frame % 150 == 0 and meta.scene == "race":
		var R: Dictionary = rc.R
		var ev = rc.events
		print("f%d %s t=%.1f rank=%d tot=%d spd=%d catch=%.2f allin=%s fov=%.2f ev=%s/%s k=%.2f wind=%d warns=%d pops=%d feed=%d gs[near=%d turbo=%d pass=%d walls=%d kmh=%d] goals=%s" % [frame, R.phase, R.time, R.rank, int(rc.P.total), int(rc.P.speed), rc.catchup, rc.allin, rc.fov_k,
			ev.state, ev.kind, ev.k, int(ev.wind), ev.warns.size(), rc.pops.size(), rc.feed.size(), rc.gs.nearmiss, rc.gs.turbos, rc.gs.passes, rc.gs.walls, int(rc.gs.maxKmh),
			str(rc.goals.map(func(g): return g.label + (":Y" if g.done else (":X" if g.failed else ":-"))))])
	if meta.scene == "race" and rc.events.state != "idle" and not logged_events.has(rc.events.kind + rc.events.state):
		logged_events[rc.events.kind + rc.events.state] = true
		print("EVENT ", rc.events.state, " ", rc.events.kind, " ", rc.events.title, " at t=", snappedf(rc.R.time, 0.1))
	var ph: String = rc.R.phase
	if args.has("auto_shots"):
		_auto_shots(meta, rc, ph)
	if ph != last_phase:
		print("PHASE ", last_phase, " -> ", ph, " scene=", meta.scene, " t=", snappedf(rc.R.time, 0.1))
		last_phase = ph
	if shots.has(frame):
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png(OUT + shots[frame])
		print("shot ", shots[frame], " f", frame, " scene=", meta.scene, " phase=", ph)
	# end-of-race flow
	if meta.scene == "race" and (ph == "finished" or ph == "wrecked" or ph == "eliminated") and rc.R.endT > 1.6:
		wait += 1
		if wait % 20 == 0:
			tap(KEY_ENTER)
	if ph == "replay" and frame % 3 == 0 and args.has("skipreplay"):
		tap(KEY_ENTER)
	if meta.scene == "podium" or meta.scene == "results":
		if stage == "done":
			return
		if stage != meta.scene:
			stage = meta.scene
			print("SCENE ", stage)
			if stage == "podium":
				print("podium=", JSON.stringify(rc.R.result.podium.map(func(e): return e.name)))
			if stage == "results":
				print("order=", JSON.stringify(rc.final_order()))
				print("PLAYER hurt=", JSON.stringify(logged_events.keys().filter(func(k): return str(k).begins_with("hurt_")).map(func(k): return "%s:%d" % [k, logged_events[k]])))
				print("PLAYER drifts=", logged_events.get("dr_n", 0), " drift_frac=%.2f" % (float(logged_events.get("dr_f", 0)) / maxf(1.0, logged_events.get("race_f", 1))))
				for b in rc.bots:
					print("BOT %-6s %-12s crashes_left=%d out=%s fin=%.1f dist=%d stats=%s" % [b.name, b.T.name, b.crashes, b.out, b.fin, int(b.s), JSON.stringify(b.stats)])
				var info = meta.last_result_info
				print("RESULT title=", info.title, " credits=", info.credits)
				for l in info.lines:
					print("  L: ", l if l is String else l.t)
				for l in info.right:
					print("  R: ", l.t)
				print("save stars=", SaveData.data.stars, " tp=", SaveData.data.tp, " rivals=", JSON.stringify(SaveData.data.rivals), " stats=", JSON.stringify(SaveData.data.stats))
				print("ghostNew=", rc.R.result.ghostNew)
				stage = "done"
				get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit())
		elif meta.scene == "podium" and frame % 40 == 0:
			tap(KEY_ENTER)
	if frame > int(args.get("maxf", "6000")):
		print("TIMEOUT stage=", stage, " phase=", ph)
		get_tree().quit()


var _taken := {}
var _ev_t := -1.0


func _snap(name: String) -> void:
	if _taken.has(name):
		return
	_taken[name] = true
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT + "auto_" + name + ".png")
	print("auto shot ", name, " t=", snappedf(main.rc.R.time, 0.1))


func _auto_shots(meta, rc, ph: String) -> void:
	if meta.scene == "race":
		if ph == "race" and rc.R.time > 6.0 and rc.R.time < 7.0:
			_snap("hud")
		if rc.events.state == "warn":
			_snap("warn_" + rc.events.kind)
		if rc.events.state == "active":
			if _ev_t < 0.0:
				_ev_t = rc.R.time
			if rc.R.time - _ev_t > 2.5:
				_snap("event_" + rc.events.kind)
		else:
			_ev_t = -1.0
		if not rc.pops.is_empty() and ph == "race":
			_snap("pop")
		if not rc.feed.is_empty():
			_snap("feed")
		if rc.allin and rc.R.time > 0.0:
			_snap("allin")
		if rc.events.warns.size() > 0:
			_snap("strike_warn")
		if ph == "finished" and rc.R.endT > 1.0:
			_snap("finish")
		if ph == "replay" and rc.rp.f > 25.0:
			_snap("replay")
		if ph == "replay" and abs(rc.rp.f - rc.clip_pass) < 3.0:
			_snap("replay_pass")
	elif meta.scene == "podium" and meta.ui_t > 0.8:
		_snap("podium")
	elif meta.scene == "results" and meta.ui_t > 0.4:
		_snap("results")


func _check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL "), name)


## Logic checks that need no race.
func _selftest() -> void:
	var meta = main.meta
	# cosmetics: buy, equip, paint applied
	SaveData.data.stars = 5
	SaveData.data.cos = {"owned": [], "paint": "stock", "flame": "stock", "trail": "none"}
	meta.go("cosmetics")
	meta.cos_idx.paint = Cosmetics.keys("paint").find("crimson")
	meta.menu_rows[0].act.call()
	_check("buy crimson costs 2 stars", int(SaveData.data.stars) == 3 and Cosmetics.owned("paint", "crimson") and Cosmetics.equipped("paint") == "crimson")
	_check("paint colours applied", Cosmetics.cb("bike")[0] == "#b01828")
	meta.cos_idx.paint = Cosmetics.keys("paint").find("gold")
	meta.menu_rows[0].act.call()
	_check("cannot buy gold with 3 stars", not Cosmetics.owned("paint", "gold") and Cosmetics.equipped("paint") == "crimson")
	# goals: deterministic and one per tier
	var a := Goals.pick(4242, "circuit")
	var b := Goals.pick(4242, "circuit")
	_check("goals deterministic", a.map(func(g): return g.id) == b.map(func(g): return g.id))
	_check("goals tiers 1,2,3", a.map(func(g): return g.tier) == [1, 2, 3])
	for mode in ["circuit", "elim", "test"]:
		for sd in 40:
			var gl := Goals.pick(sd, mode)
			for g in gl:
				if not g.modes.has(mode):
					_check("goal mode ok " + mode, false)
	# rivals
	SaveData.data.rivals = {"VEX": {"w": 0, "l": 2, "grudge": 0}, "ZED": {"w": 0, "l": 0, "grudge": 2}}
	var rep := Rivals.after_race(["ORRIN", "", "VEX", "ZED"])
	_check("rival beat counted", SaveData.data.rivals.has("ZED") and SaveData.data.rivals.ZED.l == 1)
	_check("dominated rival retires + replaced by ORRIN", not SaveData.data.rivals.has("VEX") and SaveData.data.rivals.has("ORRIN"))
	_check("beaten rival keeps his grudge and hunts", Rivals.hunting("ZED"))
	# synergies
	meta.tour = {"parts": ["engine"]}
	_check("coolant completes overclock", meta.syn_for("coolant") == "overclock")
	_check("gyro completes nothing yet", meta.syn_for("gyro") == "")
	var st := Race.compute_stats("sled", "survivor", ["engine", "coolant"], 1, false)
	_check("overclock active in stats", st.syn.has("overclock"))
	var plain := Race.compute_stats("sled", "survivor", ["engine", "coolant"], 1, false, true)
	_check("daily ignores parts", plain.syn.is_empty())
	# daily
	var di = meta.daily_info()
	_check("daily info stable", di.seed == meta.daily_info().seed and di.planet != "derven")
	# ordinals
	_check("ordinals", Race.ordinal(1) == "1ST" and Race.ordinal(2) == "2ND" and Race.ordinal(3) == "3RD" and Race.ordinal(11) == "11TH" and Race.ordinal(12) == "12TH" and Race.ordinal(22) == "22ND")
	# styles unlock gating
	SaveData.data.stats.nearmiss = 0
	SaveData.data.stats.goals = 0
	_check("new styles locked", not SaveData.style_unlocked("gambler") and not SaveData.style_unlocked("phantom"))
	SaveData.data.stats.goals = 12
	_check("phantom unlocks at 12 goals", SaveData.style_unlocked("phantom"))
