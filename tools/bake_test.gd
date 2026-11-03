extends Node
## Dev tool: generate + bake a track and save a downscaled PNG.  godot --path . res://tools/bake_test.tscn -- hullfall 123
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var pk: String = args[0] if args.size() > 0 else "hullfall"
	var sd: int = int(args[1]) if args.size() > 1 else 4242
	var t0 := Time.get_ticks_msec()
	var trk := Track.generate(pk, sd)
	print("gen ms=", Time.get_ticks_msec() - t0, " N=", trk.n, " L=", trk.length, " attempts=", trk.attempts, " fallback=", trk.fallback,
		" shortcuts=", trk.shortcuts.size(), " obst=", trk.obst.size(), " decor=", trk.decor.size(), " hazards=", trk.hazards.size())
	var sc_i := 0
	if args.size() > 2 and args[2] == "sc":    # inject a test shortcut across open ground
		var best_j := -1
		for i0 in range(0, trk.n, 7):
			for j in range(i0 + 150, trk.n - 100, 5):
				var d := Vector2(trk.px[i0], trk.py[i0]).distance_to(Vector2(trk.px[j], trk.py[j]))
				var mid := Vector2(trk.px[i0] + trk.px[j], trk.py[i0] + trk.py[j]) / 2.0
				if d > 900.0 and d < 2500.0 and trk.mask_at(mid.x, mid.y) == 0 and not trk.near_road(mid.x, mid.y):
					best_j = j
					sc_i = i0
					break
			if best_j >= 0:
				break
		if best_j >= 0:
			trk.shortcuts.append({"i": sc_i, "j": best_j, "a": trk.pts[sc_i], "b": trk.pts[best_j], "dist": 700.0, "pathLen": 2000.0})
			print("injected shortcut", sc_i, "->", best_j, " mask mid=", trk.mask_at((trk.px[sc_i] + trk.px[best_j]) / 2.0, (trk.py[sc_i] + trk.py[best_j]) / 2.0))
	var baker := TrackBaker.new()
	add_child(baker)
	await get_tree().process_frame
	t0 = Time.get_ticks_msec()
	await baker.bake(trk)
	print("bake ms=", Time.get_ticks_msec() - t0)
	var img := baker.texture().get_image()
	img.resize(1024, 1024, Image.INTERPOLATE_BILINEAR)
	img.save_png("/private/tmp/claude-501/-Users-logan-outer-rim-racers/178e8a75-dafd-466a-b69d-e2c3940756fe/scratchpad/bake_%s_%d.png" % [pk, sd])
	# crop at start line at full-res
	var full := baker.texture().get_image()
	var p := trk.pts[0] / Track.TEXEL
	var crop := full.get_region(Rect2i(int(p.x) - 128, int(p.y) - 128, 256, 256))
	crop.resize(768, 768, Image.INTERPOLATE_NEAREST)
	crop.save_png("/private/tmp/claude-501/-Users-logan-outer-rim-racers/178e8a75-dafd-466a-b69d-e2c3940756fe/scratchpad/crop_%s_%d.png" % [pk, sd])
	# mask sanity
	var on := 0
	for i in trk.n:
		if trk.mask_at(trk.px[i], trk.py[i]) != 0: on += 1
	print("centreline samples on road: ", on, "/", trk.n)
	get_tree().quit()
