## Persistent rivals: two named racers who remember you. Beat them and their grudge grows; at 2+ they hunt you.
## Records live in the save file so the feud follows you from race to race, tour to tour.
class_name Rivals

const POOL := ['VEX', 'ORRIN', 'DASH', 'KIRA', 'ZED', 'MOKK', 'TALA', 'RUUK', 'SKIV', 'JUNO', 'BRAX']    # always on the grid
const CLASSES := ["bike", "pod", "skim", "sled"]
const HUNT_GRUDGE := 2
const MAX_GRUDGE := 5

const WIN_LINES := [    # said when YOU beat them
	"NOT BAD. DON'T GET USED TO IT.", "LUCKY LINE. NEXT TIME.", "YOU'LL NEVER DO THAT TWICE.", "I WAS WARMING UP.",
	"ENJOY THE VIEW FROM THE FRONT.", "THIS ISN'T OVER.",
]
const LOSE_LINES := [    # said when THEY beat you
	"TOO SLOW, ROOKIE.", "WAVE AT MY EXHAUST NEXT TIME.", "IS THAT ALL YOU HAVE?", "I'LL SAVE YOU A SEAT AT THE BACK.",
	"EASY MONEY.", "COME BACK WHEN YOU'VE LEARNED TO DRIVE.",
]
const PASS_LINES := [    # said when they overtake you mid-race
	"EAT MY DUST!", "SEE YOU AT THE LINE!", "MOVE OVER!", "THANKS FOR THE DRAFT!", "TOO EASY!",
]


static func ensure() -> void:
	var r: Dictionary = SaveData.data.rivals
	var tries := 0
	while r.size() < 2 and tries < 40:
		tries += 1
		var n: String = POOL[randi() % POOL.size()]
		if not r.has(n):
			r[n] = {"w": 0, "l": 0, "grudge": 0}


static func is_rival(name: String) -> bool:
	return SaveData.data.rivals.has(name)


static func rec(name: String) -> Dictionary:
	return SaveData.data.rivals.get(name, {"w": 0, "l": 0, "grudge": 0})


static func hunting(name: String) -> bool:
	return is_rival(name) and int(rec(name).grudge) >= HUNT_GRUDGE


## Rivals always race the same class so you learn to read them.
static func cls_for(name: String) -> String:
	return CLASSES[POOL.find(name) % CLASSES.size()]


static func line(lines: Array, name: String, salt: int = 0) -> String:
	return lines[(POOL.find(name) * 5 + salt * 3) % lines.size()]


## `order` is the finishing order as an array of bot names / "" for the player; `wrecked` are bots that crashed out
## (they count as beaten). Updates records and returns report lines [{name, beat: bool, text}] for the results screen.
static func after_race(order: Array, wrecked: Array = []) -> Array:
	var rep: Array = []
	var me := order.find("")
	if me < 0:
		me = order.size()
	var rivals: Dictionary = SaveData.data.rivals
	for n in rivals.keys():
		var pos := order.find(n)
		if pos < 0 and not wrecked.has(n):    # not in this race at all (eliminated before the end)
			continue
		var r: Dictionary = rivals[n]
		var beat := pos < 0 or me < pos
		if beat:
			r.l = int(r.l) + 1
		else:
			r.w = int(r.w) + 1
			r.grudge = maxi(0, int(r.grudge) - 1)    # winning cools the grudge
		rep.append({"name": n, "beat": beat, "text": line(WIN_LINES if beat else LOSE_LINES, n, int(r.w) + int(r.l))})
	# a dominated rival retires; whoever finished best ahead of you steps up
	for n in rivals.keys():
		var r: Dictionary = rivals[n]
		if int(r.l) - int(r.w) >= 3:
			for cand in order:
				if cand != "" and not rivals.has(cand) and order.find(cand) < me and POOL.has(cand):
					rivals.erase(n)
					rivals[cand] = {"w": 0, "l": 0, "grudge": 1}
					rep.append({"name": cand, "beat": false, "text": "", "new": true})
					break
	ensure()
	return rep


static func add_grudge(name: String) -> void:
	if is_rival(name):
		var r: Dictionary = SaveData.data.rivals[name]
		r.grudge = mini(MAX_GRUDGE, int(r.grudge) + 1)
