extends Position3D

func _ready():
	if !Global.valid_game_state && !Global.player_spawned:
		var p = get_player()
		if p:
			p.global_transform.origin = global_transform.origin
		Global.player_spawned = true

func get_player():
	return get_tree().current_scene.get_node("player")
