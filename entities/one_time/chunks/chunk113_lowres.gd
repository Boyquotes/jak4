tool
extends Chunk

func _ready():
	if Global.stat("capacitor_113"):
		get_tree().call_group("113_delete", "queue_free")
	else:
		get_tree().call_group("113_fallen_only", "queue_free")