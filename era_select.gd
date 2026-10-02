extends Control
## Era selection. Only Era 1 is playable in v0.1; Eras 2 and 3 are shown as planned.

const UiKit = preload("res://scripts/ui/ui_kit.gd")


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.INK
	add_child(bg)
	UiKit.full_rect(bg)
	var m := MarginContainer.new()
	add_child(m)
	UiKit.full_rect(m)
	UiKit.margin(m, 32)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	m.add_child(box)

	box.add_child(UiKit.label("Choose an Era", 44, UiKit.GOLD))

	var sc: Dictionary = Game.scenario
	box.add_child(_card(str(sc["era"]["title"]), str(sc["era"]["summary"]), true))
	box.add_child(_card("Era 2: Expansion (planned)", "Not in this build.", false))
	box.add_child(_card("Era 3: Confederacy and later period (planned)", "Not in this build.", false))

	box.add_child(UiKit.label("Campaign: " + str(sc["title"]), 28, UiKit.TEXT))
	box.add_child(UiKit.label(str(sc["period"]), 20, UiKit.MUTED))
	var brief := UiKit.rich(0, 21)
	brief.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brief.text = str(sc["briefing"]) + "\n\n[b]Win:[/b] hold Torna, Rajgad, Kondana and Purandar at the same time.\n[b]Lose:[/b] lose Pune and Maval, let stability fall to zero, run out of armies and means, or run out of time (24 turns).\n\n[i]Historical dates for these events are disputed; see the in-game Codex for confidence tags.[/i]"
	box.add_child(brief)

	var begin := UiKit.button("Begin Campaign", 76, 30)
	begin.pressed.connect(_on_begin)
	box.add_child(begin)
	var back := UiKit.button("Back", 60, 24)
	back.pressed.connect(func(): Game.goto("main_menu"))
	box.add_child(back)


func _card(title: String, text: String, enabled: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var col: Color = UiKit.GOLD if enabled else Color("#4a3f31")
	p.add_theme_stylebox_override("panel", UiKit.style(UiKit.INK_LIGHT, col, 12, 3 if enabled else 1))
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UiKit.label(title, 26, UiKit.TEXT if enabled else UiKit.MUTED))
	v.add_child(UiKit.label(text, 19, UiKit.MUTED))
	return p


func _on_begin() -> void:
	Game.start_new_campaign()
	Game.goto("game")
