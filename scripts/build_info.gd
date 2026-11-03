class_name BuildInfo
extends RefCounted
## Which build this is, shown on the title screen so a tester can say which
## one they're on. trismeg-publish writes res://build_info.json
## ({"version": "v0.3.0-14-gabc1234", "channel": "beta", "commit": "abc1234",
## "stamp": "2026-11-03 18:00"}) just for the export and deletes it after, so
## a run from the editor reads as "dev build".

const PATH := "res://build_info.json"

static var _info: Dictionary = {}
static var _read := false


static func info() -> Dictionary:
	if not _read:
		_read = true
		if FileAccess.file_exists(PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if typeof(parsed) == TYPE_DICTIONARY:
				_info = parsed
	return _info


## "v0.3.0-14-gabc1234 beta", or "dev build".
static func label() -> String:
	var i := info()
	if not i.has("version"):
		return "dev build"
	return "%s %s" % [i.version, i.get("channel", "")]
