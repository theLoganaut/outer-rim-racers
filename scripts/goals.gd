## Mastery goals: three optional challenges (easy / medium / hard) per race. Completing them pays stars.
## The goals are picked from the track seed, so a retry or a daily challenge always shows the same three.
class_name Goals

## kind: reach = done as soon as stat >= n;  keep = done at the finish if stat stayed <= n;  end = judged at the finish
const POOL := [
	{"id": "near3", "label": "3 NEAR MISSES", "tier": 1, "kind": "reach", "stat": "nearmiss", "n": 3, "modes": ["circuit", "elim", "test"]},
	{"id": "turbo3", "label": "3 DRIFT TURBOS", "tier": 1, "kind": "reach", "stat": "turbos", "n": 3, "modes": ["circuit", "elim", "test"]},
	{"id": "launch", "label": "PERFECT LAUNCH", "tier": 1, "kind": "reach", "stat": "launch", "n": 1, "modes": ["circuit", "elim", "test"]},
	{"id": "ram5", "label": "5S OF RAMJET", "tier": 1, "kind": "reach", "stat": "ramSec", "n": 5, "modes": ["circuit", "elim", "test"]},
	{"id": "speed", "label": "HIT 650 KMH", "tier": 1, "kind": "reach", "stat": "maxKmh", "n": 650, "modes": ["circuit", "elim", "test"]},
	{"id": "nowall", "label": "NO WALL HITS", "tier": 2, "kind": "keep", "stat": "walls", "n": 0, "modes": ["circuit", "elim", "test"]},
	{"id": "take2", "label": "2 TAKEDOWNS", "tier": 2, "kind": "reach", "stat": "takedowns", "n": 2, "modes": ["circuit", "elim"]},
	{"id": "pass6", "label": "6 OVERTAKES", "tier": 2, "kind": "reach", "stat": "passes", "n": 6, "modes": ["circuit", "elim"]},
	{"id": "draft8", "label": "8S SLIPSTREAM", "tier": 2, "kind": "reach", "stat": "draftSec", "n": 8, "modes": ["circuit", "elim"]},
	{"id": "top3", "label": "FINISH TOP 3", "tier": 2, "kind": "end", "stat": "top3", "n": 0, "modes": ["circuit"]},
	{"id": "super2", "label": "2 SUPER TURBOS", "tier": 2, "kind": "reach", "stat": "supers", "n": 2, "modes": ["circuit", "elim", "test"]},
	{"id": "nocrash", "label": "NO CRASHES", "tier": 3, "kind": "keep", "stat": "crashes", "n": 0, "modes": ["circuit", "elim", "test"]},
	{"id": "ultra2", "label": "2 ULTRA TURBOS", "tier": 3, "kind": "reach", "stat": "ultras", "n": 2, "modes": ["circuit", "elim", "test"]},
	{"id": "comeback", "label": "WIN AFTER 11TH", "tier": 3, "kind": "end", "stat": "comeback", "n": 0, "modes": ["circuit"]},
	{"id": "take4", "label": "4 TAKEDOWNS", "tier": 3, "kind": "reach", "stat": "takedowns", "n": 4, "modes": ["circuit", "elim"]},
]


static func new_stats() -> Dictionary:
	return {"walls": 0, "crashes": 0, "nearmiss": 0, "turbos": 0, "supers": 0, "ultras": 0, "takedowns": 0, "draftSec": 0.0, "maxKmh": 0.0,
		"ramSec": 0.0, "passes": 0, "launch": 0, "worstRank": 0}


## One goal per tier, drawn with a seeded RNG.
static func pick(seed_: int, mode: String) -> Array:
	var rng := Util.Rng.new(seed_ * 7 + 13)
	var out: Array = []
	for tier in [1, 2, 3]:
		var cands: Array = POOL.filter(func(g): return g.tier == tier and g.modes.has(mode))
		var g: Dictionary = cands[int(rng.next() * cands.size())].duplicate()
		g.done = false
		g.failed = false
		out.append(g)
	return out


static func progress(g: Dictionary, gs: Dictionary) -> float:
	if g.kind != "reach":
		return 0.0
	return float(gs.get(g.stat, 0.0))


## Called every live frame. Returns the goals completed this frame.
static func update(goals: Array, gs: Dictionary) -> Array:
	var fresh: Array = []
	for g in goals:
		if g.done or g.failed:
			continue
		if g.kind == "reach" and float(gs.get(g.stat, 0.0)) >= g.n:
			g.done = true
			fresh.append(g)
		elif g.kind == "keep" and float(gs.get(g.stat, 0.0)) > g.n:
			g.failed = true
	return fresh


## Judge the end-of-race goals. `rank` is the finishing place, 0 if the race was not finished.
static func finalize(goals: Array, gs: Dictionary, rank: int, finished: bool) -> void:
	for g in goals:
		if g.done:
			continue
		if not finished or g.failed:
			g.failed = true
			continue
		if g.kind == "keep":
			g.done = true
		elif g.kind == "end":
			if g.stat == "top3":
				g.done = rank >= 1 and rank <= 3
			elif g.stat == "comeback":
				g.done = rank == 1 and int(gs.worstRank) >= 11
			g.failed = not g.done


static func stars(goals: Array) -> int:
	var s := 0
	for g in goals:
		if g.done:
			s += g.tier
	return s
