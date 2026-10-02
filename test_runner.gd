extends Node
## Headless smoke tests. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed.

const Rules = preload("res://scripts/core/rules.gd")
const TurnManager = preload("res://scripts/core/turn_manager.gd")
const SaveSystem = preload("res://scripts/save/save_system.gd")

var _fails: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_fails += 1


func _ready() -> void:
	_check(Game.territories.size() == 10, "10 territories loaded")
	_check(Game.forts.size() == 5, "5 forts loaded")
	_check(Game.scenario.has("start"), "scenario loaded")

	var s: Dictionary = Rules.new_state()
	_check(s["status"] == "playing", "new state is playing")
	_check(s["armies"].size() == 4, "four starting armies")
	_check(s["territories"]["torna"]["owner"] == "adilshahi", "Torna starts Adil Shahi")

	# Movement and attack.
	var a = Rules.army_by_id(s, 1)
	_check(a != null and a["territory"] == "maval", "army 1 at Maval")
	_check(Rules.attack_targets(s, a).has("torna"), "Torna attackable from Maval")
	var before_wall: float = float(s["territories"]["torna"]["wall"])
	var sres: Dictionary = Rules.besiege(s, a, "torna")
	_check(sres["ok"] and float(s["territories"]["torna"]["wall"]) < before_wall, "besiege lowers walls")
	_check(not Rules.attack(s, a, "torna", "balanced")["ok"], "no attack after besiege (moves spent)")

	# Recruit.
	var gold: int = int(s["factions"]["swarajya"]["gold"])
	var rr: Dictionary = Rules.recruit(s, "swarajya", "pune", "infantry")
	_check(rr["ok"] and int(s["factions"]["swarajya"]["gold"]) < gold, "recruit spends revenue")
	_check(not Rules.recruit(s, "swarajya", "torna", "infantry")["ok"], "cannot recruit in enemy land")

	# Save round trip.
	_check(SaveSystem.save_state(s), "save written")
	var loaded: Dictionary = SaveSystem.load_state()
	_check(not loaded.is_empty(), "save loads and validates")
	_check(int(loaded["turn"]) == int(s["turn"]), "turn survives round trip")
	_check(typeof(loaded["armies"][0]["id"]) == TYPE_INT, "ids normalised to int")

	# AI-only simulation: player never acts. Must not crash and must terminate.
	var sim: Dictionary = Rules.new_state()
	sim["difficulty"] = "normal"
	var guard: int = 0
	while sim["status"] == "playing" and guard < 40:
		TurnManager.end_player_turn(sim)
		guard += 1
	_check(sim["status"] != "playing", "idle game ends (status=%s after %d turns)" % [sim["status"], guard])

	print("Failures: ", _fails)
	get_tree().quit(1 if _fails > 0 else 0)
