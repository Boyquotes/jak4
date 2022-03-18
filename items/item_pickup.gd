extends Area

export(String) var item_id
export(int) var quantity = 1
export(PackedScene) var preview
export(bool) var persistent := true

func _ready():
	if persistent and Global.is_picked(get_path()):
		get_parent().remove_child(self)
		queue_free()
		return
	connect("body_entered", self, "_on_body_entered")

func _on_body_entered(_b):
	Global.add_item(item_id)
	if persistent:
		Global.mark_picked(get_path())
	queue_free()
