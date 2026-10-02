extends Control

var selected_army_id: String = ""
var selected_territory: String = ""

func _ready() -> void:
	_build_map()
	_refresh()

func _build_map() -> void:
	var layer := $MapLayer
	for c in layer.get_children():
		c.queue_free()
	for t in GameState.territories:
		var b := Button.new()
		b.position = Vector2(float(t["pos"][0]), float(t["pos"][1]))
		b.custom_minimum_size = Vector2(130, 74)
		b.set_meta("tid", t["id"])
		b.pressed.connect(_on_territory.bind(t["id"]))
		layer.add_child(b)

func _army_by_id(aid: String) -> Dictionary:
	for a in GameState.armies:
		if a.get("id") == aid:
			return a
	return {}

func _on_territory(tid: String) -> void:
	selected_territory = tid
	selected_army_id = ""
	for a in GameState.armies_at(tid):
		if a["owner"] == GameState.player_faction:
			selected_army_id = a["id"]
			break
	_refresh()

func _refresh() -> void:
	$EndPanel.visible = GameState.phase == "over"
	if GameState.phase == "over":
		$EndPanel/VBox/Title.text = "PLAYER OUTCOME: " + GameState.outcome.to_upper()
		$EndPanel/VBox/Detail.text = GameState.outcome_detail
		$EndPanel/VBox/Historical.text = "HISTORICAL OUTCOME\n" + str(GameState.campaign.get("historical_outcome", ""))
	$TopBar/Year.text = "Year %d    Turn %d / %d" % [GameState.year, GameState.turn, GameState.max_turns]
	$TopBar/Res.text = "Revenue %d    Manpower %d    Stability %d (gameplay)" % [GameState.revenue, GameState.manpower, GameState.stability]
	for b in $MapLayer.get_children():
		var tid := str(b.get_meta("tid"))
		var t := GameState.territory_by_id(tid)
		var fac := GameState.faction_by_id(str(t.get("owner", "")))
		var col := Color(fac.get("color", "#666666"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.4)
		sb.border_color = Color(0.95, 0.85, 0.6) if tid == selected_territory else col.lightened(0.2)
		sb.set_border_width_all(3 if tid == selected_territory else 1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
		b.add_theme_font_size_override("font_size", 13)
		var fort := GameState.fort_for_territory(tid)
		var visible := GameState.is_visible(tid)
		var mark := " *" if (not fort.is_empty() and visible) else ""
		var n_armies := GameState.armies_at(tid).size() if visible else 0
		var am := ("\narmy x%d" % n_armies) if n_armies > 0 else ""
		if not visible:
			b.text = "Unknown"
			sb.bg_color = Color(0.15, 0.14, 0.13)
		else:
			b.text = str(t.get("name", tid)) + mark + "\n" + str(t.get("terrain", "")) + am
	var army := _army_by_id(selected_army_id)
	var info := "Tap a territory.\nGold = Swarajya, red = Adil Shahi.\n* marks a fort.\n\nHISTORICAL BACKGROUND\n" + str(GameState.campaign.get("historical_background", ""))
	if selected_territory != "":
		var t := GameState.territory_by_id(selected_territory)
		var fort := GameState.fort_for_territory(selected_territory)
		info = "%s\nOwner: %s\nTerrain: %s\nRevenue: %s (gameplay number)\n" % [t.get("name"), t.get("owner"), t.get("terrain"), str(t.get("revenue"))]
		if not fort.is_empty():
			info += "\nFORT %s\nGameplay defense %s, supply +%s\nHISTORICAL: %s\nConfidence: %s\n" % [
				fort.get("name"), str(fort.get("defense")), str(fort.get("supply")),
				fort.get("historical_significance"), fort.get("confidence")]
		if not army.is_empty():
			var cmd := GameState.commander_by_id(str(army.get("commander", "")))
			info += "\nARMY %s\nCommander: %s\nUnits: %s\nMP %s  Morale %s  Supply %s\nStrength %s (gameplay)\n" % [
				army.get("id"), cmd.get("name", "-"), ", ".join(army.get("units", [])),
				str(army.get("mp")), str(army.get("morale")), str(army.get("supply")),
				str(GameState.strength_of(army))]
			info += "HISTORICAL RECORD: %s\nConfidence: %s\nGAMEPLAY traits: %s\n" % [
				cmd.get("historical_biography", ""), cmd.get("confidence", ""), str(cmd.get("gameplay_traits", []))]
	$Side/Info.text = info
	var logtxt := ""
	var lines: Array = GameState.log_lines
	var start := maxi(0, lines.size() - 8)
	for i in range(start, lines.size()):
		logtxt += str(lines[i]) + "\n"
	$Side/Log.text = logtxt
	_rebuild_actions(army)

func _rebuild_actions(army: Dictionary) -> void:
	var box := $Side/Actions
	for c in box.get_children():
		c.queue_free()
	if army.is_empty():
		var hint := Label.new()
		hint.text = "Select a territory that holds your army."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)
		return
	var origin := str(army.get("territory", ""))
	for nid in GameState.neighbours_of(origin):
		var nt := GameState.territory_by_id(nid)
		var hostile := false
		for a in GameState.armies_at(nid):
			if a["owner"] != GameState.player_faction:
				hostile = true
		var enemy_owner := nt.get("owner") != GameState.player_faction
		if hostile or enemy_owner:
			for tactic in ["aggressive", "defensive", "harass"]:
				var btn := Button.new()
				btn.text = "Attack %s (%s)" % [nt.get("name"), tactic]
				btn.pressed.connect(_do_attack.bind(nid, tactic))
				box.add_child(btn)
		if not hostile:
			var mv := Button.new()
			mv.text = "Move to %s" % nt.get("name")
			mv.pressed.connect(_do_move.bind(nid))
			box.add_child(mv)
	var ri := Button.new()
	ri.text = "Recruit infantry (40)"
	ri.pressed.connect(_do_recruit.bind("infantry"))
	box.add_child(ri)
	var rc := Button.new()
	rc.text = "Recruit light cavalry (55)"
	rc.pressed.connect(_do_recruit.bind("light_cavalry"))
	box.add_child(rc)

func _do_move(nid: String) -> void:
	var army := _army_by_id(selected_army_id)
	if army.is_empty():
		return
	var msg := GameState.move_army(army, nid)
	GameState.log_lines.append(msg)
	_refresh()

func _do_attack(nid: String, tactic: String) -> void:
	var army := _army_by_id(selected_army_id)
	if army.is_empty():
		return
	GameState.attack(army, nid, tactic)
	_refresh()

func _do_recruit(uid: String) -> void:
	var army := _army_by_id(selected_army_id)
	if army.is_empty():
		return
	var msg := GameState.recruit(army, uid)
	GameState.log_lines.append(msg)
	_refresh()

func _on_end_turn() -> void:
	GameState.end_player_turn()
	_refresh()

func _on_save() -> void:
	GameState.log_lines.append(GameState.save_game())
	_refresh()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_peace() -> void:
	GameState.log_lines.append(GameState.propose_peace())
	_refresh()

func _on_war() -> void:
	GameState.log_lines.append(GameState.declare_war())
	_refresh()
