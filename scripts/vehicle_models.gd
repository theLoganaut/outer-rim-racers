## Renders the four vehicle classes from simple 3D models into pixel-art sprite frames at several yaw angles,
## so pods genuinely rotate as they turn. Parts are rendered in "ID colours" and recoloured per palette.
##   frames(cls, body, light, stripe) -> [flickerA, flickerB], each an Array of YAW_FRAMES textures
## (index 0 = turned fully left, YAW_MID = straight on, last = turned fully right).
class_name VehicleModels
extends Node

const CELL_W := 48
const CELL_H := 32
const PX_PER_UNIT := 8.0
const YAW_FRAMES := 11
const YAW_MID := 5
const YAW_STEP := deg_to_rad(10.0)
const OUTLINE := Color("#14141f")

## part id colours, by which channels are lit (r,g,b)
const ID_COLORS := {
	"body": Color(1, 0, 0), "light": Color(0, 1, 0), "stripe": Color(0, 0, 1), "glass": Color(1, 1, 0),
	"metal": Color(0, 1, 1), "glow1": Color(1, 0, 1), "glow2": Color(1, 1, 1),
}

static var _raw: Dictionary = {}      # cls -> Array[Image] (ID-coloured frames)
static var _cache: Dictionary = {}

var _vp: SubViewport


## Renders every class once. Await this before starting the game.
func render_all() -> void:
	for cls in Data.HALF.keys():
		await _render_class(cls)


func _mat(id: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = ID_COLORS[id]
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if id == "glow1" or id == "glow2":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(parent: Node3D, id: String, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(id)
	mi.position = pos
	parent.add_child(mi)


## Cylinder lying along Z (nose-to-tail).
func _tube(parent: Node3D, id: String, radius: float, length: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 10
	mi.mesh = c
	mi.material_override = _mat(id)
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = pos
	parent.add_child(mi)


func _ball(parent: Node3D, id: String, radius: float, pos: Vector3, squash: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 6
	mi.mesh = s
	mi.material_override = _mat(id)
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)


func _nozzle(parent: Node3D, x: float, y: float, z: float, r: float) -> void:
	_tube(parent, "glow1", r, 0.12, Vector3(x, y, z))
	_tube(parent, "glow2", r * 0.55, 0.16, Vector3(x, y, z + 0.02))


## Nose points to -Z, up is +Y, ground at y = 0.
func _build(cls: String) -> Node3D:
	var m := Node3D.new()
	if cls == "sled":
		_box(m, "metal", Vector3(3.1, 0.3, 4.1), Vector3(0, 0.3, 0))
		_box(m, "body", Vector3(3.0, 0.6, 4.0), Vector3(0, 0.75, 0))
		_box(m, "stripe", Vector3(3.06, 0.14, 3.4), Vector3(0, 0.6, 0.1))
		_box(m, "light", Vector3(2.2, 0.12, 2.0), Vector3(0, 1.1, 0.7))
		_box(m, "glass", Vector3(1.4, 0.55, 1.4), Vector3(0, 1.3, -0.5))
		_tube(m, "body", 0.4, 1.2, Vector3(-1.0, 0.85, 2.0))
		_tube(m, "body", 0.4, 1.2, Vector3(1.0, 0.85, 2.0))
		_nozzle(m, -1.0, 0.85, 2.65, 0.3)
		_nozzle(m, 1.0, 0.85, 2.65, 0.3)
	elif cls == "bike":
		_box(m, "metal", Vector3(1.0, 0.25, 3.6), Vector3(0, 0.35, 0))
		_box(m, "body", Vector3(0.9, 0.55, 3.5), Vector3(0, 0.75, 0))
		_box(m, "stripe", Vector3(0.96, 0.12, 2.8), Vector3(0, 0.62, 0.3))
		_box(m, "light", Vector3(0.7, 0.35, 1.2), Vector3(0, 1.15, 0.5))
		_box(m, "glass", Vector3(0.6, 0.45, 0.6), Vector3(0, 1.2, -1.0))
		_box(m, "metal", Vector3(2.4, 0.14, 0.7), Vector3(0, 0.95, -0.2))
		_tube(m, "body", 0.35, 1.4, Vector3(-0.75, 0.7, 1.9))
		_tube(m, "body", 0.35, 1.4, Vector3(0.75, 0.7, 1.9))
		_nozzle(m, -0.75, 0.7, 2.62, 0.28)
		_nozzle(m, 0.75, 0.7, 2.62, 0.28)
	elif cls == "skim":
		_box(m, "metal", Vector3(3.4, 0.2, 4.2), Vector3(0, 0.2, 0))
		_box(m, "body", Vector3(3.3, 0.4, 4.1), Vector3(0, 0.5, 0))
		_box(m, "stripe", Vector3(3.36, 0.12, 3.2), Vector3(0, 0.45, 0.3))
		_box(m, "light", Vector3(2.0, 0.12, 2.2), Vector3(0, 0.76, 0.4))
		_box(m, "glass", Vector3(1.3, 0.4, 1.3), Vector3(0, 0.95, -0.6))
		_box(m, "body", Vector3(0.25, 0.8, 1.8), Vector3(-1.75, 0.7, 1.0))
		_box(m, "body", Vector3(0.25, 0.8, 1.8), Vector3(1.75, 0.7, 1.0))
		_nozzle(m, -1.0, 0.5, 2.1, 0.32)
		_nozzle(m, 1.0, 0.5, 2.1, 0.32)
	else:    # pod: two big engines up front, cockpit dragged behind on cables
		_tube(m, "body", 0.6, 3.0, Vector3(-1.45, 0.95, -0.6))
		_tube(m, "body", 0.6, 3.0, Vector3(1.45, 0.95, -0.6))
		_tube(m, "stripe", 0.64, 0.4, Vector3(-1.45, 0.95, -0.2))
		_tube(m, "stripe", 0.64, 0.4, Vector3(1.45, 0.95, -0.2))
		_tube(m, "metal", 0.45, 0.5, Vector3(-1.45, 0.95, -2.2))
		_tube(m, "metal", 0.45, 0.5, Vector3(1.45, 0.95, -2.2))
		_nozzle(m, -1.45, 0.95, 0.95, 0.4)
		_nozzle(m, 1.45, 0.95, 0.95, 0.4)
		_box(m, "metal", Vector3(2.9, 0.12, 0.14), Vector3(0, 0.9, 0.5))
		_box(m, "metal", Vector3(2.9, 0.12, 0.14), Vector3(0, 0.75, 0.2))
		_ball(m, "body", 0.7, Vector3(0, 0.75, 1.8), Vector3(1.0, 0.8, 1.5))
		_ball(m, "glass", 0.4, Vector3(0, 1.1, 1.5), Vector3(1.0, 0.8, 1.2))
		_box(m, "light", Vector3(0.7, 0.1, 0.9), Vector3(0, 1.25, 2.1))
	return m


func _render_class(cls: String) -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(CELL_W * YAW_FRAMES, CELL_H)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = false
	_vp.add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CELL_H / PX_PER_UNIT
	var pitch := deg_to_rad(20.0)
	var target := Vector3(0, 0.75, 0.2)
	cam.position = target + Vector3(0, sin(pitch), cos(pitch)) * 20.0
	cam.rotation = Vector3(-pitch, 0, 0)
	cam.far = 60.0
	_vp.add_child(cam)

	for i in YAW_FRAMES:
		var yaw := (i - YAW_MID) * YAW_STEP    # + = nose turned to the right
		var node := _build(cls)
		node.position = Vector3((i - YAW_MID) * (CELL_W / PX_PER_UNIT), 0, 0)
		node.rotation.y = -yaw
		_vp.add_child(node)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var frames: Array = []
	for i in YAW_FRAMES:
		frames.append(img.get_region(Rect2i(i * CELL_W, 0, CELL_W, CELL_H)))
	_raw[cls] = frames
	_vp.queue_free()


# ---------------------------------------------------------------- recolouring

static func _recolor(src: Image, pal: Dictionary, glow_swap: bool) -> ImageTexture:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			solid[y * w + x] = 1 if src.get_pixel(x, y).a > 0.5 else 0
	for y in h:
		for x in w:
			if solid[y * w + x] == 0:
				continue
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1 \
				or solid[y * w + x - 1] == 0 or solid[y * w + x + 1] == 0 or solid[(y - 1) * w + x] == 0 or solid[(y + 1) * w + x] == 0
			if edge:
				out.set_pixel(x, y, OUTLINE)
				continue
			var c := src.get_pixel(x, y)
			var m := maxf(c.r, maxf(c.g, c.b))
			if m < 0.12:
				out.set_pixel(x, y, OUTLINE)
				continue
			var bits := (1 if c.r >= m * 0.6 else 0) | (2 if c.g >= m * 0.6 else 0) | (4 if c.b >= m * 0.6 else 0)
			var col: Color
			match bits:
				1: col = pal.body
				2: col = pal.light
				4: col = pal.stripe
				3: col = pal.glass
				6: col = pal.metal
				5: col = pal.glow_b if glow_swap else pal.glow_a
				_: col = pal.glow_a if glow_swap else pal.glow_b
			if bits != 5 and bits != 7:    # lit parts: three shading bands
				var shade := 0.72 if m < 0.55 else (0.9 if m < 0.78 else 1.08)
				col = Color(minf(col.r * shade, 1.0), minf(col.g * shade, 1.0), minf(col.b * shade, 1.0))
			out.set_pixel(x, y, col)
	return ImageTexture.create_from_image(out)


## [flickerA, flickerB] x YAW_FRAMES textures for a class in the given colours.
static func frames(cls: String, body: String, light: String, stripe: String) -> Array:
	var key := cls + body + light + stripe
	if _cache.has(key):
		return _cache[key]
	var pal := {"body": Color.html(body), "light": Color.html(light), "stripe": Color.html(stripe), "glass": Color("#6ff0ff"),
		"metal": Color("#8e93a8"), "glow_a": Color("#ffd23a"), "glow_b": Color("#ff7a1a")}
	var res: Array = []
	for swap in [false, true]:
		var row: Array = []
		for img in _raw[cls]:
			row.append(_recolor(img, pal, swap))
		res.append(row)
	_cache[key] = res
	return res


static func yaw_index(yaw: float) -> int:
	return clampi(int(round(yaw / YAW_STEP)) + YAW_MID, 0, YAW_FRAMES - 1)
