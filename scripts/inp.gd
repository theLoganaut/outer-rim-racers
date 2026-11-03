## Keyboard state: held keys and keys pressed this frame, with the game's key groups.
class_name Inp
extends RefCounted

const UP := [KEY_UP, KEY_W]
const DN := [KEY_DOWN, KEY_S]
const LF := [KEY_LEFT, KEY_A]
const RT := [KEY_RIGHT, KEY_D]
const OK := [KEY_ENTER, KEY_KP_ENTER]
const BACK := [KEY_ESCAPE, KEY_BACKSPACE]
## Two-handed layout: left hand WASD drives, right hand J / K / L work the engine and Space drifts.
## (Arrows still steer, and Z / X / C / Shift still work as alternates.)
const AB := [KEY_J, KEY_Z]
const RAM := [KEY_K, KEY_X]
const ABIL := [KEY_L, KEY_C]
const DRIFT := [KEY_SPACE, KEY_SHIFT]
const PAUSE := [KEY_P]

var _held := {}
var _hit := {}


func feed(e: InputEventKey) -> void:
	if e.echo:
		return
	var k := e.physical_keycode
	if e.pressed:
		_held[k] = true
		_hit[k] = true
	else:
		_held.erase(k)


func down(codes: Array) -> bool:
	for c in codes:
		if _held.has(c):
			return true
	return false


func pressed(codes: Array) -> bool:
	for c in codes:
		if _hit.has(c):
			return true
	return false


func end_frame() -> void:
	_hit.clear()


func release_all() -> void:
	_held.clear()
