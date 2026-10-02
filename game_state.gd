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
var selected_campaign_path: String = "res://data/campaigns/campaign_pratapgad.json"
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
	campaign = load_json(selected_campaign_path)
	var tpath := str(campaign.get("territories_file", "res://data/territories/territories.json"))
	var fpath := str(campaign.get("forts_file", "res://data/forts/forts.json"))
	territories = load_json(tpath)
	forts = load_json(fpath)
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
	var cid0 := str(campaign.get("id", ""))
	if cid0 == "peshwa_thrust":
		explored = {"pune2": true, "satara2": true, "kolhapur": true, "nashik": true, "ahmednagar": true}
	elif cid0 == "confederacy_pressure":
		explored = {"gwalior": true, "malwa3": true, "bundelkhand": true, "indore": true, "delhi_fringe": true}
	else:
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
	var dest_owner := str(territory_by_id(dest).get("owner", ""))
	if dest_owner != army["owner"] and at_war:
		return "At war — attack to enter."
	if dest_owner != army["owner"] and relation < 0:
		return "No military access."
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
	var enemy_ids: Array = []
	for a in armies:
		if a["owner"] != player_faction and a["owner"] not in enemy_ids:
			enemy_ids.append(a["owner"])
	for t in territories:
		var own = str(t.get("owner", ""))
		if own != player_faction and own != "" and own not in enemy_ids:
			enemy_ids.append(own)
	for eid in enemy_ids:
		var ai_rev := 30
		for t in territories:
			if t.get("owner") == eid:
				ai_rev += int(t.get("revenue", 0))
		var fac := faction_by_id(eid)
		var fname := str(fac.get("name", eid))
		for a in armies:
			if a["owner"] != eid:
				continue
			a["mp"] = a.get("mp_max", 3)
			var acted := false
			var options: Array = neighbours_of(a["territory"])
			options.shuffle()
			if at_war:
				for nid in options:
					var nt := territory_by_id(nid)
					if nt.get("owner") != player_faction or a["mp"] <= 0:
						continue
					var defenders: Array = []
					for oa in armies_at(nid):
						if oa["owner"] == player_faction:
							defenders.append(oa)
					var ok := defenders.is_empty() or strength_of(a) >= strength_of(defenders[0]) - 1
					if ok:
						_resolve_attack(a, nid, "aggressive")
						acted = true
						break
			if acted:
				continue
			if at_war:
				for nid in options:
					var nt2 := territory_by_id(nid)
					if nt2.get("owner") == eid:
						continue
					if armies_at(nid).size() > 0:
						continue
					if a["mp"] <= 0:
						continue
					a["territory"] = nid
					a["mp"] -= 1
					nt2["owner"] = eid
					explored[nid] = true
					log_lines.append("%s occupied %s." % [fname, nt2["name"]])
					acted = true
					break
			if acted:
				continue
			if ai_rev >= 40 and a["units"].size() < 7:
				var prefer := "light_cavalry" if str(campaign.get("era", "")) in ["era2", "era3"] else "infantry"
				a["units"].append(prefer)
				ai_rev -= int(unit_def(prefer).get("cost", 40))
				log_lines.append("%s recruited %s." % [fname, prefer])
		log_lines.append("%s ended orders." % fname)
	log_lines.append("AI turn complete.")

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
	var by_id := {}
	for t in territories:
		by_id[t["id"]] = t
		if t.get("owner") == player_faction:
			owned += 1
	var player_alive := false
	for a in armies:
		if a["owner"] == player_faction and a["units"].size() > 0:
			player_alive = true
	var cid := str(campaign.get("id", ""))
	if cid == "peshwa_thrust":
		var has_pune := by_id.get("pune2", {}).get("owner") == player_faction
		var has_ahmed := by_id.get("ahmednagar", {}).get("owner") == player_faction
		var has_hyd := by_id.get("hyderabad", {}).get("owner") == player_faction
		if not has_pune or not player_alive:
			phase = "over"
			outcome = "defeat"
			outcome_detail = "Pune lost or all armies destroyed."
			return
		if (owned >= 7 and has_ahmed) or has_hyd:
			phase = "over"
			outcome = "victory"
			outcome_detail = "Victory conditions met: expansion objectives."
			return
	elif cid == "confederacy_pressure":
		var has_gwalior := by_id.get("gwalior", {}).get("owner") == player_faction
		var has_delhi := by_id.get("delhi_fringe", {}).get("owner") == player_faction
		var has_doab := by_id.get("doab", {}).get("owner") == player_faction
		if not has_gwalior or not player_alive:
			phase = "over"
			outcome = "defeat"
			outcome_detail = "Gwalior lost or all armies destroyed."
			return
		if (owned >= 6 and has_gwalior) or (has_delhi and has_doab):
			phase = "over"
			outcome = "victory"
			outcome_detail = "Victory conditions met: confederacy objectives."
			return
	else:
		var has_raigad := by_id.get("raigad", {}).get("owner") == player_faction
		var has_pratap := by_id.get("pratapgad", {}).get("owner") == player_faction
		var has_sinhagad := by_id.get("sinhagad", {}).get("owner") == player_faction
		var has_pune := by_id.get("pune", {}).get("owner") == player_faction
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

func pay_tribute() -> String:
	if revenue < 25:
		return "Need 25 revenue."
	revenue -= 25
	relation = mini(40, relation + 12)
	log_lines.append("Tribute paid. GAMEPLAY action, not a documented payment.")
	return "Tribute paid. Relation %d." % relation

func seek_access() -> String:
	if relation < 0:
		return "Access refused. Relation %d." % relation
	log_lines.append("Military access granted for this scenario (gameplay).")
	return "Military access granted (gameplay). Enemy territory may be crossed while at peace."

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
		"explored": explored,
		"selected_campaign_path": selected_campaign_path
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
	selected_campaign_path = str(data.get("selected_campaign_path", selected_campaign_path))
	return true
