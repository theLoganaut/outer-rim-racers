## Steam lobby + messaging. Needs a GodotSteam build of Godot (provides the `Steam` singleton) and the Steam client running.
## Uses the shared test App ID 480 ("Spacewar", see steam_appid.txt); swap in your own App ID when you ship.
class_name SteamNet
extends RefCounted

signal connected
signal failed(reason: String)
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal message(from: int, data: Dictionary)

var local_id := 0
var host_id := 0
var is_host := false

const GAME_TAG := "OuterRimRacers"
const LOBBY_PUBLIC := 2
const CHANNEL := 0

var steam: Object
var lobby_id := 0
var lobby_list: Array = []    # [{id, name, players, max}]
var _members: Array = []
var _hooked := false
var _want_join := 0


static func available() -> bool:
	return Engine.has_singleton("Steam")


func init_steam() -> bool:
	if not available():
		failed.emit("STEAM MODULE NOT FOUND (USE A GODOTSTEAM BUILD)")
		return false
	steam = Engine.get_singleton("Steam")
	if steam.has_method("isSteamRunning") and not steam.isSteamRunning():
		failed.emit("START THE STEAM CLIENT FIRST")
		return false
	var res = steam.steamInitEx(480) if steam.has_method("steamInitEx") else steam.steamInit()
	if typeof(res) == TYPE_DICTIONARY and int(res.get("status", 0)) != 0:
		failed.emit("STEAM INIT FAILED: " + str(res.get("verbal", res)))
		return false
	if not _hooked:
		_hooked = true
		steam.lobby_created.connect(_on_lobby_created)
		steam.lobby_joined.connect(_on_lobby_joined)
		steam.lobby_chat_update.connect(_on_chat_update)
		steam.lobby_match_list.connect(_on_match_list)
		steam.join_requested.connect(_on_join_requested)
		if steam.has_signal("network_messages_session_request"):
			steam.network_messages_session_request.connect(_on_session_request)
	local_id = int(steam.getSteamID())
	return true


func persona_name() -> String:
	return str(steam.getPersonaName()) if steam != null else "RACER"


func host(max_peers: int) -> void:
	if not init_steam():
		return
	is_host = true
	host_id = local_id
	steam.createLobby(LOBBY_PUBLIC, max_peers + 1)


func join(target: String) -> void:
	if not init_steam():
		return
	is_host = false
	steam.joinLobby(int(target))


func request_lobbies() -> void:
	if steam == null and not init_steam():
		return
	steam.addRequestLobbyListStringFilter("game", GAME_TAG, 0)
	steam.requestLobbyList()


func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		failed.emit("LOBBY CREATE FAILED (%d)" % result)
		return
	lobby_id = id
	steam.setLobbyData(id, "game", GAME_TAG)
	steam.setLobbyData(id, "name", persona_name() + "'S RACE")
	steam.setLobbyJoinable(id, true)
	_refresh_members()
	connected.emit()


func _on_lobby_joined(id: int, _perms: int, _locked: bool, response: int) -> void:
	if response != 1:
		failed.emit("COULD NOT JOIN LOBBY (%d)" % response)
		return
	lobby_id = id
	host_id = int(steam.getLobbyOwner(id))
	is_host = host_id == local_id
	_refresh_members()
	connected.emit()
	for m in _members:
		if m != local_id:
			peer_connected.emit(m)


func _on_chat_update(_lobby: int, changed: int, _making_change: int, state: int) -> void:
	var before := _members.duplicate()
	_refresh_members()
	if state == 1:    # entered
		if changed != local_id and changed not in before:
			peer_connected.emit(changed)
	else:    # left / disconnected / kicked / banned
		if changed in before:
			peer_disconnected.emit(changed)


func _on_match_list(lobbies: Array) -> void:
	lobby_list.clear()
	for id in lobbies:
		lobby_list.append({"id": int(id), "name": str(steam.getLobbyData(id, "name")),
			"players": int(steam.getNumLobbyMembers(id)), "max": int(steam.getLobbyMemberLimit(id))})


func _on_join_requested(id: int, _friend: int) -> void:    # accepted a Steam invite / "join game"
	_want_join = id
	join(str(id))


func _on_session_request(remote_id: int) -> void:
	steam.acceptSessionWithUser(remote_id)


func _refresh_members() -> void:
	_members.clear()
	for i in int(steam.getNumLobbyMembers(lobby_id)):
		_members.append(int(steam.getLobbyMemberByIndex(lobby_id, i)))


func peers() -> Array:
	return _members.filter(func(m): return m != local_id)


func poll() -> void:
	if steam == null:
		return
	steam.run_callbacks()
	for m in steam.receiveMessagesOnChannel(CHANNEL, 64):
		var data = bytes_to_var(m.get("payload", PackedByteArray()))
		if typeof(data) == TYPE_DICTIONARY:
			var from := int(m.get("identity", m.get("remote_steam_id", 0)))
			message.emit(from, data)


func _flags(reliable: bool) -> int:
	return int(steam.get("NETWORKING_SEND_RELIABLE")) if reliable else int(steam.get("NETWORKING_SEND_UNRELIABLE"))


func send(to: int, data: Dictionary, reliable: bool = true) -> void:
	if steam != null:
		steam.sendMessageToUser(to, var_to_bytes(data), _flags(reliable), CHANNEL)


func broadcast(data: Dictionary, reliable: bool = true) -> void:
	for m in peers():
		send(m, data, reliable)


func close() -> void:
	if steam != null and lobby_id != 0:
		steam.leaveLobby(lobby_id)
		for m in _members:
			if m != local_id:
				steam.closeSessionWithUser(m)
	lobby_id = 0
	_members.clear()
