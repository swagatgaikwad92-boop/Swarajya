extends Node
## Autoload singleton "Game": static data, the live game state, scene helpers.

const DataLoader = preload("res://scripts/core/data_loader.gd")
const Rules = preload("res://scripts/core/rules.gd")
const SaveSystem = preload("res://scripts/save/save_system.gd")

const SCENARIO_PATH = "res://data/campaigns/early_consolidation.json"

var terrain: Dictionary = {}
var units: Dictionary = {}
var factions: Dictionary = {}
var territories: Dictionary = {}
var forts: Dictionary = {}
var commanders: Dictionary = {}
var scenario: Dictionary = {}
var state: Dictionary = {}
var settings: Dictionary = {"difficulty": "normal"}


func _ready() -> void:
	load_data()
	settings = SaveSystem.load_settings(settings)


func load_data() -> void:
	terrain = _as_dict(DataLoader.load_json("res://data/terrain.json"))
	units = _as_dict(DataLoader.load_json("res://data/units.json"))
	factions = _as_dict(DataLoader.load_json("res://data/factions.json"))
	territories = _as_dict(DataLoader.load_json("res://data/territories.json"))
	forts = _as_dict(DataLoader.load_json("res://data/forts.json"))
	commanders = _as_dict(DataLoader.load_json("res://data/commanders.json"))
	scenario = _as_dict(DataLoader.load_json(SCENARIO_PATH))
	# Make adjacency symmetric so data files only need to list each link once.
	for tid in territories:
		for n in territories[tid]["neighbours"]:
			if territories.has(n) and not territories[n]["neighbours"].has(tid):
				territories[n]["neighbours"].append(tid)
	# Fort start values.
	for fid in forts:
		if not forts[fid].has("wall_start"):
			forts[fid]["wall_start"] = forts[fid]["wall_max"]


func _as_dict(v) -> Dictionary:
	if v is Dictionary:
		return v
	return {}


func start_new_campaign() -> void:
	state = Rules.new_state()
	state["difficulty"] = str(settings.get("difficulty", "normal"))
	SaveSystem.save_state(state)


func continue_campaign() -> bool:
	var loaded: Dictionary = SaveSystem.load_state()
	if loaded.is_empty():
		return false
	state = loaded
	return true


func save_game() -> bool:
	if state.is_empty():
		return false
	return SaveSystem.save_state(state)


func set_difficulty(d: String) -> void:
	settings["difficulty"] = d
	SaveSystem.save_settings(settings)


func goto(scene_name: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene_name)
