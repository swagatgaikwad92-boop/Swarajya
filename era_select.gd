extends Control

func _on_start_era1() -> void:
	GameState.selected_campaign_path = "res://data/campaigns/campaign_pratapgad.json"
	GameState.start_campaign()
	get_tree().change_scene_to_file("res://scenes/campaign_map.tscn")

func _on_start_era2() -> void:
	GameState.selected_campaign_path = "res://data/campaigns/campaign_peshwa.json"
	GameState.start_campaign()
	get_tree().change_scene_to_file("res://scenes/campaign_map.tscn")

func _on_start_era3() -> void:
	GameState.selected_campaign_path = "res://data/campaigns/campaign_confederacy.json"
	GameState.start_campaign()
	get_tree().change_scene_to_file("res://scenes/campaign_map.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
