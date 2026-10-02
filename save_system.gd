extends RefCounted
## Versioned JSON save/load with a backup copy. Saves live in user://.

const SAVE_PATH = "user://swarajya_save_1.json"
const SETTINGS_PATH = "user://swarajya_settings.json"
const CURRENT_VERSION = 1
const REQUIRED_KEYS = ["save_version", "scenario_id", "player", "turn", "year", "max_turns", "rng_seed",
	"status", "territories", "armies", "factions", "next_army_id", "log", "stats"]


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak")


static func save_state(state: Dictionary) -> bool:
	var tmp: String = SAVE_PATH + ".tmp"
	var bak: String = SAVE_PATH + ".bak"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save file.")
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(SAVE_PATH, bak)
	var err: int = DirAccess.rename_absolute(tmp, SAVE_PATH)
	return err == OK


static func load_state() -> Dictionary:
	for path in [SAVE_PATH, SAVE_PATH + ".bak"]:
		var s: Dictionary = _read(path)
		if not s.is_empty():
			return s
	return {}


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return {}
	if not validate(parsed):
		return {}
	return normalize(_migrate(parsed))


static func validate(s: Dictionary) -> bool:
	for k in REQUIRED_KEYS:
		if not s.has(k):
			push_warning("Save missing key: " + k)
			return false
	if int(s["save_version"]) > CURRENT_VERSION:
		push_warning("Save is from a newer game version.")
		return false
	if s["scenario_id"] != Game.scenario.get("id", ""):
		return false
	for tid in Game.territories:
		if not s["territories"].has(tid):
			return false
	return true


static func _migrate(s: Dictionary) -> Dictionary:
	# Hook for future save-format upgrades. Version 1 needs none.
	if not s.has("difficulty"):
		s["difficulty"] = "normal"
	return s


## JSON turns every number into a float; convert counters back to ints.
static func normalize(s: Dictionary) -> Dictionary:
	for k in ["save_version", "turn", "year", "max_turns", "rng_seed", "next_army_id"]:
		s[k] = int(s[k])
	s["log_count"] = int(s.get("log_count", 0))
	for tid in s["territories"]:
		var t: Dictionary = s["territories"][tid]
		t["wall"] = float(t.get("wall", 0.0))
		t["besieged"] = bool(t.get("besieged", false))
		t["garrison"] = _ints(t.get("garrison", {}))
	for a in s["armies"]:
		a["id"] = int(a["id"])
		a["moves_left"] = int(a["moves_left"])
		a["morale"] = float(a["morale"])
		a["supply"] = float(a["supply"])
		a["units"] = _ints(a["units"])
	for fid in s["factions"]:
		var f: Dictionary = s["factions"][fid]
		for k in ["gold", "manpower", "stability", "start_territories"]:
			f[k] = int(f.get(k, 0))
	for k in ["battles_won", "battles_lost", "forts_captured", "forts_lost", "turns_played"]:
		s["stats"][k] = int(s["stats"].get(k, 0))
	return s


static func _ints(d) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[k] = int(d[k])
	return out


static func load_settings(defaults: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return defaults
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return defaults
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for k in parsed:
			defaults[k] = parsed[k]
	return defaults


static func save_settings(settings: Dictionary) -> void:
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(settings))
	f.close()
