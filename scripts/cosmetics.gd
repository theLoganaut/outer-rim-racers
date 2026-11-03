## Unlockable looks bought with stars (earned from race goals): pod paint, afterburner flame colours and boost trails.
class_name Cosmetics

const PAINTS := {
	"stock": {"name": "STOCK", "cost": 0},
	"crimson": {"name": "CRIMSON", "cost": 2, "cb": ["#b01828", "#ff7080", "#ffe040"]},
	"mint": {"name": "MINT", "cost": 2, "cb": ["#20b090", "#a0ffe0", "#ffffff"]},
	"midnight": {"name": "MIDNIGHT", "cost": 3, "cb": ["#20284a", "#6070c0", "#40e8ff"]},
	"violet": {"name": "VIOLET", "cost": 3, "cb": ["#7a30c8", "#d8a0ff", "#ffe040"]},
	"gold": {"name": "GOLD", "cost": 5, "cb": ["#c89a10", "#fff0a0", "#202030"]},
	"chrome": {"name": "CHROME", "cost": 6, "cb": ["#8a90a8", "#e8f0ff", "#d03030"]},
}
const FLAMES := {
	"stock": {"name": "STOCK", "cost": 0},
	"green": {"name": "TOXIC GREEN", "cost": 2, "c": ["#b0ff90", "#40e060"]},
	"pink": {"name": "HOT PINK", "cost": 2, "c": ["#ffb0e8", "#ff40b0"]},
	"gold": {"name": "SOLAR GOLD", "cost": 3, "c": ["#fff0a0", "#ffc020"]},
	"void": {"name": "VOID", "cost": 4, "c": ["#d0a0ff", "#6020c0"]},
}
const TRAILS := {
	"none": {"name": "NONE", "cost": 0},
	"spark": {"name": "SPARKS", "cost": 2, "c": ["#ffffff", "#ffe060", "#ffa030"]},
	"stardust": {"name": "STARDUST", "cost": 4, "c": ["#80e8ff", "#d8a0ff", "#ffffff", "#ffe060"]},
	"plasma": {"name": "PLASMA", "cost": 5, "c": []},    # follows the equipped flame colours
}
const CATS := ["paint", "flame", "trail"]
const CAT_NAME := {"paint": "PAINT", "flame": "FLAME", "trail": "TRAIL"}


static func table(cat: String) -> Dictionary:
	return PAINTS if cat == "paint" else (FLAMES if cat == "flame" else TRAILS)


static func keys(cat: String) -> Array:
	return table(cat).keys()


static func owned(cat: String, key: String) -> bool:
	return table(cat)[key].cost == 0 or SaveData.data.cos.owned.has(cat + ":" + key)


static func equipped(cat: String) -> String:
	var k: String = SaveData.data.cos.get(cat, "")
	return k if table(cat).has(k) else table(cat).keys()[0]


## Returns "" on success, or the reason it failed.
static func buy(cat: String, key: String) -> String:
	if owned(cat, key):
		return ""
	var cost: int = table(cat)[key].cost
	if SaveData.data.stars < cost:
		return "NOT ENOUGH STARS"
	SaveData.data.stars -= cost
	SaveData.data.cos.owned.append(cat + ":" + key)
	SaveData.persist()
	return ""


static func equip(cat: String, key: String) -> void:
	SaveData.data.cos[cat] = key
	SaveData.persist()


## [body, light, stripe] for a vehicle, with the equipped paint applied.
static func cb(veh_key: String, paint: String = "") -> Array:
	if paint == "":
		paint = equipped("paint")
	var p: Dictionary = PAINTS[paint]
	return p.cb if p.has("cb") else Data.VEH[veh_key].cb


## [bright, dark] flame colours; `fallback` is the stock pair for that flame.
static func flame(fallback: Array, flame_key: String = "") -> Array:
	if flame_key == "":
		flame_key = equipped("flame")
	var f: Dictionary = FLAMES[flame_key]
	return f.c if f.has("c") else fallback


## Colour of one trail particle for the equipped trail ("" when there is no trail).
static func trail_colour(i: int) -> String:
	var t := equipped("trail")
	if t == "none":
		return ""
	var c: Array = TRAILS[t].c
	if t == "plasma":
		c = flame(["#c8f0ff", "#60b8ff"])
	return c[i % c.size()]
