extends Node
## Dev harness: boots Main, optionally jumps straight into a race, holds keys and saves screenshots.
##   godot --path . res://tools/dev_run.tscn -- planet=hullfall seed=4242 mode=circuit veh=sled style=survivor \
##        hold=up,ab shots=120:a.png,300:b.png quit=400 speed=3 tap=250:ok
## `tap=frame:key` presses a key for one frame (ok, back, z, x, c, p, up, down, left, right).
const OUT := "/private/tmp/claude-501/-Users-logan-outer-rim-racers/178e8a75-dafd-466a-b69d-e2c3940756fe/scratchpad/"
const KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "ab": KEY_Z, "z": KEY_Z, "ram": KEY_X, "x": KEY_X,
	"c": KEY_C, "ok": KEY_ENTER, "back": KEY_ESCAPE, "p": KEY_P, "shift": KEY_SHIFT, "space": KEY_SPACE, "j": KEY_J, "k": KEY_K, "l": KEY_L}
var main: Node
var args := {}
var frame := 0
var shots := {}
var taps := {}
var held: Array = []
var quit_at := 600


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Engine.time_scale = float(args.get("speed", "1"))
	main = load("res://main.tscn").instantiate()
	add_child(main)
	while main.meta == null:
		await get_tree().process_frame
	for s in str(args.get("shots", "")).split(",", false):
		var p := s.split(":")
		shots[int(p[0])] = p[1]
	for s in str(args.get("tap", "")).split(",", false):
		var p := s.split(":")
		taps[int(p[0])] = KEYS[p[1]]
	for k in str(args.get("hold", "")).split(",", false):
		held.append(KEYS[k])
	quit_at = int(args.get("quit", "600"))
	if args.has("mphost"):
		main.meta.lobby.left.connect(func(r): print("LOBBY LEFT: ", r))
		main.meta.lobby.changed.connect(func(): print("LOBBY CHANGED players=", main.meta.lobby.players.size(), " scene=", main.meta.scene))
		print("steam available: ", main.meta.lobby.available())
		main.meta.go("mp")
		main.meta.lobby.host()
	if args.has("planet"):
		await get_tree().process_frame
		var cfg := {"mode": args.get("mode", "circuit"), "planetKey": args.planet, "seed": int(args.get("seed", "4242")), "laps": int(args.get("laps", "3")),
			"diff": int(args.get("diff", "1")), "veh": args.get("veh", "sled"), "style": args.get("style", "survivor"), "parts": [], "scorched": false}
		if args.has("mpfake"):
			cfg.mp_order = [1, 2, 3]
			cfg.mp_local = 1
			cfg.mp_players = {1: {"name": "ME", "veh": "sled", "style": "survivor", "ready": true},
				2: {"name": "ALICE", "veh": "bike", "style": "survivor", "ready": true}, 3: {"name": "BOB", "veh": "pod", "style": "survivor", "ready": true}}
			main.meta.launch_race(cfg, "mp")
		else:
			main.meta.launch_race(cfg, "quick")


func _process(_dt: float) -> void:
	if main == null or main.meta == null:
		return
	frame += 1
	var inp = main.inp
	if args.has("hold") and main.meta.scene == "race" and main.rc.R.phase != "countdown" or args.has("holdcd"):
		for k in held:
			inp._held[k] = true
	if args.has("auto") and main.meta.scene == "race" and main.rc.R.phase == "race":
		main.rc.P.autoT = 5.0    # let the in-game autopilot drive
	if frame % 100 == 0 and main.meta.scene == "race":
		var R: Dictionary = main.rc.R
		print("f", frame, " ", R.phase, " t=", snappedf(R.time, 0.1), " rank=", R.rank, " total=", int(main.rc.P.total), " hp=", int(main.rc.P.hp), " crashesLeft=", main.rc.P.crashesLeft, " alive=", R.alive,
			" out=", main.rc.bots.filter(func(b): return b.out).size(), " crashing=", main.rc.bots.filter(func(b): return b.crashT > 0.0).size())
	if args.has("dbg") and main.meta.scene == "race" and frame % 15 == 0 and frame > 230:
		var rc = main.rc
		var P: Dictionary = rc.P
		print("dbg f", frame, " pos=", Vector2(int(P.x), int(P.y)), " a=", snappedf(P.a, 0.01), " spd=", int(P.speed), " mask=", rc.trk.mask_at(P.x, P.y), " idx=", P.idx, " off=", int(rc.trk.branch_off(P.idx * rc.trk.dsa)), " side=", P.lastSide, " hp=", int(P.hp), " auto=", snappedf(P.autoT, 0.1), " crT=", snappedf(P.crashT, 0.1))
	if args.has("movershot") and main.meta.scene == "race" and main.rc.trk != null and not shots.has(-1):
		for m in main.rc.trk.movers:
			var ds: float = main.rc.trk.wrap_ds(m.s, main.rc.P.idx * main.rc.trk.dsa)
			if ds > 1300.0 and ds < 1500.0:
				shots[-1] = "mover.png"
				var img := get_viewport().get_texture().get_image()
				img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
				img.save_png(OUT + "mover.png")
				print("mover shot ", m.name, " lat=", main.rc.trk.mover_lat(m, main.rc.R.time))
	if args.has("mpfake") and main.meta.scene == "race" and main.rc.R.phase == "race":
		var rc2 = main.rc
		for k in rc2.remotes.size():
			var r = rc2.remotes[k]
			var tot: float = 400.0 + rc2.R.time * (900.0 + 120.0 * k)
			var p: Dictionary = rc2.trk.pos_at(tot)
			var q: Vector2 = rc2.trk.lane_xy(p, 40.0 * (1 if k == 0 else -1))
			main.meta.lobby.apply_state(rc2.remotes, r.id, {"x": q.x, "y": q.y, "a": p.a, "sp": 900.0, "yaw": 0.2, "tot": tot, "ram": k == 1, "ab": false, "sh": false, "cr": false, "fin": -1.0, "dr": false, "stg": 0})
	if taps.has(frame):
		inp._held[taps[frame]] = true
		inp._hit[taps[frame]] = true
	elif taps.has(frame - 1):
		inp._held.erase(taps[frame - 1])
	if shots.has(frame):
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png(OUT + shots[frame])
		print("shot ", shots[frame], " frame ", frame, " scene=", main.meta.scene, " phase=", main.rc.R.phase, " speed=", main.rc.P.get("speed"))
	if frame >= quit_at:
		get_tree().quit()
