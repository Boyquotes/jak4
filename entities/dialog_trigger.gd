extends Area

export(Resource) var dialog_sequence
export(NodePath) var main_speaker

func _ready():
	var _x = connect("body_entered", self, "_on_body_entered")

func _on_body_entered(body):
	if !(body is PlayerBody):
		print_debug("BUG: Non-player triggered dialog node ", get_path())
		return
	if body.can_talk():
		body.start_dialog(self, dialog_sequence, get_node(main_speaker))
