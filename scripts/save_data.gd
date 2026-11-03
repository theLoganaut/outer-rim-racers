## Persistent profile: tuning points, unlocked vehicles, garage upgrades, stats, best laps.
class_name SaveData

const PATH := "user://save.json"
## Old planet / vehicle keys from earlier builds, mapped to their current names (saves and ghosts are migrated on load).
const RENAMED := {"jakku": "hullfall", "ando": "rime", "tatooine": "quarez", "crait": "cinnabar", "landspeeder": "sled"}

static var data: Dictionary = {}


static func defaults() -> Dictionary:
	return {
		"tp": 15,
		"vehicles": {"sled": true, "bike": false, "skim": false, "pod": false},
		"up": {"speed": 0, "accel": 0, "cool": 0, "armor": 0},
		"stats": {"takedowns": 0, "wins": 0, "ramjet": 0, "tours": 0, "nearmiss": 0, "turbos": 0, "goals": 0, "dailies": 0},
		"best": {},
		"stars": 0,
		"rivals": {},    # name -> {w, l, grudge}
		"daily": {"best": {}, "streak": 0, "last": ""},    # best: date -> {time, rank}
		"cos": {"owned": [], "paint": "stock", "flame": "stock", "trail": "none"},
	}


static func load_save() -> void:
	data = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_migrate(parsed)
	for k in data:
		if parsed.has(k):
			if typeof(data[k]) == TYPE_DICTIONARY:
				data[k].merge(parsed[k], true)
			else:
				data[k] = parsed[k]


static func _migrate(parsed: Dictionary) -> void:
	var veh = parsed.get("vehicles")
	if veh is Dictionary:
		for old in RENAMED:
			if veh.has(old):
				veh[RENAMED[old]] = veh[old] or veh.get(RENAMED[old], false)
				veh.erase(old)
	var best = parsed.get("best")
	if best is Dictionary:
		for k in best.keys():
			var pk: String = str(k).get_slice("|", 0)
			if RENAMED.has(pk):
				best[RENAMED[pk] + str(k).substr(pk.length())] = best[k]
				best.erase(k)
	var dir := DirAccess.open(Ghost.DIR)
	if dir:
		for fn in dir.get_files():
			var pk2: String = fn.get_slice("_", 0)
			if RENAMED.has(pk2):
				dir.rename(fn, RENAMED[pk2] + fn.substr(pk2.length()))


static func persist() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


static func style_unlocked(style_key: String) -> bool:
	var u = Data.STYLES[style_key].get("unlock")
	return u == null or data.stats[u.stat] >= u.n
