extends Control

func _ready() -> void:
	var text := "HISTORICAL ATLAS (slice)\nGameplay numbers elsewhere are abstractions.\n\n"
	text += "ERA I — Rise of Swarajya. Forts: Raigad, Pratapgad, Torna, Sinhagad.\n\n"
	text += "ERA II — Maratha Expansion. Peshwa cavalry pressure vs the Nizam. Palkhed referenced, not simulated.\n\n"
	text += "ERA III — Confederacy. Scindia / Holkar houses and Company pressure. Abstraction of competing interests, not a single Anglo-Maratha war.\n\n"
	text += "Confidence medium on simplified relationships. Consult Gordon, Eaton, and critical Marathi / Company sources.\n"
	$Body.text = text

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
