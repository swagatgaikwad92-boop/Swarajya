extends Control

func _ready() -> void:
	var text := "HISTORICAL ATLAS (slice)\nNumbers elsewhere in the game are gameplay abstractions.\n\n"
	text += "ERA I — Rise of Swarajya (c. 1645–1680)\nConfidence: high on the broad outline, medium on exact sequences used in this scenario.\n\n"
	text += "FORTS\n"
	text += "Raigad — later capital; coronation site in 1674. Confidence: high.\n"
	text += "Pratapgad — associated with the 1659 encounter with Afzal Khan. Confidence: high that the encounter happened; troop numbers disputed.\n"
	text += "Torna — traditionally among the early forts taken (often dated 1646). Confidence: medium on exact circumstances.\n"
	text += "Sinhagad — important fort near Pune, repeatedly contested. The later Tanaji assault is outside this slice. Confidence: high.\n\n"
	text += "COMMANDERS\n"
	text += "Shivaji (1630–1680) — founder of Swarajya, Chhatrapati from 1674. Confidence: high.\n"
	text += "Afzal Khan (d. 1659) — Adil Shahi noble killed at Pratapgad. Used here as the opposing commander abstraction. Confidence: medium on motive and force size.\n\n"
	text += "This codex does not invent citations. Consult Gordon, Eaton, and Marathi bakhars (the latter with caution) for the period.\n"
	$Body.text = text

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
