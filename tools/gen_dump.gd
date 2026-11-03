extends SceneTree
## Dev tool: print track stats for planet:seed pairs as JSON (compare against the reference in node).
func _init() -> void:
	var specs = JSON.parse_string(OS.get_cmdline_user_args()[0])
	var out := []
	for s in specs:
		var t := Track.generate(s[0], int(s[1]))
		var sc := []
		for q in t.shortcuts:
			sc.append([q.i, q.j])
		out.append({"pk": s[0], "seed": s[1], "N": t.n, "L": snappedf(t.length, 0.001), "attempts": t.attempts, "fallback": t.fallback,
			"shortcuts": t.shortcuts.size(), "obst": t.obst.size(), "decor": t.decor.size(), "hazards": t.hazards.size(), "sc": sc})
	print("JSON:" + JSON.stringify(out))
	quit()
