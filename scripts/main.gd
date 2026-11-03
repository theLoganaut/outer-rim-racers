## Entry point. Builds the draw layers (sky -> Mode 7 ground -> sprites -> HUD -> menus), owns the
## track bakers and routes input/time into Meta (menus + flow) and Race (simulation).
extends Node2D

const W := 256
const H := 224
const HORIZON := 72

var inp := Inp.new()
var audio: AudioFx
var rc: Race
var meta: Meta
var world: WorldView
var hud: Hud

var _bakers: Array[TrackBaker] = []
var _next_baker := 0
var _ground: ColorRect
var _ground_mat: ShaderMaterial
var _layers: Array[Painter] = []


func _ready() -> void:
	SaveData.load_save()
	Rivals.ensure()
	audio = AudioFx.new()
	add_child(audio)
	for i in 2:    # two bakers so a new track never overwrites the one still on screen
		var b := TrackBaker.new()
		add_child(b)
		_bakers.append(b)

	var models := VehicleModels.new()
	add_child(models)
	await models.render_all()
	rc = Race.new(inp, audio)
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://shaders/mode7.gdshader")
	world = WorldView.new(rc, _ground_mat)
	hud = Hud.new(rc)
	meta = Meta.new(rc, inp, audio, self)

	var sky := _layer(func(ci): if meta.world_ready: world.draw_sky(ci))
	_ground = ColorRect.new()
	_ground.position = Vector2(0, HORIZON)
	_ground.size = Vector2(W, H - HORIZON)
	_ground.material = _ground_mat
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)
	_layer(func(ci): if meta.world_ready: world.draw_objects(ci, rc.R.phase != "attract"))
	_layer(_draw_hud)
	_layer(func(ci): meta.draw(ci))
	meta.go("title")


func _layer(fn: Callable) -> Painter:
	var p := Painter.new()
	p.draw_fn = fn
	add_child(p)
	_layers.append(p)
	return p


func _draw_hud(ci: CanvasItem) -> void:
	if meta.scene != "race" or not meta.world_ready:
		return
	if rc.R.phase == "replay":
		hud.draw_replay(ci)
		return
	if rc.R.phase == "countdown":
		hud.draw_countdown(ci)
	hud.draw(ci)


## Generates a track and paints it on the GPU; returns once it is ready to display.
func make_track(planet_key: String, seed_: int) -> Track:
	var trk := Track.generate(planet_key, seed_)
	var baker := _bakers[_next_baker]
	_next_baker = 1 - _next_baker
	await baker.bake(trk)
	trk.tex = baker.texture()
	return trk


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		inp.feed(event)
		if event.pressed and not event.echo and event.physical_keycode == KEY_M:
			audio.muted = not audio.muted


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		inp.release_all()


func _process(delta: float) -> void:
	if meta == null:
		return
	meta.update(clampf(delta, 0.0, 0.05))
	_ground.visible = meta.world_ready and rc.trk != null
	if _ground.visible:
		_ground_mat.set_shader_parameter("track_tex", rc.trk.tex)
		world.update_ground()
	for l in _layers:
		l.queue_redraw()
	inp.end_frame()
