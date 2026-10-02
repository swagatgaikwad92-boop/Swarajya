extends RefCounted
## Core rules. Operates on the plain-Dictionary game state so it can be saved as JSON.
## Every number here is a gameplay abstraction unless a data file says otherwise.

const CombatResolver = preload("res://scripts/combat/combat_resolver.gd")

const ARMY_CAP = 14            # max units in one army
const WALL_REPAIR = 8          # wall points repaired per turn if not besieged
const NETWORK_MOVE_BONUS = 1   # move-cost reduction between fort-network territories
const MANPOWER_CAP = 40


# ---------------------------------------------------------------- results
static func _ok(msg: String = "") -> Dictionary:
	return {"ok": true, "msg": msg}


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}


# ---------------------------------------------------------------- setup
static func new_state() -> Dictionary:
	var sc: Dictionary = Game.scenario
	var start: Dictionary = sc["start"]
	var s: Dictionary = {
		"save_version": 1,
		"scenario_id": sc["id"],
		"player": sc["player_faction"],
		"turn": 1,
		"year": int(sc["start_year"]),
		"max_turns": int(sc["max_turns"]),
		"rng_seed": 20260101,
		"status": "playing",
		"end_reason": "",
		"difficulty": "normal",
		"territories": {},
		"armies": [],
		"factions": {},
		"next_army_id": 1,
		"log": [],
		"stats": {"battles_won": 0, "battles_lost": 0, "forts_captured": 0, "forts_lost": 0, "turns_played": 0}
	}
	for tid in start["territories"]:
		var t: Dictionary = start["territories"][tid]
		var fort_id: String = str(Game.territories[tid].get("fort", ""))
		var wall: float = 0.0
		if fort_id != "":
			wall = float(t.get("wall", Game.forts[fort_id]["wall_max"]))
		s["territories"][tid] = {
			"owner": t["owner"],
			"garrison": _int_units(t.get("garrison", {})),
			"wall": wall,
			"besieged": false
		}
	for fid in start["factions"]:
		var f: Dictionary = start["factions"][fid]
		s["factions"][fid] = {"gold": int(f["gold"]), "manpower": int(f["manpower"]),
			"stability": int(f["stability"]), "start_territories": 0, "last_income": 0, "last_upkeep": 0}
	for tid in s["territories"]:
		var o: String = s["territories"][tid]["owner"]
		s["factions"][o]["start_territories"] += 1
	for a in start["armies"]:
		add_army(s, a["owner"], str(a.get("commander", "")), a["territory"],
			_int_units(a["units"]), str(a.get("role", "field")))
	add_log(s, "Campaign begins: " + str(sc["title"]))
	return s


static func _int_units(d) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[k] = int(d[k])
	return out


static func add_log(s: Dictionary, line: String) -> void:
	s["log_count"] = int(s.get("log_count", 0)) + 1
	s["log"].append("T%d: %s" % [int(s["turn"]), line])
	while s["log"].size() > 200:
		s["log"].pop_front()


static func add_army(s: Dictionary, owner: String, commander: String, tid: String,
		units: Dictionary, role: String = "field") -> Dictionary:
	var army: Dictionary = {
		"id": int(s["next_army_id"]), "owner": owner, "commander": commander,
		"territory": tid, "units": units, "morale": 80.0, "supply": 100.0,
		"moves_left": 0, "role": role
	}
	s["next_army_id"] = int(s["next_army_id"]) + 1
	army["moves_left"] = army_speed(army)
	s["armies"].append(army)
	return army


# ---------------------------------------------------------------- lookups
static func army_by_id(s: Dictionary, id):
	for a in s["armies"]:
		if int(a["id"]) == int(id):
			return a
	return null


static func armies_at(s: Dictionary, tid: String) -> Array:
	var out: Array = []
	for a in s["armies"]:
		if a["territory"] == tid:
			out.append(a)
	return out


static func faction_armies(s: Dictionary, fid: String) -> Array:
	var out: Array = []
	for a in s["armies"]:
		if a["owner"] == fid:
			out.append(a)
	return out


static func unit_total(units: Dictionary) -> int:
	var n: int = 0
	for ut in units:
		n += int(units[ut])
	return n


static func owner_of(s: Dictionary, tid: String) -> String:
	return str(s["territories"][tid]["owner"])


static func fort_id_of(tid: String) -> String:
	return str(Game.territories[tid].get("fort", ""))


static func has_fort(tid: String) -> bool:
	return fort_id_of(tid) != ""


static func neighbours(tid: String) -> Array:
	return Game.territories[tid]["neighbours"]


static func army_speed(army: Dictionary) -> int:
	var speed: int = 99
	var any: bool = false
	for ut in army["units"]:
		if int(army["units"][ut]) > 0:
			speed = mini(speed, int(Game.units[ut]["move"]))
			any = true
	if not any:
		return 0
	var cid: String = str(army.get("commander", ""))
	if cid != "" and Game.commanders.has(cid):
		speed += int(Game.commanders[cid]["gameplay"].get("speed_bonus", 0))
	return speed


## A territory with an owned fort, or next to one, is in that owner's fort network.
static func in_network(s: Dictionary, fid: String, tid: String) -> bool:
	if owner_of(s, tid) != fid:
		return false
	if has_fort(tid):
		return true
	for n in neighbours(tid):
		if owner_of(s, n) == fid and has_fort(n):
			return true
	return false


static func is_source(s: Dictionary, fid: String, tid: String) -> bool:
	if owner_of(s, tid) != fid:
		return false
	return has_fort(tid) or bool(Game.territories[tid].get("supply_source", false))


## Hops through own territory to the nearest supply source; -1 if cut off.
static func supply_distance(s: Dictionary, fid: String, tid: String) -> int:
	var visited: Dictionary = {tid: true}
	var frontier: Array = [tid]
	var d: int = 0
	while not frontier.is_empty():
		for t in frontier:
			if is_source(s, fid, t):
				return d
		var nxt: Array = []
		for t in frontier:
			for n in neighbours(t):
				if not visited.has(n) and owner_of(s, n) == fid:
					visited[n] = true
					nxt.append(n)
		frontier = nxt
		d += 1
	return -1


static func supply_target(s: Dictionary, fid: String, tid: String) -> float:
	var pen: float = float(Game.terrain[Game.territories[tid]["terrain"]]["supply_penalty"])
	var d: int = supply_distance(s, fid, tid)
	var target: float = 0.0
	if d < 0:
		target = 30.0 - pen
	else:
		target = 100.0 - 12.0 * float(d) - pen
	return clampf(target, 10.0, 100.0)


## Hops from tid to the nearest territory not owned by fid (0 if tid itself is not).
static func distance_to_enemy(s: Dictionary, fid: String, tid: String) -> int:
	var visited: Dictionary = {tid: true}
	var frontier: Array = [tid]
	var d: int = 0
	while not frontier.is_empty():
		for t in frontier:
			if owner_of(s, t) != fid:
				return d
		var nxt: Array = []
		for t in frontier:
			for n in neighbours(t):
				if not visited.has(n):
					visited[n] = true
					nxt.append(n)
		frontier = nxt
		d += 1
	return 99


# ---------------------------------------------------------------- movement
static func move_cost(s: Dictionary, army: Dictionary, tid: String) -> int:
	var base: int = int(Game.terrain[Game.territories[tid]["terrain"]]["move_cost"])
	var fid: String = army["owner"]
	if in_network(s, fid, army["territory"]) and in_network(s, fid, tid):
		base = maxi(1, base - NETWORK_MOVE_BONUS)
	return base


static func can_move(s: Dictionary, army: Dictionary, tid: String) -> bool:
	if army["territory"] == tid:
		return false
	if not neighbours(army["territory"]).has(tid):
		return false
	if owner_of(s, tid) != army["owner"]:
		return false
	var left: int = int(army["moves_left"])
	if left <= 0:
		return false
	# A fresh army can always make one move, however rough the terrain.
	return left >= move_cost(s, army, tid) or left >= army_speed(army)


static func move_army(s: Dictionary, army: Dictionary, tid: String) -> void:
	var cost: int = move_cost(s, army, tid)
	army["moves_left"] = maxi(0, int(army["moves_left"]) - cost)
	army["territory"] = tid


static func attack_targets(s: Dictionary, army: Dictionary) -> Array:
	var out: Array = []
	if int(army["moves_left"]) <= 0 or unit_total(army["units"]) <= 0:
		return out
	for n in neighbours(army["territory"]):
		if owner_of(s, n) != army["owner"]:
			out.append(n)
	return out


# ---------------------------------------------------------------- recruitment
static func recruit_cost(s: Dictionary, fid: String, tid: String, ut: String) -> int:
	var cost: int = int(Game.units[ut]["cost"])
	if in_network(s, fid, tid):
		cost = int(ceil(float(cost) * 0.9))
	return cost


static func can_recruit(s: Dictionary, fid: String, tid: String, ut: String) -> Dictionary:
	if owner_of(s, tid) != fid:
		return _fail("You do not hold this territory.")
	if not Game.factions[fid]["recruitable"].has(ut):
		return _fail("That unit is not available to this faction.")
	var f: Dictionary = s["factions"][fid]
	if int(f["gold"]) < recruit_cost(s, fid, tid, ut):
		return _fail("Not enough revenue.")
	if int(f["manpower"]) < int(Game.units[ut]["manpower"]):
		return _fail("Not enough manpower.")
	return _ok()


static func recruit(s: Dictionary, fid: String, tid: String, ut: String) -> Dictionary:
	var check: Dictionary = can_recruit(s, fid, tid, ut)
	if not check["ok"]:
		return check
	var f: Dictionary = s["factions"][fid]
	f["gold"] = int(f["gold"]) - recruit_cost(s, fid, tid, ut)
	f["manpower"] = int(f["manpower"]) - int(Game.units[ut]["manpower"])
	for a in armies_at(s, tid):
		if a["owner"] == fid and unit_total(a["units"]) < ARMY_CAP:
			a["units"][ut] = int(a["units"].get(ut, 0)) + 1
			return _ok("Recruited %s." % Game.units[ut]["name"])
	var army: Dictionary = add_army(s, fid, "", tid, {ut: 1}, "field")
	army["moves_left"] = 0
	return _ok("Raised a new army with %s." % Game.units[ut]["name"])


# ---------------------------------------------------------------- garrison
static func garrison_capacity(tid: String) -> int:
	var fid: String = fort_id_of(tid)
	if fid == "":
		return 0
	return int(Game.forts[fid]["garrison_capacity"])


static func leave_garrison(s: Dictionary, army: Dictionary) -> Dictionary:
	var tid: String = army["territory"]
	var cap: int = garrison_capacity(tid)
	if cap <= 0:
		return _fail("Only fort territories can hold a garrison.")
	var inf: int = int(army["units"].get("infantry", 0))
	if inf <= 1:
		return _fail("Not enough infantry to spare.")
	var gar: Dictionary = s["territories"][tid]["garrison"]
	var room: int = cap - unit_total(gar)
	var amount: int = mini(maxi(1, int(round(float(inf) * 0.4))), room)
	if amount <= 0:
		return _fail("Garrison is full.")
	army["units"]["infantry"] = inf - amount
	gar["infantry"] = int(gar.get("infantry", 0)) + amount
	return _ok("%d infantry left in the garrison." % amount)


static func draw_garrison(s: Dictionary, army: Dictionary) -> Dictionary:
	var tid: String = army["territory"]
	var gar: Dictionary = s["territories"][tid]["garrison"]
	if unit_total(gar) <= 0:
		return _fail("No garrison to draw from.")
	var moved: int = 0
	for ut in gar.keys():
		while int(gar[ut]) > 0 and unit_total(army["units"]) < ARMY_CAP:
			gar[ut] = int(gar[ut]) - 1
			army["units"][ut] = int(army["units"].get(ut, 0)) + 1
			moved += 1
	if moved == 0:
		return _fail("Army is at full strength.")
	return _ok("%d units rejoined the army." % moved)


# ---------------------------------------------------------------- battle
static func gather_defenders(s: Dictionary, tid: String) -> Dictionary:
	var t: Dictionary = s["territories"][tid]
	var units: Dictionary = {}
	var weight: float = 0.0
	var morale_sum: float = 0.0
	var supply_sum: float = 0.0
	var best_cmd: String = ""
	var best_mod: float = -1.0
	var gar: Dictionary = t["garrison"]
	var gtotal: int = unit_total(gar)
	for ut in gar:
		units[ut] = int(units.get(ut, 0)) + int(gar[ut])
	if gtotal > 0:
		weight += float(gtotal)
		morale_sum += float(gtotal) * 80.0
		supply_sum += float(gtotal) * 100.0
	for a in armies_at(s, tid):
		var n: int = unit_total(a["units"])
		for ut in a["units"]:
			units[ut] = int(units.get(ut, 0)) + int(a["units"][ut])
		weight += float(n)
		morale_sum += float(n) * float(a["morale"])
		supply_sum += float(n) * float(a["supply"])
		var cid: String = str(a.get("commander", ""))
		if cid != "" and Game.commanders.has(cid):
			var m: float = float(Game.commanders[cid]["gameplay"]["defense_mod"])
			if m > best_mod:
				best_mod = m
				best_cmd = cid
	if weight <= 0.0:
		return {"units": units, "commander": "", "morale": 80.0, "supply": 100.0}
	return {"units": units, "commander": best_cmd, "morale": morale_sum / weight, "supply": supply_sum / weight}


static func _army_force(army: Dictionary) -> Dictionary:
	return {"units": army["units"], "commander": str(army.get("commander", "")),
		"morale": army["morale"], "supply": army["supply"]}


## Estimated powers for UI and AI. No randomness.
static func battle_preview(s: Dictionary, army: Dictionary, tid: String, tactic: String) -> Dictionary:
	var td: Dictionary = Game.territories[tid]
	var ts: Dictionary = s["territories"][tid]
	var defn: Dictionary = gather_defenders(s, tid)
	var est: Dictionary = CombatResolver.estimate(_army_force(army), defn, td["terrain"],
		fort_id_of(tid), float(ts["wall"]), tactic)
	est["ratio"] = float(est["attack"]) / maxf(0.01, float(est["defense"]))
	est["defenders"] = defn
	return est


static func _merge_counts(dst: Dictionary, src: Dictionary) -> void:
	for k in src:
		dst[k] = int(dst.get(k, 0)) + int(src[k])


static func _stab(s: Dictionary, fid: String, delta: int) -> void:
	var f: Dictionary = s["factions"][fid]
	f["stability"] = clampi(int(f["stability"]) + delta, 0, 100)


static func besiege(s: Dictionary, army: Dictionary, tid: String) -> Dictionary:
	if not attack_targets(s, army).has(tid):
		return _fail("That territory cannot be besieged now.")
	if not has_fort(tid):
		return _fail("There is no fort to besiege.")
	var ts: Dictionary = s["territories"][tid]
	if float(ts["wall"]) <= 0.0:
		return _fail("The walls are already breached.")
	var art: int = int(army["units"].get("artillery", 0))
	var dmg: float = 12.0 + 10.0 * float(art)
	ts["wall"] = maxf(0.0, float(ts["wall"]) - dmg)
	ts["besieged"] = true
	army["moves_left"] = 0
	army["supply"] = maxf(0.0, float(army["supply"]) - 8.0)
	var msg: String = "Besieged %s: walls down by %d to %d." % [
		Game.territories[tid]["name"], int(dmg), int(ts["wall"])]
	add_log(s, "%s army #%d. %s" % [Game.factions[army["owner"]]["short_name"], int(army["id"]), msg])
	return _ok(msg)


static func attack(s: Dictionary, army: Dictionary, tid: String, tactic: String) -> Dictionary:
	if not attack_targets(s, army).has(tid):
		return _fail("That territory cannot be attacked now.")
	var td: Dictionary = Game.territories[tid]
	var ts: Dictionary = s["territories"][tid]
	var attacker_owner: String = army["owner"]
	var defender_owner: String = ts["owner"]
	var fort_id: String = fort_id_of(tid)
	var defn: Dictionary = gather_defenders(s, tid)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s["rng_seed"])
	s["rng_seed"] = int(s["rng_seed"]) + 7919
	var r: Dictionary = CombatResolver.resolve(_army_force(army), defn, td["terrain"],
		fort_id, float(ts["wall"]), tactic, rng)
	var wins: bool = r["attacker_wins"]

	var att_losses: Dictionary = CombatResolver.apply_losses(army["units"], r["attacker_loss_frac"], not wins)
	var def_losses: Dictionary = {}
	_merge_counts(def_losses, CombatResolver.apply_losses(ts["garrison"], r["defender_loss_frac"], wins))
	var def_armies: Array = armies_at(s, tid).duplicate()
	for a in def_armies:
		_merge_counts(def_losses, CombatResolver.apply_losses(a["units"], r["defender_loss_frac"], wins))
		a["morale"] = clampf(float(a["morale"]) + (-20.0 if wins else 5.0), 5.0, 100.0)

	army["morale"] = clampf(float(army["morale"]) + (10.0 if wins else -20.0), 5.0, 100.0)
	army["supply"] = maxf(0.0, float(army["supply"]) - 10.0)
	army["moves_left"] = 0

	var captured: bool = false
	var strat: int = 0
	if fort_id != "":
		strat = int(Game.forts[fort_id]["strategic"])
	var player: String = s["player"]

	if wins:
		captured = true
		ts["owner"] = attacker_owner
		ts["garrison"] = {}
		ts["besieged"] = false
		if fort_id != "":
			ts["wall"] = float(Game.forts[fort_id]["wall_max"]) * 0.4
		for a in def_armies:
			_retreat(s, a, tid, defender_owner)
		army["territory"] = tid
		_stab(s, attacker_owner, 2 + (int(round(float(strat) * 0.6)) if fort_id != "" else 0))
		_stab(s, defender_owner, -3 - strat)
		if attacker_owner == player:
			s["stats"]["battles_won"] += 1
			if fort_id != "":
				s["stats"]["forts_captured"] += 1
		elif defender_owner == player:
			s["stats"]["battles_lost"] += 1
			if fort_id != "":
				s["stats"]["forts_lost"] += 1
	else:
		_stab(s, attacker_owner, -2)
		_stab(s, defender_owner, 1)
		if attacker_owner == player:
			s["stats"]["battles_lost"] += 1
		elif defender_owner == player:
			s["stats"]["battles_won"] += 1

	_cleanup_armies(s)

	var msg: String = "%s attacked %s (%s). %s." % [
		Game.factions[attacker_owner]["short_name"], td["name"],
		CombatResolver.TACTICS[tactic]["label"] if CombatResolver.TACTICS.has(tactic) else tactic,
		("The attack succeeded and the territory was taken" if wins else "The attack was repulsed")]
	add_log(s, msg)
	check_end(s)
	return {
		"ok": true, "msg": msg, "attacker_wins": wins, "captured": captured, "fort": fort_id != "",
		"territory": tid, "attacker_owner": attacker_owner, "defender_owner": defender_owner,
		"attacker_power": r["attacker_power"], "defender_power": r["defender_power"],
		"attacker_losses": att_losses, "defender_losses": def_losses
	}


static func _retreat(s: Dictionary, army: Dictionary, from_tid: String, owner: String) -> void:
	var dest: String = ""
	for n in neighbours(from_tid):
		if owner_of(s, n) == owner:
			if dest == "" or (has_fort(n) and not has_fort(dest)):
				dest = n
	if dest == "":
		army["units"] = {}
		return
	army["territory"] = dest
	army["moves_left"] = 0


static func _cleanup_armies(s: Dictionary) -> void:
	var keep: Array = []
	for a in s["armies"]:
		if unit_total(a["units"]) > 0:
			keep.append(a)
	s["armies"] = keep


# ---------------------------------------------------------------- turn processing
static func process_economy(s: Dictionary) -> void:
	for fid in s["factions"]:
		var f: Dictionary = s["factions"][fid]
		var income: int = 0
		var manpower: int = 0
		var owned: int = 0
		for tid in s["territories"]:
			if s["territories"][tid]["owner"] == fid:
				income += int(Game.territories[tid]["revenue"])
				manpower += int(Game.territories[tid]["manpower"])
				owned += 1
		var men: int = 0
		for a in faction_armies(s, fid):
			men += unit_total(a["units"])
		var upkeep: int = int(ceil(float(men) / 5.0))
		f["gold"] = maxi(0, int(f["gold"]) + income - upkeep)
		f["manpower"] = mini(MANPOWER_CAP, int(f["manpower"]) + manpower)
		f["last_income"] = income
		f["last_upkeep"] = upkeep
		var drift: int = clampi(owned - int(f["start_territories"]), -2, 2)
		if income < upkeep:
			drift -= 1
		_stab(s, fid, drift)


static func process_walls(s: Dictionary) -> void:
	for tid in s["territories"]:
		var fid: String = fort_id_of(tid)
		if fid == "":
			continue
		var ts: Dictionary = s["territories"][tid]
		if not bool(ts["besieged"]):
			ts["wall"] = minf(float(Game.forts[fid]["wall_max"]), float(ts["wall"]) + float(WALL_REPAIR))
		ts["besieged"] = false


static func process_armies(s: Dictionary) -> void:
	for a in s["armies"]:
		var fid: String = a["owner"]
		var tid: String = a["territory"]
		var target: float = supply_target(s, fid, tid)
		var sup: float = float(a["supply"])
		if sup < target:
			sup = minf(target, sup + 20.0)
		else:
			sup = maxf(target, sup - 10.0)
		a["supply"] = sup
		var morale_gain: float = 5.0 + (5.0 if in_network(s, fid, tid) else 0.0)
		if sup < 30.0:
			morale_gain = -5.0
		a["morale"] = clampf(float(a["morale"]) + morale_gain, 5.0, 100.0)
		a["moves_left"] = army_speed(a)


# ---------------------------------------------------------------- end conditions
static func check_end(s: Dictionary) -> void:
	if s["status"] != "playing":
		return
	var sc: Dictionary = Game.scenario
	var player: String = s["player"]
	var all_held: bool = true
	for fid in sc["victory"]["hold_forts"]:
		var tid: String = Game.forts[fid]["territory"]
		if owner_of(s, tid) != player:
			all_held = false
	if all_held:
		s["status"] = "won"
		s["end_reason"] = "All four strategic forts are held."
		return
	if bool(sc["defeat"].get("stability_zero", false)) and int(s["factions"][player]["stability"]) <= 0:
		s["status"] = "lost"
		s["end_reason"] = "Stability collapsed to zero (a gameplay abstraction)."
		return
	var holds_core: bool = false
	for tid in sc["defeat"]["core_territories"]:
		if owner_of(s, tid) == player:
			holds_core = true
	if not holds_core:
		s["status"] = "lost"
		s["end_reason"] = "All core territories were lost."
		return
	if faction_armies(s, player).is_empty():
		var f: Dictionary = s["factions"][player]
		if int(f["gold"]) < 10 or int(f["manpower"]) < 1:
			s["status"] = "lost"
			s["end_reason"] = "No army remains and no means to raise one."
			return
	if int(s["turn"]) > int(s["max_turns"]):
		s["status"] = "lost"
		s["end_reason"] = "Time ran out before the forts were secured."


static func forts_held(s: Dictionary, fid: String) -> Array:
	var out: Array = []
	for f in Game.forts:
		if owner_of(s, Game.forts[f]["territory"]) == fid:
			out.append(Game.forts[f]["name"])
	return out


static func player_outcome(s: Dictionary) -> String:
	var st: Dictionary = s["stats"]
	var head: String = "VICTORY (gameplay result)." if s["status"] == "won" else "DEFEAT (gameplay result)."
	var t: String = "%s %s\nReached turn %d of %d (year %d).\n" % [
		head, s["end_reason"], int(s["turn"]), int(s["max_turns"]), int(s["year"])]
	t += "Forts held: %s.\n" % (", ".join(PackedStringArray(forts_held(s, s["player"]))) if not forts_held(s, s["player"]).is_empty() else "none")
	t += "Battles won %d, lost %d. Forts captured %d, lost %d.\n" % [
		int(st["battles_won"]), int(st["battles_lost"]), int(st["forts_captured"]), int(st["forts_lost"])]
	t += "This describes your playthrough only. It is not documented history."
	return t
