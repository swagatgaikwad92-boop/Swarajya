extends Control

func _on_start() -> void:
	GameState.start_campaign()
	get_tree().change_scene_to_file("res://scenes/campaign_map.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
