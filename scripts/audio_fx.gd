## Tiny synth: one-shot beeps (square/saw/noise with optional pitch slide), a looping engine tone and a
## procedural race soundtrack whose energy follows your rank and whose tension follows your engine heat.
class_name AudioFx
extends Node

const RATE := 22050.0
const PROG := [0, 0, -4, -2]    # semitone root of each bar: Am Am F G
const ARP := [0, 3, 7, 10, 12, 15, 19, 15]
const BASS_STEPS := [0, 3, 6, 8, 11, 14]

var muted := false
var engine_on := false
var engine_freq := 55.0
var engine_gain := 0.035

## soundtrack
var music_on := false
var music_level := 0.3      # 0..1 energy: tempo, layers
var music_tension := 0.0    # 0..1 engine heat: dissonance + rising siren
var music_final := false    # final lap: faster, lead melody
var music_vol := 0.7

var _pb: AudioStreamGeneratorPlayback
var _voices: Array = []
var _eng_phase := 0.0
var _eng_lp := 0.0
var _mus_acc := 0.0
var _mus_step := 0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	var player := AudioStreamPlayer.new()
	player.stream = gen
	add_child(player)
	player.play()
	_pb = player.get_stream_playback() as AudioStreamGeneratorPlayback


func beep(freq: float, dur: float, type: String = "square", vol: float = 0.07, slide_to: float = 0.0, delay: float = 0.0) -> void:
	if muted:
		return
	_voices.append({"f0": freq, "f1": slide_to if slide_to > 0.0 else freq, "dur": dur, "t": -delay,
		"saw": type == "sawtooth", "noise": type == "noise", "vol": vol, "ph": 0.0})


func boom() -> void:
	beep(120, 0.6, "sawtooth", 0.13, 30)
	beep(70, 0.7, "square", 0.08, 25)


## One 16th-note of the soundtrack.
func _music_step() -> void:
	var step := _mus_step % 16
	var bar := (_mus_step / 16) % PROG.size()
	var root: int = PROG[bar]
	var lv := music_level
	var v := music_vol
	if step % 4 == 0 and lv > 0.1:
		beep(130, 0.11, "square", 0.05 * v, 42)    # kick
	if step in BASS_STEPS:
		beep(55.0 * pow(2.0, (root + (12 if step == 14 else 0)) / 12.0), 0.13, "sawtooth", 0.028 * v)
	if lv > 0.5 and step % 4 == 2:
		beep(9000, 0.03, "noise", 0.022 * v)    # hat
	if lv > 0.25 and (step % 2 == 0 or lv > 0.65):
		var n: int = ARP[(step + bar * 3) % ARP.size()]
		beep(220.0 * pow(2.0, (root + n) / 12.0), 0.07, "square", 0.016 * v)
	if music_final and step % 4 == 0:
		beep(440.0 * pow(2.0, (root + ARP[(_mus_step / 4) % ARP.size()]) / 12.0), 0.2, "square", 0.02 * v)
	if music_tension > 0.05 and step % 4 == 0:
		# rising siren; a tritone above the root as the engine nears redline
		var base := 330.0 + 520.0 * music_tension
		beep(base, 0.1, "square", 0.012 * v * (0.5 + music_tension))
		if music_tension > 0.55:
			beep(base * 1.414, 0.1, "square", 0.01 * v)


func _process(_dt: float) -> void:
	if _pb == null:
		return
	var frames := _pb.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var dt := 1.0 / RATE
	var lp_a := 1.0 - exp(-TAU * 600.0 / RATE)
	var run_eng := engine_on and not muted
	var run_mus := music_on and not muted
	var step_dur := 60.0 / (104.0 + 44.0 * music_level + (14.0 if music_final else 0.0)) / 4.0
	if not music_on:
		_mus_acc = 0.0
		_mus_step = 0
	for k in frames:
		if run_mus:
			_mus_acc += dt
			if _mus_acc >= step_dur:
				_mus_acc -= step_dur
				_music_step()
				_mus_step += 1
		var s := 0.0
		for v in _voices:
			if v.t < 0.0:
				v.t += dt
				continue
			var u: float = v.t / v.dur
			if u >= 1.0:
				continue
			var f: float = v.f0 + (v.f1 - v.f0) * u
			v.ph = fmod(v.ph + f * dt, 1.0)
			var w: float
			if v.noise:
				w = randf() * 2.0 - 1.0
			elif v.saw:
				w = v.ph * 2.0 - 1.0
			else:
				w = 1.0 if v.ph < 0.5 else -1.0
			s += w * v.vol * (1.0 - u)
			v.t += dt
		if run_eng:
			_eng_phase = fmod(_eng_phase + engine_freq * dt, 1.0)
			_eng_lp += lp_a * ((_eng_phase * 2.0 - 1.0) - _eng_lp)
			s += _eng_lp * engine_gain
		buf[k] = Vector2(s, s)
	_pb.push_buffer(buf)
	_voices = _voices.filter(func(v): return v.t < v.dur)
