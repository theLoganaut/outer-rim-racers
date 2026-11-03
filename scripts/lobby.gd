## Multiplayer over a Steam lobby (up to 10 racers). The host owns the player list and race settings;
## every racer simulates their own pod and broadcasts its state ~20x a second. Pods pass through each other.
class_name Lobby
extends RefCounted

signal changed                       ## player list / settings changed
signal race_start(cfg: Dictionary)   ## host pressed START: build this race
signal left(reason: String)

const MAX_PLAYERS := 10
const SEND_INTERVAL := 0.05

var net := SteamNet.new()
var active := false
var players: Dictionary = {}    # id -> {name, veh, style, ready}
var settings := {"planet": 0, "laps": 3, "seed": 0}
var my_name := "RACER"
var _send_t := 0.0


func _init() -> void:
	net.connected.connect(_on_connected)
	net.failed.connect(func(r): left.emit(r))
	net.peer_connected.connect(_on_peer_connected)
	net.peer_disconnected.connect(_on_peer_disconnected)
	net.message.connect(_on_message)


func available() -> bool:
	return SteamNet.available()


func is_host() -> bool:
	return net.is_host


func me() -> Dictionary:
	return players.get(net.local_id, {})


func host() -> void:
	active = true
	net.host(MAX_PLAYERS - 1)


func join(lobby_id: int) -> void:
	active = true
	net.join(str(lobby_id))


func leave() -> void:
	net.close()
	active = false
	players.clear()


func poll(dt: float) -> void:
	if active:
		net.poll()


func _on_connected() -> void:
	my_name = net.persona_name().to_upper()
	players[net.local_id] = {"name": my_name, "veh": "sled", "style": "survivor", "ready": false}
	if not net.is_host:
		net.send(net.host_id, {"t": "hello", "name": my_name}, true)
	changed.emit()


func _on_peer_connected(_id: int) -> void:
	pass    # a player appears once their "hello" arrives


func _on_peer_disconnected(id: int) -> void:
	if id == net.host_id and not net.is_host:
		leave()
		left.emit("THE HOST LEFT")
		return
	players.erase(id)
	if net.is_host:
		_broadcast_lobby()
	changed.emit()


func _broadcast_lobby() -> void:
	net.broadcast({"t": "lobby", "players": players, "settings": settings}, true)
	changed.emit()


## Local choices: pushes them to the host (or applies them directly if we are the host).
func set_mine(veh: String, style: String, ready: bool) -> void:
	var m := me()
	m.veh = veh
	m.style = style
	m.ready = ready
	if net.is_host:
		_broadcast_lobby()
	else:
		net.send(net.host_id, {"t": "me", "veh": veh, "style": style, "ready": ready}, true)
		changed.emit()


func set_settings(planet: int, laps: int, seed_: int) -> void:
	if net.is_host:
		settings = {"planet": planet, "laps": laps, "seed": seed_}
		_broadcast_lobby()


func all_ready() -> bool:
	for id in players:
		if not players[id].ready:
			return false
	return players.size() >= 1


## Host only. `order` fixes everyone's starting slot.
func start_race() -> void:
	if not net.is_host or not all_ready():
		return
	var order := players.keys()
	net.broadcast({"t": "start", "settings": settings, "order": order}, true)
	_launch(settings, order)


func _launch(st: Dictionary, order: Array) -> void:
	var planet_keys := Data.PLANETS.keys()
	race_start.emit({"mode": "circuit", "planetKey": planet_keys[st.planet], "seed": st.seed, "laps": st.laps, "diff": 1,
		"veh": me().veh, "style": me().style, "parts": [], "scorched": false, "mp_order": order, "mp_players": players.duplicate(true)})


func send_state(P: Dictionary, total: float, fin: float, dt: float) -> void:
	_send_t += dt
	if _send_t < SEND_INTERVAL:
		return
	_send_t = 0.0
	net.broadcast({"t": "st", "x": P.x, "y": P.y, "a": P.a, "sp": P.speed, "yaw": P.yaw, "tot": total, "ram": P.ramOn, "ab": P.abOn,
		"sh": P.shield > 0.0, "cr": P.crashT > 0.0, "fin": fin, "dr": P.drifting, "stg": P.stage}, false)


## Applies a received "st" message to the matching remote racer.
func apply_state(remotes: Array, from: int, d: Dictionary) -> void:
	for r in remotes:
		if r.id == from:
			r.tx = d.x
			r.ty = d.y
			r.a = d.a
			r.speed = d.sp
			r.yaw = d.yaw
			r.total = d.tot
			r.ramOn = d.ram
			r.abOn = d.ab
			r.shield = d.sh
			r.crashed = d.cr
			r.fin = d.fin
			r.vx = cos(d.a) * d.sp
			r.vy = sin(d.a) * d.sp
			return


## Set by the race so incoming state can reach it.
var remotes: Array = []


func _on_message(from: int, d: Dictionary) -> void:
	match d.get("t", ""):
		"hello":    # host: a new racer joined
			if net.is_host and players.size() < MAX_PLAYERS:
				players[from] = {"name": str(d.get("name", "RACER")).substr(0, 14), "veh": "sled", "style": "survivor", "ready": false}
				_broadcast_lobby()
		"me":
			if net.is_host and players.has(from):
				players[from].veh = d.veh
				players[from].style = d.style
				players[from].ready = d.ready
				_broadcast_lobby()
		"lobby":
			if not net.is_host:
				var mine := me()
				players = d.players
				settings = d.settings
				if not mine.is_empty() and players.has(net.local_id):
					pass    # the host's copy of our choices is authoritative
				changed.emit()
		"start":
			if not net.is_host:
				_launch(d.settings, d.order)
		"st":
			apply_state(remotes, from, d)
