## Small math/random helpers shared by everything.
class_name Util

const TAU_ := PI * 2.0
const M32 := 0xFFFFFFFF


static func angdiff(a: float, b: float) -> float:
	var d := a - b
	while d > PI:
		d -= TAU_
	while d < -PI:
		d += TAU_
	return d


## 32-bit hash of an integer pixel; matches hash2() in the shader (and the reference).
static func hash2(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & M32
	h = ((h ^ (h >> 13)) * 1274126177) & M32
	return (h ^ (h >> 16)) & M32


static func pick(rng: Rng, arr: Array):
	return arr[int(rng.next() * arr.size())]


static func pad2(n: int) -> String:
	return ("0" if n < 10 else "") + str(n)


static func fmt_time(t: float) -> String:
	t = maxf(0.0, t)
	return "%d:%s.%s" % [int(floor(t / 60.0)), pad2(int(floor(fmod(t, 60.0)))), pad2(int(floor(fmod(t * 100.0, 100.0))))]


static func cycle(v: int, dir: int, n: int) -> int:
	return ((v + dir) % n + n) % n


static func hex(s: String) -> Color:
	return Color.html(s)


## 'mulberry32' PRNG, bit-exact with the reference so a seed gives the same track.
class Rng:
	var a: int

	func _init(seed_: int) -> void:
		a = seed_ & 0xFFFFFFFF

	func next() -> float:
		a = (a + 0x6D2B79F5) & 0xFFFFFFFF
		var t: int = ((a ^ (a >> 15)) * (1 | a)) & 0xFFFFFFFF
		t = ((t + (((t ^ (t >> 7)) * (61 | t)) & 0xFFFFFFFF)) ^ t) & 0xFFFFFFFF
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
