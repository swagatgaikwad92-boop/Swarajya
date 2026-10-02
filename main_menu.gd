extends Control

func _ready() -> void:
	$VBox/Continue.disabled = not GameState.has_save()

func _on_new_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/era_select.tscn")

func _on_continue_pressed() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/campaign_map.tscn")

func _on_codex() -> void:
	get_tree().change_scene_to_file("res://scenes/codex.tscn")
