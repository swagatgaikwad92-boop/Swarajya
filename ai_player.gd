extends RefCounted
## Simple rule-based AI. It sees the whole map (no fog of war in v0.1).

const Rules = preload("res://scripts/core/rules.gd")

const THRESHOLDS = {"easy": 1.45, "normal": 1.2, "hard": 1.05}
const RECRUIT_EVERY = {"easy": 3, "normal": 2, "hard": 1}


static func run_faction(s: Dictionary, fid: String) -> void:
	_recruit(s, fid)
	var ids: Array = []
	for a in Rules.faction_armies(s, fid):
		ids.append(int(a["id"]))
	for id in ids:
		var army = Rules.army_by_id(s, id)
		if army == null:
			continue
		_act(s, army)


static func _threshold(s: Dictionary) -> float:
	return float(THRESHOLDS.get(str(s.get("difficulty", "normal")), 1.2))


static func _value(s: Dictionary, tid: String) -> float:
	var v: float = float(Game.territories[tid]["revenue"])
	var f: String = Rules.fort_id_of(tid)
	if f != "":
		v += float(Game.forts[f]["strategic"])
	if bool(Game.territories[tid].get("supply_source", false)):
		v += 6.0
	return v


static func _act(s: Dictionary, army: Dictionary) -> void:
	if int(army["moves_left"]) <= 0:
		return
	var fid: String = army["owner"]
	var base_need: float = _threshold(s)
	var targets: Array = Rules.attack_targets(s, army)
	var best_tid: String = ""
	var best_score: float = 0.0
	var best_ratio: float = 0.0
	for tid in targets:
		var ratio: float = float(Rules.battle_preview(s, army, tid, "balanced")["ratio"])
		var need: float = base_need
		var f: String = Rules.fort_id_of(tid)
		if f != "" and float(s["territories"][tid]["wall"]) < 0.5 * float(Game.forts[f]["wall_max"]):
			need -= 0.1
		if army["role"] == "guard":
			need = maxf(need, 1.6)
		if float(army["supply"]) < 35.0:
			need += 0.3
		if ratio >= need:
			var score: float = ratio * (1.0 + _value(s, tid) / 10.0)
			if score > best_score:
				best_score = score
				best_tid = tid
				best_ratio = ratio
	if best_tid != "":
		var tac: String = "aggressive" if best_ratio > 1.6 else "balanced"
		Rules.attack(s, army, best_tid, tac)
		return
	# Siege a strong fort if we have guns and the odds are not hopeless.
	if int(army["units"].get("artillery", 0)) > 0:
		for tid in targets:
			var f2: String = Rules.fort_id_of(tid)
			if f2 != "" and float(s["territories"][tid]["wall"]) > 35.0:
				if float(Rules.battle_preview(s, army, tid, "balanced")["ratio"]) >= 0.6:
					Rules.besiege(s, army, tid)
					return
	if army["role"] == "guard":
		return
	if float(army["supply"]) < 40.0:
		return
	# Hold if outnumbered by neighbouring enemy armies.
	var own: int = Rules.unit_total(army["units"])
	var threat: int = 0
	for n in Rules.neighbours(army["territory"]):
		if Rules.owner_of(s, n) != fid:
			for e in Rules.armies_at(s, n):
				threat += Rules.unit_total(e["units"])
	if threat > own:
		return
	var step: Array = _next_step(s, army)
	if step.size() == 2 and Rules.can_move(s, army, step[0]):
		# Only advance if we could plausibly win at the objective.
		var objective: String = step[1]
		var ratio2: float = float(Rules.battle_preview(s, army, objective, "balanced")["ratio"])
		if ratio2 >= base_need * 0.75:
			var from_name: String = Game.territories[army["territory"]]["name"]
			Rules.move_army(s, army, step[0])
			Rules.add_log(s, "%s army #%d moved from %s to %s." % [
				Game.factions[fid]["short_name"], int(army["id"]), from_name,
				Game.territories[step[0]]["name"]])


## Returns [next_step_tid, objective_tid] or [] if none (or if the next step is an attack).
static func _next_step(s: Dictionary, army: Dictionary) -> Array:
	var fid: String = army["owner"]
	var start: String = army["territory"]
	var parent: Dictionary = {start: ""}
	var queue: Array = [start]
	var goal: String = ""
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur != start and Rules.owner_of(s, cur) != fid:
			goal = cur
			break
		for n in Rules.neighbours(cur):
			if not parent.has(n):
				parent[n] = cur
				queue.append(n)
	if goal == "":
		return []
	var node: String = goal
	while parent[node] != start and parent[node] != "":
		node = parent[node]
	if node == goal:
		return []   # adjacent enemy: handled as an attack decision
	return [node, goal]


static func _recruit(s: Dictionary, fid: String) -> void:
	var every: int = int(RECRUIT_EVERY.get(str(s.get("difficulty", "normal")), 2))
	if int(s["turn"]) % every != 0:
		return
	var best_tid: String = ""
	var best_d: int = 999
	for tid in s["territories"]:
		if s["territories"][tid]["owner"] != fid:
			continue
		if not Rules.is_source(s, fid, tid):
			continue
		var d: int = Rules.distance_to_enemy(s, fid, tid)
		if d < best_d:
			best_d = d
			best_tid = tid
	if best_tid == "":
		return
	var pick: Array = ["infantry", "infantry", "cavalry"]
	var ut: String = pick[int(s["turn"]) % 3]
	if int(s["turn"]) % 6 == 0 and int(s["factions"][fid]["gold"]) >= 45:
		ut = "artillery"
	var res: Dictionary = Rules.recruit(s, fid, best_tid, ut)
	if not res["ok"]:
		Rules.recruit(s, fid, best_tid, "infantry")
