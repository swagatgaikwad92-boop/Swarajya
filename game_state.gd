extends Node
## Autoload: GameState
## Central mutable campaign state. Data files are read-only templates.

const SAVE_PATH := "user://swarajya_save.json"
const SAVE_VERSION := 1

var campaign: Dictionary = {}
var territories: Array = []
var forts: Array = []
var factions: Array = []
var commanders: Array = []
var unit_defs: Array = []
var armies: Array = []
var year: int = 1656
var turn: int = 1
var max_turns: int = 16
var phase: String = "player" # player | ai | over
var revenue: int = 0
var manpower: int = 0
var stability: int = 0
var player_faction: String = "maratha"
var enemy_faction: String = "adilshahi"
var log_lines: Array = []
var outcome: String = ""
var outcome_detail: String = ""
var relation: int = -40
var at_war: bool = true
var explored: Dictionary = {}

func _ready() -> void:
	pass

func load_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data: " + path)
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed

func start_campaign() -> void:
	factions = load_json("res://data/factions/factions.json")
	unit_defs = load_json("res://data/units/units.json")
	commanders = load_json("res://data/commanders/commanders.json")
	forts = load_json("res://data/forts/forts.json")
	territories = load_json("res://data/territories/territories.json")
	campaign = load_json("res://data/campaigns/campaign_pratapgad.json")
	year = int(campaign.get("year", 1656))
	turn = 1
	max_turns = int(campaign.get("max_turns", 16))
	player_faction = campaign.get("player_faction", "maratha")
	enemy_faction = campaign.get("enemy_faction", "adilshahi")
	revenue = int(campaign.get("starting_revenue", 80))
	manpower = int(campaign.get("starting_manpower", 6))
	stability = int(campaign.get("starting_stability", 60))
	phase = "player"
	outcome = ""
	outcome_detail = ""
	armies.clear()
	for a in campaign.get("armies", []):
		armies.append({
			"id": a["id"],
			"owner": a["owner"],
			"commander": a["commander"],
			"territory": a["territory"],
			"units": a["units"].duplicate(),
			"mp": int(a.get("mp", 3)),
			"mp_max": int(a.get("mp", 3)),
			"morale": int(a.get("morale", 70)),
			"supply": int(a.get("supply", 80))
		})
	log_lines = ["Campaign started. Year %d. GAMEPLAY scenario, not a literal reconstruction." % year]
	relation = -40
	at_war = true
	explored = {"raigad": true, "pratapgad": true, "torna": true, "mahad": true, "sinhagad": true}
	refresh_mp()

func territory_by_id(tid: String) -> Dictionary:
	for t in territories:
		if t["id"] == tid:
			return t
	return {}

func fort_for_territory(tid: String) -> Dictionary:
	for ft in forts:
		if ft.get("territory") == tid:
			return ft
	return {}

func commander_by_id(cid: String) -> Dictionary:
	for c in commanders:
		if c["id"] == cid:
			return c
	return {}

func unit_def(uid: String) -> Dictionary:
	for u in unit_defs:
		if u["id"] == uid:
			return u
	return {}

func faction_by_id(fid: String) -> Dictionary:
	for f in factions:
		if f["id"] == fid:
			return f
	return {}

func armies_at(tid: String) -> Array:
	var out: Array = []
	for a in armies:
		if a["territory"] == tid:
			out.append(a)
	return out

func player_armies() -> Array:
	var out: Array = []
	for a in armies:
		if a["owner"] == player_faction:
			out.append(a)
	return out

func strength_of(army: Dictionary) -> int:
	var s := 0
	var cmd := commander_by_id(army.get("commander", ""))
	for uid in army.get("units", []):
		var u := unit_def(uid)
		s += int(u.get("attack", 5)) + int(u.get("defense", 5))
	s += int(cmd.get("gameplay_attack_mod", 0)) * 2
	s = int(s * (float(army.get("morale", 70)) / 100.0))
	s = int(s * (0.6 + 0.4 * float(army.get("supply", 80)) / 100.0))
	return max(1, s)

func neighbours_of(tid: String) -> Array:
	var t := territory_by_id(tid)
	return t.get("neighbours", [])

func refresh_mp() -> void:
	for a in armies:
		if a["owner"] == player_faction and phase == "player":
			a["mp"] = a.get("mp_max", 3)
		elif a["owner"] != player_faction and phase == "ai":
			a["mp"] = a.get("mp_max", 3)

func move_army(army: Dictionary, dest: String) -> String:
	if phase != "player" or army["owner"] != player_faction:
		return "Not your turn."
	if army["mp"] <= 0:
		return "No movement points."
	if dest not in neighbours_of(army["territory"]):
		return "Not adjacent."
	var hostiles := []
	for a in armies_at(dest):
		if a["owner"] != army["owner"]:
			hostiles.append(a)
	if hostiles.size() > 0:
		return "Enemy present — attack instead."
	var t := territory_by_id(dest)
	var cost := 1
	if t.get("terrain") in ["mountains", "forest"]:
		cost = 2
	if army["mp"] < cost:
		return "Terrain costs %d movement." % cost
	army["mp"] -= cost
	army["territory"] = dest
	explored[dest] = true
	for nid in neighbours_of(dest):
		explored[nid] = true
	if t.get("owner") != army["owner"]:
		t["owner"] = army["owner"]
		stability = mini(100, stability + 2)
		log_lines.append("Occupied %s." % t["name"])
	else:
		log_lines.append("Moved to %s." % t["name"])
	_check_end()
	return "OK"

func recruit(army: Dictionary, unit_id: String) -> String:
	if phase != "player":
		return "Not your turn."
	var u := unit_def(unit_id)
	if u.is_empty():
		return "Unknown unit."
	if unit_id == "garrison":
		return "Garrisons are raised only in forts via Reinforce Fort."
	var cost := int(u.get("cost", 40))
	if revenue < cost:
		return "Not enough revenue."
	if manpower < 1:
		return "Not enough manpower."
	revenue -= cost
	manpower -= 1
	army["units"].append(unit_id)
	log_lines.append("Recruited %s." % u["name"])
	return "OK"

func end_player_turn() -> void:
	if phase != "player":
		return
	phase = "ai"
	_income(player_faction)
	_supply_tick()
	refresh_mp()
	_ai_turn()
	turn += 1
	year += 1 if turn % 2 == 0 else 0
	phase = "player"
	refresh_mp()
	_income_note()
	_check_end()

func _income(fid: String) -> void:
	var gain := 0
	for t in territories:
		if t.get("owner") == fid:
			gain += int(t.get("revenue", 0))
	if fid == player_faction:
		revenue += gain
		manpower = mini(12, manpower + 1)
		log_lines.append("Revenue +%d. Manpower refreshed slightly." % gain)

func _income_note() -> void:
	pass

func _supply_tick() -> void:
	for a in armies:
		var t := territory_by_id(a["territory"])
		var friendly := t.get("owner") == a["owner"]
		var fort := fort_for_territory(a["territory"])
		var delta := 8 if friendly else -12
		if not fort.is_empty() and t.get("owner") == a["owner"]:
			delta += int(fort.get("supply", 0)) * 2
		if t.get("terrain") == "mountains":
			delta -= 4
		a["supply"] = clampi(int(a.get("supply", 80)) + delta, 0, 100)
		if a["supply"] < 30:
			a["morale"] = max(20, int(a["morale"]) - 5)

func _ai_turn() -> void:
	# Priorities: defend own forts, attack adjacent weak player territory, recruit if rich.
	var ai_rev := 40
	for t in territories:
		if t.get("owner") == enemy_faction:
			ai_rev += int(t.get("revenue", 0))
	for a in armies:
		if a["owner"] != enemy_faction:
			continue
		a["mp"] = a.get("mp_max", 3)
		var acted := false
		# attack adjacent player territory if stronger
		var options: Array = neighbours_of(a["territory"])
		options.shuffle()
		for nid in options:
			var nt := territory_by_id(nid)
			if at_war and nt.get("owner") == player_faction and a["mp"] > 0:
				var defenders := []
				for oa in armies_at(nid):
					if oa["owner"] == player_faction:
						defenders.append(oa)
				if defenders.is_empty() or strength_of(a) >= strength_of(defenders[0]) - 2:
					_resolve_attack(a, nid, "aggressive")
					acted = true
					break
		if acted:
			continue
		# step toward a player territory
		for nid in neighbours_of(a["territory"]):
			var nt2 := territory_by_id(nid)
			if at_war and nt2.get("owner") != enemy_faction and armies_at(nid).is_empty() and a["mp"] > 0:
				a["territory"] = nid
				a["mp"] -= 1
				nt2["owner"] = enemy_faction
				log_lines.append("Adil Shahi occupied %s." % nt2["name"])
				acted = true
				break
		if not acted and ai_rev >= 40 and a["units"].size() < 6:
			a["units"].append("infantry")
			ai_rev -= 40
			log_lines.append("Adil Shahi recruited infantry.")
	log_lines.append("Adil Shahi ended the turn.")

func attack(army: Dictionary, dest: String, tactic: String) -> String:
	if phase != "player" or army["owner"] != player_faction:
		return "Not your turn."
	if army["mp"] <= 0:
		return "No movement points."
	if dest not in neighbours_of(army["territory"]) and dest != army["territory"]:
		return "Not adjacent."
	return _resolve_attack(army, dest, tactic)

func _resolve_attack(army: Dictionary, dest: String, tactic: String) -> String:
	var dest_t := territory_by_id(dest)
	var defenders: Array = []
	for a in armies_at(dest):
		if a["owner"] != army["owner"]:
			defenders.append(a)
	var fort := fort_for_territory(dest)
	var atk := strength_of(army)
	var dfn := 4
	if defenders.size() > 0:
		dfn = strength_of(defenders[0])
	else:
		dfn = 6 + int(dest_t.get("strategic", 1))
	# terrain
	var terrain := str(dest_t.get("terrain", "plains"))
	if terrain == "hills":
		dfn += 3
	elif terrain == "mountains":
		dfn += 5
	elif terrain == "forest":
		dfn += 2
	if not fort.is_empty() and dest_t.get("owner") != army["owner"]:
		dfn += int(fort.get("defense", 4))
	if tactic == "aggressive":
		atk += 3
	elif tactic == "defensive":
		atk -= 1
		dfn += 2
	elif tactic == "harass":
		atk += 1
	var attacker_wins: bool = atk + randi_range(-2, 2) >= dfn
	army["mp"] = max(0, int(army["mp"]) - 1)
	var msg := ""
	if attacker_wins:
		if defenders.size() > 0:
			var d := defenders[0]
			if d["units"].size() > 0:
				d["units"].pop_back()
			d["morale"] = max(10, int(d["morale"]) - 15)
			if d["units"].is_empty():
				armies.erase(d)
				msg = "Defender army destroyed."
			else:
				# retreat to a friendly neighbour if possible
				var retreated := false
				for nid in neighbours_of(dest):
					var nt := territory_by_id(nid)
					if nt.get("owner") == d["owner"] and armies_at(nid).is_empty():
						d["territory"] = nid
						retreated = true
						break
				msg = "Defender retreated." if retreated else "Defender holds a remnant."
				if not retreated and d["units"].size() > 0 and dest_t.get("owner") == d["owner"]:
					pass
		if army["units"].size() > 0 and randf() < 0.35:
			army["units"].pop_back()
		dest_t["owner"] = army["owner"]
		army["territory"] = dest
		army["morale"] = mini(100, int(army["morale"]) + 5)
		if army["owner"] == player_faction:
			stability = mini(100, stability + 4)
		msg = "Victory at %s. %s" % [dest_t["name"], msg]
	else:
		if army["units"].size() > 0:
			army["units"].pop_back()
		army["morale"] = max(10, int(army["morale"]) - 12)
		if army["owner"] == player_faction:
			stability = max(0, stability - 4)
		msg = "Repulsed at %s." % dest_t["name"]
		if army["units"].is_empty():
			armies.erase(army)
			msg += " Army lost."
	log_lines.append(msg)
	_check_end()
	return msg

func _check_end() -> void:
	var owned := 0
	var has_raigad := false
	var has_pratap := false
	var has_sinhagad := false
	var has_pune := false
	for t in territories:
		if t.get("owner") == player_faction:
			owned += 1
			if t["id"] == "raigad":
				has_raigad = true
			if t["id"] == "pratapgad":
				has_pratap = true
			if t["id"] == "sinhagad":
				has_sinhagad = true
			if t["id"] == "pune":
				has_pune = true
	var player_alive := false
	for a in armies:
		if a["owner"] == player_faction and a["units"].size() > 0:
			player_alive = true
	if not has_raigad or not player_alive:
		phase = "over"
		outcome = "defeat"
		outcome_detail = "Raigad lost or all armies destroyed."
		return
	if (has_raigad and has_pratap and owned >= 7) or (has_sinhagad and has_pune):
		phase = "over"
		outcome = "victory"
		outcome_detail = "Victory conditions met: forts and territory."
		return
	if turn > max_turns:
		phase = "over"
		outcome = "defeat"
		outcome_detail = "Campaign time expired without meeting victory conditions."

func propose_peace() -> String:
	if not at_war:
		return "Already at peace."
	if relation < -10:
		relation += 5
		return "Adil Shahi rejects peace. Relation %d (gameplay)." % relation
	at_war = false
	relation = 10
	log_lines.append("Peace agreed. GAMEPLAY treaty, not a documented treaty.")
	return "Peace agreed."

func declare_war() -> String:
	if at_war:
		return "Already at war."
	at_war = true
	relation = -30
	log_lines.append("War declared.")
	return "War declared."

func is_visible(tid: String) -> bool:
	var t := territory_by_id(tid)
	if t.get("owner") == player_faction:
		return true
	return bool(explored.get(tid, false))

func to_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"year": year,
		"turn": turn,
		"phase": phase,
		"revenue": revenue,
		"manpower": manpower,
		"stability": stability,
		"territories": territories,
		"armies": armies,
		"log_lines": log_lines,
		"outcome": outcome,
		"outcome_detail": outcome_detail,
		"relation": relation,
		"at_war": at_war,
		"explored": explored
	}

func save_game() -> String:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return "Save failed."
	f.store_string(JSON.stringify(to_save()))
	f.close()
	return "Saved."

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	start_campaign()
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	year = int(data.get("year", year))
	turn = int(data.get("turn", turn))
	phase = str(data.get("phase", "player"))
	revenue = int(data.get("revenue", revenue))
	manpower = int(data.get("manpower", manpower))
	stability = int(data.get("stability", stability))
	territories = data.get("territories", territories)
	armies = data.get("armies", armies)
	log_lines = data.get("log_lines", log_lines)
	outcome = str(data.get("outcome", ""))
	outcome_detail = str(data.get("outcome_detail", ""))
	relation = int(data.get("relation", relation))
	at_war = bool(data.get("at_war", true))
	var ex = data.get("explored", {})
	if typeof(ex) == TYPE_DICTIONARY:
		explored = ex
	return true
