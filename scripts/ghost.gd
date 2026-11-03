## Personal-best ghost. Records the player's path 20x a second; the best run per track is saved to disk and
## replayed next time as a translucent pod, with a live time delta against it.
class_name Ghost
extends RefCounted

const STEP := 0.05
const DIR := "user://ghosts/"
const MAX_FILES := 40

var key := ""
var enabled := false
var best: Dictionary = {}        # saved run: {x, y, a, yaw, tot, veh, time}
var cur := {"x": [], "y": [], "a": [], "yaw": [], "tot": []}
var on := false                  # a ghost is currently visible
var x := 0.0
var y := 0.0
var a := 0.0
var yaw := 0.0
var veh := "sled"
var delta := 0.0                 # my time minus the ghost's at my current distance (negative = ahead of it)
var has_delta := false
var _t := 0.0


static func make_key(cfg: Dictionary) -> String:
	return "%s_%d_%s_%d" % [cfg.planetKey, cfg.seed, cfg.mode, cfg.get("laps", 3)]


func begin(cfg: Dictionary) -> void:
	enabled = (cfg.mode == "circuit" or cfg.mode == "test") and not cfg.has("mp_order") and not cfg.get("attract", false)
	cur = {"x": [], "y": [], "a": [], "yaw": [], "tot": []}
	_t = 0.0
	on = false
	has_delta = false
	best = {}
	if not enabled:
		return
	key = make_key(cfg)
	var path := DIR + key + ".json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("x") and parsed.x.size() > 4:
				best = parsed
				veh = str(best.get("veh", "sled"))
				veh = SaveData.RENAMED.get(veh, veh)


## Record the player's pose; called every live frame with the race clock.
func record(time: float, P: Dictionary) -> void:
	if not enabled:
		return
	while _t <= time:
		cur.x.append(snappedf(P.x, 0.1))
		cur.y.append(snappedf(P.y, 0.1))
		cur.a.append(snappedf(P.a, 0.001))
		cur.yaw.append(snappedf(P.yaw, 0.01))
		cur.tot.append(snappedf(P.total, 1.0))
		_t += STEP
	if best.is_empty():
		return
	var f: float = time / STEP
	var n: int = best.x.size()
	if f >= n - 1:
		on = false
		has_delta = false
	else:
		var i := int(f)
		var u := f - i
		x = lerpf(best.x[i], best.x[i + 1], u)
		y = lerpf(best.y[i], best.y[i + 1], u)
		a = best.a[i] + Util.angdiff(best.a[i + 1], best.a[i]) * u
		yaw = lerpf(best.yaw[i], best.yaw[i + 1], u)
		on = true
		# delta: when did the ghost reach my current distance?
		var tot: Array = best.tot
		if P.total > 0.0 and P.total < tot[n - 1]:
			var lo := 0
			var hi := n - 1
			while lo < hi:
				var mid := (lo + hi) / 2
				if tot[mid] < P.total:
					lo = mid + 1
				else:
					hi = mid
			delta = time - lo * STEP
			has_delta = true
		else:
			has_delta = false


## Saves the run if it beats the stored best. Returns true when a new best was written.
func finish(time: float, veh_key: String) -> bool:
	if not enabled or cur.x.size() < 5:
		return false
	if not best.is_empty() and float(best.time) <= time:
		return false
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + key + ".json", FileAccess.WRITE)
	if f == null:
		return false
	var out := cur.duplicate()
	out.veh = veh_key
	out.time = snappedf(time, 0.001)
	f.store_string(JSON.stringify(out))
	f.close()
	_prune()
	return true


## Random-seed races would pile up ghost files forever; keep the newest MAX_FILES.
func _prune() -> void:
	var files: Array = []
	for fn in DirAccess.get_files_at(DIR):
		if fn.ends_with(".json"):
			files.append({"fn": fn, "t": FileAccess.get_modified_time(DIR + fn)})
	if files.size() <= MAX_FILES:
		return
	files.sort_custom(func(a, b): return a.t > b.t)
	for i in range(MAX_FILES, files.size()):
		DirAccess.remove_absolute(DIR + files[i].fn)
